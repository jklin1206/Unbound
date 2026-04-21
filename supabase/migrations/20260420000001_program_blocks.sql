-- Program blocks — one record per 2-week training block per user.
-- Written by BlockRolloverService when a new block is generated.
-- Stores the bias + rotation snapshot that was active for the block.

-- ============================================================================
-- PROGRAM BLOCKS
-- ============================================================================

create table public.program_blocks (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.users(id) on delete cascade,
    program_id uuid not null references public.programs(id) on delete cascade,
    block_number integer not null,
    started_at timestamptz not null,
    ended_at timestamptz,
    scan_id uuid references public.scans(id) on delete set null,
    accessory_bias jsonb not null default '{}'::jsonb,          -- MuscleGroup → Int
    cut_mode_active boolean not null default false,
    bias_refreshed_from_previous boolean not null default false,
    exercise_rotations_this_block jsonb not null default '[]'::jsonb,  -- [String]
    created_at timestamptz not null default now()
);

create index program_blocks_user_block_idx
    on public.program_blocks (user_id, block_number desc);
create index program_blocks_user_started_idx
    on public.program_blocks (user_id, started_at desc);
create index program_blocks_program_idx
    on public.program_blocks (program_id);

alter table public.program_blocks enable row level security;

create policy "program_blocks_owner" on public.program_blocks
    for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ============================================================================
-- END program_blocks migration
-- ============================================================================
