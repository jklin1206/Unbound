-- =============================================================================
-- Lock server-owned entitlement columns outside the sync RPC
-- =============================================================================
-- RLS keeps users scoped to their own row, but the original users_self_write
-- policy was FOR ALL and normal PostgREST/table grants could still write every
-- column through UPDATE, INSERT, or delete/reinsert. Premium entitlement columns
-- are server-owned, so authenticated clients get column-specific profile grants
-- that intentionally exclude is_pro and is_pro_expires_at. Direct client DELETE
-- is removed; account deletion goes through the service-role Edge Function.
-- =============================================================================

revoke insert, update, delete on table public.users from public, anon, authenticated;
revoke insert (is_pro, is_pro_expires_at) on table public.users from public, anon, authenticated;
revoke update (is_pro, is_pro_expires_at) on table public.users from public, anon, authenticated;
grant all privileges on table public.users to service_role;

drop policy if exists "users_self_write" on public.users;

create policy "users_self_insert_profile" on public.users
    for insert to authenticated
    with check (id = auth.uid());

create policy "users_self_update_profile" on public.users
    for update to authenticated
    using (id = auth.uid())
    with check (id = auth.uid());

grant insert (
    id,
    email,
    display_name,
    display_handle,
    created_at,
    updated_at,
    onboarding_completed,
    total_scans,
    current_program_id,
    preferred_archetype,
    height_cm,
    weight_kg,
    age,
    biological_sex,
    gender,
    motivations,
    goals,
    target_areas,
    obstacles,
    experience,
    current_frequency,
    target_frequency,
    workout_time,
    equipment,
    exercise_styles,
    session_length,
    prior_attempts,
    diet_quality,
    sleep_quality,
    stress_level,
    commitment,
    current_body_type,
    training_feedback_mode,
    training_style_override,
    training_days,
    cut_mode
) on table public.users to authenticated;

grant update (
    email,
    display_name,
    display_handle,
    created_at,
    updated_at,
    onboarding_completed,
    total_scans,
    current_program_id,
    preferred_archetype,
    height_cm,
    weight_kg,
    age,
    biological_sex,
    gender,
    motivations,
    goals,
    target_areas,
    obstacles,
    experience,
    current_frequency,
    target_frequency,
    workout_time,
    equipment,
    exercise_styles,
    session_length,
    prior_attempts,
    diet_quality,
    sleep_quality,
    stress_level,
    commitment,
    current_body_type,
    training_feedback_mode,
    training_style_override,
    training_days,
    cut_mode
) on table public.users to authenticated;

do $$
begin
    if exists (
        select 1
        from pg_policies
        where schemaname = 'public'
          and tablename = 'users'
          and policyname = 'users_self_write'
    ) then
        raise exception 'users_self_write FOR ALL policy must not survive entitlement hardening';
    end if;

    if has_table_privilege('authenticated', 'public.users', 'DELETE') then
        raise exception 'authenticated must not have direct DELETE on public.users';
    end if;

    if has_column_privilege('authenticated', 'public.users', 'is_pro', 'INSERT')
       or has_column_privilege('authenticated', 'public.users', 'is_pro_expires_at', 'INSERT')
       or has_column_privilege('authenticated', 'public.users', 'is_pro', 'UPDATE')
       or has_column_privilege('authenticated', 'public.users', 'is_pro_expires_at', 'UPDATE') then
        raise exception 'authenticated must not be able to write public.users entitlement columns';
    end if;

    if not has_column_privilege('authenticated', 'public.users', 'display_name', 'INSERT')
       or not has_column_privilege('authenticated', 'public.users', 'display_name', 'UPDATE') then
        raise exception 'authenticated profile column write grants were not installed';
    end if;

    if not has_table_privilege('service_role', 'public.users', 'UPDATE') then
        raise exception 'service_role must retain entitlement write capability';
    end if;
end $$;
