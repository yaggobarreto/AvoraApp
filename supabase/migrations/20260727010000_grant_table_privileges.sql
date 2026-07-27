-- RLS policies only restrict *rows*; Postgres still requires base table-level
-- grants before a role can attempt any query at all. Tables created via plain
-- SQL migrations don't inherit the default grants Supabase's dashboard sets up
-- automatically, so authenticated requests were failing with "permission
-- denied for table profiles" even though the RLS policies were correct.

grant usage on schema public to authenticated;

grant select, insert, update, delete on
  public.profiles,
  public.groups,
  public.group_members,
  public.movies,
  public.watch_entries,
  public.watch_entry_participants
to authenticated;

grant execute on function public.join_group_by_invite_code(text) to authenticated;
