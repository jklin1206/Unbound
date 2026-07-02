-- Squads: cross-member training visibility + membership lifecycle.
--
-- 1. squad_member_workout_logs — the leaderboard/roster/member-detail data
--    source for REAL accounts. workout_logs is owner-only under RLS, so
--    squadmates' rows are invisible to direct selects; this gated
--    SECURITY DEFINER RPC returns each member's completed logs to any
--    caller who shares the squad. The client decodes the jsonb into the
--    same WorkoutLog model it logs with, so streaks / workout days / PRs
--    are computed by ONE Swift implementation for self and squadmates
--    alike (no SQL twin of the PR rules).
-- 2. leave_squad_atomic — leaving as captain previously stranded the
--    squad (captain_id kept pointing at a non-member; squads has no
--    DELETE policy so client-side disband silently no-ops). This RPC
--    deletes the membership, promotes the earliest-joined remaining
--    member when the captain leaves, and deletes the squad when the
--    last member leaves.
-- 3. friend_challenges decline/withdraw — challenges could only be
--    accepted or left to expire. Participants may now DELETE a
--    challenge that has not been accepted and has no winner.

-- ---------------------------------------------------------------------------
-- 1. Cross-member workout logs (gated read)
-- ---------------------------------------------------------------------------
create or replace function public.squad_member_workout_logs(
  p_squad_id uuid,
  p_since timestamptz,
  p_per_member_limit int default 200
)
returns table (member_user_id uuid, log jsonb)
language sql
security definer
set search_path = ''
stable
as $$
  select sm.user_id as member_user_id, to_jsonb(wl.*) as log
  from   public.squad_members sm
  cross join lateral (
    select *
    from   public.workout_logs w
    where  w.user_id = sm.user_id
    and    w.completed_at is not null
    and    w.completed_at >= p_since
    order  by w.completed_at desc
    limit  least(greatest(p_per_member_limit, 1), 500)
  ) wl
  where  sm.squad_id = p_squad_id
  and    public.is_squad_member((select auth.uid()), p_squad_id);
$$;

revoke all on function public.squad_member_workout_logs(uuid, timestamptz, int) from public;
grant execute on function public.squad_member_workout_logs(uuid, timestamptz, int) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 2. Atomic leave with captain succession / last-member disband
-- ---------------------------------------------------------------------------
create or replace function public.leave_squad_atomic(p_squad_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id     uuid := (select auth.uid());
  v_squad       public.squads%rowtype;
  v_new_captain uuid;
begin
  if v_user_id is null then
    return jsonb_build_object('error', 'unauthorized');
  end if;

  select * into v_squad
  from   public.squads
  where  id = p_squad_id
  for update;

  if not found then
    return jsonb_build_object('error', 'squad_not_found');
  end if;

  delete from public.squad_members
  where  squad_id = p_squad_id
  and    user_id  = v_user_id;

  if not found then
    return jsonb_build_object('error', 'not_a_member');
  end if;

  if v_squad.captain_id = v_user_id then
    select user_id into v_new_captain
    from   public.squad_members
    where  squad_id = p_squad_id
    order  by joined_at asc, user_id asc
    limit  1;

    if v_new_captain is null then
      delete from public.squads where id = p_squad_id;
      return jsonb_build_object('status', 'left', 'disbanded', true);
    end if;

    update public.squads
    set    captain_id = v_new_captain
    where  id = p_squad_id;

    return jsonb_build_object(
      'status', 'left',
      'disbanded', false,
      'new_captain_id', v_new_captain
    );
  end if;

  return jsonb_build_object('status', 'left', 'disbanded', false);
end;
$$;

revoke all on function public.leave_squad_atomic(uuid) from public;
grant execute on function public.leave_squad_atomic(uuid) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 3. Decline / withdraw a pending friend challenge
-- ---------------------------------------------------------------------------
drop policy if exists "friend_challenges_participant_delete" on public.friend_challenges;
create policy "friend_challenges_participant_delete" on public.friend_challenges
  for delete using (
    (select auth.uid()) in (challenger_id, challenged_id)
    and accepted_at is null
    and winner_user_id is null
  );
