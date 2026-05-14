create table squad_missions (
  id              uuid primary key default gen_random_uuid(),
  squad_id        uuid not null references public.squads(id) on delete cascade,
  week_iso        text not null,
  mission_kind    text not null,
  target          int not null,
  current_progress int not null default 0,
  completed_at    timestamptz,
  created_at      timestamptz not null default now(),
  unique (squad_id, week_iso)
);

create index on squad_missions (squad_id, week_iso desc);

alter table squad_missions enable row level security;

create policy "squad_missions: members can read"
  on squad_missions for select
  to authenticated
  using (public.is_squad_member(auth.uid(), squad_id));

create policy "squad_missions: service-role insert/update only"
  on squad_missions for insert
  to authenticated
  with check (false);

create policy "squad_missions: service-role update only"
  on squad_missions for update
  to authenticated
  using (false);
