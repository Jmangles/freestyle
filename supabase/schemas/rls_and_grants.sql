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
grant insert, update, delete         on positions       to authenticated;
grant select                         on tricks          to anon, authenticated;
grant insert, update, delete         on tricks          to authenticated;
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
grant execute on function get_trick_vote_stats(integer) to anon, authenticated;
