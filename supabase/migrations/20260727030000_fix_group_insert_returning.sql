-- The on_group_created AFTER INSERT trigger's write to group_members isn't
-- guaranteed visible in time for the same statement's RETURNING clause to
-- pass the "members can read their groups" check (confirmed by testing:
-- INSERT ... RETURNING still failed RLS even with the trigger in place).
-- Letting the creator see their own group directly sidesteps that ordering
-- question entirely instead of depending on trigger timing.

drop policy "members can read their groups" on groups;

create policy "members can read their groups"
  on groups for select
  to authenticated
  using (is_group_member(id) or created_by = auth.uid());
