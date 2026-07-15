-- ============================================================
-- Migration: replace is_admin boolean with flags smallint
-- Bit 0 (value 1): can edit tricks (replaces is_admin)
-- Run in Supabase SQL Editor.
-- ============================================================

-- 1. Drop all policies that reference is_admin BEFORE touching the column
drop policy if exists "positions_insert" on positions;
drop policy if exists "positions_update" on positions;
drop policy if exists "positions_delete" on positions;
drop policy if exists "tricks_read_admin" on tricks;
drop policy if exists "tricks_update_admin" on tricks;
drop policy if exists "tricks_delete_admin" on tricks;

-- 2. Add the new column
alter table profiles add column flags smallint not null default 0;

-- 3. Copy existing is_admin values into bit 0
update profiles set flags = 1 where is_admin = true;

-- 4. Drop the old column (no dependents remain)
alter table profiles drop column is_admin;

-- 5. Recreate RLS policies for positions
create policy "positions_insert" on positions for insert with check (
  exists (select 1 from profiles where id = auth.uid() and (flags & 1) = 1)
);
create policy "positions_update" on positions for update using (
  exists (select 1 from profiles where id = auth.uid() and (flags & 1) = 1)
);
create policy "positions_delete" on positions for delete using (
  exists (select 1 from profiles where id = auth.uid() and (flags & 1) = 1)
);

-- 6. Recreate RLS policies for tricks
create policy "tricks_read_admin" on tricks for select
  using (exists (select 1 from profiles where id = auth.uid() and (flags & 1) = 1));
create policy "tricks_update_admin" on tricks for update
  using (exists (select 1 from profiles where id = auth.uid() and (flags & 1) = 1));
create policy "tricks_delete_admin" on tricks for delete
  using (exists (select 1 from profiles where id = auth.uid() and (flags & 1) = 1));

-- 7. Update the new-user trigger function
create or replace function handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, username, flags)
  values (new.id, new.raw_user_meta_data->>'username', 0);
  return new;
end;
$$;
