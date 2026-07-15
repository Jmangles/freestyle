-- Tricks
-- flags: bit 0 = isCore, bit 1 = hasTrainingVideo
create table tricks (
  id                     integer generated always as identity primary key,
  given_name             text not null,
  technical_name         text,
  difficulty_tier        smallint not null check (difficulty_tier = -1 or difficulty_tier between 1 and 30),
  date_submitted         timestamptz not null default now(),
  date_performed         date,
  original_performer     text,
  prerequisite_trick_ids integer[] not null default '{}',
  base_trick_ids         integer[] not null default '{}',
  description            text,
  tips                   text,
  video_link             text,
  video_start            smallint,
  video_end              smallint,
  start_position_id      smallint references positions(id),
  end_position_id        smallint references positions(id),
  status                 smallint not null default 0 check (status between 0 and 2),
  submitted_by           integer references profiles(int_id) on delete set null,
  flags                  smallint not null default 0
);
