-- Complete the existing user-scoped tables so local JSON migration payloads
-- can be upserted without creating parallel migration tables.

-- UserProfile has gained local-only fields since the initial schema. Add the
-- matching columns so profile migration preserves them when present.
alter table public.users
    add column if not exists current_body_type text,
    add column if not exists training_feedback_mode text,
    add column if not exists training_style_override text,
    add column if not exists training_days jsonb,
    add column if not exists cut_mode jsonb;

-- WorkingWeight keeps the source log locally. Preserve it as text because
-- some legacy source ids came from local/non-UUID performance logs.
alter table public.working_weights
    add column if not exists source_log_id text;

-- UserSkillProgress now contains XP, training cadence, and goal/bookmark state
-- in addition to the original node-state maps.
alter table public.skill_progress
    add column if not exists skill_progress jsonb not null default '{}'::jsonb,
    add column if not exists last_trained_at jsonb not null default '{}'::jsonb,
    add column if not exists bookmarked_node_ids jsonb not null default '[]'::jsonb,
    add column if not exists active_goal_ids jsonb not null default '[]'::jsonb,
    add column if not exists weekly_schedule jsonb not null default '[null,null,null,null,null,null,null]'::jsonb,
    add column if not exists current_week_phase text not null default 'moderate';
