create table squad_weekly_honors (
  id              uuid primary key default gen_random_uuid(),
  squad_id        uuid not null references public.squads(id) on delete cascade,
  week_iso        text not null,
  honor_kind      text not null,
  recipient_user_id uuid not null references auth.users(id) on delete cascade,
  awarded_at      timestamptz not null default now()
);

create index on squad_weekly_honors (squad_id, week_iso desc);
create index on squad_weekly_honors (recipient_user_id);

alter table squad_weekly_honors enable row level security;

create policy "squad_weekly_honors: members can read"
  on squad_weekly_honors for select
  to authenticated
  using (public.is_squad_member(auth.uid(), squad_id));

create policy "squad_weekly_honors: service-role insert only"
  on squad_weekly_honors for insert
  to authenticated
  with check (false);
