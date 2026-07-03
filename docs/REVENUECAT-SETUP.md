# RevenueCat / paywall — go-live setup

The **code is fully wired** (SDK, configure, login, offerings, purchase, restore,
entitlement gate, onboarding + lock-screen paywalls). What's left to make it
charge real money is **dashboard + App Store Connect config** — there's nothing
left to build in the app.

## What's already wired (no code work needed)

| Piece | Where |
|---|---|
| SDK installed + linked | `project.yml` → `RevenueCat` package, product `RevenueCat` |
| `Purchases.configure` on launch | `AppDelegate.application(_:didFinishLaunching:)` → `SubscriptionService.configure()` |
| Login (aliases the anon purchase to the user) | `RootView` post-auth task → `subscription.login(userId:)` |
| Offerings / purchase / restore / entitlement | `SubscriptionService` (RevenueCat) |
| Entitlement = single source of truth | `EntitlementService.isEntitled` (real sub OR dev flag) |
| App gate after onboarding | `SubscriptionGate` → `LockedView` |
| Onboarding paywall | `Step_Paywall` → `SubscriptionPackagePicker` |
| Lock-screen / mid-app paywall | `LockedView` + `ProgramOverviewView` → `PaywallPlaceholderView` (misnamed — it's the real paywall) |
| Restore button | `RestorePurchasesButton` |
| DEBUG bypass | `DevFlags.unlockAllFeatures` ("DEV · Unlock simulator") |

## Code config points (already set — verify before shipping)

`UNBOUND/Utilities/AppConstants.swift`:
- `RevenueCat.apiKey` = `appl_OIQYrbHrtkobrAoGiqBJVJkLpcf` — the public **Apple** SDK key. (If it ever shows a `PLACEHOLDER_…` value the SDK runs in stub mode and offerings come back empty by design.)
- `RevenueCat.entitlementIdentifier` = **`Unbound Pro`** — must match the entitlement id in the RevenueCat dashboard exactly.
- `Paywall.hardGate` = `hard_gate` — analytics placement string only.

Bundle id: `com.unboundapp.ios`.

## To go live — do this once (external)

1. **App Store Connect → Subscriptions:** create an auto-renewable subscription
   group and the products you want. The package picker auto-labels by
   name/duration, so include some of: **weekly, monthly, 3-month, annual**
   (it sorts quarterly → weekly → annual → monthly and badges them). Add a free
   trial as an introductory offer if desired (the UI surfaces "X TRIAL").
2. **RevenueCat dashboard:**
   - Add the iOS app with bundle id `com.unboundapp.ios` and the App Store
     **shared secret**.
   - Create an **Entitlement** named exactly **`Unbound Pro`**.
   - Attach every product above to that entitlement.
   - Create the **current Offering** and add the products as packages.
3. **Verify the SDK key** in `AppConstants.RevenueCat.apiKey` matches the dashboard's
   Apple public key (it already looks correct: `appl_…`).
4. **Sandbox test:** run on a real device with a Sandbox Apple ID →
   onboarding paywall should list the packages → purchase → entitlement flips →
   `SubscriptionGate` opens the app. Then delete + reinstall → **Restore** should
   re-unlock.

## Gotchas

- Until step 2's Offering exists, `fetchOfferings()` returns empty and the picker
  shows "RevenueCat returned no available packages." That's expected pre-config,
  not a bug.
- The paywall is a **hard gate** post-onboarding — there is intentionally no
  "skip" in release builds; the only bypass is the DEBUG dev-unlock.
- New users complete onboarding **before** sign-in; their answers are stashed and
  replayed onto the real account at sign-in (`PendingOnboardingProfile`). A
  purchase made during onboarding is anonymous until `subscription.login` aliases
  it — RevenueCat handles that automatically.

## Agent access (MCP) — 2026-06-30

Both APIs are wired as MCP servers so an agent (Claude Code / Cursor) can manage
products + offerings directly instead of clicking the dashboards. Config lives in
the **git-ignored** `.mcp.json` at the repo root:

- **revenuecat** — `https://mcp.revenuecat.ai/mcp` (OAuth; run `/mcp` to
  authenticate). Manages apps, products, offerings/packages, entitlements; reads
  experiment results.
- **app-store-connect** — `npx -y mcp-asc` (the `beautyfree/appstore-connect-mcp`
  server, official ASC API). Auth via env in `.mcp.json`:
  `APP_STORE_CONNECT_KEY_ID` / `APP_STORE_CONNECT_ISSUER_ID` /
  `APP_STORE_CONNECT_P8_PATH`. The `.p8` lives at `~/.appstoreconnect/`
  (chmod 600), **never** in git.

MCP servers load at Claude Code **startup** — restart after editing `.mcp.json`.
Agent pipeline: create subscriptions + pricing via `app-store-connect` → import
into an Offering + attach to the `Unbound Pro` entitlement via `revenuecat` → A/B
via RevenueCat Experiments (the app already reads `offerings.current`).

## Current state (2026-07-01 — Apple block CLEARED)

The Apple **Individual → Organization** migration is done (entity = **Gauvalin
LLC**). The old ASC API key `873FU4R5LK` was orphaned to the dead individual
entity and returned `403 REQUIRED_AGREEMENTS_MISSING_OR_EXPIRED` on *every* call
(even `list-territories`). A **fresh LLC Team Key `UUXWY5JR86`** (same issuer
`6b7d2cb2-…`) now returns **200** — App Store Connect API is unblocked.

Verified directly from ASC (2026-07-01, via a local ES256-JWT signer since the
running MCP still holds the old key until a Claude Code restart):
- App **Unbound: Break the Restriction** (`6762562742`, `com.unboundapp.ios`).
- Subscription group **Unbound Pro** (`22113031`) — group localization set.
- **`unbound_weekly`** (sub `6773110842`, `ONE_WEEK`) — localization ✅, prices
  ✅ across **175 territories** (US **$14.99**), intro offers 0.
- **`unbound_month_3`** (sub `6773108367`, `THREE_MONTHS`) — localization ✅,
  prices ✅ across 175 territories (US **$24.99**), intro offers 0.
- Both still `MISSING_METADATA` for **one reason only: no App Review
  screenshot** (`appStoreReviewScreenshot` = NONE). The screenshot is required
  to *submit for review*, NOT for RC sync or sandbox purchase testing.

RevenueCat project **Unbound** (`proj3b7dfa50`):
- **Offering `default`** (`ofrng7252d03c51`, current) — Weekly / Three Month / Yearly.
- **Entitlement `Unbound Pro`** (`entl8b6365ec06`) — attached to the two real products.
- **App `Unbound (App Store)`** (`appaaebf0fcb9`) — shared secret set.
- **Still shows `duration: null` + `store_status: could_not_check`** because RC's
  dashboard ASC key is *still the old orphaned `873FU4R5LK`*. This is the last gap.

**Open items:**
1. **Update RevenueCat's dashboard ASC key to the new LLC key `UUXWY5JR86`.**
   RC dashboard → Project → App `Unbound (App Store)` → App Store Connect API /
   in-app-purchase-key config → upload `~/Downloads/AuthKey_UUXWY5JR86.p8`, Key ID
   `UUXWY5JR86`, Issuer `6b7d2cb2-2b87-46cb-aca6-365019dd7dd0`. (An agent can't
   push it — harness blocks materializing the `.p8`.) The moment it lands, RC
   reads Apple and durations/prices populate; verify via MCP `get-product-store-state`
   (flips `could_not_check` → `ok`).
2. **`MISSING_METADATA` → add the review screenshot** (only needed to submit for
   App Review; not blocking sync or sandbox testing). Can be uploaded via ASC API
   once we have a paywall screenshot.
3. **Package-naming nit:** package `$rc_monthly` (`pkge2c6cd53b13`) holds the
   *weekly* product. Cosmetic (app labels by `subscriptionPeriod`); left as-is.

**MCP note:** `.mcp.json` now points at `UUXWY5JR86` /
`~/Downloads/AuthKey_UUXWY5JR86.p8`, but the running `app-store-connect` MCP
loaded the old key at startup — **restart Claude Code** to use the ASC MCP tools;
until then use a local JWT signer (see `scratchpad/asc_*.py`) for ASC reads.

## Price A/B runbook (RevenueCat Experiments)

Decision (2026-07): **keep the custom SwiftUI paywall, A/B the PRICES** (not the
design). The app already reads `offerings.current`, so RC Experiments serve price
variants automatically — no app release. The app-side is A/B-ready:
`SubscriptionPackagePicker` renders `offerings.current` dynamically, prices come
from the live `StoreProduct`, packages are classified by product duration (robust
to lookup_key mismatch — hardened 2026-07 so `isMonthly` can't double-match a
weekly product), and it fires `paywallPresented`/`paywallConverted` analytics for
attribution.

Apple prices are fixed per product, so **each test price is its own product.** To
A/B two prices for a plan (gated on the Apple migration + ASC API working):
1. **App Store Connect** → in the `Unbound Pro` group, create the price-variant
   product(s), e.g. control `unbound_month_3` ($24.99) + variant
   `unbound_month_3_1999` ($19.99). Set display name + price + optional trial;
   get to "Ready to Submit."
2. **RevenueCat** → products auto-import once the ASC API key is configured (or
   add them). Attach BOTH to the `Unbound Pro` entitlement.
3. **RevenueCat → Offerings** → create a variant offering (e.g. `price-b`)
   mirroring `default` but swapping in the variant product; keep `default` as
   control.
4. **RevenueCat → Experiments** (dashboard — NOT available via MCP) → new
   experiment: Control = `default`, Treatment = `price-b`, 50/50, metric =
   conversion or revenue. Launch.
5. Nothing ships. The app serves whichever offering RC assigns per user; read
   results in RC or via MCP `get-experiment-results`.
