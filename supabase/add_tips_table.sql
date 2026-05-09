-- ============================================================
-- Tips: community-submitted tips for freestyle highlining.
-- Not trick-specific. Requires admin approval before being visible.
-- ============================================================

create table tips (
  id              integer generated always as identity primary key,
  title           text not null,
  header          text not null,
  body            text not null,
  status          boolean not null default false,      -- false = pending, true = approved
  type            smallint not null default 0          -- 0=general, 1=rigging, 2=health
                    check (type between 0 and 2),
  submitted_on    date not null default current_date,
  submitted_by    integer references profiles(int_id) on delete set null,
  approved_on     date,
  approved_by     integer references profiles(int_id) on delete set null,
  last_updated    date,
  last_updated_by integer references profiles(int_id) on delete set null
);

alter table tips enable row level security;

-- Anyone can read approved tips
create policy "tips_read_approved" on tips for select
  using (status = true);

-- Authenticated users can read their own pending tips
create policy "tips_read_own" on tips for select
  using (submitted_by = (select int_id from profiles where id = auth.uid()));

-- Admins can read all tips (including pending)
create policy "tips_read_admin" on tips for select
  using (exists (select 1 from profiles where id = auth.uid() and (flags & 1) = 1));

-- Authenticated users can submit tips (always inserted as pending)
create policy "tips_insert" on tips for insert
  with check (
    auth.uid() is not null
    and status = false
  );

-- Admins can update any tip (approve, edit)
create policy "tips_update_admin" on tips for update
  using (exists (select 1 from profiles where id = auth.uid() and (flags & 1) = 1));

-- Admins can delete any tip (decline)
create policy "tips_delete_admin" on tips for delete
  using (exists (select 1 from profiles where id = auth.uid() and (flags & 1) = 1));

-- Grants
grant select         on tips to anon, authenticated;
grant insert         on tips to authenticated;
grant update, delete on tips to authenticated;
