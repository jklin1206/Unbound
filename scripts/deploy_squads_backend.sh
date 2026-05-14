#!/usr/bin/env bash
# Deploy the squads backend to Supabase.
# Run after sub-projects #1-#6 are merged into program-redesign.
#
# Prerequisites:
#   - supabase CLI installed: `brew install supabase/tap/supabase`
#   - You are logged in: `supabase login` (browser opens)
#   - The UNBOUND project is linked: `supabase link --project-ref <ref>`
#     (Get <ref> from Supabase Dashboard → Project Settings → Reference ID)
#   - SUPABASE_SERVICE_ROLE_KEY set in your shell OR Supabase Dashboard secrets
#
# Run:
#   cd /Users/jlin/Documents/toji/UNBOUND
#   ./scripts/deploy_squads_backend.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# --- Sanity checks ---
command -v supabase >/dev/null 2>&1 || {
    echo "ERROR: supabase CLI not installed. Run: brew install supabase/tap/supabase"
    exit 1
}

if [ ! -d "supabase/migrations" ]; then
    echo "ERROR: supabase/migrations directory not found. Are you in the repo root?"
    exit 1
fi

# --- Step 1: Apply migrations ---
echo "==> Applying 5 squad migrations..."
supabase db push

# Migrations applied:
#   20260514130000_squad_schema.sql
#   20260514130001_squad_activity_nullable_user.sql
#   20260514130002_squad_missions.sql
#   20260514130003_squad_weekly_honors.sql
#   20260514130004_friend_challenges.sql

# --- Step 2: Deploy 5 Edge Functions ---
echo "==> Deploying 5 Edge Functions..."

supabase functions deploy join_squad
supabase functions deploy detect_linked_sessions --no-verify-jwt
supabase functions deploy evaluate_squad_streak --no-verify-jwt
supabase functions deploy evaluate_squad_mission --no-verify-jwt
supabase functions deploy assign_weekly_honors --no-verify-jwt

# --no-verify-jwt: these are server-only crons + webhooks invoked by Supabase
# itself, not by authenticated users. The `join_squad` function DOES need JWT
# (called by the iOS client with the user's auth token).

# --- Step 3: Configure webhooks + cron (manual via Dashboard) ---
echo ""
echo "==> MANUAL STEPS REMAINING:"
echo ""
echo "1. Webhook on workout_logs INSERT → detect_linked_sessions"
echo "   Dashboard → Database → Webhooks → Create"
echo "   - Table: workout_logs"
echo "   - Events: INSERT"
echo "   - URL: https://<project-ref>.supabase.co/functions/v1/detect_linked_sessions"
echo "   - Headers: Authorization: Bearer <service-role-key>"
echo ""
echo "2. pg_cron schedules — run this SQL in the Dashboard SQL editor:"
echo ""
cat <<'SQL'
-- Run daily 03:00 UTC: weekly streak rollup
select cron.schedule(
  'evaluate_squad_streak_daily',
  '0 3 * * *',
  $$select net.http_post(
    url := 'https://<project-ref>.supabase.co/functions/v1/evaluate_squad_streak',
    headers := '{"Authorization": "Bearer <service-role-key>"}'::jsonb
  ) as request_id;$$
);

-- Run daily 04:00 UTC: mission progress + Monday generation
select cron.schedule(
  'evaluate_squad_mission_daily',
  '0 4 * * *',
  $$select net.http_post(
    url := 'https://<project-ref>.supabase.co/functions/v1/evaluate_squad_mission',
    headers := '{"Authorization": "Bearer <service-role-key>"}'::jsonb
  ) as request_id;$$
);

-- Run Sunday 23:00 UTC: weekly honors assignment
select cron.schedule(
  'assign_weekly_honors_sunday',
  '0 23 * * 0',
  $$select net.http_post(
    url := 'https://<project-ref>.supabase.co/functions/v1/assign_weekly_honors',
    headers := '{"Authorization": "Bearer <service-role-key>"}'::jsonb
  ) as request_id;$$
);
SQL
echo ""
echo "3. AASA file for Universal Links (/squad/<code>)"
echo "   Deploy at https://unboundapp.com/.well-known/apple-app-site-association"
echo "   Content:"
echo ""
cat <<'JSON'
{
  "applinks": {
    "details": [
      {
        "appIDs": ["TEAMID.com.unboundapp.ios"],
        "components": [{ "/": "/squad/*" }]
      }
    ]
  }
}
JSON
echo ""
echo "   (Replace TEAMID with your Apple Developer Team ID.)"
echo "   The file must be served with Content-Type: application/json and no extension."
echo ""
echo "==> Backend deploy complete."
echo "==> Test the integration:"
echo "    1. Open app on sim, create a squad."
echo "    2. Use the invite code on a second sim/device."
echo "    3. Train workouts on both — should detect linked session within 5 min window."
echo "    4. On Monday at 04:00 UTC, evaluate_squad_mission auto-generates a mission."
echo "    5. On Sunday at 23:00 UTC, assign_weekly_honors picks 3 honors."
