-- Initial schema for the movie diary MVP.
-- Tables: profiles, groups, group_members, movies, watch_entries, watch_entry_participants.
-- RLS is scoped by group membership so private groups stay private.

create table profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  name text not null,
  avatar_url text,
  created_at timestamptz not null default now()
);

create table groups (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  photo_url text,
  invite_code text not null unique default substr(md5(random()::text), 1, 8),
  created_by uuid not null references profiles (id),
  created_at timestamptz not null default now()
);

create type group_role as enum ('owner', 'member');

create table group_members (
  group_id uuid not null references groups (id) on delete cascade,
  user_id uuid not null references profiles (id) on delete cascade,
  role group_role not null default 'member',
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

create table movies (
  id uuid primary key default gen_random_uuid(),
  tmdb_id integer not null unique,
  title text not null,
  year integer,
  poster_url text,
  backdrop_url text,
  synopsis text,
  runtime_minutes integer,
  genres text[] not null default '{}',
  director text,
  trailer_url text,
  cached_at timestamptz not null default now()
);

create type watch_location as enum (
  'cinema', 'netflix', 'prime_video', 'disney_plus', 'max', 'apple_tv',
  'youtube', 'tv_aberta', 'tv_a_cabo', 'dvd_blu_ray', 'outro'
);

create table watch_entries (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references groups (id) on delete cascade,
  movie_id uuid not null references movies (id),
  logged_by uuid not null references profiles (id),
  watched_at date not null,
  watch_location watch_location not null,
  times_watched integer not null default 1,
  rating numeric(2, 1) check (rating >= 0 and rating <= 5),
  comment text,
  emojis text[] not null default '{}',
  created_at timestamptz not null default now()
);

create table watch_entry_participants (
  watch_entry_id uuid not null references watch_entries (id) on delete cascade,
  user_id uuid not null references profiles (id) on delete cascade,
  primary key (watch_entry_id, user_id)
);

create index on group_members (user_id);
create index on watch_entries (group_id, watched_at desc);
create index on watch_entry_participants (user_id);

-- Helper: is the current user a member of a given group?
create function is_group_member(check_group_id uuid)
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1 from group_members
    where group_id = check_group_id and user_id = auth.uid()
  );
$$;

alter table profiles enable row level security;
alter table groups enable row level security;
alter table group_members enable row level security;
alter table movies enable row level security;
alter table watch_entries enable row level security;
alter table watch_entry_participants enable row level security;

create policy "profiles are readable by anyone authenticated"
  on profiles for select
  to authenticated
  using (true);

create policy "users manage their own profile"
  on profiles for all
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

create policy "members can read their groups"
  on groups for select
  to authenticated
  using (is_group_member(id));

create policy "authenticated users can create groups"
  on groups for insert
  to authenticated
  with check (created_by = auth.uid());

create policy "owners can update their groups"
  on groups for update
  to authenticated
  using (is_group_member(id));

create policy "members can read membership of their groups"
  on group_members for select
  to authenticated
  using (is_group_member(group_id));

create policy "users can join a group (insert own membership)"
  on group_members for insert
  to authenticated
  with check (user_id = auth.uid());

create policy "movies are readable by anyone authenticated"
  on movies for select
  to authenticated
  using (true);

create policy "authenticated users can cache movie metadata"
  on movies for insert
  to authenticated
  with check (true);

create policy "members can read watch entries of their groups"
  on watch_entries for select
  to authenticated
  using (is_group_member(group_id));

create policy "members can log watch entries in their groups"
  on watch_entries for insert
  to authenticated
  with check (is_group_member(group_id) and logged_by = auth.uid());

create policy "authors can update their own watch entries"
  on watch_entries for update
  to authenticated
  using (logged_by = auth.uid());

create policy "authors can delete their own watch entries"
  on watch_entries for delete
  to authenticated
  using (logged_by = auth.uid());

create policy "members can read participants of entries in their groups"
  on watch_entry_participants for select
  to authenticated
  using (
    exists (
      select 1 from watch_entries
      where watch_entries.id = watch_entry_id
        and is_group_member(watch_entries.group_id)
    )
  );

create policy "members can add participants to entries in their groups"
  on watch_entry_participants for insert
  to authenticated
  with check (
    exists (
      select 1 from watch_entries
      where watch_entries.id = watch_entry_id
        and is_group_member(watch_entries.group_id)
    )
  );

-- Joining a group requires knowing its invite code but the caller isn't a
-- member yet, so the regular "members can read their groups" policy would
-- block the lookup. This runs as security definer to look up + join atomically
-- without having to relax the groups select policy to all authenticated users.
create function join_group_by_invite_code(code text)
returns groups
language plpgsql
security definer
as $$
declare
  target_group groups;
begin
  select * into target_group from groups where invite_code = code;

  if target_group.id is null then
    raise exception 'Invalid invite code';
  end if;

  insert into group_members (group_id, user_id, role)
  values (target_group.id, auth.uid(), 'member')
  on conflict (group_id, user_id) do nothing;

  return target_group;
end;
$$;

-- Create a profile row automatically when a new auth user signs up.
create function handle_new_user()
returns trigger
language plpgsql
security definer
as $$
begin
  insert into public.profiles (id, name, avatar_url)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.email, 'Novo usuário'),
    new.raw_user_meta_data ->> 'avatar_url'
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();
