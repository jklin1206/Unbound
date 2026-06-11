-- =============================================================================
-- Harden SECURITY DEFINER helper functions
-- =============================================================================
-- 1. is_squad_member: created with the default PUBLIC EXECUTE grant, so it was
--    reachable via POST /rpc/is_squad_member with just the anon key — an
--    arbitrary (user_id, squad_id) membership oracle. RLS policy expressions
--    run with the *invoker's* privileges, so authenticated must keep EXECUTE
--    for every squad-table policy that calls it; anon never needs it.
-- 2. handle_new_user: the only remaining SECURITY DEFINER function without a
--    pinned search_path. Body is already fully qualified; pin it anyway so a
--    search_path-manipulation escalation is structurally impossible.
-- =============================================================================

revoke execute on function public.is_squad_member(uuid, uuid) from public, anon;
grant execute on function public.is_squad_member(uuid, uuid) to authenticated, service_role;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    insert into public.users (id, email)
    values (new.id, new.email)
    on conflict (id) do nothing;
    return new;
end;
$$;

-- Trigger-returning functions are not RPC-callable, but drop the default
-- PUBLIC EXECUTE grant anyway for parity with the other definer helpers.
revoke execute on function public.handle_new_user() from public, anon, authenticated;

do $$
begin
    if has_function_privilege('anon', 'public.is_squad_member(uuid, uuid)', 'execute') then
        raise exception 'is_squad_member is still executable by anon';
    end if;
    if not has_function_privilege('authenticated', 'public.is_squad_member(uuid, uuid)', 'execute') then
        raise exception 'is_squad_member lost authenticated execute (RLS policies would break)';
    end if;
    if not exists (
        select 1 from pg_proc p
        join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'public'
        and   p.proname = 'handle_new_user'
        and   exists (
            select 1 from unnest(coalesce(p.proconfig, '{}'::text[])) cfg
            where cfg like 'search_path=%'
        )
    ) then
        raise exception 'handle_new_user search_path is not pinned';
    end if;
end $$;
