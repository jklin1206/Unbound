-- =============================================================================
-- Server-owned premium entitlement source of truth
-- =============================================================================
-- Premium access was previously gated only by a LOCAL client flag (RevenueCat
-- cache / onboarding flag), which a user could spoof to call premium server
-- functions for free. This adds a server-owned `is_pro` flag on the user row,
-- written ONLY by the revenuecat_webhook Edge Function (service role), and read
-- by premium Edge Functions before doing premium work.
-- =============================================================================

alter table public.users
    add column if not exists is_pro boolean not null default false,
    add column if not exists is_pro_expires_at timestamptz;

comment on column public.users.is_pro is
    'Server-owned premium entitlement. Written only by the revenuecat_webhook Edge Function. Never trust a client-asserted entitlement.';
comment on column public.users.is_pro_expires_at is
    'Expiry of the current premium period (from RevenueCat event.expiration_at_ms). Null when not pro.';
