-- User trick tracking
-- consistency: 0 = never tried, 1 = attempting .. 6 = always (see migration 20260715120000)
create table user_tricks (
  id              integer generated always as identity primary key,
  user_id         integer not null references profiles(int_id) on delete cascade,
  trick_id        integer not null references tricks(id) on delete cascade,
  consistency     smallint not null default 0 check (consistency between 0 and 6),
  difficulty_vote smallint check (difficulty_vote between 1 and 30),
  leash_position  smallint check (leash_position between 0 and 2),
  video_link      text,
  video_start     smallint,
  video_end       smallint,
  updated_at      timestamptz not null default now(),
  unique(user_id, trick_id)
);
