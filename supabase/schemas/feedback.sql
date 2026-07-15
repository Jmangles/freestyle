-- Feedback: in-app user feedback with optional screenshot/video attachment.
-- status: new/reviewed/dismissed. Attachment is deleted from storage once
-- an editor resolves the item (reviewed or dismissed).
create table feedback (
  id              integer generated always as identity primary key,
  submitted_by    integer references profiles(int_id) on delete set null,
  message         text not null check (char_length(message) between 1 and 2000),
  attachment_paths text[],
  status          text not null default 'new' check (status in ('new', 'reviewed', 'dismissed')),
  created_at      timestamptz not null default now()
);
