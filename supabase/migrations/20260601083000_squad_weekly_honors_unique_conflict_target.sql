-- Ensure assign_weekly_honors can use
-- onConflict: "squad_id,week_iso,honor_kind" safely and idempotently.

with ranked as (
  select
    id,
    row_number() over (
      partition by squad_id, week_iso, honor_kind
      order by awarded_at desc, id
    ) as rn
  from public.squad_weekly_honors
)
delete from public.squad_weekly_honors h
using ranked r
where h.id = r.id
  and r.rn > 1;

create unique index if not exists squad_weekly_honors_once_per_kind_week_idx
  on public.squad_weekly_honors (squad_id, week_iso, honor_kind);

do $$
begin
  if not exists (
    select 1
    from pg_indexes
    where schemaname = 'public'
      and tablename = 'squad_weekly_honors'
      and indexname = 'squad_weekly_honors_once_per_kind_week_idx'
  ) then
    raise exception 'squad_weekly_honors unique conflict target is missing';
  end if;
end $$;
