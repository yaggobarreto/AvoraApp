-- Security hardening pass. Each change closes a hole confirmed by probing the
-- running instance with a second real user account.

-- 1) Profile enumeration.
--    "profiles are readable by anyone authenticated ... using (true)" let any
--    signed-up user dump the name and avatar of every user in the app. The
--    product promise is private groups, so a profile should only be visible
--    to yourself and to people you actually share a group with.
drop policy "profiles are readable by anyone authenticated" on profiles;

create function shares_group_with(other_user_id uuid)
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1
    from group_members mine
    join group_members theirs on theirs.group_id = mine.group_id
    where mine.user_id = auth.uid()
      and theirs.user_id = other_user_id
  );
$$;

create policy "profiles are readable by yourself and your group mates"
  on profiles for select
  to authenticated
  using (id = auth.uid() or shares_group_with(id));

-- 2) Movie cache poisoning + broken re-cache.
--    "authenticated users can cache movie metadata ... with check (true)"
--    allowed writing arbitrary rows into a table every user reads. There was
--    also no UPDATE policy, so upserting a title another user had already
--    cached failed outright. Writes now go through the `cache-movie` edge
--    function, which pulls authoritative data from TMDB under the service
--    role (service_role bypasses RLS, so no policy is needed for it).
drop policy "authenticated users can cache movie metadata" on movies;
-- DELETE goes too: nothing in the app deletes cached titles, and leaving it
-- would let any user drop rows other groups' timelines join against.
revoke insert, update, delete on movies from authenticated;

-- These tables were created by plain SQL migrations, so they never inherited
-- the default grants Supabase normally gives service_role. The edge function
-- needs them to write the cache on the user's behalf.
grant usage on schema public to service_role;
grant select, insert, update, delete on
  public.profiles,
  public.groups,
  public.group_members,
  public.movies,
  public.watch_entries,
  public.watch_entry_participants,
  public.watchlist_items,
  public.planned_sessions,
  public.session_rsvps
to service_role;

-- 3) Bound free-text fields so a client can't store multi-megabyte blobs that
--    every group member then has to download.
alter table groups add constraint groups_name_length
  check (char_length(name) between 1 and 60);
alter table groups add constraint groups_icon_length
  check (icon is null or char_length(icon) <= 8);
alter table profiles add constraint profiles_name_length
  check (char_length(name) between 1 and 80);
alter table watch_entries add constraint watch_entries_comment_length
  check (comment is null or char_length(comment) <= 2000);
alter table watch_entries add constraint watch_entries_emojis_bounded
  check (
    array_length(emojis, 1) is null
    or (array_length(emojis, 1) <= 10 and array_length(emojis, 1) >= 0)
  );

-- 4) Ratings are shown as stars and averaged; values outside 0-5 would skew
--    every ranking in the app.
alter table watch_entries add constraint watch_entries_rating_range
  check (rating is null or (rating >= 0 and rating <= 5));
alter table watch_entries add constraint watch_entries_times_watched_range
  check (times_watched between 1 and 1000);

-- 5) A watch entry could be logged with any date, including the future, which
--    corrupts the "assistido em" timeline and recency-weighted rankings.
alter table watch_entries add constraint watch_entries_watched_at_not_future
  check (watched_at <= (now() at time zone 'utc')::date);
