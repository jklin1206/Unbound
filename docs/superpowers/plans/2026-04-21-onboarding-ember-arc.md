# Onboarding Ember Arc Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the ember-arc redesign across the UNBOUND onboarding flow — a neutral sealed-baseline intro, continuous-loop archetype carousel, per-user 6-stat system, ember-ignition chapter cards, ember-rune stage cards, umbrella-select picker pattern for muscle groups and equipment, and strip all named-anime-IP copy from the UI.

**Architecture:** New reusable SwiftUI primitives (`EmberView`, `UmbrellaSelectList<T>`, `EmberRuneIcon`, expanded `StatBar` / `SilhouetteView`) live in `Views/Components/Unbound/` and `Views/Components/Anime/`. Screen-level views in `Views/Onboarding/Steps/` consume them. The `Archetype` model gets a `characterTagline` strip + `neutralSealed` asset addition. No backend changes; no data model migration beyond removing the tagline accessor.

**Tech Stack:** SwiftUI (iOS 17+), Xcodegen project, existing UNBOUND design system (`Color.unbound.*`, `Font.unbound.*`), existing `OnboardingFlowViewModel` state machine.

**Spec reference:** `docs/superpowers/specs/2026-04-21-onboarding-ember-arc-design.md`

---

## Phase Map & Review Gates

| Phase | What | Review gate |
|---|---|---|
| 0 | Prerequisites (art assets) | Assets in place before Phase 2 merge |
| 1 | Foundation primitives — EmberView, expanded StatBar to 6, expanded SilhouetteView | Visual preview on simulator, user approves ember look |
| 2 | Screen 1 (Baseline sealed) | User approves on simulator |
| 3 | Screen 2 (Archetype carousel + 6 stats) | User approves on simulator |
| 4 | Screen 4 (Chapter card ignition animation) | User approves on simulator |
| 5 | Stage card (Step_LifeChange) ember rune | User approves on simulator |
| 6 | Archetype picker (strip taglines + silhouettes) | User approves on simulator |
| 7 | UmbrellaSelectList + muscle/equipment pickers | User approves on simulator |
| 8 | Icon audit + final polish | Ship-ready |

Review gate = stop, show, get approval before next phase.

---

## Phase 0 — Prerequisites

Art assets are a separate track (Gemini image gen or commissioned) but block Phase 2+. Spec them here so they're ready.

### Task 0.1: Generate missing archetype silhouettes

**Files:**
- Create: `UNBOUND/Resources/BodyMap/archetype_vtaper.png`
- Create: `UNBOUND/Resources/BodyMap/archetype_heavyweight.png`
- Create: `UNBOUND/Resources/BodyMap/archetype_shredded.png`
- Create: `UNBOUND/Resources/BodyMap/neutral_sealed.png`
- Already exists: `UNBOUND/Resources/BodyMap/archetype_sleeper.png`

- [ ] **Step 1:** Verify which silhouettes are missing

```bash
ls UNBOUND/Resources/BodyMap/archetype_*.png
ls UNBOUND/Resources/BodyMap/neutral_sealed.png 2>/dev/null || echo "missing: neutral_sealed"
```

- [ ] **Step 2:** Generate each missing asset using Gemini (match style of existing `archetype_sleeper.png`: dark body, violet rim light, black-to-violet background, full body front-facing). Poses per internal archetype energy (shorthand — never shipped in copy):
  - `archetype_vtaper.png` — lean assassin stance, hands loose at sides
  - `archetype_heavyweight.png` — power stance, feet wide, arms slightly out from body
  - `archetype_shredded.png` — athletic ready stance, fists loose
  - `neutral_sealed.png` — generic male body, dim grey, subtle muted violet aura, barely-perceptible (this is the "before" state)

- [ ] **Step 3:** Drop files into `UNBOUND/Resources/BodyMap/` and commit

```bash
git add UNBOUND/Resources/BodyMap/archetype_*.png UNBOUND/Resources/BodyMap/neutral_sealed.png
git commit -m "assets: archetype silhouettes + neutral sealed baseline"
```

---

## Phase 1 — Foundation Primitives

### Task 1.1: Create `EmberView` component

Reusable ember glow — a dim/active pulsing violet ember used on silhouettes, stage cards, chapter animations. Drives the whole visual thread.

**Files:**
- Create: `UNBOUND/UNBOUND/Views/Components/Unbound/EmberView.swift`

- [ ] **Step 1: Write the component**

```swift
import SwiftUI

/// Animated ember glow. Two states:
/// - `.dormant` — cold, dim grey, slow 2s pulse
/// - `.active` — alive violet, faster 1s pulse with sparkle
/// - `.igniting` — one-shot transition from dormant to active (0.6s)
struct EmberView: View {
    enum State { case dormant, active, igniting }

    var state: State = .dormant
    var size: CGFloat = 24

    @SwiftUI.State private var pulse: Bool = false

    var body: some View {
        ZStack {
            // Outer halo
            Circle()
                .fill(
                    RadialGradient(
                        colors: [haloColor.opacity(0.55), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 1.4
                    )
                )
                .frame(width: size * 2.8, height: size * 2.8)
                .opacity(pulse ? 1.0 : 0.55)

            // Core
            Circle()
                .fill(coreColor)
                .frame(width: size * 0.55, height: size * 0.55)
                .blur(radius: 2)
                .opacity(pulse ? 1.0 : 0.75)
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: pulseDuration)
                .repeatForever(autoreverses: true)
            ) {
                pulse = true
            }
        }
    }

    private var pulseDuration: Double {
        switch state {
        case .dormant: return 2.0
        case .active, .igniting: return 1.0
        }
    }

    private var coreColor: Color {
        switch state {
        case .dormant: return Color.gray.opacity(0.5)
        case .active, .igniting: return Color.unbound.accent
        }
    }

    private var haloColor: Color {
        switch state {
        case .dormant: return Color.gray
        case .active, .igniting: return Color.unbound.accent
        }
    }
}

#Preview("Ember — dormant vs active") {
    HStack(spacing: 48) {
        EmberView(state: .dormant, size: 40)
        EmberView(state: .active, size: 40)
    }
    .frame(width: 400, height: 200)
    .background(Color.unbound.bg)
}
```

- [ ] **Step 2: Build and preview**

```bash
xcodegen generate
xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build 2>&1 | tail -20
```

Expected: no compile errors. Open the `#Preview` in Xcode canvas to confirm visual.

- [ ] **Step 3: Commit**

```bash
git add UNBOUND/UNBOUND/Views/Components/Unbound/EmberView.swift
git commit -m "feat(ui): add EmberView primitive — dormant/active/igniting states"
```

### Task 1.2: Add 2 new stats to the baseline stat system

Current `StatBar` supports 4 stats (strength/stamina/discipline/confidence). Need `focus` and `recovery`. First find where the 4-stat list is defined.

**Files:**
- Modify: wherever `StatBar` call sites list the 4 stats (discover via grep)
- Modify: `UNBOUND/UNBOUND/Views/Components/Anime/StatBar.swift` if stats are enumerated inside it

- [ ] **Step 1: Find the stat enumeration**

```bash
grep -rn "STRENGTH\|CONFIDENCE" UNBOUND/UNBOUND/Views/ --include="*.swift" | head -20
grep -rn "struct StatBar" UNBOUND/UNBOUND/ --include="*.swift"
```

- [ ] **Step 2: Read the StatBar file**

```bash
cat UNBOUND/UNBOUND/Views/Components/Anime/StatBar.swift
```

- [ ] **Step 3: If there's a shared `OnboardingStat` enum, extend it. Otherwise create one.**

Create or modify: `UNBOUND/UNBOUND/Models/OnboardingStat.swift`

```swift
import Foundation

enum OnboardingStat: String, CaseIterable, Identifiable {
    case strength, stamina, discipline, confidence, focus, recovery

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .strength:   return "STRENGTH"
        case .stamina:    return "STAMINA"
        case .discipline: return "DISCIPLINE"
        case .confidence: return "CONFIDENCE"
        case .focus:      return "FOCUS"
        case .recovery:   return "RECOVERY"
        }
    }
}
```

- [ ] **Step 4: Verify StatBar accepts a generic label/value and doesn't hardcode the 4-stat list**

If `StatBar` hardcodes stats internally, refactor to accept `(label: String, rank: Rank, fillFraction: Double)` parameters. If it already does, skip.

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/UNBOUND/Models/OnboardingStat.swift
git commit -m "feat(onboarding): add OnboardingStat enum with focus + recovery"
```

### Task 1.3: Add `BaselineStats` per-user computation

Generates the 6 baseline stat ranks for a new user. Until scan results exist, all default to E (lowest). Post-scan this can be replaced with real derivation.

**Files:**
- Create: `UNBOUND/UNBOUND/Models/BaselineStats.swift`

- [ ] **Step 1: Write the struct**

```swift
import Foundation

/// Baseline rank per onboarding stat. Until scan/goal answers feed in,
/// every new user starts at E (Dormant).
struct BaselineStats {
    let ranks: [OnboardingStat: Rank]

    static var defaultDormant: BaselineStats {
        BaselineStats(ranks: Dictionary(
            uniqueKeysWithValues: OnboardingStat.allCases.map { ($0, .e) }
        ))
    }

    func rank(for stat: OnboardingStat) -> Rank {
        ranks[stat] ?? .e
    }

    /// Eventual derivation point — consumes scan + goal answers and
    /// returns a customized baseline. For now it just returns dormant.
    static func compute(from profile: UserProfile?) -> BaselineStats {
        defaultDormant
    }
}
```

- [ ] **Step 2: Verify `Rank` exists**

```bash
grep -rn "enum Rank" UNBOUND/UNBOUND/Models/ --include="*.swift"
```

If missing, create it:

```swift
// Add to an appropriate existing file, or create Models/Rank.swift
enum Rank: String, Codable, CaseIterable {
    case e, d, c, b, a, s

    var displayLetter: String { rawValue.uppercased() }

    var stateName: String {
        switch self {
        case .e: return "Dormant"
        case .d: return "Awakened"
        case .c: return "Forged"
        case .b: return "Sharpened"
        case .a: return "Unbound"
        case .s: return "Ascended"
        }
    }

    /// Fraction-full for progress bars: E=0.15, D=0.3, C=0.5, B=0.7, A=0.85, S=1.0
    var fillFraction: Double {
        switch self {
        case .e: return 0.15
        case .d: return 0.30
        case .c: return 0.50
        case .b: return 0.70
        case .a: return 0.85
        case .s: return 1.00
        }
    }
}
```

- [ ] **Step 3: Build**

```bash
xcodegen generate && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build 2>&1 | tail -10
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add UNBOUND/UNBOUND/Models/BaselineStats.swift UNBOUND/UNBOUND/Models/Rank.swift
git commit -m "feat(onboarding): add BaselineStats + Rank model"
```

### Task 1.4: Extend `SilhouetteView` to support neutral sealed + ember overlay

**Files:**
- Modify: `UNBOUND/UNBOUND/Views/Components/Anime/SilhouetteView.swift`

- [ ] **Step 1: Read the current file**

```bash
cat UNBOUND/UNBOUND/Views/Components/Anime/SilhouetteView.swift
```

- [ ] **Step 2: Add `neutralSealed` to `BodyAsset` enum and wire an optional ember overlay**

Modify the file so `BodyAsset` has a `.neutralSealed` case pointing to `neutral_sealed.png`, and `SilhouetteView` accepts an optional `embersState: EmberView.State?` parameter that renders an `EmberView` centered on the chest (roughly 45% down from top, centered horizontally).

Expected new API:
```swift
SilhouetteView(asset: .neutralSealed, embersState: .dormant)
SilhouetteView(asset: .sleeper, embersState: .active)
SilhouetteView(asset: .sleeper, embersState: nil) // no ember overlay
```

- [ ] **Step 3: Build**

```bash
xcodegen generate && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build 2>&1 | tail -10
```

- [ ] **Step 4: Commit**

```bash
git add UNBOUND/UNBOUND/Views/Components/Anime/SilhouetteView.swift
git commit -m "feat(ui): SilhouetteView — neutralSealed asset + optional ember overlay"
```

### Task 1.5: Strip `characterTagline` from `Archetype` model

Remove the property that returns "Toji build" / "Itadori build" etc. This enforces the no-anime-names rule at the model level — the UI can't accidentally render it.

**Files:**
- Modify: `UNBOUND/UNBOUND/Models/Archetype.swift:34-41`

- [ ] **Step 1: Find all callers before removing**

```bash
grep -rn "characterTagline" UNBOUND/UNBOUND/ --include="*.swift"
```

Expected output: list of files using it. Step 04_PickArchetype almost certainly is one.

- [ ] **Step 2: Remove the `characterTagline` property from `Archetype.swift`**

Delete lines 31–41 (the comment block + `characterTagline` computed property).

- [ ] **Step 3: Remove all callers**

For each file returned in step 1, remove the Text rendering of `characterTagline`. If removing leaves empty VStack slots, close them cleanly.

- [ ] **Step 4: Build — compile must succeed**

```bash
xcodegen generate && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build 2>&1 | tail -10
```

Expected: clean build. Any lingering reference = compile error = fix before proceeding.

- [ ] **Step 5: Also audit `animeReferences` — confirm it's internal-only**

```bash
grep -rn "animeReferences" UNBOUND/UNBOUND/Views/ --include="*.swift"
```

If it's rendered in any View, remove those renders too.

- [ ] **Step 6: Commit**

```bash
git add UNBOUND/UNBOUND/Models/Archetype.swift UNBOUND/UNBOUND/Views/
git commit -m "feat(archetype): strip characterTagline — remove anime-named UI copy (IP risk)"
```

### 🛑 Review Gate — End of Phase 1

Stop. Run on simulator, show user:
- `EmberView` preview (dormant + active side-by-side)
- `SilhouetteView` with `neutralSealed` + dormant ember

Get approval before Phase 2.

---

## Phase 2 — Screen 1: Baseline Sealed

### Task 2.1: Redesign `Step_Arc02_Problem` baseline layout

**Files:**
- Modify: `UNBOUND/UNBOUND/Views/Onboarding/Steps/Step_Arc02_Problem.swift`

- [ ] **Step 1: Read the current file**

```bash
cat UNBOUND/UNBOUND/Views/Onboarding/Steps/Step_Arc02_Problem.swift
```

- [ ] **Step 2: Reorganize layout — silhouette left half, stats right half**

The current implementation stacks stats alone. Change to a 2-column HStack:
- Left column: `SilhouetteView(asset: .neutralSealed, embersState: .dormant)` (fills ~45% width)
- Right column: 6 `StatBar` rows (strength, stamina, discipline, confidence, focus, recovery), all at rank `.e`, 80ms entrance stagger

- [ ] **Step 3: Add optional chapter label top-left**

Small uppercase mono text `CHAPTER I · THE BASELINE`, low opacity (0.6), above the main content.

- [ ] **Step 4: Update copy**

- Headline: `"This is where you start."` (replaces current)
- Sub: `"Everyone begins sealed. The ones who stay — break through."`

- [ ] **Step 5: Entrance animation**

```swift
@State private var silhouetteIn = false
@State private var statsIn = false

.onAppear {
    withAnimation(.easeOut(duration: 0.8)) { silhouetteIn = true }
    withAnimation(.easeOut(duration: 0.6).delay(0.4)) { statsIn = true }
}
```

Silhouette fades from `opacity: 0` → `1` + slight `offset(y: 12)` → `0`. Stats appear with 80ms stagger per bar (each bar has its own `.delay(index * 0.08)`).

- [ ] **Step 6: Build + run simulator**

```bash
xcodegen generate && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build 2>&1 | tail -10
```

Open simulator, DEV·SKIP through to Step_Arc02_Problem, visually verify.

- [ ] **Step 7: Commit**

```bash
git add UNBOUND/UNBOUND/Views/Onboarding/Steps/Step_Arc02_Problem.swift
git commit -m "feat(onboarding): Screen 1 baseline — sealed silhouette + 6 stats + chapter label"
```

### 🛑 Review Gate — End of Phase 2

Show simulator. Confirm the cold ember pulses visible on chest. Get approval before Phase 3.

---

## Phase 3 — Screen 2: Archetype Carousel + 6 Stats

### Task 3.1: Create `ArchetypeCarouselView`

Continuous loop, 0.5s cross-fade between archetype silhouettes, no settling.

**Files:**
- Create: `UNBOUND/UNBOUND/Views/Components/Unbound/ArchetypeCarouselView.swift`

- [ ] **Step 1: Write the view**

```swift
import SwiftUI

/// Ambient continuous-loop carousel. Cycles all 4 archetypes every 2s
/// with a 0.5s cross-fade between each. User's actual archetype (passed
/// in) gets an active ember on display; others show dormant ember.
struct ArchetypeCarouselView: View {
    let userArchetype: Archetype

    @State private var currentIndex: Int = 0
    private let archetypes = Archetype.allCases
    private let rotationInterval: TimeInterval = 2.0

    var body: some View {
        ZStack {
            ForEach(Array(archetypes.enumerated()), id: \.offset) { index, archetype in
                SilhouetteView(
                    asset: silhouetteAsset(for: archetype),
                    embersState: archetype == userArchetype ? .active : .dormant
                )
                .opacity(index == currentIndex ? 1 : 0)
                .animation(.easeInOut(duration: 0.5), value: currentIndex)
            }
        }
        .onAppear {
            startRotation()
        }
    }

    private func silhouetteAsset(for archetype: Archetype) -> BodyAsset {
        switch archetype {
        case .vTaper: return .vTaper
        case .heavyDuty: return .heavyweight
        case .leanCut: return .shredded
        case .shredded: return .sleeper  // displayName = "SLEEPER"
        }
    }

    private func startRotation() {
        Timer.scheduledTimer(withTimeInterval: rotationInterval, repeats: true) { _ in
            currentIndex = (currentIndex + 1) % archetypes.count
        }
    }
}
```

> NOTE: `BodyAsset` enum extended in Task 1.4 needs `.vTaper`, `.heavyweight`, `.shredded`, `.sleeper` cases all present. Verify before implementing.

- [ ] **Step 2: Build**

```bash
xcodegen generate && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build 2>&1 | tail -10
```

- [ ] **Step 3: Commit**

```bash
git add UNBOUND/UNBOUND/Views/Components/Unbound/ArchetypeCarouselView.swift
git commit -m "feat(onboarding): ArchetypeCarouselView — continuous loop + ember differentiation"
```

### Task 3.2: Wire carousel into Screen 2 (archetype reveal step)

The "archetype reveal + stats" screen is the second arc step. Find which step file renders it (likely also in `Step_Arc02_Problem` depending on state toggles, or a separate `Step_Arc03_Path`).

**Files:**
- Discover via grep + modify the matching step file

- [ ] **Step 1: Find the screen**

```bash
grep -rn "Your training arc\|training arc starts" UNBOUND/UNBOUND/Views/Onboarding/ --include="*.swift"
grep -rn "YOUR VERSION OF STRONG" UNBOUND/UNBOUND/Views/Onboarding/ --include="*.swift"
```

- [ ] **Step 2: In that file, replace the single-silhouette render with `ArchetypeCarouselView(userArchetype: flow.selectedArchetype)`**

- [ ] **Step 3: Change the stats from 4 to 6**

Add FOCUS and RECOVERY rows to the stats column. Pull ranks from `BaselineStats.compute(from: profile)`.

> **Carousel + stats sync behavior** (per spec section 8): Stats stay pinned to the user's archetype while the carousel rotates background silhouettes. If visual feels wrong in prototype, revisit.

- [ ] **Step 4: Update sub-copy**

Change `"Every rep ranked. Every week measured."` → `"Every rep ranked. Every arc measured."`

- [ ] **Step 5: Build + simulator run**

```bash
xcodegen generate && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build 2>&1 | tail -10
```

- [ ] **Step 6: Commit**

```bash
git add UNBOUND/UNBOUND/Views/Onboarding/Steps/
git commit -m "feat(onboarding): Screen 2 — continuous archetype carousel + 6 stats per user"
```

### 🛑 Review Gate — End of Phase 3

Show simulator. Confirm 0.5s cross-fade feels smooth. Confirm the user's archetype reads clearly via ember diff. Confirm 6 stats breathe without deadspace. Get approval.

---

## Phase 4 — Chapter Card Ignition Animation

### Task 4.1: Build ember-ignition entrance for `ChapterInterstitial`

**Files:**
- Modify: `UNBOUND/UNBOUND/Views/Onboarding/Steps/ChapterInterstitial.swift`

- [ ] **Step 1: Read the current file**

```bash
cat UNBOUND/UNBOUND/Views/Onboarding/Steps/ChapterInterstitial.swift
```

- [ ] **Step 2: Replace current staggered-text reveal with ember-ignition sequence**

Sequence (~1.2s total):
1. `t=0.0s` — black screen, single ember drifts up from bottom center (offset y: +200 → 0, opacity 0 → 1)
2. `t=0.5s` — ember bursts into a spark: brief white flash (60ms), then ember scales 1.0 → 1.4 → 1.0
3. `t=0.7s` — chapter label text emerges from the spark (scale 0.9 → 1.0 + opacity 0 → 1)
4. `t=1.0s` — sub-title fades in below
5. `t=1.2s` — DEV·SKIP button + background grid fade in

Implementation: use `@State` flags for each stage + `DispatchQueue.main.asyncAfter` to fire each stage, or use `TimelineView` for precise control. Prefer a set of `withAnimation(.easeOut(duration: X).delay(Y))` calls attached to `@State` booleans set in `.onAppear`.

- [ ] **Step 3: Keep auto-advance logic**

Don't change the 2.8s auto-advance. The 1.2s ignition runs, then ~1.6s of settled state before advancing.

- [ ] **Step 4: Build + simulator**

```bash
xcodegen generate && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build 2>&1 | tail -10
```

Navigate to a chapter interstitial via DEV·SKIP, verify.

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/UNBOUND/Views/Onboarding/Steps/ChapterInterstitial.swift
git commit -m "feat(onboarding): ChapterInterstitial ember-ignition entrance animation"
```

### 🛑 Review Gate — End of Phase 4

Show simulator. Confirm the ignition reads as "unlocking / breaking restriction" without being on-the-nose. Get approval.

---

## Phase 5 — Stage Card Hexagon Fix + Ember Rune

### Task 5.1: Fix `HUDHexagon` squish (defensive aspect handling)

**Files:**
- Modify: `UNBOUND/UNBOUND/Views/Components/HUD/ChamferedShape.swift:23-44`

- [ ] **Step 1: Update `HUDHexagon` to draw a regular pointy-top hex inside any frame**

Replace the current `path(in:)` to compute from `min(rect.width, rect.height)`, centered, so the shape stays regular regardless of parent frame aspect.

```swift
struct HUDHexagon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let side = min(rect.width, rect.height)
        // Regular pointy-top hex: width = side, height = side * 2/sqrt(3)
        // Fit inside the smaller dimension to avoid overflow.
        let w = side
        let h = side * 2 / sqrt(3) * 0.866  // = side * 1.0 (fits width-locked)
        let cx = rect.midX
        let cy = rect.midY
        let halfW = w / 2.0
        let quarterH = h / 4.0

        path.move(to: CGPoint(x: cx, y: cy - h / 2))
        path.addLine(to: CGPoint(x: cx + halfW, y: cy - quarterH))
        path.addLine(to: CGPoint(x: cx + halfW, y: cy + quarterH))
        path.addLine(to: CGPoint(x: cx, y: cy + h / 2))
        path.addLine(to: CGPoint(x: cx - halfW, y: cy + quarterH))
        path.addLine(to: CGPoint(x: cx - halfW, y: cy - quarterH))
        path.closeSubpath()
        return path
    }
}
```

- [ ] **Step 2: Fix the call site in `Step_LifeChange.swift:88`**

Change `.frame(width: 170, height: 156)` → `.frame(width: 170, height: 170)` so the container is square.

- [ ] **Step 3: Build + simulator — navigate to a Life Change slide**

```bash
xcodegen generate && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build 2>&1 | tail -10
```

- [ ] **Step 4: Commit**

```bash
git add UNBOUND/UNBOUND/Views/Components/HUD/ChamferedShape.swift UNBOUND/UNBOUND/Views/Onboarding/Steps/Step_LifeChange.swift
git commit -m "fix(ui): HUDHexagon — regular pointy-top hex regardless of frame aspect"
```

### Task 5.2: Create `EmberRuneIcon` — hex rune with inner ember + variable inner icon

**Files:**
- Create: `UNBOUND/UNBOUND/Views/Components/Unbound/EmberRuneIcon.swift`

- [ ] **Step 1: Write the component**

```swift
import SwiftUI

/// Ember-containing hex rune. Used on stage cards (sleep, energy, etc).
/// The hex is the rune, the ember sits behind the inner SF Symbol icon.
struct EmberRuneIcon: View {
    let systemIcon: String
    var size: CGFloat = 170

    var body: some View {
        ZStack {
            // Hex rune outline
            HUDHexagon()
                .stroke(Color.unbound.accent.opacity(0.45), lineWidth: 1.5)
                .frame(width: size, height: size)
                .animeGlow(color: Color.unbound.accent, radius: 18, intensity: 0.85)

            // Ember behind icon
            EmberView(state: .active, size: size * 0.35)
                .opacity(0.6)

            // Inner icon
            Image(systemName: systemIcon)
                .font(.system(size: size * 0.3, weight: .light))
                .foregroundStyle(Color.unbound.accent)
                .shadow(color: Color.unbound.accent.opacity(0.5), radius: 14)
        }
    }
}
```

- [ ] **Step 2: Replace the ZStack in `Step_LifeChange.swift` (around line 75-95) with `EmberRuneIcon(systemIcon: slide.icon)`**

- [ ] **Step 3: Build + simulator**

```bash
xcodegen generate && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build 2>&1 | tail -10
```

- [ ] **Step 4: Commit**

```bash
git add UNBOUND/UNBOUND/Views/Components/Unbound/EmberRuneIcon.swift UNBOUND/UNBOUND/Views/Onboarding/Steps/Step_LifeChange.swift
git commit -m "feat(ui): EmberRuneIcon — stage-card hex rune with inner ember"
```

### 🛑 Review Gate — End of Phase 5

Show simulator. Confirm hex is un-squished. Confirm ember reads through the inner icon without fighting it. Get approval.

---

## Phase 6 — Archetype Picker (strip taglines + silhouettes)

### Task 6.1: Update `ArchetypePickerCard` — remove tagline, add silhouette slot

**Files:**
- Modify: `UNBOUND/UNBOUND/Views/Components/Unbound/ArchetypePickerCard.swift`

- [ ] **Step 1: Read current card structure**

```bash
cat UNBOUND/UNBOUND/Views/Components/Unbound/ArchetypePickerCard.swift
```

- [ ] **Step 2: Remove any rendering of `characterTagline`**

Per Task 1.5, the property is already deleted — the card should already compile without it. But if the card has a `Text` reading a local tagline variable, strip it.

- [ ] **Step 3: Add silhouette slot**

Card body renders `SilhouetteView(asset: archetype.bodyAsset, embersState: selected ? .active : .dormant)` above the archetype name. Keep the `01` number top-left, hex check top-right.

- [ ] **Step 4: Build + simulator — navigate to Step04_PickArchetype**

```bash
xcodegen generate && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build 2>&1 | tail -10
```

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/UNBOUND/Views/Components/Unbound/ArchetypePickerCard.swift
git commit -m "feat(onboarding): ArchetypePickerCard — silhouette slot + ember + no tagline"
```

### 🛑 Review Gate — End of Phase 6

Show simulator. Verify all 4 silhouettes render (none fall back to placeholder). Ember ignites on selection. Get approval.

---

## Phase 7 — UmbrellaSelectList + Muscle/Equipment Pickers

### Task 7.1: Build generic `UmbrellaSelectList<T>`

**Files:**
- Create: `UNBOUND/UNBOUND/Views/Components/Unbound/UmbrellaSelectList.swift`

- [ ] **Step 1: Write the view**

```swift
import SwiftUI

/// Generic multi-select list with an umbrella option at index 0 that
/// auto-selects all sub-options. Sub-selection auto-manages umbrella state.
///
/// Usage:
///   UmbrellaSelectList(
///       umbrella: .init(id: "all", label: "Full body", icon: "figure"),
///       options: muscleGroups,
///       selection: $selectedGroups
///   )
struct UmbrellaSelectList<T: Identifiable & Hashable>: View {
    struct Option {
        let id: T.ID
        let label: String
        let icon: String  // SF Symbol or custom asset name
    }

    let umbrella: Option
    let options: [T]
    let optionLabel: (T) -> String
    let optionIcon: (T) -> String
    @Binding var selection: Set<T.ID>

    private var allSubIds: Set<T.ID> {
        Set(options.map(\.id))
    }
    private var umbrellaSelected: Bool {
        selection.contains(umbrella.id) || selection == allSubIds
    }

    var body: some View {
        VStack(spacing: 12) {
            umbrellaRow
            ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                subRow(option: option, index: index + 2)
            }
        }
    }

    private var umbrellaRow: some View {
        rowView(
            number: 1,
            icon: umbrella.icon,
            label: umbrella.label,
            selected: umbrellaSelected
        )
        .onTapGesture {
            toggleUmbrella()
        }
    }

    private func subRow(option: T, index: Int) -> some View {
        rowView(
            number: index,
            icon: optionIcon(option),
            label: optionLabel(option),
            selected: selection.contains(option.id)
        )
        .onTapGesture {
            toggleSub(option.id)
        }
    }

    private func toggleUmbrella() {
        if umbrellaSelected {
            selection.removeAll()
        } else {
            // Cascade: stagger selection fills 50ms each
            for (i, opt) in options.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05 * Double(i)) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        selection.insert(opt.id)
                    }
                }
            }
        }
    }

    private func toggleSub(_ id: T.ID) {
        withAnimation(.easeOut(duration: 0.2)) {
            if selection.contains(id) {
                selection.remove(id)
            } else {
                selection.insert(id)
                // Auto-promote to umbrella if all subs now selected
                if selection == allSubIds {
                    // Visual pulse on umbrella — handled in row view via state
                }
            }
        }
    }

    @ViewBuilder
    private func rowView(number: Int, icon: String, label: String, selected: Bool) -> some View {
        HStack(spacing: 16) {
            Text(String(format: "%02d", number))
                .font(Font.unbound.monoS)
                .foregroundStyle(selected ? Color.unbound.accent : Color.unbound.textTertiary)
                .frame(width: 32, alignment: .leading)

            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(selected ? Color.unbound.accent : Color.unbound.textSecondary)
                .frame(width: 28)

            Text(label)
                .font(Font.unbound.titleS)
                .foregroundStyle(Color.unbound.textPrimary)

            Spacer()

            HUDHexagon()
                .fill(selected ? Color.unbound.accent : Color.clear)
                .overlay(
                    HUDHexagon().stroke(Color.unbound.border, lineWidth: 1)
                )
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .opacity(selected ? 1 : 0)
                )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(
            ChamferedRectangle(inset: 4)
                .fill(Color.unbound.surface)
                .overlay(
                    ChamferedRectangle(inset: 4)
                        .stroke(selected ? Color.unbound.accent : Color.clear, lineWidth: 1.5)
                )
        )
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodegen generate && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build 2>&1 | tail -10
```

- [ ] **Step 3: Commit**

```bash
git add UNBOUND/UNBOUND/Views/Components/Unbound/UmbrellaSelectList.swift
git commit -m "feat(ui): UmbrellaSelectList — generic select-all with cascade"
```

### Task 7.2: Apply to muscle group picker (Step13 or wherever)

**Files:**
- Discover via grep + modify

- [ ] **Step 1: Find the muscle group picker**

```bash
grep -rn "Chest\|Glutes" UNBOUND/UNBOUND/Views/Onboarding/ --include="*.swift"
```

- [ ] **Step 2: Replace the current multi-select list with `UmbrellaSelectList`**

Umbrella option: `Full body` (was at 08, now position 01). Sub-options: Chest, Back, Shoulders, Arms, Core, Legs, Glutes.

- [ ] **Step 3: Build + simulator — navigate to muscle picker**

- [ ] **Step 4: Commit**

```bash
git add UNBOUND/UNBOUND/Views/Onboarding/Steps/
git commit -m "feat(onboarding): muscle picker — umbrella select-all + Full body at top"
```

### Task 7.3: Apply to equipment picker (`Step14_Equipment`)

**Files:**
- Modify: `UNBOUND/UNBOUND/Views/Onboarding/Steps/Step14_Equipment.swift`

- [ ] **Step 1: Read the current picker**

```bash
cat UNBOUND/UNBOUND/Views/Onboarding/Steps/Step14_Equipment.swift
```

- [ ] **Step 2: Replace current `HUDMultiSelectGroup` with `UmbrellaSelectList`**

Umbrella: `Full gym` (already at 01). Sub-options: Cables/machines, Barbell + rack, Dumbbells, Bench, Pull-up bar (and any others currently there).

- [ ] **Step 3: Build + simulator**

- [ ] **Step 4: Commit**

```bash
git add UNBOUND/UNBOUND/Views/Onboarding/Steps/Step14_Equipment.swift
git commit -m "feat(onboarding): equipment picker — umbrella select-all via UmbrellaSelectList"
```

### 🛑 Review Gate — End of Phase 7

Show simulator. Test select-all cascade (tap Full body/Full gym, watch checks fill top-to-bottom). Test auto-demote (tap a sub, umbrella deselects). Test auto-promote (manually select all subs, umbrella fills). Get approval.

---

## Phase 8 — Icon Audit + Final Polish

### Task 8.1: Audit and replace unclear muscle group icons

Per spec: Back (two figures) and Shoulders (runner) don't read. Plus audit Core, Legs, Glutes for muscle specificity.

**Files:**
- Modify: wherever muscle group → icon mapping lives (probably in the muscle picker view or a dedicated helper)

- [ ] **Step 1: Find the mapping**

```bash
grep -rn "\"figure\\.\\|chest\\|back\\|shoulder" UNBOUND/UNBOUND/Views/Onboarding/ --include="*.swift"
```

- [ ] **Step 2: Replace with clearer SF Symbols**

Suggested mapping (verify availability):
- Chest — `figure.strengthtraining.functional` or `heart.fill` (no great SF Symbol, may need custom)
- Back — `figure.mind.and.body` (poor) — consider custom SVG
- Shoulders — `figure.arms.open` (poor) — consider custom SVG
- Arms — `dumbbell.fill`
- Core — `figure.core.training`
- Legs — `figure.walk.motion`
- Glutes — `figure.step.training`

> If SF Symbols don't cut it, create custom icon assets in `Resources/Icons/` and reference by asset name. Flag this to user before committing.

- [ ] **Step 3: Build + simulator**

- [ ] **Step 4: Commit**

```bash
git add UNBOUND/UNBOUND/Views/Onboarding/Steps/ UNBOUND/Resources/Icons/
git commit -m "fix(ui): muscle group icons — clearer glyphs for Back/Shoulders/Core/Legs/Glutes"
```

### Task 8.2: Full onboarding walkthrough

- [ ] **Step 1: Fresh simulator run**

Delete app from simulator. Launch fresh. Walk through the entire onboarding without using DEV·SKIP, noting any remaining:
- Stale "build" tagline references
- Squished shapes
- Jittery animations
- Dead space
- Missing ember continuity

- [ ] **Step 2: Fix any regressions found**

- [ ] **Step 3: Commit final polish**

```bash
git commit -am "polish(onboarding): final walkthrough fixes"
```

### 🛑 Final Review Gate

Walk user through full onboarding on simulator. Confirm ember thread is coherent end-to-end. Ship-ready.

---

## Self-Review

**Spec coverage check:**
- ✅ Narrative frame + cringe rules — enforced at model level by stripping `characterTagline` (Task 1.5); not a code task beyond copy edits.
- ✅ Ember thread — Task 1.1 (`EmberView`), Task 1.4 (`SilhouetteView` integration), Task 4.1 (chapter ignition), Task 5.2 (`EmberRuneIcon`).
- ✅ Screen 1 baseline — Phase 2.
- ✅ Screen 2 carousel + 6 stats — Phase 3 (Tasks 3.1, 3.2); stats expansion Task 1.2/1.3.
- ✅ Screen 3 hexagon fix + ember rune — Phase 5 (Tasks 5.1, 5.2).
- ✅ Screen 4 chapter animation — Phase 4.
- ✅ Archetype picker — Phase 6.
- ✅ UmbrellaSelectList — Phase 7 (Tasks 7.1, 7.2, 7.3).
- ✅ Icon audit — Task 8.1.
- ✅ Art assets — Phase 0.

**Placeholder scan:** No TBDs. Each task has concrete code or concrete discovery commands.

**Type consistency:** `EmberView.State`, `OnboardingStat`, `Rank`, `BaselineStats`, `BodyAsset.neutralSealed`, `Archetype.bodyAsset` (or equivalent) — all referenced consistently across tasks. `BodyAsset` cases per Task 1.4 must align with Task 3.1's switch statement (vTaper, heavyweight, shredded, sleeper) — flagged as verify step.

**Known ambiguity (tracked in spec):** Screen 2 carousel + stats sync behavior. Defaulted to "stats pinned to user archetype" in Task 3.2; revisit on first simulator run if it feels wrong.
