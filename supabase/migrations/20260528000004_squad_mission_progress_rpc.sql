-- Server-side increment of squad_missions.current_progress (WS-B B2, sub-issue C).
--
-- squad_missions has RLS UPDATE policy `using (false)` for authenticated callers
-- (only the service-role Edge Function may mutate it). That blocked the iOS
-- client's SquadMissionService.recordProgress() from ever advancing a mission,
-- so the evaluate_squad_mission cron (which completes a mission when
-- current_progress >= target) had nothing to complete.
--
-- This SECURITY DEFINER RPC lets a *squad member* bump their own squad's
-- current-week open mission by p_delta, without granting blanket UPDATE on the
-- table. Mirrors the sync_merge_row ownership-guard pattern (20260528000002).
--
-- Contract (called by SquadBackend.incrementMissionProgress):
--   p_squad_id : the caller's squad id.
--   p_delta    : amount to add to current_progress (always +1 from the client).
--
-- Guard: caller must be a member of p_squad_id. service_role (auth.uid() null)
-- is trusted and skips the check. Only the most-recent OPEN mission for the
-- current ISO week is touched; if none exists (cron hasn't generated one yet)
-- the call is a no-op.
create or replace function public.increment_squad_mission_progress(
  p_squad_id uuid,
  p_delta int
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();   -- null for service_role / trusted backend calls
  v_week_iso text;
begin
  -- Ownership guard: end-user calls must come from a member of the squad.
  if v_uid is not null and not public.is_squad_member(v_uid, p_squad_id) then
    raise exception 'increment_squad_mission_progress: caller % is not a member of squad %', v_uid, p_squad_id;
  end if;

  -- Bound the delta so a misbehaving / replayed client can't inflate progress.
  if p_delta is null or p_delta < 0 or p_delta > 100 then
    raise exception 'increment_squad_mission_progress: delta % out of range', p_delta;
  end if;

  -- ISO week (ISO-8601: %G year-of-week, %V week number), matching
  -- SquadMissionService.currentWeekIso() ("YYYY-Wnn").
  v_week_iso := to_char(now() at time zone 'UTC', 'IYYY') || '-W' || to_char(now() at time zone 'UTC', 'IW');

  update public.squad_missions sm
     set current_progress = sm.current_progress + p_delta
   where sm.id = (
     select id
       from public.squad_missions
      where squad_id = p_squad_id
        and week_iso = v_week_iso
        and completed_at is null
      order by created_at desc
      limit 1
   );
end;
$$;

grant execute on function public.increment_squad_mission_progress(uuid, int) to authenticated, service_role;
