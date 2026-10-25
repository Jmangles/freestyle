
  create table "public"."feedback_messages" (
    "id" integer generated always as identity not null,
    "feedback_id" integer not null,
    "author_id" integer,
    "body" text not null,
    "attachment_paths" text[],
    "created_at" timestamp with time zone not null default now()
      );


alter table "public"."feedback_messages" enable row level security;

CREATE UNIQUE INDEX feedback_messages_pkey ON public.feedback_messages USING btree (id);

CREATE INDEX feedback_messages_thread_idx ON public.feedback_messages USING btree (feedback_id, created_at);

CREATE INDEX feedback_submitted_by_idx ON public.feedback USING btree (submitted_by);

alter table "public"."feedback_messages" add constraint "feedback_messages_pkey" PRIMARY KEY using index "feedback_messages_pkey";

alter table "public"."feedback_messages" add constraint "feedback_messages_body_check" CHECK (((char_length(body) >= 1) AND (char_length(body) <= 2000))) not valid;

alter table "public"."feedback_messages" validate constraint "feedback_messages_body_check";

alter table "public"."feedback_messages" add constraint "feedback_messages_feedback_id_fkey" FOREIGN KEY (feedback_id) REFERENCES public.feedback(id) ON DELETE CASCADE not valid;

alter table "public"."feedback_messages" validate constraint "feedback_messages_feedback_id_fkey";

alter table "public"."feedback_messages" add constraint "feedback_messages_author_id_fkey" FOREIGN KEY (author_id) REFERENCES public.profiles(int_id) ON DELETE SET NULL not valid;

alter table "public"."feedback_messages" validate constraint "feedback_messages_author_id_fkey";

-- Existing feedback rows carry their message inline; move each one in as the
-- first message of its thread before the columns go away.
insert into public.feedback_messages (feedback_id, author_id, body, attachment_paths, created_at)
select id, submitted_by, message, attachment_paths, created_at
from public.feedback;

alter table "public"."feedback" add column "user_last_read_at" timestamp with time zone;

alter table "public"."feedback" add column "last_message_at" timestamp with time zone not null default now();

update public.feedback set last_message_at = created_at;

alter table "public"."feedback" drop column "message";

alter table "public"."feedback" drop column "attachment_paths";

alter table "public"."feedback" drop constraint "feedback_status_check";

alter table "public"."feedback" add constraint "feedback_status_check" CHECK ((status = ANY (ARRAY['new'::text, 'answered'::text, 'reviewed'::text, 'dismissed'::text]))) not valid;

alter table "public"."feedback" validate constraint "feedback_status_check";

grant select on table "public"."feedback_messages" to "authenticated";

grant insert on table "public"."feedback_messages" to "authenticated";

grant references on table "public"."feedback_messages" to "authenticated";

grant trigger on table "public"."feedback_messages" to "authenticated";

grant references on table "public"."feedback_messages" to "anon";

grant trigger on table "public"."feedback_messages" to "anon";

grant references on table "public"."feedback_messages" to "service_role";

grant trigger on table "public"."feedback_messages" to "service_role";


  create policy "feedback_read_own"
  on "public"."feedback"
  as permissive
  for select
  to public
using ((submitted_by = ( SELECT profiles.int_id
   FROM public.profiles
  WHERE (profiles.id = auth.uid()))));



  create policy "feedback_messages_read"
  on "public"."feedback_messages"
  as permissive
  for select
  to public
using (
  exists (
    select 1
    from public.feedback f
    where f.id = feedback_messages.feedback_id
      and f.submitted_by = (select p.int_id from public.profiles p where p.id = auth.uid())
  )
  or exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and (p.flags::integer & 1) = 1
  )
);



  create policy "feedback_messages_insert"
  on "public"."feedback_messages"
  as permissive
  for insert
  to public
with check (
  author_id = (select p.int_id from public.profiles p where p.id = auth.uid())
  and (
    exists (
      select 1
      from public.feedback f
      where f.id = feedback_messages.feedback_id
        and f.submitted_by = feedback_messages.author_id
        and f.status in ('new', 'answered')
    )
    or exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and (p.flags::integer & 1) = 1
    )
  )
);


set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.bump_feedback_thread()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  owner_id   integer;
  from_owner boolean;
begin
  select submitted_by into owner_id from feedback where id = new.feedback_id;
  from_owner := new.author_id is not distinct from owner_id;
  update feedback
  set last_message_at   = new.created_at,
      status            = case
                            when status in ('reviewed', 'dismissed') then status
                            when from_owner then 'new'
                            else 'answered'
                          end,
      user_last_read_at = case
                            when from_owner then new.created_at
                            else user_last_read_at
                          end
  where id = new.feedback_id;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.submit_feedback(p_message text, p_attachment_paths text[] DEFAULT NULL::text[])
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  me     integer;
  new_id integer;
begin
  select int_id into me from profiles where id = auth.uid();
  if me is null then
    raise exception 'not authenticated';
  end if;
  insert into feedback (submitted_by) values (me) returning id into new_id;
  insert into feedback_messages (feedback_id, author_id, body, attachment_paths)
  values (new_id, me, p_message, p_attachment_paths);
  return new_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.mark_feedback_read(p_feedback_id integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  update feedback
  set user_last_read_at = now()
  where id = p_feedback_id
    and submitted_by = (select int_id from profiles where id = auth.uid());
end;
$function$
;

CREATE OR REPLACE FUNCTION public.unread_feedback_count()
 RETURNS integer
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select count(*)::integer
  from feedback
  where submitted_by = (select int_id from profiles where id = auth.uid())
    and last_message_at > coalesce(user_last_read_at, '-infinity'::timestamptz);
$function$
;

CREATE TRIGGER feedback_messages_bump_thread AFTER INSERT ON public.feedback_messages FOR EACH ROW EXECUTE FUNCTION bump_feedback_thread();

revoke execute on function public.submit_feedback(text, text[]) from public;

revoke execute on function public.mark_feedback_read(integer) from public;

revoke execute on function public.unread_feedback_count() from public;

grant execute on function public.submit_feedback(text, text[]) to "authenticated";

grant execute on function public.mark_feedback_read(integer) to "authenticated";

grant execute on function public.unread_feedback_count() to "authenticated";
