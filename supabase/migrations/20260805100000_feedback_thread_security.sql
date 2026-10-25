-- Generated from supabase/schemas/ against the preceding migration history:
-- supabase db diff --use-pg-schema --schema public,storage -f feedback_thread_security
-- Generated in an isolated project; explicit privilege handling is noted below.

-- HAS_UNTRACKABLE_DEPENDENCIES: Dependencies, i.e. other functions used in the function body, of non-sql functions cannot be tracked. As a result, we cannot guarantee that function dependencies are ordered properly relative to this statement. For adds, this means you need to ensure that all functions this function depends on are created/altered before this statement.
CREATE OR REPLACE FUNCTION public.prepare_feedback_message()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  thread_status text;
begin
  select status into thread_status from feedback
  where id = new.feedback_id for update;
  if thread_status in ('reviewed', 'dismissed') then
    raise exception 'feedback thread is closed' using errcode = '42501';
  end if;
  new.created_at := clock_timestamp();
  return new;
end;
$function$
;

-- AUTHZ_UPDATE: Altering a policy could cause queries to fail if not correctly configured or allow unauthorized access to data.
ALTER POLICY "feedback_messages_insert" ON "public"."feedback_messages"
	WITH CHECK (((author_id = ( SELECT profiles.int_id
   FROM profiles
  WHERE (profiles.id = auth.uid()))) AND (EXISTS ( SELECT 1
   FROM feedback f
  WHERE ((f.id = feedback_messages.feedback_id) AND (f.status = ANY (ARRAY['new'::text, 'answered'::text])) AND ((f.submitted_by = feedback_messages.author_id) OR (EXISTS ( SELECT 1
           FROM profiles
          WHERE ((profiles.id = auth.uid()) AND (((profiles.flags)::integer & 1) = 1))))))))));

-- AUTHZ_UPDATE: Altering a policy could cause queries to fail if not correctly configured or allow unauthorized access to data.
ALTER POLICY "feedback_messages_read" ON "public"."feedback_messages"
	USING (((EXISTS ( SELECT 1
   FROM feedback f
  WHERE ((f.id = feedback_messages.feedback_id) AND (f.submitted_by = ( SELECT profiles.int_id
           FROM profiles
          WHERE (profiles.id = auth.uid())))))) OR (EXISTS ( SELECT 1
   FROM profiles
  WHERE ((profiles.id = auth.uid()) AND (((profiles.flags)::integer & 1) = 1))))));

CREATE TRIGGER feedback_messages_prepare BEFORE INSERT ON public.feedback_messages FOR EACH ROW EXECUTE FUNCTION prepare_feedback_message();

-- AUTHZ_UPDATE: Altering a policy could cause queries to fail if not correctly configured or allow unauthorized access to data.
ALTER POLICY "feedback_attachments_select" ON "storage"."objects"
	USING (((bucket_id = 'feedback-attachments'::text) AND (((storage.foldername(name))[1] = ( SELECT (profiles.int_id)::text AS int_id
   FROM profiles
  WHERE (profiles.id = auth.uid()))) OR (EXISTS ( SELECT 1
   FROM profiles
  WHERE ((profiles.id = auth.uid()) AND (((profiles.flags)::integer & 1) = 1)))) OR (EXISTS ( SELECT 1
   FROM (feedback_messages m
     JOIN feedback f ON ((f.id = m.feedback_id)))
  WHERE ((f.submitted_by = ( SELECT profiles.int_id
           FROM profiles
          WHERE (profiles.id = auth.uid()))) AND (objects.name = ANY (m.attachment_paths)) AND ((storage.foldername(objects.name))[1] = (m.author_id)::text)))))));


-- pg-schema-diff does not track function privileges. Keep the declarative
-- privilege restriction explicitly; trigger execution does not need this grant.
revoke execute on function public.prepare_feedback_message() from public;
