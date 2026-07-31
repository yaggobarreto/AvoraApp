-- Lean version of the "Planejador" feature: a per-group watch-later list
-- and scheduled sessions with RSVP. Deliberately leaves out chat, voting,
-- external calendar export, and push/email reminders — those need more
-- infrastructure (FCM, an email provider, OAuth calendar scopes) and are a
-- separate future phase.

create table watchlist_items (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references groups (id) on delete cascade,
  movie_id uuid not null references movies (id),
  added_by uuid not null references profiles (id),
  created_at timestamptz not null default now(),
  unique (group_id, movie_id)
);

create type session_location as enum (
  'casa', 'cinema', 'com_pizza', 'discord', 'online', 'outro'
);

create type session_status as enum ('scheduled', 'watched', 'cancelled');

create table planned_sessions (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references groups (id) on delete cascade,
  movie_id uuid not null references movies (id),
  scheduled_at timestamptz not null,
  location session_location not null default 'casa',
  notes text,
  status session_status not null default 'scheduled',
  created_by uuid not null references profiles (id),
  created_at timestamptz not null default now()
);

create type rsvp_status as enum ('confirmed', 'declined', 'maybe');

create table session_rsvps (
  session_id uuid not null references planned_sessions (id) on delete cascade,
  user_id uuid not null references profiles (id) on delete cascade,
  status rsvp_status not null,
  responded_at timestamptz not null default now(),
  primary key (session_id, user_id)
);

create index on watchlist_items (group_id);
create index on planned_sessions (group_id, scheduled_at);
create index on session_rsvps (user_id);

alter table watchlist_items enable row level security;
alter table planned_sessions enable row level security;
alter table session_rsvps enable row level security;

grant select, insert, update, delete on
  public.watchlist_items,
  public.planned_sessions,
  public.session_rsvps
to authenticated;

create policy "members can read their group's watchlist"
  on watchlist_items for select
  to authenticated
  using (is_group_member(group_id));

create policy "members can add to their group's watchlist"
  on watchlist_items for insert
  to authenticated
  with check (is_group_member(group_id) and added_by = auth.uid());

create policy "members can remove from their group's watchlist"
  on watchlist_items for delete
  to authenticated
  using (is_group_member(group_id));

create policy "members can read their group's sessions"
  on planned_sessions for select
  to authenticated
  using (is_group_member(group_id));

create policy "members can schedule sessions for their group"
  on planned_sessions for insert
  to authenticated
  with check (is_group_member(group_id) and created_by = auth.uid());

create policy "members can update their group's sessions"
  on planned_sessions for update
  to authenticated
  using (is_group_member(group_id));

create policy "members can read rsvps for sessions in their groups"
  on session_rsvps for select
  to authenticated
  using (
    exists (
      select 1 from planned_sessions
      where planned_sessions.id = session_id
        and is_group_member(planned_sessions.group_id)
    )
  );

create policy "members can set their own rsvp"
  on session_rsvps for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from planned_sessions
      where planned_sessions.id = session_id
        and is_group_member(planned_sessions.group_id)
    )
  );

create policy "members can update their own rsvp"
  on session_rsvps for update
  to authenticated
  using (user_id = auth.uid());
