-- Per-user rate limiting.
--
-- Supabase already throttles the auth endpoints per IP, but nothing stopped an
-- authenticated user from creating content in a loop: flooding a group's
-- timeline, spamming the watchlist, or mass-creating groups. RLS answers "may
-- you?", not "how often?".
--
-- The limits are enforced by BEFORE INSERT triggers that count the user's own
-- recent rows in the same table, so there is no counter table to keep in sync
-- and a deleted row correctly frees up quota. No dynamic SQL is used.
--
-- Every security definer function below pins `search_path`: without it, a role
-- able to create objects in an earlier schema could shadow the tables these
-- functions reference and have them run against its own.

-- Counting "rows by this user since T" is the hot path for every insert below,
-- so give each check an index that matches it.
create index on watch_entries (logged_by, created_at desc);
create index on watchlist_items (added_by, created_at desc);
create index on planned_sessions (created_by, created_at desc);
create index on groups (created_by, created_at desc);
create index on group_members (user_id, joined_at desc);

-- Raised with a dedicated SQLSTATE so the client can tell throttling apart
-- from a genuine permission error and show a "slow down" message. 'AV429'
-- mirrors HTTP 429; the built-in P00xx codes are already taken by plpgsql.
create function raise_rate_limited(p_what text)
returns void
language plpgsql
as $$
begin
  raise exception 'Limite de % atingido. Aguarde alguns minutos.', p_what
    using errcode = 'AV429';
end;
$$;

create function enforce_watch_entry_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  recent_count integer;
begin
  select count(*) into recent_count
  from watch_entries
  where logged_by = new.logged_by
    and created_at > now() - interval '1 hour';

  if recent_count >= 60 then
    perform raise_rate_limited('registros de filmes por hora');
  end if;

  return new;
end;
$$;

create function enforce_watchlist_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  recent_count integer;
begin
  select count(*) into recent_count
  from watchlist_items
  where added_by = new.added_by
    and created_at > now() - interval '1 hour';

  if recent_count >= 100 then
    perform raise_rate_limited('itens na lista por hora');
  end if;

  return new;
end;
$$;

create function enforce_session_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  recent_count integer;
begin
  select count(*) into recent_count
  from planned_sessions
  where created_by = new.created_by
    and created_at > now() - interval '1 hour';

  if recent_count >= 30 then
    perform raise_rate_limited('sessões agendadas por hora');
  end if;

  return new;
end;
$$;

create function enforce_group_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  recent_count integer;
begin
  select count(*) into recent_count
  from groups
  where created_by = new.created_by
    and created_at > now() - interval '1 hour';

  if recent_count >= 10 then
    perform raise_rate_limited('grupos criados por hora');
  end if;

  return new;
end;
$$;

-- Joining is also throttled: an invite code is only 8 hex characters, and
-- unlimited attempts would make guessing one practical.
create function enforce_group_join_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  recent_count integer;
begin
  select count(*) into recent_count
  from group_members
  where user_id = new.user_id
    and joined_at > now() - interval '1 hour';

  if recent_count >= 20 then
    perform raise_rate_limited('entradas em grupos por hora');
  end if;

  return new;
end;
$$;

create trigger rate_limit_watch_entries
  before insert on watch_entries
  for each row execute function enforce_watch_entry_rate_limit();

create trigger rate_limit_watchlist_items
  before insert on watchlist_items
  for each row execute function enforce_watchlist_rate_limit();

create trigger rate_limit_planned_sessions
  before insert on planned_sessions
  for each row execute function enforce_session_rate_limit();

create trigger rate_limit_groups
  before insert on groups
  for each row execute function enforce_group_rate_limit();

create trigger rate_limit_group_members
  before insert on group_members
  for each row execute function enforce_group_join_rate_limit();

-- Edge functions spend our TMDB quota, so they get their own budget. They run
-- under the service role and record each call here; unlike the triggers above
-- there is no natural table of "calls" to count, so this one is explicit.
create table rate_limit_events (
  id bigserial primary key,
  user_id uuid not null references profiles (id) on delete cascade,
  action text not null,
  created_at timestamptz not null default now()
);

create index on rate_limit_events (user_id, action, created_at desc);

alter table rate_limit_events enable row level security;
-- Deliberately no policy for `authenticated`: this table is written and read
-- only by the service role, which bypasses RLS. Clients must never touch it.

grant select, insert, delete on rate_limit_events to service_role;
grant usage, select on sequence rate_limit_events_id_seq to service_role;

-- Records a call and reports whether the caller is still within budget.
create function consume_rate_limit(
  p_user_id uuid,
  p_action text,
  p_max_calls integer,
  p_window_seconds integer
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  recent_count integer;
begin
  select count(*) into recent_count
  from rate_limit_events
  where user_id = p_user_id
    and action = p_action
    and created_at > now() - make_interval(secs => p_window_seconds);

  if recent_count >= p_max_calls then
    return false;
  end if;

  insert into rate_limit_events (user_id, action) values (p_user_id, p_action);
  return true;
end;
$$;

grant execute on function consume_rate_limit(uuid, text, integer, integer) to service_role;

-- Housekeeping: without this the events table grows forever. Called
-- opportunistically by the edge functions rather than needing pg_cron.
create function prune_rate_limit_events()
returns void
language sql
security definer
set search_path = public
as $$
  delete from rate_limit_events where created_at < now() - interval '1 day';
$$;

grant execute on function prune_rate_limit_events() to service_role;

-- The security definer functions written before this pass didn't pin
-- search_path either. Same hijacking risk, so fix them here rather than
-- editing already-applied migrations.
alter function add_creator_as_owner() set search_path = public;
alter function get_global_top_movies(integer) set search_path = public;
alter function get_group_top_movies(uuid, integer) set search_path = public;
alter function get_my_groups_with_stats() set search_path = public;
alter function is_group_member(uuid) set search_path = public;
alter function shares_group_with(uuid) set search_path = public;
-- handle_new_user() reads auth.users via the trigger's NEW record but writes
-- to public.profiles, so it needs both schemas visible.
alter function handle_new_user() set search_path = public, auth;

-- Replaced rather than altered: a bad invite code raised a bare English
-- 'Invalid invite code' with the generic P0001, indistinguishable from any
-- other raise, so the app could only show a generic failure. It now carries
-- its own code and a message meant for the person reading it.
create or replace function join_group_by_invite_code(code text)
returns groups
language plpgsql
security definer
set search_path = public
as $$
declare
  target_group groups;
begin
  select * into target_group from groups where invite_code = code;

  if target_group.id is null then
    raise exception 'Convite inválido ou expirado.' using errcode = 'AV404';
  end if;

  insert into group_members (group_id, user_id, role)
  values (target_group.id, auth.uid(), 'member')
  on conflict (group_id, user_id) do nothing;

  return target_group;
end;
$$;
