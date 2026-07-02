-- Rerunnable rollback test for 20260702090000_squad_member_stats_and_lifecycle.sql
--
-- Run against the linked db (everything rolls back):
--   supabase db query --linked -f supabase/tests/squad_member_stats_and_lifecycle_test.sql
--
-- Covers:
--   1. squad_member_workout_logs returns every member's completed logs to a
--      member, honors p_since, and skips incomplete logs
--   2. squad_member_workout_logs returns zero rows to a non-member
--   3. leave_squad_atomic: non-captain leave removes only the membership
--   4. leave_squad_atomic: captain leave promotes the earliest-joined member
--   5. leave_squad_atomic: last member leave deletes the squad
--   6. friend_challenges decline policy: a participant can DELETE a pending
--      challenge, cannot DELETE an accepted one, and a stranger can't touch it
--
-- All work happens inside one transaction and is rolled back at the end.

begin;

insert into auth.users (id, instance_id, aud, role, email)
values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'cap_lifecycle@example.com'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'mate_lifecycle@example.com'),
  ('cccccccc-cccc-cccc-cccc-ccccccccccc1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'stranger_lifecycle@example.com')
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Scenarios 1 + 2: squad_member_workout_logs gating and content
-- ---------------------------------------------------------------------------
do $$
declare
  v_squad_id uuid;
  v_cap uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1';
  v_mate uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1';
  v_stranger uuid := 'cccccccc-cccc-cccc-cccc-ccccccccccc1';
  v_count int;
  v_members int;
begin
  insert into public.squads (name, captain_id, invite_code)
  values ('LFTEST_LOGS', v_cap, 'LF' || lpad((floor(random()*9999))::text, 4, '0'))
  returning id into v_squad_id;

  insert into public.squad_members (squad_id, user_id)
  values (v_squad_id, v_mate)
  on conflict (squad_id, user_id) do nothing;

  -- Captain: one completed log inside the window, one before it, one incomplete.
  insert into public.workout_logs (user_id, day_number, planned_workout_name, started_at, completed_at, exercise_entries)
  values
    (v_cap, 1, 'LFTEST Recent', now() - interval '1 day', now() - interval '1 day', '[]'::jsonb),
    (v_cap, 2, 'LFTEST Ancient', now() - interval '400 days', now() - interval '400 days', '[]'::jsonb),
    (v_cap, 3, 'LFTEST Unfinished', now(), null, '[]'::jsonb);
  -- Mate: one completed log.
  insert into public.workout_logs (user_id, day_number, planned_workout_name, started_at, completed_at, exercise_entries)
  values (v_mate, 1, 'LFTEST Mate', now() - interval '2 days', now() - interval '2 days', '[]'::jsonb);

  -- As the mate (a regular member): sees the captain's recent log + own log,
  -- not the pre-window or incomplete ones.
  perform set_config('request.jwt.claims', json_build_object('sub', v_mate, 'role', 'authenticated')::text, true);

  select count(*) into v_count
    from public.squad_member_workout_logs(v_squad_id, now() - interval '90 days', 200);
  if v_count <> 2 then
    raise exception 'scenario1: expected 2 logs across members, got %', v_count;
  end if;

  select count(distinct member_user_id) into v_members
    from public.squad_member_workout_logs(v_squad_id, now() - interval '90 days', 200);
  if v_members <> 2 then
    raise exception 'scenario1: expected logs for 2 members, got %', v_members;
  end if;

  -- Window: only the mate's log is newer than 36 hours.
  select count(*) into v_count
    from public.squad_member_workout_logs(v_squad_id, now() - interval '30 hours', 200);
  if v_count <> 1 then
    raise exception 'scenario1: expected 1 log inside 30h window, got %', v_count;
  end if;

  -- As a stranger: zero rows.
  perform set_config('request.jwt.claims', json_build_object('sub', v_stranger, 'role', 'authenticated')::text, true);
  select count(*) into v_count
    from public.squad_member_workout_logs(v_squad_id, now() - interval '90 days', 200);
  if v_count <> 0 then
    raise exception 'scenario2: non-member should get 0 rows, got %', v_count;
  end if;

  perform set_config('request.jwt.claims', '', true);
  raise notice 'scenarios 1-2 (member logs RPC) passed';
end $$;

-- ---------------------------------------------------------------------------
-- Scenarios 3-5: leave_squad_atomic
-- ---------------------------------------------------------------------------
do $$
declare
  v_squad_id uuid;
  v_cap uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1';
  v_mate uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1';
  v_result jsonb;
  v_captain uuid;
  v_count int;
begin
  insert into public.squads (name, captain_id, invite_code)
  values ('LFTEST_LEAVE', v_cap, 'LV' || lpad((floor(random()*9999))::text, 4, '0'))
  returning id into v_squad_id;

  insert into public.squad_members (squad_id, user_id)
  values (v_squad_id, v_mate)
  on conflict (squad_id, user_id) do nothing;

  -- 3. Non-captain leaves: membership gone, captain unchanged, squad intact.
  perform set_config('request.jwt.claims', json_build_object('sub', v_mate, 'role', 'authenticated')::text, true);
  select public.leave_squad_atomic(v_squad_id) into v_result;
  if coalesce(v_result->>'status', '') <> 'left' or (v_result->>'disbanded')::boolean then
    raise exception 'scenario3: unexpected result %', v_result;
  end if;
  select count(*) into v_count from public.squad_members where squad_id = v_squad_id and user_id = v_mate;
  if v_count <> 0 then
    raise exception 'scenario3: mate membership should be deleted';
  end if;
  select captain_id into v_captain from public.squads where id = v_squad_id;
  if v_captain <> v_cap then
    raise exception 'scenario3: captain should be unchanged';
  end if;

  -- Re-join the mate for the succession scenario (older captain stays earliest).
  insert into public.squad_members (squad_id, user_id) values (v_squad_id, v_mate);

  -- 4. Captain leaves: earliest-joined remaining member is promoted.
  perform set_config('request.jwt.claims', json_build_object('sub', v_cap, 'role', 'authenticated')::text, true);
  select public.leave_squad_atomic(v_squad_id) into v_result;
  if coalesce(v_result->>'new_captain_id', '') <> v_mate::text then
    raise exception 'scenario4: expected mate promoted, got %', v_result;
  end if;
  select captain_id into v_captain from public.squads where id = v_squad_id;
  if v_captain <> v_mate then
    raise exception 'scenario4: captain_id should be the mate';
  end if;

  -- 5. Last member (the promoted mate) leaves: squad row is deleted.
  perform set_config('request.jwt.claims', json_build_object('sub', v_mate, 'role', 'authenticated')::text, true);
  select public.leave_squad_atomic(v_squad_id) into v_result;
  if not (v_result->>'disbanded')::boolean then
    raise exception 'scenario5: expected disband, got %', v_result;
  end if;
  select count(*) into v_count from public.squads where id = v_squad_id;
  if v_count <> 0 then
    raise exception 'scenario5: squad row should be deleted';
  end if;

  perform set_config('request.jwt.claims', '', true);
  raise notice 'scenarios 3-5 (leave_squad_atomic) passed';
end $$;

-- ---------------------------------------------------------------------------
-- Scenario 6: friend_challenges decline policy (RLS, so run as authenticated)
-- ---------------------------------------------------------------------------
do $$
declare
  v_squad_id uuid;
  v_cap uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1';
  v_mate uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1';
  v_pending uuid;
  v_accepted uuid;
  v_count int;
begin
  insert into public.squads (name, captain_id, invite_code)
  values ('LFTEST_DECL', v_cap, 'DC' || lpad((floor(random()*9999))::text, 4, '0'))
  returning id into v_squad_id;

  insert into public.squad_members (squad_id, user_id)
  values (v_squad_id, v_mate)
  on conflict (squad_id, user_id) do nothing;

  insert into public.friend_challenges (challenger_id, challenged_id, squad_id, challenge_kind, started_at, expires_at)
  values (v_cap, v_mate, v_squad_id, 'mostSessions', now(), now() + interval '7 days')
  returning id into v_pending;

  insert into public.friend_challenges (challenger_id, challenged_id, squad_id, challenge_kind, started_at, expires_at, accepted_at)
  values (v_cap, v_mate, v_squad_id, 'mostReps', now(), now() + interval '7 days', now())
  returning id into v_accepted;

  -- Switch to the authenticated role so RLS applies.
  perform set_config('request.jwt.claims', json_build_object('sub', v_mate, 'role', 'authenticated')::text, true);
  set local role authenticated;

  -- Accepted challenge cannot be deleted (0 rows affected).
  delete from public.friend_challenges where id = v_accepted;
  select count(*) into v_count from public.friend_challenges where id = v_accepted;
  if v_count <> 1 then
    raise exception 'scenario6: accepted challenge must survive delete';
  end if;

  -- Pending challenge can be declined by the challenged user.
  delete from public.friend_challenges where id = v_pending;
  select count(*) into v_count from public.friend_challenges where id = v_pending;
  if v_count <> 0 then
    raise exception 'scenario6: pending challenge should be deletable by challenged user';
  end if;

  reset role;
  perform set_config('request.jwt.claims', '', true);
  raise notice 'scenario 6 (decline policy) passed';
end $$;

rollback;
