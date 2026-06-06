-- ============================================================
-- Freestyle Highline – Supabase Schema
-- Reflects full current state including all applied migrations.
-- Run this in the Supabase SQL Editor on a fresh project.
-- ============================================================

-- ============================================================
-- Tables
-- ============================================================

-- Positions (e.g. Standing, Hanging, Sitting)
create table positions (
  id   smallint generated always as identity primary key,
  name text not null unique
);

-- User profiles (extends auth.users)
-- flags: bit 0 = can edit tricks
create table profiles (
  int_id   integer generated always as identity primary key,
  id       uuid unique not null references auth.users(id) on delete cascade,
  username text unique,
  flags    smallint not null default 0
);

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

-- User trick tracking
create table user_tricks (
  id              integer generated always as identity primary key,
  user_id         integer not null references profiles(int_id) on delete cascade,
  trick_id        integer not null references tricks(id) on delete cascade,
  consistency     smallint not null default 0 check (consistency between 0 and 5),
  difficulty_vote smallint check (difficulty_vote between 1 and 30),
  leash_position  smallint check (leash_position between 0 and 2),
  video_link      text,
  video_start     smallint,
  video_end       smallint,
  updated_at      timestamptz not null default now(),
  unique(user_id, trick_id)
);

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

-- Tips: community-submitted general highlining tips (not trick-specific)
-- status: false = pending, true = approved
-- type: 0 = general, 1 = rigging, 2 = health
create table tips (
  id              integer generated always as identity primary key,
  title           text not null,
  header          text,
  body            text not null,
  status          boolean not null default false,
  type            smallint not null default 0 check (type between 0 and 2),
  submitted_on    date not null default current_date,
  submitted_by    integer references profiles(int_id) on delete set null,
  approved_on     date,
  approved_by     integer references profiles(int_id) on delete set null,
  last_updated    date,
  last_updated_by integer references profiles(int_id) on delete set null
);

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

-- ============================================================
-- Row Level Security
-- ============================================================

alter table profiles          enable row level security;
alter table tricks            enable row level security;
alter table user_tricks       enable row level security;
alter table positions         enable row level security;
alter table trick_suggestions enable row level security;
alter table tips              enable row level security;
alter table trick_annotations enable row level security;

-- Profiles
create policy "profiles_read"   on profiles for select using (true);
create policy "profiles_insert" on profiles for insert with check (auth.uid() = id);
create policy "profiles_update" on profiles for update using (auth.uid() = id);

-- Positions: anyone reads, only editors write
create policy "positions_read"   on positions for select using (true);
create policy "positions_insert" on positions for insert with check (
  exists (select 1 from profiles where id = auth.uid() and (flags & 1) = 1)
);
create policy "positions_update" on positions for update using (
  exists (select 1 from profiles where id = auth.uid() and (flags & 1) = 1)
);
create policy "positions_delete" on positions for delete using (
  exists (select 1 from profiles where id = auth.uid() and (flags & 1) = 1)
);

-- Tricks: approved tricks are public; submitter can read own; editors can read/write all
create policy "tricks_read_approved" on tricks for select using (status = 1);
create policy "tricks_read_own"      on tricks for select
  using (submitted_by = (select int_id from profiles where id = auth.uid()));
create policy "tricks_read_admin"    on tricks for select
  using (exists (select 1 from profiles where id = auth.uid() and (flags & 1) = 1));
create policy "tricks_insert"        on tricks for insert
  with check (submitted_by = (select int_id from profiles where id = auth.uid()));
create policy "tricks_update_admin"  on tricks for update
  using (exists (select 1 from profiles where id = auth.uid() and (flags & 1) = 1));
create policy "tricks_delete_admin"  on tricks for delete
  using (exists (select 1 from profiles where id = auth.uid() and (flags & 1) = 1));

-- User tricks: users manage only their own rows
create policy "user_tricks_select" on user_tricks for select
  using (user_id = (select int_id from profiles where id = auth.uid()));
create policy "user_tricks_insert" on user_tricks for insert
  with check (user_id = (select int_id from profiles where id = auth.uid()));
create policy "user_tricks_update" on user_tricks for update
  using (user_id = (select int_id from profiles where id = auth.uid()));
create policy "user_tricks_delete" on user_tricks for delete
  using (user_id = (select int_id from profiles where id = auth.uid()));

-- Trick suggestions
create policy "suggestions_insert" on trick_suggestions for insert
  with check (submitted_by = (select int_id from profiles where id = auth.uid()));
create policy "suggestions_read_own" on trick_suggestions for select
  using (submitted_by = (select int_id from profiles where id = auth.uid()));
create policy "suggestions_read_admin" on trick_suggestions for select
  using (exists (select 1 from profiles where id = auth.uid() and (flags & 1) = 1));
create policy "suggestions_delete_admin" on trick_suggestions for delete
  using (exists (select 1 from profiles where id = auth.uid() and (flags & 1) = 1));

-- Tips
create policy "tips_read_approved" on tips for select using (status = true);
create policy "tips_read_own"      on tips for select
  using (submitted_by = (select int_id from profiles where id = auth.uid()));
create policy "tips_read_admin"    on tips for select
  using (exists (select 1 from profiles where id = auth.uid() and (flags & 1) = 1));
create policy "tips_insert"        on tips for insert
  with check (auth.uid() is not null and status = false);
create policy "tips_update_admin"  on tips for update
  using (exists (select 1 from profiles where id = auth.uid() and (flags & 1) = 1));
create policy "tips_delete_admin"  on tips for delete
  using (exists (select 1 from profiles where id = auth.uid() and (flags & 1) = 1));

-- Trick annotations: anyone reads, only editors write
create policy "annotations_read"   on trick_annotations for select using (true);
create policy "annotations_insert" on trick_annotations for insert
  with check (exists (select 1 from profiles where id = auth.uid() and (flags & 1) = 1));
create policy "annotations_update" on trick_annotations for update
  using (exists (select 1 from profiles where id = auth.uid() and (flags & 1) = 1));
create policy "annotations_delete" on trick_annotations for delete
  using (exists (select 1 from profiles where id = auth.uid() and (flags & 1) = 1));

-- ============================================================
-- Grants
-- ============================================================

grant select                         on positions       to anon, authenticated;
grant select                         on tricks          to anon, authenticated;
grant insert, update                 on tricks          to authenticated;
grant select                         on profiles        to anon, authenticated;
grant insert, update                 on profiles        to authenticated;
grant select, insert, update, delete on user_tricks     to authenticated;
grant select, insert, delete         on trick_suggestions to authenticated;
grant select                         on tips            to anon, authenticated;
grant insert                         on tips            to authenticated;
grant update, delete                 on tips            to authenticated;
grant select                         on trick_annotations to anon, authenticated;
grant insert, update, delete         on trick_annotations to authenticated;
grant usage, select on sequence trick_annotations_id_seq to authenticated;

-- ============================================================
-- Functions
-- ============================================================

create or replace function touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end;
$$;

create trigger user_tricks_updated_at
  before update on user_tricks
  for each row execute function touch_updated_at();

create or replace function get_trick_vote_stats(p_trick_id integer)
returns json language sql security definer as $$
  select json_build_object(
    'difficulty_votes', coalesce((
      select json_object_agg(difficulty_vote::text, cnt)
      from (
        select difficulty_vote, count(*) as cnt
        from user_tricks
        where trick_id = p_trick_id and difficulty_vote is not null
        group by difficulty_vote
      ) t
    ), '{}'),
    'leash_positions', coalesce((
      select json_object_agg(leash_position::text, cnt)
      from (
        select leash_position, count(*) as cnt
        from user_tricks
        where trick_id = p_trick_id and leash_position is not null
        group by leash_position
      ) t
    ), '{}')
  );
$$;

grant execute on function get_trick_vote_stats(integer) to anon, authenticated;

-- ============================================================
-- Trigger: auto-create profile on sign-up
-- ============================================================

create or replace function handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, username, flags)
  values (new.id, new.raw_user_meta_data->>'username', 0);
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- ============================================================
-- Trigger: clean up array references when a trick is deleted
-- ============================================================

create or replace function remove_deleted_trick_refs()
returns trigger language plpgsql as $$
begin
  update tricks
  set prerequisite_trick_ids = array_remove(prerequisite_trick_ids, old.id),
      base_trick_ids          = array_remove(base_trick_ids, old.id)
  where old.id = any(prerequisite_trick_ids)
     or old.id = any(base_trick_ids);
  return old;
end;
$$;

create trigger on_trick_deleted
  before delete on tricks
  for each row execute function remove_deleted_trick_refs();
