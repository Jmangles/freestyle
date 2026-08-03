-- Feedback: a threaded conversation between one user and the admins.
-- The feedback row is the thread head; every message, including the user's
-- first one, lives in feedback_messages.
-- status: new (waiting on an admin) / answered (waiting on the user) /
-- reviewed / dismissed. The last two are terminal: the thread goes read-only
-- and its attachments are deleted from storage.
create table feedback (
  id                integer generated always as identity primary key,
  submitted_by      integer references profiles(int_id) on delete set null,
  status            text not null default 'new'
                      check (status in ('new', 'answered', 'reviewed', 'dismissed')),
  created_at        timestamptz not null default now(),
  user_last_read_at timestamptz,
  last_message_at   timestamptz not null default now()
);

create index feedback_submitted_by_idx on feedback (submitted_by);

create table feedback_messages (
  id               integer generated always as identity primary key,
  feedback_id      integer not null references feedback(id) on delete cascade,
  author_id        integer references profiles(int_id) on delete set null,
  body             text not null check (char_length(body) between 1 and 2000),
  attachment_paths text[],
  created_at       timestamptz not null default now()
);

create index feedback_messages_thread_idx on feedback_messages (feedback_id, created_at);
