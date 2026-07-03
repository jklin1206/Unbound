-- Cloud backup for the trial-confirmed rank + per-lift tiers.
--
-- The displayed rank (OverallRankTrialStore.currentRank, derived from passed
-- rank-trial attempts) and the per-lift tiers (LiftTierService) previously lived
-- ONLY in device UserDefaults. A reinstall or an orphaned identity migration
-- silently reset a user's rank to Initiate even though their workout logs
-- restored fine. These two jsonb columns ride the existing synced `users` doc so
-- the rank survives a reinstall.
--
-- Written client-side through the outbox / `sync_merge_row` field-level merge
-- (SupabaseRemoteSync), which snake-cases nested jsonb keys; reads mirror it via
-- the convertFromSnakeCase / iso8601 decoder (UnboundSupabase.dbDecoder).
--
-- RLS on public.users is already owner-only, so no policy changes are needed.
alter table public.users
    add column if not exists overall_rank_trials jsonb,
    add column if not exists lift_tiers jsonb;
