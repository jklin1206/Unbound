-- Squads v2 — kind-aware co-op mission progress.
--
-- The weekly squad mission pipeline already records progress idempotently by
-- workout-log id (see 20260601084000_squad_progress_source_ledgers.sql). This
-- migration makes the recorded *amount* kind-aware: the client RPC and the
-- workout-completion trigger still pass delta=1 as a SIGNAL, but the helper now
-- computes the real per-kind delta server-side from the trusted
-- workout_logs.exercise_entries jsonb. The client never supplies an amount.
--
-- Five mission kinds (hash mod 5, order is the cross-site contract shared with
-- SquadMissionCatalog.swift and evaluate_squad_mission/index.ts):
--   idx 0 total_weight   (8000 * memberCount)  — Σ weightKg×reps, non-warmup
--   idx 1 total_sessions (4 * memberCount)      — 1 per completed session
--   idx 2 total_reps     (600 * memberCount)    — Σ reps, non-warmup
--   idx 3 crew_coverage  (memberCount)          — members with >= 3 sessions
--   idx 4 train_together (3)                     — linked sessions (edge fn path)
--
-- Adds pick_squad_mission(uuid, text): captain-gated immediate selection of the
-- week's mission, superseding the deterministic hash fallback.

-- ---------------------------------------------------------------------------
-- Relax the receipts delta bound: total_weight/total_reps deltas exceed 100.
-- The original inline `check (delta >= 0 and delta <= 100)` auto-named
-- squad_mission_progress_receipts_delta_check. Keep a non-negativity floor.
-- ---------------------------------------------------------------------------
alter table public.squad_mission_progress_receipts
  drop constraint if exists squad_mission_progress_receipts_delta_check;
alter table public.squad_mission_progress_receipts
  add constraint squad_mission_progress_receipts_delta_check check (delta >= 0);

-- ---------------------------------------------------------------------------
-- (a) Kind-aware delta computation in the source-validated helper.
--     Signature UNCHANGED (uuid, int, text, uuid) so both existing callers —
--     the auth-forwarding wrapper increment_squad_mission_progress(uuid,int,text)
--     and the workout-completion trigger record_workout_log_social_progress —
--     keep working without modification.
-- (b) 5-kind deterministic fallback catalog (hash mod 5).
-- ---------------------------------------------------------------------------
create or replace function public.increment_squad_mission_progress_for_user(
  p_squad_id uuid,
  p_delta int,
  p_source_log_id text,
  p_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_source_uuid uuid;
  v_week_iso text;
  v_mission_id uuid;
  v_existing_mission_id uuid;
  v_member_count int;
  v_seed text;
  v_hash bigint := 0;
  v_i int;
  v_template_idx int;
  v_mission_kind text;
  v_target int;
  v_kind text;
  v_entries jsonb;
  v_delta int;
  v_inserted int := 0;
begin
  if p_user_id is null then
    raise exception 'increment_squad_mission_progress: user_id is required';
  end if;

  if not public.is_squad_member(p_user_id, p_squad_id) then
    raise exception 'increment_squad_mission_progress: user % is not a member of squad %', p_user_id, p_squad_id;
  end if;

  -- p_delta is a SIGNAL only now; the real delta is computed server-side below.

  if nullif(trim(p_source_log_id), '') is null then
    raise exception 'increment_squad_mission_progress: source_log_id is required';
  end if;

  v_week_iso := to_char(now() at time zone 'UTC', 'IYYY') || '-W' || to_char(now() at time zone 'UTC', 'IW');

  begin
    v_source_uuid := p_source_log_id::uuid;
  exception when invalid_text_representation then
    raise exception 'increment_squad_mission_progress: source_log_id must be a workout log uuid';
  end;

  -- Source-log ownership + current-week guard. Capture exercise_entries here so
  -- the delta math runs over the trusted server-side log, never client input.
  select wl.exercise_entries
    into v_entries
    from public.workout_logs wl
   where wl.id = v_source_uuid
     and wl.user_id = p_user_id
     and wl.completed_at is not null
     and (
       to_char(wl.completed_at at time zone 'UTC', 'IYYY') ||
       '-W' ||
       to_char(wl.completed_at at time zone 'UTC', 'IW')
     ) = v_week_iso;

  if not found then
    raise exception 'increment_squad_mission_progress: current-week completed workout source % for user % not found',
      p_source_log_id, p_user_id;
  end if;

  select sm.id
    into v_mission_id
    from public.squad_missions sm
   where sm.squad_id = p_squad_id
     and sm.week_iso = v_week_iso
     and sm.completed_at is null
   order by sm.created_at desc
   limit 1
   for update;

  if v_mission_id is null then
    select sm.id
      into v_existing_mission_id
      from public.squad_missions sm
     where sm.squad_id = p_squad_id
       and sm.week_iso = v_week_iso
     limit 1;

    -- A mission already exists for this week but is complete; this workout simply
    -- has no active mission to advance.
    if v_existing_mission_id is not null then
      return;
    end if;

    select count(*)
      into v_member_count
      from public.squad_members sm
     where sm.squad_id = p_squad_id;

    -- Mirrors the Edge Function: solo squads do not receive weekly missions.
    if coalesce(v_member_count, 0) < 2 then
      return;
    end if;

    -- Keep the pre-cron fallback deterministic with evaluate_squad_mission.ts.
    -- Hash routine is byte-identical to the original; only the modulus drops to 5.
    v_seed := p_squad_id::text || v_week_iso;
    for v_i in 1..char_length(v_seed) loop
      v_hash := mod((31 * v_hash + ascii(substr(v_seed, v_i, 1))), 4294967296);
    end loop;
    if v_hash >= 2147483648 then
      v_hash := v_hash - 4294967296;
    end if;
    v_template_idx := mod(abs(v_hash), 5)::int;

    case v_template_idx
      when 0 then
        v_mission_kind := 'total_weight';
        v_target := 8000 * v_member_count;
      when 1 then
        v_mission_kind := 'total_sessions';
        v_target := 4 * v_member_count;
      when 2 then
        v_mission_kind := 'total_reps';
        v_target := 600 * v_member_count;
      when 3 then
        v_mission_kind := 'crew_coverage';
        v_target := v_member_count;
      else
        v_mission_kind := 'train_together';
        v_target := 3;
    end case;

    insert into public.squad_missions (
      squad_id,
      week_iso,
      mission_kind,
      target,
      current_progress,
      created_at
    )
    values (
      p_squad_id,
      v_week_iso,
      v_mission_kind,
      v_target,
      0,
      now()
    )
    on conflict (squad_id, week_iso) do nothing;

    select sm.id
      into v_mission_id
      from public.squad_missions sm
     where sm.squad_id = p_squad_id
       and sm.week_iso = v_week_iso
       and sm.completed_at is null
     order by sm.created_at desc
     limit 1
     for update;
  end if;

  if v_mission_id is null then
    raise exception 'increment_squad_mission_progress: no active mission for squad % week %', p_squad_id, v_week_iso;
  end if;

  -- Kind-aware server-computed delta from the trusted exercise_entries jsonb.
  select sm.mission_kind into v_kind
    from public.squad_missions sm
   where sm.id = v_mission_id;

  v_delta := case v_kind
    when 'total_sessions' then 1
    when 'crew_coverage'  then 1
    when 'total_weight' then (
      select coalesce(floor(sum(
        coalesce((s->>'weightKg')::numeric, 0) * coalesce((s->>'reps')::int, 0)
      ))::int, 0)
      from jsonb_array_elements(v_entries) e,
           jsonb_array_elements(e->'sets') s
      where coalesce((s->>'isWarmup')::boolean, false) = false
    )
    when 'total_reps' then (
      select coalesce(sum(coalesce((s->>'reps')::int, 0)), 0)
      from jsonb_array_elements(v_entries) e,
           jsonb_array_elements(e->'sets') s
      where coalesce((s->>'isWarmup')::boolean, false) = false
    )
    else 0   -- train_together progresses via linked sessions; legacy kinds inert
  end;

  -- No qualifying work → record nothing (do not write a dedup receipt, so a
  -- later log for the same week's mission can still contribute).
  if v_delta is null or v_delta <= 0 then
    return;
  end if;

  insert into public.squad_mission_progress_receipts (squad_id, mission_id, source_log_id, user_id, delta)
  values (p_squad_id, v_mission_id, v_source_uuid::text, p_user_id, v_delta)
  on conflict (squad_id, source_log_id) do nothing;

  get diagnostics v_inserted = row_count;
  if v_inserted = 0 then
    return;
  end if;

  if v_kind = 'crew_coverage' then
    -- Coverage = count of members who have logged >= 3 contributing sessions.
    update public.squad_missions sm
       set current_progress = (
         select count(*) from (
           select r.user_id
             from public.squad_mission_progress_receipts r
            where r.mission_id = v_mission_id
            group by r.user_id
           having count(*) >= 3
         ) covered
       )
     where sm.id = v_mission_id;
  else
    update public.squad_missions sm
       set current_progress = sm.current_progress + v_delta
     where sm.id = v_mission_id;
  end if;

  -- Close immediately (the nightly cron remains the backstop) so the in-app
  -- celebration can fire in the same session the target is reached.
  update public.squad_missions sm
     set completed_at = now()
   where sm.id = v_mission_id
     and sm.completed_at is null
     and sm.current_progress >= sm.target;
end;
$$;

revoke all on function public.increment_squad_mission_progress_for_user(uuid, int, text, uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- (c) pick_squad_mission — captain-gated immediate mission selection.
-- ---------------------------------------------------------------------------
create or replace function public.pick_squad_mission(
  p_squad_id uuid,
  p_kind text
)
returns setof public.squad_missions
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_week_iso text;
  v_member_count int;
  v_target int;
begin
  if v_uid is null then
    raise exception 'pick_squad_mission: authenticated caller required';
  end if;
  if not exists (select 1 from public.squads s where s.id = p_squad_id and s.captain_id = v_uid) then
    raise exception 'pick_squad_mission: caller is not the captain of squad %', p_squad_id;
  end if;
  if p_kind not in ('total_weight','total_sessions','total_reps','crew_coverage','train_together') then
    raise exception 'pick_squad_mission: unknown kind %', p_kind;
  end if;

  v_week_iso := to_char(now() at time zone 'UTC', 'IYYY') || '-W' || to_char(now() at time zone 'UTC', 'IW');
  select count(*) into v_member_count from public.squad_members sm where sm.squad_id = p_squad_id;
  if coalesce(v_member_count, 0) < 2 then
    raise exception 'pick_squad_mission: squad needs at least 2 members';
  end if;

  v_target := case p_kind
    when 'total_weight'   then 8000 * v_member_count
    when 'total_sessions' then 4 * v_member_count
    when 'total_reps'     then 600 * v_member_count
    when 'crew_coverage'  then v_member_count
    else 3  -- train_together
  end;

  return query
    insert into public.squad_missions (squad_id, week_iso, mission_kind, target, current_progress)
    values (p_squad_id, v_week_iso, p_kind, v_target, 0)
    on conflict (squad_id, week_iso) do nothing
    returning *;
end;
$$;

revoke all on function public.pick_squad_mission(uuid, text) from public, anon;
grant execute on function public.pick_squad_mission(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- (d) Verification.
-- ---------------------------------------------------------------------------
do $$
begin
  if to_regprocedure('public.increment_squad_mission_progress_for_user(uuid,int,text,uuid)') is null then
    raise exception 'kind-aware squad mission helper missing';
  end if;

  if to_regprocedure('public.pick_squad_mission(uuid,text)') is null then
    raise exception 'pick_squad_mission RPC missing';
  end if;

  -- The auth-forwarding wrapper must still exist (untouched by this migration).
  if to_regprocedure('public.increment_squad_mission_progress(uuid,int,text)') is null then
    raise exception 'auth-forwarding squad mission wrapper missing';
  end if;

  -- The old delta upper-bound (delta <= 100) must be gone: assert no remaining
  -- check on the receipts table references the literal 100.
  if exists (
    select 1
      from pg_constraint c
     where c.conrelid = 'public.squad_mission_progress_receipts'::regclass
       and c.contype = 'c'
       and pg_get_constraintdef(c.oid) like '%100%'
  ) then
    raise exception 'receipts delta upper-bound constraint (<= 100) still present';
  end if;
end
$$;
