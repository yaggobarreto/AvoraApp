-- Social feed (item 13 of the "Atualização Geral" backlog), scoped per
-- group rather than across every group a user belongs to — the app's whole
-- privacy model is that one group's activity is invisible to another, and a
-- cross-group feed would be the first thing in the app to break that.
--
-- This is deliberately not a stored/denormalized activity log: every event
-- type already exists in its own table with a created_at, so the feed is
-- computed by unioning them on read, the same way the ranking functions
-- compute a leaderboard from watch_entries instead of maintaining one.
create function get_group_activity_feed(
  p_group_id uuid,
  p_limit int default 20,
  p_offset int default 0
)
returns table (
  event_type text,
  event_id uuid,
  actor_name text,
  actor_avatar_url text,
  movie_title text,
  movie_poster_url text,
  rating numeric,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  -- security definer bypasses RLS, so membership has to be checked by hand —
  -- this is the only thing standing between a group's activity and anyone
  -- with a valid account.
  if not is_group_member(p_group_id) then
    raise exception 'Você não é membro deste grupo.' using errcode = 'AV403';
  end if;

  return query
  select * from (
    select
      'watch_entry'::text as event_type,
      we.id as event_id,
      p.name as actor_name,
      p.avatar_url as actor_avatar_url,
      m.title as movie_title,
      m.poster_url as movie_poster_url,
      we.rating,
      we.created_at
    from watch_entries we
    join profiles p on p.id = we.logged_by
    join movies m on m.id = we.movie_id
    where we.group_id = p_group_id

    union all

    select
      'member_joined',
      gm.user_id,
      p2.name,
      p2.avatar_url,
      null,
      null,
      null,
      gm.joined_at
    from group_members gm
    join profiles p2 on p2.id = gm.user_id
    where gm.group_id = p_group_id

    union all

    select
      'session_scheduled',
      ps.id,
      p3.name,
      p3.avatar_url,
      m2.title,
      m2.poster_url,
      null,
      ps.created_at
    from planned_sessions ps
    join profiles p3 on p3.id = ps.created_by
    join movies m2 on m2.id = ps.movie_id
    where ps.group_id = p_group_id

    union all

    select
      'watchlist_added',
      wi.id,
      p4.name,
      p4.avatar_url,
      m3.title,
      m3.poster_url,
      null,
      wi.created_at
    from watchlist_items wi
    join profiles p4 on p4.id = wi.added_by
    join movies m3 on m3.id = wi.movie_id
    where wi.group_id = p_group_id
  ) as feed
  order by created_at desc
  limit p_limit offset p_offset;
end;
$$;

grant execute on function get_group_activity_feed(uuid, int, int) to authenticated;
