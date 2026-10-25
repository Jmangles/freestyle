-- Minimal pre-thread schema and Supabase auth/storage stand-ins for the
-- disposable regression harness. This is not a production migration.
create role authenticated;
create role anon;
create role service_role;
create schema auth;
create function auth.uid() returns uuid language sql stable as $$
  select current_setting('test.uid')::uuid
$$;
grant usage on schema auth to authenticated;

create table profiles (int_id integer primary key, id uuid, flags integer);
insert into profiles values
  (7, '00000000-0000-0000-0000-000000000007', 0),
  (8, '00000000-0000-0000-0000-000000000008', 0),
  (2, '00000000-0000-0000-0000-000000000002', 1);
grant select on profiles to authenticated;

create table feedback (
  id integer generated always as identity primary key,
  submitted_by integer references profiles(int_id),
  message text not null check (char_length(message) between 1 and 2000),
  attachment_paths text[],
  status text not null default 'new' constraint feedback_status_check
    check (status in ('new', 'reviewed', 'dismissed')),
  created_at timestamptz not null default now()
);
alter table feedback enable row level security;
create policy feedback_read_admin on feedback for select using (
  exists (select 1 from profiles where id = auth.uid() and (flags & 1) = 1)
);
create policy feedback_update_admin on feedback for update using (
  exists (select 1 from profiles where id = auth.uid() and (flags & 1) = 1)
);
grant select, insert, update on feedback to authenticated;

create schema storage;
create function storage.foldername(text) returns text[]
language sql immutable as $$
  select (string_to_array($1, '/'))[1:array_length(string_to_array($1, '/'), 1)-1]
$$;
create table storage.objects (bucket_id text, name text);
alter table storage.objects enable row level security;
grant usage on schema storage to authenticated;
grant select on storage.objects to authenticated;
create policy feedback_attachments_select on storage.objects
for select to authenticated using (
  bucket_id = 'feedback-attachments'
  and (
    (storage.foldername(name))[1] = (select int_id::text from profiles where id = auth.uid())
    or exists (select 1 from profiles where id = auth.uid() and (flags & 1) = 1)
  )
);
