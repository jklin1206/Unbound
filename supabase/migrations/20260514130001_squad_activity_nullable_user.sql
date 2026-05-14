-- squad_activity.user_id is nullable to support system events (e.g. nightly
-- evaluate_squad_streak posts squadStreakExtended with no human user).
alter table public.squad_activity
  alter column user_id drop not null;

-- Update the insert policy to handle null user_id for service-role inserts.
-- The existing policy:
--   insert where user_id = auth.uid() AND is_squad_member(auth.uid(), squad_id)
-- Service-role bypasses RLS entirely (Edge Functions use service-role), so
-- the policy doesn't need to change to allow null user_id. Authenticated JWT
-- callers still need user_id = auth.uid() which can't be null.
-- No policy change needed.
