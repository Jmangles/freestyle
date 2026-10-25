#!/usr/bin/env bash
# Targeted PostgreSQL/RLS regression harness, not a full Supabase integration test.
# Requires initdb, pg_ctl, psql, python3. Never connects to an existing database.
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
db=$(mktemp -d)
cleanup() {
  pg_ctl -D "$db/data" -m immediate -w stop >/dev/null 2>&1 || true
  rm -rf "$db"
}
trap cleanup EXIT
initdb -D "$db/data" -A trust --no-locale >"$db/init.log"
pg_ctl -D "$db/data" -l "$db/server.log" \
  -o "-k $db -c listen_addresses=''" -w start >/dev/null
run_sql() { psql -X -h "$db" -U "$(id -un)" -d postgres -v ON_ERROR_STOP=1 "$@"; }
run_sql -f "$root/supabase/tests/feedback/setup.sql" >"$db/setup.log"
for migration in "$root"/supabase/migrations/202608*feedback*.sql; do
  run_sql -f "$migration" >>"$db/setup.log"
done
run_sql -f "$root/supabase/tests/feedback/assertions.sql"
PGHOST="$db" PGPORT=5432 PGDATABASE=postgres PGUSER="$(id -un)" \
  python3 "$root/supabase/tests/feedback/concurrent_close.py"
