-- Squad cron/webhook auth: read the shared service-function secret from
-- Supabase Vault instead of a database GUC.
--
-- The original design required an out-of-band
--   alter database postgres set app.settings.service_function_secret = '…'
-- which was never run (and the managed API role is not allowed to run it),
-- so every scheduled call has presented a NULL bearer and failed auth since
-- launch. Vault is writable through the standard tooling:
--
--   select vault.create_secret('<same value as SQUAD_CRON_SECRET>', 'squad_cron_secret');
--
-- The GUC is kept as a fallback so environments that DID configure it keep
-- working. Cron jobs run as their owner (postgres), which can read vault.

create or replace function public.squad_service_function_secret()
returns text
language sql
security definer
set search_path = ''
stable
as $$
  select coalesce(
    (select decrypted_secret from vault.decrypted_secrets where name = 'squad_cron_secret' limit 1),
    current_setting('app.settings.service_function_secret', true)
  );
$$;

-- Internal helper for the cron jobs + workout_logs webhook trigger only.
revoke all on function public.squad_service_function_secret() from public;
revoke all on function public.squad_service_function_secret() from anon;
revoke all on function public.squad_service_function_secret() from authenticated;

do $$
begin
  if exists (select 1 from cron.job where jobname = 'evaluate_squad_streak_daily') then
    perform cron.unschedule('evaluate_squad_streak_daily');
  end if;
end $$;

select cron.schedule(
  'evaluate_squad_streak_daily',
  '0 3 * * *',
  $$select net.http_post(
    url := 'https://xwoemvkzrnnsvtupxctu.supabase.co/functions/v1/evaluate_squad_streak',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || public.squad_service_function_secret()
    ),
    body := '{}'::jsonb
  );$$
);

do $$
begin
  if exists (select 1 from cron.job where jobname = 'evaluate_squad_mission_daily') then
    perform cron.unschedule('evaluate_squad_mission_daily');
  end if;
end $$;

select cron.schedule(
  'evaluate_squad_mission_daily',
  '0 4 * * *',
  $$select net.http_post(
    url := 'https://xwoemvkzrnnsvtupxctu.supabase.co/functions/v1/evaluate_squad_mission',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || public.squad_service_function_secret()
    ),
    body := '{}'::jsonb
  );$$
);

do $$
begin
  if exists (select 1 from cron.job where jobname = 'assign_weekly_honors_sunday') then
    perform cron.unschedule('assign_weekly_honors_sunday');
  end if;
end $$;

select cron.schedule(
  'assign_weekly_honors_sunday',
  '0 23 * * 0',
  $$select net.http_post(
    url := 'https://xwoemvkzrnnsvtupxctu.supabase.co/functions/v1/assign_weekly_honors',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || public.squad_service_function_secret()
    ),
    body := '{}'::jsonb
  );$$
);

create or replace function public.notify_detect_linked_sessions()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform net.http_post(
    url := 'https://xwoemvkzrnnsvtupxctu.supabase.co/functions/v1/detect_linked_sessions',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || public.squad_service_function_secret()
    ),
    body := jsonb_build_object('record', to_jsonb(NEW))
  );
  return NEW;
end;
$$;
