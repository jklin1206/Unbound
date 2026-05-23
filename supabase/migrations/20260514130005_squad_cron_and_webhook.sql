-- =============================================================================
-- Squad backend automation: cron schedules + workout_logs webhook
-- =============================================================================
-- Edge Functions referenced here were deployed with --no-verify-jwt, so the
-- net.http_post calls don't need an Authorization header.
-- =============================================================================

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Project URL — hardcoded for clarity; rebuilds use the same URL.
-- xwoemvkzrnnsvtupxctu is the UNBOUND project ref.

-- --- Cron 1: evaluate_squad_streak (daily 03:00 UTC) ---
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
    headers := '{"Content-Type": "application/json"}'::jsonb
  );$$
);

-- --- Cron 2: evaluate_squad_mission (daily 04:00 UTC) — also generates Monday missions ---
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
    headers := '{"Content-Type": "application/json"}'::jsonb
  );$$
);

-- --- Cron 3: assign_weekly_honors (Sunday 23:00 UTC) ---
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
    headers := '{"Content-Type": "application/json"}'::jsonb
  );$$
);

-- =============================================================================
-- Webhook trigger: workout_logs INSERT → detect_linked_sessions
-- =============================================================================
-- Fires a fire-and-forget POST to the Edge Function after every workout_logs
-- insert. The function detects 5-min-overlap presence and creates linked_sessions.
-- =============================================================================

create or replace function notify_detect_linked_sessions()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform net.http_post(
    url := 'https://xwoemvkzrnnsvtupxctu.supabase.co/functions/v1/detect_linked_sessions',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body := jsonb_build_object('record', to_jsonb(NEW))
  );
  return NEW;
end;
$$;

-- Drop + recreate trigger to make this migration idempotent.
do $$
begin
  if exists (
    select 1 from pg_trigger
    where tgname = 'workout_logs_detect_linked_sessions'
  ) then
    drop trigger workout_logs_detect_linked_sessions on public.workout_logs;
  end if;
end $$;

-- Only create the trigger if workout_logs table exists in this database.
do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'workout_logs'
  ) then
    execute $trig$
      create trigger workout_logs_detect_linked_sessions
      after insert on public.workout_logs
      for each row execute function notify_detect_linked_sessions();
    $trig$;
  end if;
end $$;
