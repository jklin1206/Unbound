-- join_squad hardening: per-user invite-code throttle + atomic capacity check.
--
-- Previously the edge function did lookup → count → insert as separate
-- service-role queries: the capacity check could race (two joins past
-- max_size), and invite codes could be brute-forced without limit.
--
-- join_squad_atomic runs the whole join in one transaction:
--   • throttle: max 10 attempts per user per 10 minutes (counts failures too,
--     so invite-code guessing is rate-limited)
--   • SELECT ... FOR UPDATE on the squad row — all joins for a squad
--     serialize on the lock, so the member count cannot race past max_size
--   • member + activity insert commit or roll back together
--
-- service_role-execute-only: the join_squad edge function stays the entry
-- point (it owns JWT resolution and the HTTP contract).

create table public.squad_join_attempts (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  attempted_at  timestamptz not null default now()
);

create index squad_join_attempts_user_time_idx
  on public.squad_join_attempts (user_id, attempted_at desc);

-- RLS on, no policies: service-role access only.
alter table public.squad_join_attempts enable row level security;

create or replace function public.join_squad_atomic(p_user_id uuid, p_invite_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_attempts     int;
  v_squad        squads%rowtype;
  v_member_count int;
  v_display_name text;
begin
  if p_user_id is null then
    return jsonb_build_object('error', 'unauthorized');
  end if;

  select count(*) into v_attempts
  from squad_join_attempts
  where user_id = p_user_id
    and attempted_at > now() - interval '10 minutes';
  if v_attempts >= 10 then
    return jsonb_build_object('error', 'rate_limited');
  end if;

  -- Record the attempt (success or failure) and self-clean old rows.
  delete from squad_join_attempts
  where user_id = p_user_id and attempted_at < now() - interval '1 day';
  insert into squad_join_attempts (user_id) values (p_user_id);

  if exists (select 1 from squad_members where user_id = p_user_id) then
    return jsonb_build_object('error', 'already_in_squad');
  end if;

  select * into v_squad
  from squads
  where invite_code = p_invite_code
  for update;
  if not found then
    return jsonb_build_object('error', 'invalid_invite_code');
  end if;

  select count(*) into v_member_count
  from squad_members
  where squad_id = v_squad.id;
  if v_member_count >= v_squad.max_size then
    return jsonb_build_object('error', 'squad_full');
  end if;

  select display_handle into v_display_name
  from users
  where id = p_user_id;

  insert into squad_members (squad_id, user_id)
  values (v_squad.id, p_user_id);

  insert into squad_activity (squad_id, user_id, kind, payload)
  values (
    v_squad.id,
    p_user_id,
    'memberJoined',
    jsonb_build_object('memberDisplayName', coalesce(v_display_name, 'Someone'))
  );

  return jsonb_build_object('squad', to_jsonb(v_squad));
end; $$;

revoke all on function public.join_squad_atomic(uuid, text) from public;
revoke all on function public.join_squad_atomic(uuid, text) from anon;
revoke all on function public.join_squad_atomic(uuid, text) from authenticated;
grant execute on function public.join_squad_atomic(uuid, text) to service_role;
