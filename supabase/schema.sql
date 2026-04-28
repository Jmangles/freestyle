-- ============================================================
-- Freestyle Highline – Supabase Schema
-- Run this in the Supabase SQL Editor after creating a project.
-- ============================================================

-- Positions (e.g. Standing, Hanging, Sitting)
create table positions (
  id   smallint generated always as identity primary key,
  name text not null unique
);

-- User profiles (extends auth.users)
create table profiles (
  int_id   integer generated always as identity primary key,
  id       uuid unique not null references auth.users(id) on delete cascade,
  username text unique,
  is_admin boolean not null default false
);

-- Tricks
create table tricks (
  id                    integer generated always as identity primary key,
  given_name            text not null,
  technical_name        text,
  difficulty_tier       smallint not null check (difficulty_tier = -1 or difficulty_tier between 1 and 30),
  date_submitted        timestamptz not null default now(),
  date_performed        date,
  original_performer    text,
  prerequisite_trick_ids integer[] not null default '{}',
  description           text,
  tips                  text,
  video_link            text,
  start_position_id     smallint references positions(id),
  end_position_id       smallint references positions(id),
  status                smallint not null default 0 check (status between 0 and 2),
  submitted_by          integer references profiles(int_id) on delete set null
);

-- User trick tracking
create table user_tricks (
  id          integer generated always as identity primary key,
  user_id     integer not null references profiles(int_id) on delete cascade,
  trick_id    integer not null references tricks(id) on delete cascade,
  consistency smallint not null default 0 check (consistency between 0 and 5),
  unique(user_id, trick_id)
);

-- ============================================================
-- Row Level Security
-- ============================================================

alter table profiles    enable row level security;
alter table tricks      enable row level security;
alter table user_tricks enable row level security;
alter table positions   enable row level security;

-- Profiles
create policy "profiles_read"   on profiles for select using (true);
create policy "profiles_insert" on profiles for insert with check (auth.uid() = id);
create policy "profiles_update" on profiles for update using (auth.uid() = id);

-- Positions: anyone reads, only admins write
create policy "positions_read" on positions for select using (true);
create policy "positions_insert" on positions for insert with check (
  exists (select 1 from profiles where id = auth.uid() and is_admin = true)
);
create policy "positions_update" on positions for update using (
  exists (select 1 from profiles where id = auth.uid() and is_admin = true)
);
create policy "positions_delete" on positions for delete using (
  exists (select 1 from profiles where id = auth.uid() and is_admin = true)
);

-- Tricks: approved tricks are public; submitter can read own; admins can read/update all
create policy "tricks_read_approved" on tricks for select
  using (status = 1);
create policy "tricks_read_own" on tricks for select
  using (submitted_by = (select int_id from profiles where id = auth.uid()));
create policy "tricks_read_admin" on tricks for select
  using (exists (select 1 from profiles where id = auth.uid() and is_admin = true));
create policy "tricks_insert" on tricks for insert
  with check (submitted_by = (select int_id from profiles where id = auth.uid()));
create policy "tricks_update_admin" on tricks for update
  using (exists (select 1 from profiles where id = auth.uid() and is_admin = true));

-- User tricks: users manage only their own rows
create policy "user_tricks_select" on user_tricks for select
  using (user_id = (select int_id from profiles where id = auth.uid()));
create policy "user_tricks_insert" on user_tricks for insert
  with check (user_id = (select int_id from profiles where id = auth.uid()));
create policy "user_tricks_update" on user_tricks for update
  using (user_id = (select int_id from profiles where id = auth.uid()));
create policy "user_tricks_delete" on user_tricks for delete
  using (user_id = (select int_id from profiles where id = auth.uid()));

-- ============================================================
-- Grants
-- ============================================================

grant select                       on positions   to anon, authenticated;
grant select                       on tricks      to anon, authenticated;
grant insert                       on tricks      to authenticated;
grant update                       on tricks      to authenticated;
grant select                       on profiles    to anon, authenticated;
grant insert, update               on profiles    to authenticated;
grant select, insert, update, delete on user_tricks to authenticated;

-- ============================================================
-- Trigger: auto-create profile on sign-up
-- ============================================================

create or replace function handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, username, is_admin)
  values (new.id, new.raw_user_meta_data->>'username', false);
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();
