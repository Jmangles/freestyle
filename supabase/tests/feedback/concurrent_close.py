"""Check that a reply waiting on a concurrent closure is rejected after commit."""

import subprocess
import time


def query(sql):
    return subprocess.check_output(
        ["psql", "-XAt", "-v", "ON_ERROR_STOP=1", "-c", sql], text=True
    ).strip()


def session():
    return subprocess.Popen(
        ["psql", "-XAtq", "-v", "ON_ERROR_STOP=1"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
    )


query("update feedback set status = 'new' where id = 1")
closer, reply = session(), session()
try:
    closer.stdin.write(
        "begin; update feedback set status = 'reviewed' where id = 1;\n"
        "select pg_backend_pid();\n"
    )
    closer.stdin.flush()
    closer_pid = int(closer.stdout.readline())
    reply.stdin.write("select pg_backend_pid();\n")
    reply.stdin.flush()
    reply_pid = int(reply.stdout.readline())
    reply.stdin.write(
        "set role authenticated;\n"
        "set test.uid = '00000000-0000-0000-0000-000000000002';\n"
        "insert into feedback_messages(feedback_id, author_id, body) "
        "values (1, 2, 'Concurrent reply must fail');\n"
    )
    reply.stdin.flush()

    # Observe a real lock wait, rather than relying on a timing-only sleep.
    deadline = time.monotonic() + 10
    while query(f"select {closer_pid} = any(pg_blocking_pids({reply_pid}))") != "t":
        if reply.poll() is not None or time.monotonic() > deadline:
            raise AssertionError("Reply did not wait for the thread lock")
        time.sleep(0.02)

    closer.stdin.write("commit;\n")
    closer.stdin.flush()
    closer.communicate(timeout=10)
    _, error = reply.communicate(timeout=10)
    assert reply.returncode != 0 and "feedback thread is closed" in error, error
    assert query(
        "select count(*) from feedback_messages "
        "where body = 'Concurrent reply must fail'"
    ) == "0"
    print("Concurrent closure regression passed")
finally:
    for process in (closer, reply):
        if process.poll() is None:
            process.kill()
        process.wait()
