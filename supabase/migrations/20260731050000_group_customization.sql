-- Group identity: a group can be represented either by an uploaded photo or,
-- for people who don't want to pick an image, a single emoji icon.

alter table groups add column icon text;

-- Group photos live under "<group_id>/..." so membership can be enforced by
-- parsing the folder prefix, mirroring how avatars are scoped per user.
create policy "group photos are publicly readable"
  on storage.objects for select
  to public
  using (bucket_id = 'group-photos');

create policy "members can upload their group photo"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'group-photos'
    and is_group_member(((storage.foldername(name))[1])::uuid)
  );

create policy "members can update their group photo"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'group-photos'
    and is_group_member(((storage.foldername(name))[1])::uuid)
  );

create policy "members can delete their group photo"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'group-photos'
    and is_group_member(((storage.foldername(name))[1])::uuid)
  );

-- Group cards show "N membros · N títulos". Computing that per group from the
-- client would be a query per card, so aggregate it in one round trip.
create function get_my_groups_with_stats()
returns table (
  id uuid,
  name text,
  photo_url text,
  icon text,
  invite_code text,
  member_count bigint,
  entry_count bigint,
  last_watched_at date,
  latest_backdrop_url text
)
language sql
security definer
stable
as $$
  select
    g.id,
    g.name,
    g.photo_url,
    g.icon,
    g.invite_code,
    (select count(*) from group_members gm where gm.group_id = g.id),
    (select count(*) from watch_entries we where we.group_id = g.id),
    (select max(we.watched_at) from watch_entries we where we.group_id = g.id),
    (
      select m.backdrop_url
      from watch_entries we
      join movies m on m.id = we.movie_id
      where we.group_id = g.id and m.backdrop_url is not null
      order by we.watched_at desc
      limit 1
    )
  from groups g
  where exists (
    select 1 from group_members gm
    where gm.group_id = g.id and gm.user_id = auth.uid()
  )
  order by g.created_at;
$$;

grant execute on function get_my_groups_with_stats() to authenticated;
