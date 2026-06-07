-- Squad routine drops: shared Saved Workout templates inside a squad.

create table if not exists public.squad_routine_drops (
  id                  uuid primary key default gen_random_uuid(),
  squad_id            uuid not null references public.squads(id) on delete cascade,
  author_user_id      uuid not null references auth.users(id) on delete cascade,
  author_display_name text not null default 'Crewmate',
  title               text not null check (char_length(title) between 1 and 80),
  note                text check (note is null or char_length(note) <= 180),
  workout             jsonb not null,
  created_at          timestamp with time zone not null default now()
);

create index if not exists squad_routine_drops_squad_created_idx
  on public.squad_routine_drops(squad_id, created_at desc);

create index if not exists squad_routine_drops_author_idx
  on public.squad_routine_drops(author_user_id);

alter table public.squad_routine_drops enable row level security;

drop policy if exists "squad_routine_drops: members can read" on public.squad_routine_drops;
create policy "squad_routine_drops: members can read"
  on public.squad_routine_drops for select
  to authenticated
  using (public.is_squad_member((select auth.uid()), squad_id));

drop policy if exists "squad_routine_drops: members can insert own" on public.squad_routine_drops;
create policy "squad_routine_drops: members can insert own"
  on public.squad_routine_drops for insert
  to authenticated
  with check (
    (select auth.uid()) = author_user_id
    and public.is_squad_member((select auth.uid()), squad_id)
  );

drop policy if exists "squad_routine_drops: authors or captains can delete" on public.squad_routine_drops;
create policy "squad_routine_drops: authors or captains can delete"
  on public.squad_routine_drops for delete
  to authenticated
  using (
    (select auth.uid()) = author_user_id
    or exists (
      select 1
      from public.squads s
      where s.id = squad_id
        and s.captain_id = (select auth.uid())
    )
  );

grant select, insert, delete on public.squad_routine_drops to authenticated;

-- The routine payload is stored in squad_routine_drops. The chat row is only
-- the lightweight social event that points at the drop id.
drop policy if exists "squad_messages: members can send own text" on public.squad_messages;
create policy "squad_messages: members can send own text"
  on public.squad_messages for insert
  to authenticated
  with check (
    kind in ('text', 'savedWorkoutShare')
    and deleted_at is null
    and author_user_id = (select auth.uid())
    and public.is_squad_member((select auth.uid()), squad_id)
  );
