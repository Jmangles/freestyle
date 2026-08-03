-- Bump updated_at on every user_tricks change
create or replace function touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end;
$$;

create trigger user_tricks_updated_at
  before update on user_tricks
  for each row execute function touch_updated_at();

-- Aggregated difficulty / leash-position vote counts for one trick
create or replace function get_trick_vote_stats(p_trick_id integer)
returns json language sql security definer as $$
  select json_build_object(
    'difficulty_votes', coalesce((
      select json_object_agg(difficulty_vote::text, cnt)
      from (
        select difficulty_vote, count(*) as cnt
        from user_tricks
        where trick_id = p_trick_id and difficulty_vote is not null
        group by difficulty_vote
      ) t
    ), '{}'),
    'leash_positions', coalesce((
      select json_object_agg(leash_position::text, cnt)
      from (
        select leash_position, count(*) as cnt
        from user_tricks
        where trick_id = p_trick_id and leash_position is not null
        group by leash_position
      ) t
    ), '{}')
  );
$$;

-- Auto-create a profile row when an auth user signs up
create or replace function handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, username, flags)
  values (new.id, new.raw_user_meta_data->>'username', 0);
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- Opening a thread creates the head and its first message in one transaction,
-- so a failed message insert can't leave an empty thread behind.
create or replace function submit_feedback(
  p_message text,
  p_attachment_paths text[] default null
)
returns integer language plpgsql security definer set search_path = public as $$
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
$$;

-- A new message hands its thread to the other side: the owner's messages wait
-- on an admin, everyone else's wait on the owner. Closed threads keep their
-- status. Runs as definer because users have no update grant on feedback.
create or replace function bump_feedback_thread()
returns trigger language plpgsql security definer set search_path = public as $$
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
$$;

create trigger feedback_messages_bump_thread
  after insert on feedback_messages
  for each row execute function bump_feedback_thread();

create or replace function mark_feedback_read(p_feedback_id integer)
returns void language plpgsql security definer set search_path = public as $$
begin
  update feedback
  set user_last_read_at = now()
  where id = p_feedback_id
    and submitted_by = (select int_id from profiles where id = auth.uid());
end;
$$;

-- Threads with activity the caller hasn't opened yet. PostgREST can't compare
-- two columns in a filter, so the unread badge asks for the count here.
create or replace function unread_feedback_count()
returns integer language sql security definer set search_path = public as $$
  select count(*)::integer
  from feedback
  where submitted_by = (select int_id from profiles where id = auth.uid())
    and last_message_at > coalesce(user_last_read_at, '-infinity'::timestamptz);
$$;

-- Strip a deleted trick's id out of other tricks' reference arrays
create or replace function remove_deleted_trick_refs()
returns trigger language plpgsql as $$
begin
  update tricks
  set prerequisite_trick_ids = array_remove(prerequisite_trick_ids, old.id),
      base_trick_ids          = array_remove(base_trick_ids, old.id)
  where old.id = any(prerequisite_trick_ids)
     or old.id = any(base_trick_ids);
  return old;
end;
$$;

create trigger on_trick_deleted
  before delete on tricks
  for each row execute function remove_deleted_trick_refs();
