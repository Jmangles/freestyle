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
