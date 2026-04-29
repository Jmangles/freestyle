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

grant execute on function get_trick_vote_stats(integer) to anon, authenticated;
