# Hard Paywall — Subscription Gating

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans`.

**Goal:** Convert UNBOUND from "free with subscription entitlement" to "hard paywall — subscribe or you can't use the app." No free workouts, no free trial in-app (Apple's 3-day intro offer still applies via App Store Connect). After onboarding, users either subscribe or hit a "Subscribe to continue" screen.

**Architecture:** A single `SubscriptionGate` SwiftUI ViewModifier wraps the root content. If the user is not subscribed AND has completed onboarding, the gate replaces the entire app surface with `LockedView` (the paywall presenter). Onboarding completes → paywall presents → on successful subscription, gate releases. Existing `SubscriptionService` already does entitlement checks; this plan adds the gating layer and the locked-state UI.

**Tech stack:** SwiftUI, existing RevenueCat + Superwall integration.

---

## Scope

In:
- `SubscriptionGate` ViewModifier wrapping the root view
- `LockedView` (paywall-aware, presents Superwall on appear)
- Paywall offered immediately after onboarding completion
- Settings → Subscription row shows current state + manage subscription deeplink
- Restore Purchases flow
- Gating behavior on app launch (subscribed → app; not subscribed → onboarding or paywall)
- Sign-out re-locks the app

Out:
- Multi-tier pricing
- Family sharing
- Promo code redemption UI (Apple handles via Settings)
- Discounted offers / win-back campaigns (Superwall ships these later)

---

## File-Touch Matrix

| File | Action | Notes |
|---|---|---|
| `UNBOUND/Services/Subscription/SubscriptionGate.swift` | **Create** | ViewModifier + helper |
| `UNBOUND/Views/Subscription/LockedView.swift` | **Create** | Full-screen "Subscribe to continue" with Superwall trigger |
| `UNBOUND/Views/Subscription/RestorePurchasesButton.swift` | **Create** | Small button used in LockedView + Settings |
| `UNBOUND/Services/Subscription/SubscriptionService.swift` | **Modify** | Add `@Published var isSubscribed: Bool` so views can react |
| `UNBOUND/App/AniBodyApp.swift` (or root) | **Modify** | Apply `.subscriptionGate()` modifier to root |
| `UNBOUND/Views/Onboarding/OnboardingFinishView.swift` (if exists; if not, the final onboarding step) | **Modify** | On Continue → mark onboarding complete → SubscriptionGate now triggers LockedView automatically |
| `UNBOUND/Views/Settings/SettingsView.swift` (or equivalent) | **Modify** | Add Subscription section: current state, Manage (opens Apple Settings), Restore Purchases |
| `UNBOUND/UNBOUNDTests/Services/SubscriptionGateTests.swift` | **Create** | Not-subscribed + onboarded → LockedView; subscribed → passes through |
| `UNBOUND/UNBOUNDUITests/PaywallGateWalkthroughTests.swift` | **Create** | Onboarding → paywall → mock-subscribe → app accessible |

---

## Tasks

### Task 1 — Make `SubscriptionService.isSubscribed` observable

**File:** Modify `UNBOUND/Services/Subscription/SubscriptionService.swift`.

If the service is not already `@MainActor` + `ObservableObject`, make it so. Add:

```swift
@Published private(set) var isSubscribed: Bool = false
```

Drive `isSubscribed` from the existing RevenueCat customer-info listener. On launch, fetch current entitlements once. On any entitlement change, update `isSubscribed`.

**Acceptance:** Subscribing in a sim path with a mock entitlement flips `isSubscribed` to true; expiring flips it back.

**Commit:** `feat(subscription): observable isSubscribed`

### Task 2 — `SubscriptionGate` ViewModifier

**File:** Create `UNBOUND/Services/Subscription/SubscriptionGate.swift`.

```swift
struct SubscriptionGate: ViewModifier {
    @EnvironmentObject var services: ServiceContainer
    @AppStorage("onboarding.completed") private var onboardingCompleted: Bool = false

    func body(content: Content) -> some View {
        if !onboardingCompleted {
            content                              // onboarding runs unwrapped
        } else if services.subscription.isSubscribed {
            content                              // app accessible
        } else {
            LockedView()                          // hard paywall
        }
    }
}

extension View {
    func subscriptionGate() -> some View { modifier(SubscriptionGate()) }
}
```

**Acceptance:** `SubscriptionGateTests` exercises three states (onboarding incomplete, onboarded-not-subscribed, onboarded-subscribed) — only the second renders `LockedView`.

**Commit:** `feat(subscription): SubscriptionGate ViewModifier`

### Task 3 — `LockedView`

**File:** Create `UNBOUND/Views/Subscription/LockedView.swift`.

Layout:
- Branded gradient background
- App wordmark
- Headline: "Subscribe to unlock UNBOUND"
- Subhead: "Your training, your crew, your build. Cancel anytime."
- Subscribe button → triggers Superwall paywall (existing `PaywallService.present(trigger:)`)
- `RestorePurchasesButton` below

On `.onAppear`, present Superwall paywall automatically (so users land directly in the purchase flow, not a sub-screen). Add a 500ms delay before auto-present so the LockedView render isn't jarring.

**Acceptance:** Preview shows the locked state. Tapping Subscribe re-presents Superwall.

**Commit:** `feat(subscription): LockedView paywall surface`

### Task 4 — `RestorePurchasesButton`

**File:** Create `UNBOUND/Views/Subscription/RestorePurchasesButton.swift`.

```swift
struct RestorePurchasesButton: View {
    @EnvironmentObject var services: ServiceContainer
    @State private var isRestoring = false
    @State private var restoreResult: String?

    var body: some View {
        Button {
            Task { await restore() }
        } label: {
            Text(isRestoring ? "Restoring..." : "Restore purchases")
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.accent)
        }
        .disabled(isRestoring)
        .overlay(alignment: .bottom) {
            if let result = restoreResult { Text(result).font(.caption2).padding(.top, 30) }
        }
    }

    private func restore() async {
        isRestoring = true
        do {
            try await services.subscription.restorePurchases()
            restoreResult = services.subscription.isSubscribed
                ? "Restored! Loading app…"
                : "No active subscription found."
        } catch {
            restoreResult = "Couldn't restore. Try again."
        }
        isRestoring = false
    }
}
```

Add `restorePurchases()` to `SubscriptionService` if it doesn't exist (calls the RevenueCat SDK).

**Acceptance:** Tapping restores in a sim path with an active sandbox subscription → `isSubscribed` flips → LockedView replaced by app.

**Commit:** `feat(subscription): Restore Purchases flow`

### Task 5 — Apply gate to root + onboarding handoff

**File:** Modify the app root (likely `AniBodyApp.swift` or `RootView.swift`).

Wrap the root content with `.subscriptionGate()`. Confirm `@AppStorage("onboarding.completed")` is set to `true` from inside the final onboarding step (`OnboardingFinishView` or equivalent).

**Acceptance:** Fresh install → onboarding plays → on finish, paywall appears immediately. Subscribe → app accessible.

**Commit:** `feat(subscription): wire hard paywall at root`

### Task 6 — Settings subscription section

**File:** Modify `SettingsView.swift` (or equivalent — find via `grep "Settings" UNBOUND/Views/`).

Add a section:
```
SUBSCRIPTION
  Active · monthly · renews May 25     [Manage]
  Restore purchases
  Sign out
```

`[Manage]` opens `https://apps.apple.com/account/subscriptions` via `UIApplication.shared.open`.

On sign-out, the gate naturally re-locks the app (since `isSubscribed` will read as false until next auth + entitlement check).

**Acceptance:** Tapping Manage opens Apple's subscription management. Signing out shows the paywall.

**Commit:** `feat(subscription): Settings subscription section`

### Task 7 — UI walkthrough test

**File:** Create `PaywallGateWalkthroughTests.swift`.

Scenario:
1. Fresh install (clear UserDefaults).
2. Onboarding plays → finish.
3. Verify `LockedView` is presented.
4. Verify Superwall auto-presents after 500ms.
5. Mock-subscribe via test seam → `isSubscribed = true`.
6. Verify app root is now accessible (e.g., Home tab visible).
7. Sign out via Settings.
8. Verify `LockedView` returns.

**Acceptance:** All 8 steps pass.

**Commit:** `test(subscription): hard paywall walkthrough`

---

## App Store review notes

- **Onboarding before paywall is critical.** Apple guideline 3.1.2: don't lock users out before they understand what they're paying for. Onboarding teaches the value; paywall arrives once they've seen what the app does.
- **Restore Purchases must be visible** on the paywall AND in Settings. Both ship in this plan.
- **Privacy policy + Terms** links are presented by Superwall's own paywall template — confirm they're configured in the Superwall dashboard. Apple WILL reject without them.
- **Subscription terms** (price + duration + renewal info) must appear on the paywall screen — Superwall handles this if the template is configured correctly.
- **No "free trial" claim in-app** — if you offer Apple's 3-day intro, only refer to it as "3-day intro offer" in copy, and let StoreKit handle the trial mechanics.

---

## Verification (end of plan)

```bash
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:UNBOUNDTests/Services/SubscriptionGateTests \
  -only-testing:UNBOUNDUITests/PaywallGateWalkthroughTests
```

Manual sanity:
1. Fresh install on a real device → onboarding → paywall → subscribe with sandbox account → app loads.
2. Force-quit and relaunch → app loads (subscription persists).
3. Cancel subscription in Apple Settings, wait for expiry, relaunch → paywall returns.
