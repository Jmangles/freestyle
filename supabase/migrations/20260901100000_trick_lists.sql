-- Private, user-owned trick lists.
-- sort_mode: 0 = custom, 1 = difficulty, 2 = checked, 3 = date added
-- position is the persisted custom order and is kept even while another
-- sort mode is active.

create table trick_lists (
  id              integer generated always as identity primary key,
  user_id         integer not null references profiles(int_id) on delete cascade,
  name            text not null check (char_length(btrim(name)) between 1 and 100),
  sort_mode       smallint not null default 0 check (sort_mode between 0 and 3),
  sort_descending boolean not null default false,
  created_at      timestamptz not null default now()
);

create index trick_lists_user_idx on trick_lists(user_id);

create table trick_list_items (
  id       integer generated always as identity primary key,
  list_id  integer not null references trick_lists(id) on delete cascade,
  trick_id integer not null references tricks(id) on delete cascade,
  checked  boolean not null default false,
  position integer not null default 0,
  added_at timestamptz not null default now(),
  unique(list_id, trick_id)
);

create index trick_list_items_trick_idx on trick_list_items(trick_id);

alter table trick_lists      enable row level security;
alter table trick_list_items enable row level security;

create policy "trick_lists_select" on trick_lists for select
  using (user_id = (select int_id from profiles where id = auth.uid()));
create policy "trick_lists_insert" on trick_lists for insert
  with check (user_id = (select int_id from profiles where id = auth.uid()));
create policy "trick_lists_update" on trick_lists for update
  using (user_id = (select int_id from profiles where id = auth.uid()))
  with check (user_id = (select int_id from profiles where id = auth.uid()));
create policy "trick_lists_delete" on trick_lists for delete
  using (user_id = (select int_id from profiles where id = auth.uid()));

create policy "trick_list_items_select" on trick_list_items for select
  using (exists (select 1 from trick_lists l
    where l.id = list_id
      and l.user_id = (select int_id from profiles where id = auth.uid())));
create policy "trick_list_items_insert" on trick_list_items for insert
  with check (exists (select 1 from trick_lists l
    where l.id = list_id
      and l.user_id = (select int_id from profiles where id = auth.uid())));
create policy "trick_list_items_update" on trick_list_items for update
  using (exists (select 1 from trick_lists l
    where l.id = list_id
      and l.user_id = (select int_id from profiles where id = auth.uid())))
  with check (exists (select 1 from trick_lists l
    where l.id = list_id
      and l.user_id = (select int_id from profiles where id = auth.uid())));
create policy "trick_list_items_delete" on trick_list_items for delete
  using (exists (select 1 from trick_lists l
    where l.id = list_id
      and l.user_id = (select int_id from profiles where id = auth.uid())));

grant select, insert, update, delete on trick_lists      to authenticated;
grant select, insert, update, delete on trick_list_items to authenticated;
