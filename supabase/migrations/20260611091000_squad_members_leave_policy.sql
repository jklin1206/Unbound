-- squad_members had no DELETE policy, so there was no possible client
-- "leave squad" path (INSERT is service-role-only via join_squad; SELECT is
-- roster-scoped). Allow a user to delete exactly their own membership row.
--
-- A captain leaving their own squad is a product question (transfer vs.
-- disband) handled at the app layer; this policy only unblocks the data path.

create policy "squad_members: user can leave squad"
  on public.squad_members for delete
  to authenticated
  using (user_id = auth.uid());
