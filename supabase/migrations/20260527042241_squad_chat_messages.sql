-- =============================================================================
-- Squad chat messages + reactions
-- =============================================================================
-- Human chat is stored separately from squad_activity. The activity table remains
-- the durable product ledger; this table is for conversational messages that can
-- be retained, soft-deleted, and eventually pruned without losing challenge or
-- workout history.
-- =============================================================================

create table public.squad_messages (
  id                uuid primary key default gen_random_uuid(),
  squad_id          uuid not null references public.squads(id) on delete cascade,
  author_user_id    uuid references auth.users(id) on delete cascade,
  kind              text not null default 'text'
                    check (kind in ('text', 'workout', 'pr', 'vowSeal', 'challengeEvent', 'savedWorkoutShare', 'system')),
  payload           jsonb not null default '{}'::jsonb,
  client_message_id text,
  created_at        timestamp with time zone not null default now(),
  updated_at        timestamp with time zone,
  deleted_at        timestamp with time zone,
  check (
    kind <> 'text'
    or (
      payload ? 'body'
      and length(trim(coalesce(payload->>'body', ''))) between 1 and 1000
    )
  )
);

create table public.squad_message_reactions (
  id         uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.squad_messages(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  emoji      text not null check (emoji in ('🔥', '💪', '👏', '❤️', '👀')),
  created_at timestamp with time zone not null default now(),
  unique(message_id, user_id, emoji)
);

create table public.squad_message_reports (
  id               uuid primary key default gen_random_uuid(),
  message_id       uuid not null references public.squad_messages(id) on delete cascade,
  reporter_user_id uuid not null references auth.users(id) on delete cascade,
  reason           text not null default 'inappropriate',
  detail           text,
  created_at       timestamp with time zone not null default now(),
  unique(message_id, reporter_user_id)
);

create index squad_messages_squad_created_idx
  on public.squad_messages(squad_id, created_at desc)
  where deleted_at is null;

create unique index squad_messages_client_dedupe_idx
  on public.squad_messages(squad_id, author_user_id, client_message_id)
  where client_message_id is not null;

create index squad_message_reactions_message_idx
  on public.squad_message_reactions(message_id);

create index squad_message_reports_message_idx
  on public.squad_message_reports(message_id);

alter table public.squad_messages enable row level security;
alter table public.squad_message_reactions enable row level security;
alter table public.squad_message_reports enable row level security;

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

grant select, insert, update on public.squad_messages to authenticated;
grant select, insert, delete on public.squad_message_reactions to authenticated;
grant insert on public.squad_message_reports to authenticated;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    if exists (select 1 from cron.job where jobname = 'prune_expired_squad_messages_daily') then
      perform cron.unschedule('prune_expired_squad_messages_daily');
    end if;

    perform cron.schedule(
      'prune_expired_squad_messages_daily',
      '15 5 * * *',
      'delete from public.squad_messages where kind = ''text'' and created_at < now() - interval ''90 days'';'
    );
  end if;
end $$;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'squad_messages'
    ) then
      alter publication supabase_realtime add table public.squad_messages;
    end if;

    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'squad_message_reactions'
    ) then
      alter publication supabase_realtime add table public.squad_message_reactions;
    end if;
  end if;
end $$;
