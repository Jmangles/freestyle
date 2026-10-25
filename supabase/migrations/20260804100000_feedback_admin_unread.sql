alter table "public"."feedback" add column "admin_last_read_at" timestamp with time zone;

-- Everything that exists today counts as already seen by the admins.
update public.feedback set admin_last_read_at = last_message_at;

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
                          end,
      admin_last_read_at = case
                             when from_owner then admin_last_read_at
                             else new.created_at
                           end
  where id = new.feedback_id;
  return new;
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
  update feedback
  set admin_last_read_at = now()
  where id = p_feedback_id
    and exists (select 1 from profiles where id = auth.uid() and (flags & 1) = 1);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_unread_feedback_count()
 RETURNS integer
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select count(*)::integer
  from feedback
  where exists (select 1 from profiles where id = auth.uid() and (flags & 1) = 1)
    and status in ('new', 'answered')
    and last_message_at > coalesce(admin_last_read_at, '-infinity'::timestamptz);
$function$
;

revoke execute on function public.admin_unread_feedback_count() from public;

grant execute on function public.admin_unread_feedback_count() to "authenticated";
