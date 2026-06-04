#!/usr/bin/env bash
# Deploy the squads backend to Supabase.
# Run after sub-projects #1-#6 are merged into program-redesign.
#
# Prerequisites:
#   - supabase CLI installed: `brew install supabase/tap/supabase`
#   - You are logged in: `supabase login` (browser opens)
#   - The UNBOUND project is linked: `supabase link --project-ref <ref>`
#     (Get <ref> from Supabase Dashboard → Project Settings → Reference ID)
#   - SQUAD_CRON_SECRET set in your shell. This is a dedicated shared secret
#     for server-only cron/webhook Edge Function calls. Do not use the Supabase
#     service-role key as this bearer secret.
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

SERVICE_FUNCTION_SECRET="${SQUAD_CRON_SECRET:-}"

if [ -z "$SERVICE_FUNCTION_SECRET" ]; then
    echo "ERROR: SQUAD_CRON_SECRET is not set."
    echo "Generate a dedicated random secret for cron/webhook callers; do not use the Supabase service-role key."
    exit 1
fi

# --- Step 1: Apply migrations ---
echo "==> Applying Supabase migrations..."
supabase db push

# Key squad migrations applied:
#   20260514130000_squad_schema.sql
#   20260514130001_squad_activity_nullable_user.sql
#   20260514130002_squad_missions.sql
#   20260514130003_squad_weekly_honors.sql
#   20260514130004_friend_challenges.sql
#   20260514130005_squad_cron_and_webhook.sql
#   20260601081000_squad_backend_auth_forward_fix.sql
#   20260601083000_squad_weekly_honors_unique_conflict_target.sql
#   20260601084000_squad_progress_source_ledgers.sql

# --- Step 2: Deploy 5 Edge Functions ---
echo "==> Deploying 5 Edge Functions..."

supabase secrets set SQUAD_CRON_SECRET="$SERVICE_FUNCTION_SECRET"

supabase functions deploy join_squad
supabase functions deploy detect_linked_sessions --no-verify-jwt
supabase functions deploy evaluate_squad_streak --no-verify-jwt
supabase functions deploy evaluate_squad_mission --no-verify-jwt
supabase functions deploy assign_weekly_honors --no-verify-jwt

# --no-verify-jwt: these are server-only crons + webhooks invoked by Supabase
# itself, not by authenticated users. They still require
# SQUAD_CRON_SECRET through Authorization: Bearer <secret>.
# The `join_squad` function DOES need JWT (called by the iOS client with the
# user's auth token).

# --- Step 3: Configure DB secret + deployment-only manual items ---
echo ""
echo "==> MANUAL STEPS REMAINING:"
echo ""
echo "1. Configure the DB-side copy of the service-function secret"
echo "   Dashboard → SQL editor:"
echo "   alter database postgres"
echo "   set app.settings.service_function_secret = '<same value as SQUAD_CRON_SECRET>';"
echo ""
echo "2. Squad automation is installed by migrations"
echo "   - pg_cron schedules call evaluate_squad_* and assign_weekly_honors"
echo "   - public.workout_logs_detect_linked_sessions calls detect_linked_sessions"
echo "   Do not create a Dashboard Database Webhook for detect_linked_sessions;"
echo "   the DB trigger is authoritative and a Dashboard webhook would double-fire."
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
