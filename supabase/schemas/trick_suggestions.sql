-- Trick suggestions: sparse proposed edits to approved tricks.
-- Only changed fields are stored; null means "no change to this field".
-- Approved rows are deleted after applying the delta; rejected rows deleted outright.
create table trick_suggestions (
  id                     integer generated always as identity primary key,
  trick_id               integer not null references tricks(id) on delete cascade,
  given_name             text,
  technical_name         text,
  difficulty_tier        smallint check (difficulty_tier = -1 or difficulty_tier between 1 and 30),
  date_performed         date,
  original_performer     text,
  prerequisite_trick_ids integer[],
  base_trick_ids         integer[],
  description            text,
  tips                   text,
  video_link             text,
  video_start            integer,
  video_end              integer,
  start_position_id      smallint references positions(id),
  end_position_id        smallint references positions(id),
  submitted_by           integer references profiles(int_id) on delete set null,
  date_submitted         timestamptz not null default now()
);
