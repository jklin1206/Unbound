-- UNBOUND initial schema
-- One migration per deploy. Never edit existing migrations — add new ones.
--
-- RLS policy convention: every table scoped to the authenticated user
-- via `user_id = auth.uid()`. Service-role bypasses RLS and is used only
-- by Edge Functions.

-- ============================================================================
-- USERS
-- ============================================================================

create table public.users (
    id uuid primary key default auth.uid(),
    email text,
    display_name text,
    display_handle text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),

    -- Onboarding answers
    onboarding_completed boolean not null default false,
    total_scans integer not null default 0,
    current_program_id uuid,
    preferred_archetype text,
    height_cm double precision,
    weight_kg double precision,
    age integer,
    biological_sex text,
    gender text,
    motivations jsonb,
    goals jsonb,
    target_areas jsonb,
    obstacles jsonb,
    experience text,
    current_frequency text,
    target_frequency text,
    workout_time text,
    equipment jsonb,
    exercise_styles jsonb,
    session_length text,
    prior_attempts jsonb,
    diet_quality integer,
    sleep_quality integer,
    stress_level integer,
    commitment integer
);

alter table public.users enable row level security;

create policy "users_self_read" on public.users
    for select using (id = auth.uid());
create policy "users_self_write" on public.users
    for all using (id = auth.uid()) with check (id = auth.uid());

-- Auto-create a users row on first Supabase auth.uid resolution
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
as $$
begin
    insert into public.users (id, email)
    values (new.id, new.email)
    on conflict (id) do nothing;
    return new;
end;
$$;

create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();

-- ============================================================================
-- PROGRAMS (12-week training protocols)
-- ============================================================================

create table public.programs (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.users(id) on delete cascade,
    scan_id uuid,
    analysis_id uuid,
    created_at timestamptz not null default now(),
    archetype text not null,
    name text not null,
    description text,
    duration_days integer not null,
    difficulty_level text,
    required_equipment jsonb,
    estimated_daily_minutes integer,
    days jsonb not null,             -- full ProgramDay[] as JSONB
    nutrition_plan jsonb,
    recovery_plan jsonb
);

create index programs_user_id_idx on public.programs (user_id);
alter table public.programs enable row level security;
create policy "programs_owner" on public.programs
    for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ============================================================================
-- WORKOUT LOGS
-- ============================================================================

create table public.workout_logs (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.users(id) on delete cascade,
    program_id uuid not null references public.programs(id) on delete cascade,
    day_number integer not null,
    planned_workout_name text not null,
    started_at timestamptz not null,
    completed_at timestamptz,
    duration_minutes integer,
    overall_rpe integer,
    overall_notes text,
    exercise_entries jsonb not null   -- array of ExerciseLogEntry
);

create index workout_logs_user_started_idx on public.workout_logs (user_id, started_at desc);
create index workout_logs_program_idx on public.workout_logs (program_id);
alter table public.workout_logs enable row level security;
create policy "workout_logs_owner" on public.workout_logs
    for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ============================================================================
-- WORKING WEIGHTS (current load per exercise per user)
-- ============================================================================

create table public.working_weights (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.users(id) on delete cascade,
    exercise_name text not null,
    weight_kg double precision not null,
    last_reps integer,
    last_rpe integer,
    consecutive_sessions_at_target integer not null default 0,
    updated_at timestamptz not null default now(),

    unique (user_id, exercise_name)
);

create index working_weights_user_idx on public.working_weights (user_id);
alter table public.working_weights enable row level security;
create policy "working_weights_owner" on public.working_weights
    for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ============================================================================
-- PROGRESSION STATES (Hawks' per-exercise progression tracker)
-- ============================================================================

create table public.progression_states (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.users(id) on delete cascade,
    exercise_name text not null,
    current_working_weight_kg double precision not null,
    target_rep_min integer not null,
    target_rep_max integer not null,
    target_rpe integer not null,
    consecutive_sessions_at_target integer not null default 0,
    last_bump_date timestamptz,
    block_type text not null default 'accumulation',   -- accumulation/intensification/realization/deload
    week_in_block integer not null default 1,
    updated_at timestamptz not null default now(),

    unique (user_id, exercise_name)
);

create index progression_states_user_idx on public.progression_states (user_id);
alter table public.progression_states enable row level security;
create policy "progression_states_owner" on public.progression_states
    for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ============================================================================
-- EXERCISE PREFERENCES (YES/SUB/NO library)
-- ============================================================================

create table public.exercise_preferences (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.users(id) on delete cascade,
    exercise_name text not null,
    display_name text not null,
    status text not null,                -- available / substitute / avoid
    muscle_groups jsonb,
    substitute_preference text,
    notes text,
    updated_at timestamptz not null default now(),

    unique (user_id, exercise_name)
);

create index exercise_preferences_user_idx on public.exercise_preferences (user_id);
alter table public.exercise_preferences enable row level security;
create policy "exercise_preferences_owner" on public.exercise_preferences
    for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ============================================================================
-- SKILL PROGRESS (gamification layer — per-node state)
-- ============================================================================

create table public.skill_progress (
    user_id uuid primary key references public.users(id) on delete cascade,
    node_states jsonb not null default '{}'::jsonb,      -- nodeId → state
    achieved_at jsonb not null default '{}'::jsonb,       -- nodeId → ISO timestamp
    mastered_at jsonb not null default '{}'::jsonb,       -- nodeId → ISO timestamp
    updated_at timestamptz not null default now()
);

alter table public.skill_progress enable row level security;
create policy "skill_progress_owner" on public.skill_progress
    for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ============================================================================
-- COACH MESSAGES (immutable chat log with action audit)
-- ============================================================================

create table public.coach_messages (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.users(id) on delete cascade,
    role text not null,                        -- user / assistant
    content text not null,
    context_snapshot_hash text,
    tokens_in integer,
    tokens_out integer,
    applied_actions jsonb default '[]'::jsonb,  -- array of CoachAction
    undone boolean not null default false,
    created_at timestamptz not null default now()
);

create index coach_messages_user_created_idx on public.coach_messages (user_id, created_at desc);
alter table public.coach_messages enable row level security;
create policy "coach_messages_owner_read" on public.coach_messages
    for select using (user_id = auth.uid());
create policy "coach_messages_owner_insert" on public.coach_messages
    for insert with check (user_id = auth.uid());
-- updates only to flip `undone` — no full mutation
create policy "coach_messages_owner_undo" on public.coach_messages
    for update using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ============================================================================
-- SCANS (body scan metadata — photos in Storage bucket)
-- ============================================================================

create table public.scans (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.users(id) on delete cascade,
    created_at timestamptz not null default now(),
    status text not null default 'pending',     -- pending/analyzing/program_generating/complete/failed
    analysis_id uuid,
    program_id uuid,
    derived_rank text,
    archetype text,
    notes text
);

create index scans_user_created_idx on public.scans (user_id, created_at desc);
alter table public.scans enable row level security;
create policy "scans_owner" on public.scans
    for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ============================================================================
-- STORAGE BUCKET: scans
-- ============================================================================

-- Create bucket once (idempotent with on conflict do nothing)
insert into storage.buckets (id, name, public)
values ('scans', 'scans', false)
on conflict (id) do nothing;

-- Path policy: only read/write your own folder scans/{auth.uid}/*
create policy "scans_bucket_owner_read" on storage.objects
    for select using (
        bucket_id = 'scans'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

create policy "scans_bucket_owner_write" on storage.objects
    for insert with check (
        bucket_id = 'scans'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

create policy "scans_bucket_owner_delete" on storage.objects
    for delete using (
        bucket_id = 'scans'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

-- ============================================================================
-- END initial schema
-- ============================================================================
