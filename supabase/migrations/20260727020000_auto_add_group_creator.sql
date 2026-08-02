-- Inserting a group and immediately RETURNING it (which every Supabase client
-- does) requires the select policy ("members can read their groups") to pass
-- right away — but the creator isn't a group_members row yet at that point,
-- so the RETURNING clause's implicit select check failed with the same
-- generic "violates row-level security policy" error as the insert itself.
-- Auto-adding the creator as owner closes that gap and removes the need for
-- a separate client-side insert that could fail/race independently.

create function add_creator_as_owner()
returns trigger
language plpgsql
security definer
as $$
begin
  insert into public.group_members (group_id, user_id, role)
  values (new.id, new.created_by, 'owner');
  return new;
end;
$$;

create trigger on_group_created
  after insert on public.groups
  for each row execute function add_creator_as_owner();
