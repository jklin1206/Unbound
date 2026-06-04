-- Forward-fix already-applied 20260514130005 environments.
--
-- The original squad cron/webhook migration may already be recorded as applied,
-- so changes to that historical file will not repair live projects. Reinstall
-- the cron jobs and DB trigger here with the shared service-function bearer
-- header and the JSON bodies expected by the Edge Functions.
--
-- Configure the DB-side copy of the same secret out of band:
--
--   alter database postgres
--   set app.settings.service_function_secret = '<same value as SQUAD_CRON_SECRET>';

create extension if not exists pg_cron;
create extension if not exists pg_net;

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
      'Authorization', 'Bearer ' || current_setting('app.settings.service_function_secret', true)
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
      'Authorization', 'Bearer ' || current_setting('app.settings.service_function_secret', true)
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
      'Authorization', 'Bearer ' || current_setting('app.settings.service_function_secret', true)
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
      'Authorization', 'Bearer ' || current_setting('app.settings.service_function_secret', true)
    ),
    body := jsonb_build_object('record', to_jsonb(NEW))
  );
  return NEW;
end;
$$;

do $$
begin
  if to_regclass('public.workout_logs') is not null and exists (
    select 1 from pg_trigger
    where tgname = 'workout_logs_detect_linked_sessions'
      and tgrelid = 'public.workout_logs'::regclass
  ) then
    drop trigger workout_logs_detect_linked_sessions on public.workout_logs;
  end if;
end $$;

do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'workout_logs'
  ) then
    execute $trig$
      create trigger workout_logs_detect_linked_sessions
      after insert on public.workout_logs
      for each row execute function public.notify_detect_linked_sessions();
    $trig$;
  end if;
end $$;
