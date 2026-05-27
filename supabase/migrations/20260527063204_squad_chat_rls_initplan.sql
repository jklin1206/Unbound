-- =============================================================================
-- Squad chat RLS initplan optimization
-- =============================================================================
-- Supabase advisors recommend wrapping auth.uid() in a scalar select in RLS
-- policies so Postgres can initialize it once per statement instead of
-- re-evaluating it per row.
-- =============================================================================

drop policy if exists "squad_messages: members can read visible chat"
  on public.squad_messages;
drop policy if exists "squad_messages: members can send own text"
  on public.squad_messages;
drop policy if exists "squad_messages: authors can update own visible chat"
  on public.squad_messages;
drop policy if exists "squad_message_reactions: members can read reactions"
  on public.squad_message_reactions;
drop policy if exists "squad_message_reactions: members can add own reaction"
  on public.squad_message_reactions;
drop policy if exists "squad_message_reactions: users can remove own reaction"
  on public.squad_message_reactions;
drop policy if exists "squad_message_reports: members can report visible chat"
  on public.squad_message_reports;

create policy "squad_messages: members can read visible chat"
  on public.squad_messages for select
  to authenticated
  using (
    deleted_at is null
    and public.is_squad_member((select auth.uid()), squad_id)
  );

create policy "squad_messages: members can send own text"
  on public.squad_messages for insert
  to authenticated
  with check (
    kind = 'text'
    and deleted_at is null
    and author_user_id = (select auth.uid())
    and public.is_squad_member((select auth.uid()), squad_id)
  );

create policy "squad_messages: authors can update own visible chat"
  on public.squad_messages for update
  to authenticated
  using (
    author_user_id = (select auth.uid())
    and public.is_squad_member((select auth.uid()), squad_id)
  )
  with check (
    kind = 'text'
    and author_user_id = (select auth.uid())
    and public.is_squad_member((select auth.uid()), squad_id)
  );

create policy "squad_message_reactions: members can read reactions"
  on public.squad_message_reactions for select
  to authenticated
  using (
    exists (
      select 1
      from public.squad_messages sm
      where sm.id = message_id
        and sm.deleted_at is null
        and public.is_squad_member((select auth.uid()), sm.squad_id)
    )
  );

create policy "squad_message_reactions: members can add own reaction"
  on public.squad_message_reactions for insert
  to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1
      from public.squad_messages sm
      where sm.id = message_id
        and sm.deleted_at is null
        and public.is_squad_member((select auth.uid()), sm.squad_id)
    )
  );

create policy "squad_message_reactions: users can remove own reaction"
  on public.squad_message_reactions for delete
  to authenticated
  using (user_id = (select auth.uid()));

create policy "squad_message_reports: members can report visible chat"
  on public.squad_message_reports for insert
  to authenticated
  with check (
    reporter_user_id = (select auth.uid())
    and exists (
      select 1
      from public.squad_messages sm
      where sm.id = message_id
        and sm.deleted_at is null
        and public.is_squad_member((select auth.uid()), sm.squad_id)
    )
  );
