-- Rerunnable rollback test for 20260611120000_squad_mission_kinds_v2.sql
--
-- Run against the linked db (everything rolls back):
--   supabase db query --linked -f supabase/tests/squad_mission_kinds_v2_test.sql
--
-- Covers:
--   1. total_weight delta computation from exercise_entries (non-warmup, floor)
--   2. crew_coverage per-member >= 3 sessions counting
--   3. pick_squad_mission captain gating (non-captain raises)
--
-- All work happens inside one transaction and is rolled back at the end, so it
-- leaves no rows behind and can be run repeatedly.

begin;

-- Synthetic identities. Fixed uuids so the script is deterministic.
-- (Insert directly into auth.users to satisfy the FKs; rolled back at the end.)
insert into auth.users (id, instance_id, aud, role, email)
values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'cap_v2test@example.com'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'mate_v2test@example.com')
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Scenario 1: total_weight — server delta = Σ weightKg×reps over non-warmup sets
-- ---------------------------------------------------------------------------
do $$
declare
  v_squad_id uuid;
  v_cap uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  v_mate uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  v_log_id uuid := gen_random_uuid();
  v_mission_id uuid;
  v_progress int;
  v_expected int;
begin
  -- Captain creates the squad (trigger auto-joins captain as a member).
  insert into public.squads (name, captain_id, invite_code)
  values ('V2TEST_TW', v_cap, 'ZZ' || lpad((floor(random()*9999))::text, 4, '0'))
  returning id into v_squad_id;

  insert into public.squad_members (squad_id, user_id)
  values (v_squad_id, v_mate)
  on conflict (squad_id, user_id) do nothing;

  -- Captain picks the total_weight mission (captain-gated RPC). Set auth.uid().
  perform set_config('request.jwt.claims', json_build_object('sub', v_cap, 'role', 'authenticated')::text, true);
  perform public.pick_squad_mission(v_squad_id, 'total_weight');
  perform set_config('request.jwt.claims', '', true);

  select id into v_mission_id
    from public.squad_missions
   where squad_id = v_squad_id
     and mission_kind = 'total_weight';
  if v_mission_id is null then
    raise exception 'scenario1: pick_squad_mission did not create a total_weight mission';
  end if;

  -- A completed workout for the captain in the current ISO week.
  -- Sets: 80×5 (working) + 100×3 (working) + 60×8 (WARMUP, must be ignored).
  -- Expected delta = 80*5 + 100*3 = 400 + 300 = 700.
  v_expected := 700;
  insert into public.workout_logs (id, user_id, day_number, planned_workout_name, started_at, completed_at, exercise_entries)
  values (
    v_log_id,
    v_cap,
    1,
    'V2TEST Day',
    now(),
    now(),
    '[
      {"exerciseName":"Bench Press","sets":[
        {"weightKg":80,"reps":5,"isWarmup":false},
        {"weightKg":100,"reps":3,"isWarmup":false},
        {"weightKg":60,"reps":8,"isWarmup":true}
      ]}
    ]'::jsonb
  );

  -- Record progress (p_delta=1 is a signal; the helper computes the real 700).
  perform public.increment_squad_mission_progress_for_user(v_squad_id, 1, v_log_id::text, v_cap);

  select current_progress into v_progress from public.squad_missions where id = v_mission_id;
  assert v_progress = v_expected,
    format('scenario1 total_weight: expected progress %s, got %s', v_expected, v_progress);

  -- Idempotency: replaying the same source log must not double-count.
  perform public.increment_squad_mission_progress_for_user(v_squad_id, 1, v_log_id::text, v_cap);
  select current_progress into v_progress from public.squad_missions where id = v_mission_id;
  assert v_progress = v_expected,
    format('scenario1 idempotency: expected %s after replay, got %s', v_expected, v_progress);

  raise notice 'scenario1 total_weight OK: progress=%', v_progress;
end
$$;

-- ---------------------------------------------------------------------------
-- Scenario 2: crew_coverage — progress = count of members with >= 3 sessions
-- ---------------------------------------------------------------------------
do $$
declare
  v_squad_id uuid;
  v_cap uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  v_mate uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  v_mission_id uuid;
  v_progress int;
  v_log uuid;
  i int;
begin
  insert into public.squads (name, captain_id, invite_code)
  values ('V2TEST_CC', v_cap, 'YY' || lpad((floor(random()*9999))::text, 4, '0'))
  returning id into v_squad_id;

  insert into public.squad_members (squad_id, user_id)
  values (v_squad_id, v_mate)
  on conflict (squad_id, user_id) do nothing;

  perform set_config('request.jwt.claims', json_build_object('sub', v_cap, 'role', 'authenticated')::text, true);
  perform public.pick_squad_mission(v_squad_id, 'crew_coverage');
  perform set_config('request.jwt.claims', '', true);

  select id into v_mission_id from public.squad_missions
   where squad_id = v_squad_id and mission_kind = 'crew_coverage';

  -- Captain logs 3 sessions (each a distinct source log) → captain counts as 1.
  for i in 1..3 loop
    v_log := gen_random_uuid();
    insert into public.workout_logs (id, user_id, day_number, planned_workout_name, started_at, completed_at, exercise_entries)
    values (v_log, v_cap, 1, 'V2TEST Day', now(), now(), '[{"exerciseName":"Squat","sets":[{"weightKg":100,"reps":5,"isWarmup":false}]}]'::jsonb);
    perform public.increment_squad_mission_progress_for_user(v_squad_id, 1, v_log::text, v_cap);
  end loop;

  -- Mate logs only 2 sessions → NOT covered yet.
  for i in 1..2 loop
    v_log := gen_random_uuid();
    insert into public.workout_logs (id, user_id, day_number, planned_workout_name, started_at, completed_at, exercise_entries)
    values (v_log, v_mate, 1, 'V2TEST Day', now(), now(), '[{"exerciseName":"Squat","sets":[{"weightKg":100,"reps":5,"isWarmup":false}]}]'::jsonb);
    perform public.increment_squad_mission_progress_for_user(v_squad_id, 1, v_log::text, v_mate);
  end loop;

  select current_progress into v_progress from public.squad_missions where id = v_mission_id;
  assert v_progress = 1,
    format('scenario2 crew_coverage: after cap(3)+mate(2) expected 1 covered, got %s', v_progress);

  -- Mate's 3rd session pushes them to covered → progress becomes 2.
  v_log := gen_random_uuid();
  insert into public.workout_logs (id, user_id, day_number, planned_workout_name, started_at, completed_at, exercise_entries)
  values (v_log, v_mate, 1, 'V2TEST Day', now(), now(), '[{"exerciseName":"Squat","sets":[{"weightKg":100,"reps":5,"isWarmup":false}]}]'::jsonb);
  perform public.increment_squad_mission_progress_for_user(v_squad_id, 1, v_log::text, v_mate);

  select current_progress into v_progress from public.squad_missions where id = v_mission_id;
  assert v_progress = 2,
    format('scenario2 crew_coverage: after mate 3rd session expected 2 covered, got %s', v_progress);

  raise notice 'scenario2 crew_coverage OK: progress=%', v_progress;
end
$$;

-- ---------------------------------------------------------------------------
-- Scenario 3: pick_squad_mission must reject a non-captain caller
-- ---------------------------------------------------------------------------
do $$
declare
  v_squad_id uuid;
  v_cap uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  v_mate uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  v_raised boolean := false;
begin
  insert into public.squads (name, captain_id, invite_code)
  values ('V2TEST_GATE', v_cap, 'XX' || lpad((floor(random()*9999))::text, 4, '0'))
  returning id into v_squad_id;

  insert into public.squad_members (squad_id, user_id)
  values (v_squad_id, v_mate)
  on conflict (squad_id, user_id) do nothing;

  -- Act as the non-captain mate.
  perform set_config('request.jwt.claims', json_build_object('sub', v_mate, 'role', 'authenticated')::text, true);
  begin
    perform public.pick_squad_mission(v_squad_id, 'total_reps');
  exception when others then
    v_raised := true;
  end;
  perform set_config('request.jwt.claims', '', true);

  assert v_raised, 'scenario3 captain-gate: non-captain pick_squad_mission did NOT raise';
  raise notice 'scenario3 captain-gate OK: non-captain correctly rejected';
end
$$;

rollback;
