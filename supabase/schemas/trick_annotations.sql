-- Trick annotations: editor-placed time-windowed text overlays for the training studio
create table trick_annotations (
  id         serial primary key,
  trick_id   int not null references tricks(id) on delete cascade,
  start_ms   int not null,
  end_ms     int not null,
  text       text not null,
  created_by int not null references profiles(int_id),
  created_at timestamptz not null default now(),
  language   text not null default 'en'
);
