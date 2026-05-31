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
