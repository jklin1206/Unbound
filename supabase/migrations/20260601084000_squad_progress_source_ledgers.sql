-- Durable source ledgers for workout-driven squad/friend progress.
--
-- Training completion may retry after local crashes or partial persistence.
-- These receipts make the remote counters idempotent by performanceLog.id
-- instead of trusting a process-local client guard.

alter table public.workout_logs
  add column if not exists local_start_hour int
  check (local_start_hour is null or (local_start_hour >= 0 and local_start_hour <= 23));

alter table public.workout_logs
  alter column program_id drop not null;

create table if not exists public.squad_mission_progress_receipts (
  id uuid primary key default gen_random_uuid(),
  squad_id uuid not null references public.squads(id) on delete cascade,
  mission_id uuid not null references public.squad_missions(id) on delete cascade,
  source_log_id text not null,
  user_id uuid references auth.users(id) on delete set null,
  delta int not null check (delta >= 0 and delta <= 100),
  created_at timestamptz not null default now(),
  unique (squad_id, source_log_id)
);

create index if not exists squad_mission_progress_receipts_squad_created_idx
  on public.squad_mission_progress_receipts (squad_id, created_at desc);
create index if not exists squad_mission_progress_receipts_mission_created_idx
  on public.squad_mission_progress_receipts (mission_id, created_at desc);

alter table public.squad_mission_progress_receipts enable row level security;

drop policy if exists "squad_mission_progress_receipts: members can read"
  on public.squad_mission_progress_receipts;
create policy "squad_mission_progress_receipts: members can read"
  on public.squad_mission_progress_receipts for select
  to authenticated
  using (public.is_squad_member(auth.uid(), squad_id));

drop policy if exists "squad_mission_progress_receipts: rpc insert only"
  on public.squad_mission_progress_receipts;
create policy "squad_mission_progress_receipts: rpc insert only"
  on public.squad_mission_progress_receipts for insert
  to authenticated
  with check (false);

drop policy if exists "friend_challenges: participants can update progress"
  on public.friend_challenges;

drop policy if exists "friend_challenges: challenged user can accept"
  on public.friend_challenges;

revoke update on table public.friend_challenges from public, anon, authenticated;
grant update (accepted_at) on table public.friend_challenges to authenticated;
grant update on table public.friend_challenges to service_role;

create policy "friend_challenges: challenged user can accept"
  on public.friend_challenges for update
  to authenticated
  using (
    auth.uid() = challenged_id
    and accepted_at is null
    and winner_user_id is null
  )
  with check (
    auth.uid() = challenged_id
    and accepted_at is not null
    and winner_user_id is null
  );

drop function if exists public.increment_squad_mission_progress(uuid, int);

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
  v_inserted int := 0;
begin
  if p_user_id is null then
    raise exception 'increment_squad_mission_progress: user_id is required';
  end if;

  if not public.is_squad_member(p_user_id, p_squad_id) then
    raise exception 'increment_squad_mission_progress: user % is not a member of squad %', p_user_id, p_squad_id;
  end if;

  if p_delta is distinct from 1 then
    raise exception 'increment_squad_mission_progress: delta must be 1';
  end if;

  if nullif(trim(p_source_log_id), '') is null then
    raise exception 'increment_squad_mission_progress: source_log_id is required';
  end if;

  v_week_iso := to_char(now() at time zone 'UTC', 'IYYY') || '-W' || to_char(now() at time zone 'UTC', 'IW');

  begin
    v_source_uuid := p_source_log_id::uuid;
  exception when invalid_text_representation then
    raise exception 'increment_squad_mission_progress: source_log_id must be a workout log uuid';
  end;

  if not exists (
    select 1
      from public.workout_logs wl
     where wl.id = v_source_uuid
       and wl.user_id = p_user_id
       and wl.completed_at is not null
       and (
         to_char(wl.completed_at at time zone 'UTC', 'IYYY') ||
         '-W' ||
         to_char(wl.completed_at at time zone 'UTC', 'IW')
       ) = v_week_iso
  ) then
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
    v_seed := p_squad_id::text || v_week_iso;
    for v_i in 1..char_length(v_seed) loop
      v_hash := mod((31 * v_hash + ascii(substr(v_seed, v_i, 1))), 4294967296);
    end loop;
    if v_hash >= 2147483648 then
      v_hash := v_hash - 4294967296;
    end if;
    v_template_idx := mod(abs(v_hash), 6)::int;

    case v_template_idx
      when 0 then
        v_mission_kind := 'alignedSessions';
        v_target := 4 * v_member_count;
      when 1 then
        v_mission_kind := 'capstonesTogether';
        v_target := v_member_count;
      when 2 then
        v_mission_kind := 'focusSessions';
        v_target := 6 * v_member_count;
      when 3 then
        v_mission_kind := 'tierCrossings';
        v_target := v_member_count;
      when 4 then
        v_mission_kind := 'linkedSessions';
        v_target := 3;
      else
        v_mission_kind := 'perfectAttendance';
        v_target := v_member_count;
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

  insert into public.squad_mission_progress_receipts (squad_id, mission_id, source_log_id, user_id, delta)
  values (p_squad_id, v_mission_id, v_source_uuid::text, p_user_id, p_delta)
  on conflict (squad_id, source_log_id) do nothing;

  get diagnostics v_inserted = row_count;
  if v_inserted = 0 then
    return;
  end if;

  update public.squad_missions sm
     set current_progress = sm.current_progress + p_delta
   where sm.id = v_mission_id;
end;
$$;

revoke all on function public.increment_squad_mission_progress_for_user(uuid, int, text, uuid) from public, anon, authenticated;

create or replace function public.increment_squad_mission_progress(
  p_squad_id uuid,
  p_delta int,
  p_source_log_id text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_role text := coalesce(auth.role(), '');
  v_source_uuid uuid;
begin
  if v_uid is null and v_role <> 'service_role' then
    raise exception 'increment_squad_mission_progress: authenticated caller required';
  end if;

  if v_uid is null then
    begin
      v_source_uuid := p_source_log_id::uuid;
    exception when invalid_text_representation then
      raise exception 'increment_squad_mission_progress: source_log_id must be a workout log uuid';
    end;

    select wl.user_id
      into v_uid
      from public.workout_logs wl
     where wl.id = v_source_uuid
       and wl.completed_at is not null;
  end if;

  perform public.increment_squad_mission_progress_for_user(
    p_squad_id,
    p_delta,
    p_source_log_id,
    v_uid
  );
end;
$$;

revoke all on function public.increment_squad_mission_progress(uuid, int, text) from public, anon;
grant execute on function public.increment_squad_mission_progress(uuid, int, text) to authenticated, service_role;

create table if not exists public.friend_challenge_progress_receipts (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.friend_challenges(id) on delete cascade,
  participant_user_id uuid not null references auth.users(id) on delete cascade,
  source_log_id text not null,
  delta int not null check (delta >= 0 and delta <= 100),
  created_at timestamptz not null default now(),
  unique (challenge_id, participant_user_id, source_log_id)
);

create index if not exists friend_challenge_progress_receipts_challenge_created_idx
  on public.friend_challenge_progress_receipts (challenge_id, created_at desc);

alter table public.friend_challenge_progress_receipts enable row level security;

drop policy if exists "friend_challenge_progress_receipts: participants can read"
  on public.friend_challenge_progress_receipts;
create policy "friend_challenge_progress_receipts: participants can read"
  on public.friend_challenge_progress_receipts for select
  to authenticated
  using (
    exists (
      select 1
        from public.friend_challenges fc
       where fc.id = challenge_id
         and (fc.challenger_id = auth.uid() or fc.challenged_id = auth.uid())
    )
  );

drop policy if exists "friend_challenge_progress_receipts: rpc insert only"
  on public.friend_challenge_progress_receipts;
create policy "friend_challenge_progress_receipts: rpc insert only"
  on public.friend_challenge_progress_receipts for insert
  to authenticated
  with check (false);

create or replace function public.increment_friend_challenge_progress_for_user(
  p_challenge_id uuid,
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
  v_source_started_at timestamptz;
  v_source_completed_at timestamptz;
  v_source_local_start_hour int;
  v_source_rpe int;
  v_is_challenger boolean;
  v_kind text;
  v_qualifies boolean;
  v_inserted int := 0;
begin
  if p_user_id is null then
    raise exception 'increment_friend_challenge_progress: user_id is required';
  end if;

  if p_delta is distinct from 1 then
    raise exception 'increment_friend_challenge_progress: delta must be 1';
  end if;

  if nullif(trim(p_source_log_id), '') is null then
    raise exception 'increment_friend_challenge_progress: source_log_id is required';
  end if;

  begin
    v_source_uuid := p_source_log_id::uuid;
  exception when invalid_text_representation then
    raise exception 'increment_friend_challenge_progress: source_log_id must be a workout log uuid';
  end;

  select wl.started_at, wl.completed_at, wl.local_start_hour, wl.overall_rpe
    into v_source_started_at, v_source_completed_at, v_source_local_start_hour, v_source_rpe
      from public.workout_logs wl
     where wl.id = v_source_uuid
       and wl.user_id = p_user_id
       and wl.completed_at is not null;

  if v_source_completed_at is null then
    raise exception 'increment_friend_challenge_progress: completed workout source % for user % not found',
      p_source_log_id, p_user_id;
  end if;

  select fc.challenger_id = p_user_id, fc.challenge_kind
    into v_is_challenger, v_kind
    from public.friend_challenges fc
   where fc.id = p_challenge_id
     and fc.accepted_at is not null
     and fc.winner_user_id is null
     and fc.started_at <= v_source_completed_at
     and fc.expires_at >= v_source_completed_at
     and (fc.challenger_id = p_user_id or fc.challenged_id = p_user_id)
   for update;

  if v_is_challenger is null then
    raise exception 'increment_friend_challenge_progress: user % cannot update challenge %', p_user_id, p_challenge_id;
  end if;

  v_qualifies := case v_kind
    when 'mostSessions' then true
    when 'noMissedDays' then true
    when 'mostAlignedSessions' then coalesce(v_source_rpe, 0) > 0
    when 'earlyRiser' then v_source_local_start_hour is not null and v_source_local_start_hour < 8
    else false
  end;

  if not v_qualifies then
    return;
  end if;

  insert into public.friend_challenge_progress_receipts (
    challenge_id,
    participant_user_id,
    source_log_id,
    delta
  )
  values (p_challenge_id, p_user_id, v_source_uuid::text, p_delta)
  on conflict (challenge_id, participant_user_id, source_log_id) do nothing;

  get diagnostics v_inserted = row_count;
  if v_inserted = 0 then
    return;
  end if;

  if v_is_challenger then
    update public.friend_challenges
       set challenger_progress = challenger_progress + p_delta
     where id = p_challenge_id
       and winner_user_id is null;
  else
    update public.friend_challenges
       set challenged_progress = challenged_progress + p_delta
     where id = p_challenge_id
       and winner_user_id is null;
  end if;
end;
$$;

revoke all on function public.increment_friend_challenge_progress_for_user(uuid, int, text, uuid) from public, anon, authenticated;

create or replace function public.increment_friend_challenge_progress(
  p_challenge_id uuid,
  p_delta int,
  p_source_log_id text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_role text := coalesce(auth.role(), '');
  v_source_uuid uuid;
begin
  if v_uid is null and v_role <> 'service_role' then
    raise exception 'increment_friend_challenge_progress: authenticated caller required';
  end if;

  if v_uid is null then
    begin
      v_source_uuid := p_source_log_id::uuid;
    exception when invalid_text_representation then
      raise exception 'increment_friend_challenge_progress: source_log_id must be a workout log uuid';
    end;

    select wl.user_id
      into v_uid
      from public.workout_logs wl
     where wl.id = v_source_uuid
       and wl.completed_at is not null;
  end if;

  perform public.increment_friend_challenge_progress_for_user(
    p_challenge_id,
    p_delta,
    p_source_log_id,
    v_uid
  );
end;
$$;

revoke all on function public.increment_friend_challenge_progress(uuid, int, text) from public, anon;
grant execute on function public.increment_friend_challenge_progress(uuid, int, text) to authenticated, service_role;

create or replace function public.settle_friend_challenge(
  p_challenge_id uuid
)
returns setof public.friend_challenges
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_role text := coalesce(auth.role(), '');
  v_challenge record;
  v_winner_id uuid;
begin
  if v_uid is null and v_role <> 'service_role' then
    raise exception 'settle_friend_challenge: authenticated caller required';
  end if;

  select fc.id,
         fc.challenger_id,
         fc.challenged_id,
         fc.challenger_progress,
         fc.challenged_progress
    into v_challenge
    from public.friend_challenges fc
   where fc.id = p_challenge_id
     and fc.accepted_at is not null
     and fc.winner_user_id is null
     and fc.expires_at < now()
     and (
       v_role = 'service_role'
       or fc.challenger_id = v_uid
       or fc.challenged_id = v_uid
     )
   for update;

  if v_challenge.id is null then
    return;
  end if;

  if v_challenge.challenged_progress > v_challenge.challenger_progress then
    v_winner_id := v_challenge.challenged_id;
  else
    v_winner_id := v_challenge.challenger_id;
  end if;

  return query
    update public.friend_challenges fc
       set winner_user_id = v_winner_id
     where fc.id = p_challenge_id
       and fc.winner_user_id is null
     returning fc.*;
end;
$$;

revoke all on function public.settle_friend_challenge(uuid) from public, anon;
grant execute on function public.settle_friend_challenge(uuid) to authenticated, service_role;

create or replace function public.record_workout_log_social_progress()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_squad_id uuid;
  v_challenge record;
  v_current_week_iso text;
  v_completed_week_iso text;
  v_should_increment boolean;
begin
  if new.completed_at is null then
    return new;
  end if;

  if tg_op = 'UPDATE' then
    if old.completed_at is not distinct from new.completed_at then
      return new;
    end if;
  end if;

  v_current_week_iso := to_char(now() at time zone 'UTC', 'IYYY') || '-W' || to_char(now() at time zone 'UTC', 'IW');
  v_completed_week_iso :=
    to_char(new.completed_at at time zone 'UTC', 'IYYY') ||
    '-W' ||
    to_char(new.completed_at at time zone 'UTC', 'IW');

  if v_completed_week_iso = v_current_week_iso then
    for v_squad_id in
      select sm.squad_id
        from public.squad_members sm
       where sm.user_id = new.user_id
    loop
      perform public.increment_squad_mission_progress_for_user(
        v_squad_id,
        1,
        new.id::text,
        new.user_id
      );
    end loop;
  end if;

  for v_challenge in
    select fc.id, fc.challenge_kind as kind
      from public.friend_challenges fc
     where fc.accepted_at is not null
       and fc.winner_user_id is null
       and fc.started_at <= new.completed_at
       and fc.expires_at >= new.completed_at
       and (fc.challenger_id = new.user_id or fc.challenged_id = new.user_id)
     for update of fc
  loop
    v_should_increment := case v_challenge.kind
      when 'mostSessions' then true
      when 'noMissedDays' then true
      when 'mostAlignedSessions' then coalesce(new.overall_rpe, 0) > 0
      when 'earlyRiser' then new.local_start_hour is not null and new.local_start_hour < 8
      else false
    end;

    if v_should_increment then
      perform public.increment_friend_challenge_progress_for_user(
        v_challenge.id,
        1,
        new.id::text,
        new.user_id
      );
    end if;
  end loop;

  return new;
end;
$$;

revoke all on function public.record_workout_log_social_progress() from public, anon, authenticated;

drop trigger if exists workout_logs_social_progress on public.workout_logs;
create trigger workout_logs_social_progress
  after insert or update of completed_at on public.workout_logs
  for each row
  execute function public.record_workout_log_social_progress();

do $$
begin
  if to_regclass('public.squad_mission_progress_receipts') is null then
    raise exception 'squad_mission_progress_receipts table was not created';
  end if;

  if to_regclass('public.friend_challenge_progress_receipts') is null then
    raise exception 'friend_challenge_progress_receipts table was not created';
  end if;

  if to_regprocedure('public.increment_squad_mission_progress(uuid,int,text)') is null then
    raise exception 'source-idempotent squad mission RPC missing';
  end if;

  if to_regprocedure('public.increment_squad_mission_progress_for_user(uuid,int,text,uuid)') is null then
    raise exception 'source-validated squad mission helper missing';
  end if;

  if to_regprocedure('public.increment_friend_challenge_progress(uuid,int,text)') is null then
    raise exception 'source-idempotent friend challenge RPC missing';
  end if;

  if to_regprocedure('public.increment_friend_challenge_progress_for_user(uuid,int,text,uuid)') is null then
    raise exception 'source-validated friend challenge helper missing';
  end if;

  if to_regprocedure('public.settle_friend_challenge(uuid)') is null then
    raise exception 'source-safe friend challenge settlement RPC missing';
  end if;

  if exists (
    select 1
      from pg_policies
     where schemaname = 'public'
       and tablename = 'friend_challenges'
       and policyname = 'friend_challenges: participants can update progress'
  ) then
    raise exception 'unsafe friend challenge participant update policy still exists';
  end if;

  if to_regprocedure('public.record_workout_log_social_progress()') is null then
    raise exception 'workout social progress trigger function missing';
  end if;

  if not exists (
    select 1
      from pg_trigger
     where tgname = 'workout_logs_social_progress'
       and tgrelid = 'public.workout_logs'::regclass
       and not tgisinternal
  ) then
    raise exception 'workout_logs_social_progress trigger missing';
  end if;
end
$$;
