-- =============================================================================
-- Squads schema + RLS
-- Migration: 20260513120000_squad_schema.sql
-- Spec: docs/superpowers/specs/2026-05-13-squads-design.md § Backend schema
-- =============================================================================

-- (is_squad_member helper function is created AFTER squad_members table below)

-- ---------------------------------------------------------------------------
-- Table: squads
-- One row per crew.
-- ---------------------------------------------------------------------------
create table squads (
  id                  uuid primary key default gen_random_uuid(),
  name                text not null,
  captain_id          uuid not null references auth.users(id) on delete cascade,
  affinity_axis       text,                             -- nullable: AttributeKey rawValue or null
  affinity_set_at     timestamp with time zone,
  invite_code         text not null unique check (invite_code ~ '^[A-Z0-9]{6}$'),
  max_size            int  not null default 8,
  squad_streak_weeks  int  not null default 0,          -- updated by nightly evaluator
  created_at          timestamp with time zone default now()
);

-- ---------------------------------------------------------------------------
-- Table: squad_members
-- Many-to-one to squads.
-- ---------------------------------------------------------------------------
create table squad_members (
  id         uuid primary key default gen_random_uuid(),
  squad_id   uuid not null references squads(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  joined_at  timestamp with time zone default now(),
  unique(squad_id, user_id)
);

-- ---------------------------------------------------------------------------
-- Table: squad_presence
-- Ephemeral "in workout" state, written by client.
-- ---------------------------------------------------------------------------
create table squad_presence (
  user_id             uuid primary key references auth.users(id) on delete cascade,
  squad_id            uuid not null references squads(id) on delete cascade,
  workout_started_at  timestamp with time zone not null,
  expires_at          timestamp with time zone not null  -- auto-expires 3h after start
);

-- ---------------------------------------------------------------------------
-- Table: squad_activity
-- Feed entries.
-- ---------------------------------------------------------------------------
create table squad_activity (
  id         uuid primary key default gen_random_uuid(),
  squad_id   uuid not null references squads(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  kind       text not null,                              -- SquadActivityEntry.Kind rawValues
  payload    jsonb not null,
  created_at timestamp with time zone default now()
);

-- ---------------------------------------------------------------------------
-- Table: linked_sessions
-- Pairs (or groups) of overlapping workouts detected by Edge Function.
-- ---------------------------------------------------------------------------
create table linked_sessions (
  id         uuid primary key default gen_random_uuid(),
  squad_id   uuid not null references squads(id) on delete cascade,
  user_ids   uuid[] not null,                            -- 2+ user ids whose sessions linked
  started_at timestamp with time zone not null,
  ended_at   timestamp with time zone not null,
  created_at timestamp with time zone default now()
);

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------
create index on squad_members(user_id);
create index on squad_members(squad_id);
create index on squad_activity(squad_id, created_at desc);
create index on linked_sessions(squad_id, started_at desc);
create index on squad_presence(squad_id);

-- ---------------------------------------------------------------------------
-- Helper: is_squad_member (defined AFTER squad_members exists)
-- Used by RLS policies to avoid repeated subquery joins.
-- security definer so it runs with the definer's rights (bypasses RLS on
-- squad_members when called from a policy on another table) — standard
-- Supabase pattern for helper functions referenced in policies.
-- search_path is pinned to '' and table is fully-qualified to prevent
-- search_path-manipulation privilege escalation.
-- ---------------------------------------------------------------------------
create or replace function is_squad_member(p_user_id uuid, p_squad_id uuid)
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
  select exists (
    select 1
    from   public.squad_members sm
    where  sm.squad_id = p_squad_id
    and    sm.user_id  = p_user_id
  );
$$;

-- ---------------------------------------------------------------------------
-- Row Level Security — enable on all five tables
-- ---------------------------------------------------------------------------
alter table squads          enable row level security;
alter table squad_members   enable row level security;
alter table squad_presence  enable row level security;
alter table squad_activity  enable row level security;
alter table linked_sessions enable row level security;

-- ---------------------------------------------------------------------------
-- RLS policies: squads
-- • select  → any authenticated member of that squad
-- • insert  → any authenticated user (creator becomes captain via trigger)
-- • update  → captain only
-- ---------------------------------------------------------------------------
create policy "squads: members can read their squad"
  on squads for select
  to authenticated
  using (is_squad_member(auth.uid(), id));

create policy "squads: authenticated users can create a squad"
  on squads for insert
  to authenticated
  with check (auth.uid() = captain_id);

create policy "squads: captain can update"
  on squads for update
  to authenticated
  using  (auth.uid() = captain_id)
  with check (auth.uid() = captain_id);

-- ---------------------------------------------------------------------------
-- RLS policies: squad_members
-- • select  → members of the same squad
-- • insert  → service-role only (Edge Function validates invite code)
-- ---------------------------------------------------------------------------
create policy "squad_members: members can read roster"
  on squad_members for select
  to authenticated
  using (
    -- Cannot use is_squad_member() here — would recurse since this table is the one being checked.
    squad_id in (
      select squad_id from public.squad_members where user_id = auth.uid()
    )
  );

-- Service-role bypasses RLS by default in Supabase (no JWT → no auth.uid()).
-- Explicitly block direct inserts from authenticated JWT callers so that only
-- the Edge Function (service key) can add rows.
create policy "squad_members: service-role insert only"
  on squad_members for insert
  to authenticated
  with check (false);

-- ---------------------------------------------------------------------------
-- RLS policies: squad_presence
-- • select           → members of the same squad
-- • insert/update    → only the row's own user_id
-- • delete           → only the row's own user_id
-- ---------------------------------------------------------------------------
create policy "squad_presence: squad members can read presence"
  on squad_presence for select
  to authenticated
  using (is_squad_member(auth.uid(), squad_id));

create policy "squad_presence: user can insert own presence"
  on squad_presence for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "squad_presence: user can update own presence"
  on squad_presence for update
  to authenticated
  using  (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "squad_presence: user can delete own presence"
  on squad_presence for delete
  to authenticated
  using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- RLS policies: squad_activity
-- • select → members of that squad
-- • insert → user_id = auth.uid() AND user is a member of squad_id
-- ---------------------------------------------------------------------------
create policy "squad_activity: squad members can read feed"
  on squad_activity for select
  to authenticated
  using (is_squad_member(auth.uid(), squad_id));

create policy "squad_activity: member can insert own activity"
  on squad_activity for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and is_squad_member(auth.uid(), squad_id)
  );

-- ---------------------------------------------------------------------------
-- RLS policies: linked_sessions
-- • select → squad members
-- • insert → service-role only (Edge Function detect_linked_sessions)
-- ---------------------------------------------------------------------------
create policy "linked_sessions: squad members can read"
  on linked_sessions for select
  to authenticated
  using (is_squad_member(auth.uid(), squad_id));

create policy "linked_sessions: service-role insert only"
  on linked_sessions for insert
  to authenticated
  with check (false);

-- ---------------------------------------------------------------------------
-- Trigger: auto-join creator as captain on squad insert
-- search_path is pinned to '' and table is fully-qualified to prevent
-- search_path-manipulation privilege escalation.
-- ---------------------------------------------------------------------------
create or replace function squads_auto_join_captain()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.squad_members (squad_id, user_id)
  values (new.id, new.captain_id);
  return new;
end;
$$;

create trigger squads_insert_auto_join_captain
  after insert on squads
  for each row
  execute function squads_auto_join_captain();
