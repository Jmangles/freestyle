-- Feedback: in-app user feedback with optional screenshot/video attachment.
-- status: new/reviewed/dismissed. Attachment is deleted from storage once
-- an editor resolves the item (reviewed or dismissed) — nothing is kept
-- once the "issue" behind it is closed.
create table feedback (
  id              integer generated always as identity primary key,
  submitted_by    integer references profiles(int_id) on delete set null,
  message         text not null check (char_length(message) between 1 and 2000),
  attachment_path text,
  status          text not null default 'new' check (status in ('new', 'reviewed', 'dismissed')),
  created_at      timestamptz not null default now()
);

alter table feedback enable row level security;

create policy "feedback_insert" on feedback for insert
  with check (submitted_by = (select int_id from profiles where id = auth.uid()));
create policy "feedback_read_admin" on feedback for select
  using (exists (select 1 from profiles where id = auth.uid() and (flags & 1) = 1));
create policy "feedback_update_admin" on feedback for update
  using (exists (select 1 from profiles where id = auth.uid() and (flags & 1) = 1));

grant select, insert, update on feedback to authenticated;

-- Private bucket for feedback attachments, capped at 25MB per file.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'feedback-attachments',
  'feedback-attachments',
  false,
  26214400,
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif', 'video/mp4', 'video/webm', 'video/quicktime']
)
on conflict (id) do update set
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Uploads live under "<int_id>/<filename>" so ownership is just a path check.
create policy "feedback_attachments_insert" on storage.objects for insert to authenticated
  with check (
    bucket_id = 'feedback-attachments'
    and (storage.foldername(name))[1] = (select int_id::text from profiles where id = auth.uid())
  );

create policy "feedback_attachments_select" on storage.objects for select to authenticated
  using (
    bucket_id = 'feedback-attachments'
    and (
      (storage.foldername(name))[1] = (select int_id::text from profiles where id = auth.uid())
      or exists (select 1 from profiles where id = auth.uid() and (flags & 1) = 1)
    )
  );

create policy "feedback_attachments_delete_admin" on storage.objects for delete to authenticated
  using (
    bucket_id = 'feedback-attachments'
    and exists (select 1 from profiles where id = auth.uid() and (flags & 1) = 1)
  );
