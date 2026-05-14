create table friend_challenges (
  id              uuid primary key default gen_random_uuid(),
  challenger_id   uuid not null references auth.users(id) on delete cascade,
  challenged_id   uuid not null references auth.users(id) on delete cascade,
  squad_id        uuid not null references public.squads(id) on delete cascade,
  challenge_kind  text not null,
  started_at      timestamptz not null default now(),
  expires_at      timestamptz not null,
  winner_user_id  uuid references auth.users(id) on delete set null,
  accepted_at     timestamptz,
  challenger_progress int not null default 0,
  challenged_progress int not null default 0,
  check (challenger_id <> challenged_id)
);

create index on friend_challenges (squad_id, expires_at desc);
create index on friend_challenges (challenger_id);
create index on friend_challenges (challenged_id);

alter table friend_challenges enable row level security;

create policy "friend_challenges: squad members can read"
  on friend_challenges for select
  to authenticated
  using (public.is_squad_member(auth.uid(), squad_id));

create policy "friend_challenges: members can create challenge if both in same squad"
  on friend_challenges for insert
  to authenticated
  with check (
    auth.uid() = challenger_id
    and public.is_squad_member(auth.uid(), squad_id)
    and public.is_squad_member(challenged_id, squad_id)
  );

create policy "friend_challenges: participants can update progress"
  on friend_challenges for update
  to authenticated
  using (auth.uid() = challenger_id or auth.uid() = challenged_id);
