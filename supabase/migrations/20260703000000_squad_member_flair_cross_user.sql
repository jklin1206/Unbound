-- Cross-user squad-member profile flair: each user writes only their own row
-- (equipped cosmetics + showcase skill/lift + rank tier + attribute snapshot).
-- Squadmates read it only through the gated SECURITY DEFINER RPC below, mirroring
-- squad_members_enriched. This lets a member's profile render 1:1 for crewmates
-- (the underlying cosmetics are otherwise device-local UserDefaults).
create table if not exists public.squad_member_flair (
  user_id uuid primary key references public.users(id) on delete cascade,
  flair jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.squad_member_flair enable row level security;

drop policy if exists squad_member_flair_owner_select on public.squad_member_flair;
drop policy if exists squad_member_flair_owner_insert on public.squad_member_flair;
drop policy if exists squad_member_flair_owner_update on public.squad_member_flair;

create policy squad_member_flair_owner_select on public.squad_member_flair
  for select using (auth.uid() = user_id);
create policy squad_member_flair_owner_insert on public.squad_member_flair
  for insert with check (auth.uid() = user_id);
create policy squad_member_flair_owner_update on public.squad_member_flair
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

grant select, insert, update on public.squad_member_flair to authenticated;

-- Read every member's flair for a squad the caller belongs to.
create or replace function public.squad_member_flair_for_squad(p_squad_id uuid)
returns table(user_id uuid, flair jsonb)
language sql
stable
security definer
set search_path to ''
as $function$
  select f.user_id, f.flair
  from   public.squad_member_flair f
  join   public.squad_members sm on sm.user_id = f.user_id
  where  sm.squad_id = p_squad_id
    and  public.is_squad_member(auth.uid(), p_squad_id);
$function$;

grant execute on function public.squad_member_flair_for_squad(uuid) to authenticated;
