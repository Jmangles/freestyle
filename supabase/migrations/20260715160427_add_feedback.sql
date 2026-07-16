
  create table "public"."feedback" (
    "id" integer generated always as identity not null,
    "submitted_by" integer,
    "message" text not null,
    "attachment_path" text,
    "status" text not null default 'new'::text,
    "created_at" timestamp with time zone not null default now()
      );


alter table "public"."feedback" enable row level security;

CREATE UNIQUE INDEX feedback_pkey ON public.feedback USING btree (id);

alter table "public"."feedback" add constraint "feedback_pkey" PRIMARY KEY using index "feedback_pkey";

alter table "public"."feedback" add constraint "feedback_message_check" CHECK (((char_length(message) >= 1) AND (char_length(message) <= 2000))) not valid;

alter table "public"."feedback" validate constraint "feedback_message_check";

alter table "public"."feedback" add constraint "feedback_status_check" CHECK ((status = ANY (ARRAY['new'::text, 'reviewed'::text, 'dismissed'::text]))) not valid;

alter table "public"."feedback" validate constraint "feedback_status_check";

alter table "public"."feedback" add constraint "feedback_submitted_by_fkey" FOREIGN KEY (submitted_by) REFERENCES public.profiles(int_id) ON DELETE SET NULL not valid;

alter table "public"."feedback" validate constraint "feedback_submitted_by_fkey";

grant references on table "public"."feedback" to "anon";

grant trigger on table "public"."feedback" to "anon";

grant truncate on table "public"."feedback" to "anon";

grant insert on table "public"."feedback" to "authenticated";

grant references on table "public"."feedback" to "authenticated";

grant select on table "public"."feedback" to "authenticated";

grant trigger on table "public"."feedback" to "authenticated";

grant truncate on table "public"."feedback" to "authenticated";

grant update on table "public"."feedback" to "authenticated";

grant references on table "public"."feedback" to "service_role";

grant trigger on table "public"."feedback" to "service_role";

grant truncate on table "public"."feedback" to "service_role";


  create policy "feedback_insert"
  on "public"."feedback"
  as permissive
  for insert
  to public
with check ((submitted_by = ( SELECT profiles.int_id
   FROM public.profiles
  WHERE (profiles.id = auth.uid()))));



  create policy "feedback_read_admin"
  on "public"."feedback"
  as permissive
  for select
  to public
using ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (((profiles.flags)::integer & 1) = 1)))));



  create policy "feedback_update_admin"
  on "public"."feedback"
  as permissive
  for update
  to public
using ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (((profiles.flags)::integer & 1) = 1)))));


insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'feedback-attachments',
  'feedback-attachments',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif', 'image/gif']
)
on conflict (id) do update set
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;


  create policy "feedback_attachments_delete_admin"
  on "storage"."objects"
  as permissive
  for delete
  to authenticated
using (((bucket_id = 'feedback-attachments'::text) AND (EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (((profiles.flags)::integer & 1) = 1))))));



  create policy "feedback_attachments_insert"
  on "storage"."objects"
  as permissive
  for insert
  to authenticated
with check (((bucket_id = 'feedback-attachments'::text) AND ((storage.foldername(name))[1] = ( SELECT (profiles.int_id)::text AS int_id
   FROM public.profiles
  WHERE (profiles.id = auth.uid())))));



  create policy "feedback_attachments_select"
  on "storage"."objects"
  as permissive
  for select
  to authenticated
using (((bucket_id = 'feedback-attachments'::text) AND (((storage.foldername(name))[1] = ( SELECT (profiles.int_id)::text AS int_id
   FROM public.profiles
  WHERE (profiles.id = auth.uid()))) OR (EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (((profiles.flags)::integer & 1) = 1)))))));



