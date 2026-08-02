-- Achievements/gamification (item 10 of the "Atualização Geral" backlog).
--
-- The catalog (title, emoji, description) lives in the Dart client, same as
-- watch-location labels and genre choices elsewhere in this app — it's
-- static display metadata, not something that needs a table. What must live
-- server-side is the *eligibility check*: if the client could just call
-- `unlock_achievement('cinefilo_50')` with an id of its choosing, anyone
-- could claim any badge regardless of whether they'd actually earned it.
-- This function is the only thing that decides what gets unlocked, and it
-- computes each condition from the user's own real data.
--
-- unlocked_at reflects when the app first *noticed* the milestone was met
-- (the first time this function ran after it was crossed), not the exact
-- historical moment the threshold was passed — backdating that would need
-- walking the user's full history per achievement for no real product value.

create table user_achievements (
  user_id uuid not null references profiles (id) on delete cascade,
  achievement_id text not null,
  unlocked_at timestamptz not null default now(),
  primary key (user_id, achievement_id)
);

alter table user_achievements enable row level security;

create policy "users read their own achievements"
  on user_achievements for select
  to authenticated
  using (user_id = auth.uid());

-- Deliberately no insert/update/delete policy for `authenticated`: the only
-- writer is sync_and_fetch_achievements(), running as security definer.
grant select on user_achievements to authenticated;

create function sync_and_fetch_achievements()
returns table (achievement_id text, unlocked_at timestamptz, is_new boolean)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_total_logged bigint;
  v_series_logged bigint;
  v_five_star_count bigint;
  v_distinct_genres bigint;
  v_group_count bigint;
  v_is_group_founder boolean;
  v_current_streak int;
  v_eligible text[] := '{}';
  v_newly_unlocked text[];
begin
  select
    count(*),
    count(*) filter (where m.media_type = 'tv'),
    count(*) filter (where we.rating = 5)
  into v_total_logged, v_series_logged, v_five_star_count
  from watch_entries we
  join movies m on m.id = we.movie_id
  where we.logged_by = v_user;

  select count(distinct genre) into v_distinct_genres
  from watch_entries we
  join movies m on m.id = we.movie_id
  cross join lateral unnest(m.genres) as genre
  where we.logged_by = v_user;

  select count(*) into v_group_count
  from group_members
  where user_id = v_user;

  select exists(select 1 from groups where created_by = v_user) into v_is_group_founder;

  -- Current streak: the length of the run of distinct watched_at dates that
  -- ends today or yesterday (a gap of one day doesn't reset it until it's
  -- actually missed a full day) — same rule the profile screen's streak
  -- counter uses, expressed as a gaps-and-islands query instead of a client
  -- loop over fetched rows.
  select coalesce(max(len) filter (where last_day >= current_date - 1), 0)
  into v_current_streak
  from (
    select grp, count(*) as len, max(d) as last_day
    from (
      select d, d - (row_number() over (order by d))::int as grp
      from (select distinct watched_at as d from watch_entries where logged_by = v_user) as days
    ) as islands
    group by grp
  ) as streaks;

  if v_total_logged >= 1 then v_eligible := array_append(v_eligible, 'first_watch'); end if;
  if v_total_logged >= 10 then v_eligible := array_append(v_eligible, 'ten_watched'); end if;
  if v_total_logged >= 50 then v_eligible := array_append(v_eligible, 'fifty_watched'); end if;
  if v_series_logged >= 1 then v_eligible := array_append(v_eligible, 'first_series'); end if;
  if v_five_star_count >= 5 then v_eligible := array_append(v_eligible, 'five_star_fan'); end if;
  if v_distinct_genres >= 5 then v_eligible := array_append(v_eligible, 'genre_explorer'); end if;
  if v_is_group_founder then v_eligible := array_append(v_eligible, 'group_founder'); end if;
  if v_group_count >= 3 then v_eligible := array_append(v_eligible, 'social_butterfly'); end if;
  if v_current_streak >= 7 then v_eligible := array_append(v_eligible, 'week_streak'); end if;

  -- A plain `INSERT ... RETURNING col INTO scalar_var` only keeps the first
  -- row when the statement affects several — the CTE + array_agg is what
  -- actually collects every id this call newly unlocked.
  --
  -- The conflict target is named by constraint, not by column list: this
  -- function's RETURNS TABLE makes `achievement_id` an implicit OUT
  -- parameter for its whole body, and `on conflict (achievement_id)` doesn't
  -- allow table-qualifying that reference the way a normal SELECT does — so
  -- naming it in ON CONFLICT's column-list form is ambiguous no matter how
  -- it's written, and the constraint name is the only way around it.
  with newly_inserted as (
    insert into user_achievements (user_id, achievement_id)
    select v_user, unnest(v_eligible)
    on conflict on constraint user_achievements_pkey do nothing
    returning user_achievements.achievement_id as aid
  )
  select coalesce(array_agg(aid), '{}') into v_newly_unlocked from newly_inserted;

  return query
  select ua.achievement_id, ua.unlocked_at, ua.achievement_id = any(v_newly_unlocked)
  from user_achievements ua
  where ua.user_id = v_user
  order by ua.unlocked_at;
end;
$$;

grant execute on function sync_and_fetch_achievements() to authenticated;
