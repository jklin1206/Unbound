# The Crossing — Rank-Up Cinematic + Asset Lane Implementation Plan (Plan 3 of 4)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build *The Crossing* rank-up cinematic (replaces the static RankUpCinematic for overall-rank gate crossings), its asset resolver with graceful fallback, and the jlin-curated art-generation lane — all **build-alongside** (reachable via the demo harness; live cutover + video-clip wiring are Plan 4).

**Architecture:** A 5-beat full-screen cinematic (hush → walk → arrival → investiture → spoils, spec §8) tiered by destination rank. It renders on the **best-available threshold still** resolved per gate (bespoke `gate_threshold_<token>` if present, else the existing `profile_banner_<token>`), with a Ken Burns push-in + native SwiftUI particles — which is also the spec's canonical reduced-motion/offline fallback, so it is fully functional today with zero generated assets. The video-clip "walk" (Seedance i2v) is a documented seam activated in Plan 4 once jlin's curated art lane produces clips. Every color derives from the `RankTier` token system (single source); every design and asset passes a **Color Design Check** (the `pixel-council` skill).

**Tech Stack:** Swift / SwiftUI / XCTest, xcodegen. Reuses Plan 2's `GateWorld`/`GateWorldCatalog`/`GateCardView`. Codex `image_gen` for stills (zero credits); Higgsfield/Seedance for i2v (jlin-curated).

**Branch:** `claude/rank-gates-engine` (continues the engine+spine branch). **Worktree:** `/Users/jlin/Documents/toji/UNBOUND-agent-a` (Lane A: sim iPhone 17, DerivedData `/private/tmp/unbound-dd-a`).

---

## The Color Design Check (applies to every view + asset task below)

Before any new view or asset is marked done, run it through the `pixel-council` skill (Apple-HIG / blended flavor; UNBOUND is dark-only, true-black `#050505`) and confirm:
1. **Tokens only, zero ad-hoc hex** — colors come from `Color.unbound.*` or `RankTier.rewardTint` (fills) / `rewardTextTint` (text+icons) / `rewardGlowColors` (multi-stop for unbound/ascendant). No raw `Color(red:…)`/hex in a view.
2. **AA contrast** on true-black and over the banner gradient — `rewardTextTint` for text/icons, `rewardTint` for fills/sigils.
3. **Per-rank palette fidelity** — views anchor to `RankTier` tokens; generated art anchors to spec §3's rank↔hex table and stays anime-JRPG (never photoreal, [[banner-art-is-anime-jrpg]]).
4. **Reduced-motion + dark-mode** respected (dark is primary).
5. **Screenshot-read** the rendered result and eyeball it ([[ui-claims-need-onsim-screenshot]]).

Reference: `memory/every-design-color-checked.md`.

---

## File Structure

All new code under `UNBOUND/Views/Gates/Crossing/`:

- `CrossingTier.swift` — `enum CrossingTier { short, full, finale }` + timing constants, derived from destination-rank order. One responsibility: the cadence of the cinematic.
- `GateCrossing.swift` — config struct: wraps a `GateWorld`, adds Crossing copy (dwell line) + tier + asset seeds + computed investiture title. Color derives from the wrapped world.
- `GateCrossingCatalog.swift` — `GateCrossingCatalog.crossing(for: RankTrialFormat)`, 8 entries.
- `CrossingAssetResolver.swift` — resolves the best-available threshold still (`gate_threshold_<token>` → `profile_banner_<token>`); exposes `hasBespokeArt`. No video in Plan 3 (Plan 4 seam documented inline).
- `CrossingParticles.swift` — native SwiftUI particle layer (ember / gold / spark), color-keyed to the rank tint; reduced-motion static-glow fallback.
- `TheCrossingView.swift` — the 5-beat cinematic; reuses `GateCardView` (Plan 2) in the spoils beat; replayable; reduced-motion fallback.

Tests under `UNBOUNDTests/Views/Gates/Crossing/`:
- `GateCrossingCatalogTests.swift`, `CrossingAssetResolverTests.swift`.

Modified:
- `UNBOUND/Views/Gates/GateExperienceDemoView.swift` — add a `crossing` stage + wire the verdict's `onMintedCardTapped` hook to present `TheCrossingView`.
- `UNBOUND/App/UnboundApp.swift` — `-rankCrossingDemo` / `UNBOUND_OPEN_CROSSING=<1-8>` branch (optional; the demo also reaches the Crossing from the verdict stage's minted-card tap).

Docs:
- `docs/rank-gates-art-lane.md` — the jlin-curated generation pipeline (per-gate Codex `image_gen` still briefs + Higgsfield/Seedance i2v briefs + the Color Design Check gate + HEVC/catalog steps).
- `docs/HANDOFF-rank-gates-crossing.md` — Plan 3 handoff.

---

## Task 1: CrossingTier

**Files:**
- Create: `UNBOUND/Views/Gates/Crossing/CrossingTier.swift`

- [ ] **Step 1: Write the file**

```swift
import Foundation

/// The cadence of The Crossing, tiered by how far into the journey the gate is
/// (spec §8). `short` = gates I–IV (~7s), `full` = V–VII (~15s), `finale` = VIII
/// (flashback montage of all eight stamped gate cards → the gold flood).
enum CrossingTier: Equatable, Sendable {
    case short
    case full
    case finale

    /// Derive from the destination rank's gate order (1…8).
    static func forOrder(_ order: Int) -> CrossingTier {
        switch order {
        case ...4: return .short
        case 5...7: return .full
        default: return .finale
        }
    }

    /// Beat durations in seconds: (hush, walk, arrival, investiture).
    /// The spoils beat holds until dismissed. `finale` adds a montage budget.
    var beats: (hush: Double, walk: Double, arrival: Double, investiture: Double) {
        switch self {
        case .short:  return (0.6, 2.2, 1.4, 1.6)
        case .full:   return (0.9, 5.0, 3.0, 2.6)
        case .finale: return (0.9, 3.0, 2.4, 2.6) // walk = the 8-card flashback montage
        }
    }

    /// Per-card dwell time for the finale flashback montage (8 cards).
    var montageCardInterval: Double { 0.34 }
}
```

- [ ] **Step 2: Verify it compiles in the next build (no standalone test — exercised by Task 2's tests).**

- [ ] **Step 3: Commit**

```bash
cd /Users/jlin/Documents/toji/UNBOUND-agent-a
git add UNBOUND/Views/Gates/Crossing/CrossingTier.swift
git commit -m "feat(crossing): CrossingTier cadence (short/full/finale)"
```

---

## Task 2: GateCrossing + GateCrossingCatalog (TDD)

**Files:**
- Create: `UNBOUND/Views/Gates/Crossing/GateCrossing.swift`
- Create: `UNBOUND/Views/Gates/Crossing/GateCrossingCatalog.swift`
- Test: `UNBOUNDTests/Views/Gates/Crossing/GateCrossingCatalogTests.swift`

- [ ] **Step 1: Write `GateCrossing.swift`**

```swift
import SwiftUI

/// Config for one gate's Crossing cinematic. Wraps the Plan-2 `GateWorld` (single
/// source for numeral, tint, banner, destination rank) and adds the Crossing-only
/// pieces: tier cadence + the dwell line. Investiture title derives from the rank.
struct GateCrossing: Identifiable, Equatable, Sendable {
    let world: GateWorld
    /// One brand-safe, non-negging line for the arrival/dwell beat ("You live here now.").
    let dwellLine: String

    var id: RankTrialFormat { world.format }
    var tier: CrossingTier { CrossingTier.forOrder(world.order) }

    /// "FORGED." — the rank, spoken as arrival.
    var investitureTitle: String { world.destinationRank.displayName.uppercased() + "." }

    /// Color surface — all derive from the destination rank (Color Design Check §1).
    var tint: Color { world.tint }          // foreground-safe (rewardTextTint)
    var fillTint: Color { world.fillTint }   // saturated fill (rewardTint)
    var glowColors: [Color] { world.destinationRank.rewardGlowColors }

    /// Banner-cosmetic unlock chip copy for the spoils beat.
    var unlockChip: String { "\(world.destinationRank.displayName.uppercased()) BANNER UNLOCKED" }
}
```

- [ ] **Step 2: Write `GateCrossingCatalog.swift`**

```swift
import Foundation

/// One `GateCrossing` per gate. Reads `GateWorldCatalog` (Plan 2) for the world,
/// adds the Crossing dwell line. Copy is brand-safe and non-negging (world
/// language, never "limiter/weak link"; CLAUDE.md Brand Language Guardrail).
enum GateCrossingCatalog {
    static func crossing(for format: RankTrialFormat) -> GateCrossing {
        let world = GateWorldCatalog.world(for: format)
        return GateCrossing(world: world, dwellLine: dwellLine(for: format))
    }

    static var all: [GateCrossing] { RankTrialFormat.allCases.map { crossing(for: $0) } }

    private static func dwellLine(for format: RankTrialFormat) -> String {
        switch format {
        case .firstLight:  return "The courtyard is yours now."
        case .theCount:    return "You move with the bell now."
        case .theForging:  return "You were made in the fire."
        case .deckOfProof: return "You cleared the whole deck."
        case .theAscent:   return "You stand above the clouds."
        case .sevenSeals:  return "Every part of you is sealed."
        case .theThreshold:return "You held the line. The way is open."
        case .theLastGate: return "Nothing holds you now."
        }
    }
}
```

- [ ] **Step 3: Write the failing test `GateCrossingCatalogTests.swift`**

```swift
import XCTest
@testable import UNBOUND

final class GateCrossingCatalogTests: XCTestCase {

    func test_everyFormatHasACrossing() {
        for format in RankTrialFormat.allCases {
            let c = GateCrossingCatalog.crossing(for: format)
            XCTAssertEqual(c.id, format)
            XCTAssertFalse(c.dwellLine.isEmpty, "\(format) missing dwell line")
        }
        XCTAssertEqual(GateCrossingCatalog.all.count, 8)
    }

    func test_tierLaddersWithGateOrder() {
        XCTAssertEqual(GateCrossingCatalog.crossing(for: .firstLight).tier, .short)
        XCTAssertEqual(GateCrossingCatalog.crossing(for: .deckOfProof).tier, .short)   // order 4
        XCTAssertEqual(GateCrossingCatalog.crossing(for: .theAscent).tier, .full)      // order 5
        XCTAssertEqual(GateCrossingCatalog.crossing(for: .theThreshold).tier, .full)   // order 7
        XCTAssertEqual(GateCrossingCatalog.crossing(for: .theLastGate).tier, .finale)  // order 8
    }

    func test_investitureTitleIsDestinationRank() {
        XCTAssertEqual(GateCrossingCatalog.crossing(for: .theForging).investitureTitle, "FORGED.")
        XCTAssertEqual(GateCrossingCatalog.crossing(for: .theLastGate).investitureTitle, "UNBOUND.")
    }

    func test_copyIsBrandSafe() {
        let banned = ["limiter", "weak link", "holding you back", "emom", "amrap", "wod", "metcon"]
        for c in GateCrossingCatalog.all {
            let lower = (c.dwellLine + " " + c.unlockChip + " " + c.investitureTitle).lowercased()
            for word in banned {
                XCTAssertFalse(lower.contains(word), "\(c.id) copy contains banned term '\(word)'")
            }
        }
    }
}
```

- [ ] **Step 4: Generate the project + run the test**

```bash
cd /Users/jlin/Documents/toji/UNBOUND-agent-a && xcodegen generate
set -o pipefail
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath /private/tmp/unbound-dd-a \
  -only-testing:UNBOUNDTests/GateCrossingCatalogTests 2>&1 | grep -E "Test Suite|passed|failed|error:"
```
Expected: 4 tests pass.

- [ ] **Step 5: Color Design Check** — `GateCrossing.tint/fillTint/glowColors` all route through `GateWorld`/`RankTier` (no literals). Confirm by reading the file. ✓ tokens only.

- [ ] **Step 6: Commit**

```bash
git add UNBOUND/Views/Gates/Crossing/GateCrossing.swift UNBOUND/Views/Gates/Crossing/GateCrossingCatalog.swift UNBOUNDTests/Views/Gates/Crossing/GateCrossingCatalogTests.swift
git commit -m "feat(crossing): GateCrossing config + catalog (8 gates, brand-safe)"
```

---

## Task 3: CrossingAssetResolver (TDD)

**Files:**
- Create: `UNBOUND/Views/Gates/Crossing/CrossingAssetResolver.swift`
- Test: `UNBOUNDTests/Views/Gates/Crossing/CrossingAssetResolverTests.swift`

- [ ] **Step 1: Write `CrossingAssetResolver.swift`**

```swift
import SwiftUI

/// Resolves the best-available threshold still for a gate's Crossing, with
/// graceful fallback (spec §8: "missing assets → animated still on the banner").
///
/// Plan 3 ships on stills only. When jlin's curated art lane (docs/rank-gates-art-lane.md)
/// drops `gate_threshold_<token>` imagesets into the catalog, this resolver picks
/// them up automatically — no code change. Video clips (Seedance i2v "walk") are a
/// Plan-4 seam: they land as `gate_crossing_<token>` and a `.clip` case is added here.
enum CrossingAssetResolver {

    /// Asset name of the still to render under The Crossing.
    static func thresholdStill(for crossing: GateCrossing) -> String {
        let bespoke = bespokeStillName(for: crossing)
        return imageExists(bespoke) ? bespoke : crossing.world.bannerAssetName
    }

    /// True when a bespoke threshold painting exists (vs. falling back to the rank banner).
    static func hasBespokeArt(for crossing: GateCrossing) -> Bool {
        imageExists(bespokeStillName(for: crossing))
    }

    static func bespokeStillName(for crossing: GateCrossing) -> String {
        "gate_threshold_\(crossing.world.destinationRank.token)"
    }

    private static func imageExists(_ name: String) -> Bool {
        UIImage(named: name) != nil
    }
}
```

- [ ] **Step 2: Write the test `CrossingAssetResolverTests.swift`**

```swift
import XCTest
import UIKit
@testable import UNBOUND

final class CrossingAssetResolverTests: XCTestCase {

    func test_fallsBackToRankBannerWhenNoBespokeArt() {
        // Plan 3: no gate_threshold_* assets shipped yet → resolver returns the rank banner.
        for c in GateCrossingCatalog.all {
            let still = CrossingAssetResolver.thresholdStill(for: c)
            XCTAssertEqual(still, c.world.bannerAssetName,
                           "\(c.id) should fall back to the rank banner until bespoke art lands")
            XCTAssertNotNil(UIImage(named: still), "fallback banner \(still) must exist in the catalog")
            XCTAssertFalse(CrossingAssetResolver.hasBespokeArt(for: c))
        }
    }

    func test_bespokeNameFollowsRankToken() {
        let forge = GateCrossingCatalog.crossing(for: .theForging)
        XCTAssertEqual(CrossingAssetResolver.bespokeStillName(for: forge), "gate_threshold_forged")
    }
}
```

- [ ] **Step 3: Run the test**

```bash
cd /Users/jlin/Documents/toji/UNBOUND-agent-a && xcodegen generate
set -o pipefail
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath /private/tmp/unbound-dd-a \
  -only-testing:UNBOUNDTests/CrossingAssetResolverTests 2>&1 | grep -E "Test Suite|passed|failed|error:"
```
Expected: 2 tests pass (the fallback banners are the shipped `profile_banner_<token>`).

- [ ] **Step 4: Commit**

```bash
git add UNBOUND/Views/Gates/Crossing/CrossingAssetResolver.swift UNBOUNDTests/Views/Gates/Crossing/CrossingAssetResolverTests.swift
git commit -m "feat(crossing): asset resolver with rank-banner fallback (bespoke art auto-pickup)"
```

---

## Task 4: CrossingParticles (native FX, color-keyed)

**Files:**
- Create: `UNBOUND/Views/Gates/Crossing/CrossingParticles.swift`

- [ ] **Step 1: Write the file**

```swift
import SwiftUI

/// Native SwiftUI particle layer for the investiture/arrival beats (spec §9:
/// "minor beats = native SwiftUI particles"). Color-keyed to the destination
/// rank tint — never a hardcoded color (Color Design Check §1). Reduced-motion
/// renders a single static glow instead of moving particles.
struct CrossingParticles: View {
    let tint: Color
    var reduceMotion: Bool = false
    var particleCount: Int = 28

    var body: some View {
        if reduceMotion {
            RadialGradient(colors: [tint.opacity(0.35), .clear],
                           center: .center, startRadius: 10, endRadius: 280)
                .blendMode(.screen)
                .ignoresSafeArea()
        } else {
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    for i in 0..<particleCount {
                        let seed = Double(i)
                        let phase = (t * 0.35 + seed * 0.137).truncatingRemainder(dividingBy: 1)
                        let x = size.width * (0.5 + 0.42 * sin(seed * 2.4))
                        let y = size.height * (1.0 - phase) - 20
                        let radius = 2.0 + 3.0 * (1 - phase)
                        let opacity = max(0, sin(phase * .pi)) * 0.7
                        let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                        context.fill(Path(ellipseIn: rect), with: .color(tint.opacity(opacity)))
                    }
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }
}
```

- [ ] **Step 2: Color Design Check** — the layer takes `tint: Color` and uses only that + `.clear`. Callers pass `crossing.tint`/`fillTint` (rank tokens). ✓ no literals.

- [ ] **Step 3: Commit**

```bash
git add UNBOUND/Views/Gates/Crossing/CrossingParticles.swift
git commit -m "feat(crossing): native rank-tinted particle layer (reduced-motion safe)"
```

---

## Task 5: TheCrossingView (the 5-beat cinematic)

**Files:**
- Create: `UNBOUND/Views/Gates/Crossing/TheCrossingView.swift`

Beats (spec §8): **hush** (black, one breath) → **walk** (Ken Burns push-in through the threshold still; finale = 8-card flashback montage) → **arrival** (settles on the still, dwell line) → **investiture** (rank sigil + particles, investiture title types/fades in) → **spoils** (banner-unlock chip + minted GateCardView + share). Replayable; reduced-motion = crossfades, no Ken Burns, static glow.

- [ ] **Step 1: Write the file**

```swift
import SwiftUI

/// The Crossing — the rank-up cinematic for an overall-rank gate (spec §8).
/// Replaces the static RankUpCinematic for gate crossings. Build-alongside in
/// Plan 3: reachable via the demo harness + the verdict's minted-card tap; the
/// live cutover (presenting on a real gate pass) is Plan 4.
///
/// Runs on the resolved threshold still (CrossingAssetResolver) with a Ken Burns
/// push-in + native particles — also the spec's reduced-motion/offline fallback,
/// so it is fully functional with zero generated assets. The Seedance i2v clip
/// "walk" is a Plan-4 seam.
struct TheCrossingView: View {
    let crossing: GateCrossing
    var dateText: String? = nil
    var definingNumber: String? = nil
    var onShare: (() -> Void)? = nil
    var onReplay: (() -> Void)? = nil
    var onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Beat { case hush, walk, arrival, investiture, spoils }
    @State private var beat: Beat = .hush
    @State private var kenBurns = false
    @State private var titleShown = false
    @State private var montageIndex = 0

    private var still: String { CrossingAssetResolver.thresholdStill(for: crossing) }
    private var b: (hush: Double, walk: Double, arrival: Double, investiture: Double) { crossing.tier.beats }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if beat != .hush {
                if crossing.tier == .finale && beat == .walk {
                    montageLayer
                } else {
                    stillLayer
                }
            }

            if beat == .investiture || beat == .spoils {
                CrossingParticles(tint: crossing.tint, reduceMotion: reduceMotion)
            }

            content
        }
        .contentShape(Rectangle())
        .onTapGesture { if beat == .spoils { onDismiss() } }
        .task { await run() }
        .accessibilityIdentifier("the-crossing")
    }

    // MARK: Layers

    private var stillLayer: some View {
        Image(still).resizable().scaledToFill()
            .scaleEffect(reduceMotion ? 1.0 : (kenBurns ? 1.15 : 1.0))
            .ignoresSafeArea()
            .clipped()
            .overlay(LinearGradient(colors: [.clear, Color.black.opacity(0.55), Color.black.opacity(0.9)],
                                    startPoint: .top, endPoint: .bottom).ignoresSafeArea())
            .overlay(RadialGradient(colors: [crossing.tint.opacity(beat == .arrival ? 0.28 : 0.12), .clear],
                                    center: .center, startRadius: 30, endRadius: 320)
                        .blendMode(.screen).ignoresSafeArea())
    }

    /// Finale: flash through all eight stamped gate cards, then the gold flood.
    private var montageLayer: some View {
        let cards = GateWorldCatalog.allOrdered
        return ZStack {
            Color.black.ignoresSafeArea()
            if montageIndex < cards.count {
                GateCardView(world: cards[montageIndex], dateText: nil,
                             definingNumber: cards[montageIndex].numeral, stamped: true)
                    .padding(.horizontal, 36)
                    .transition(.opacity)
                    .id(montageIndex)
            }
        }
    }

    private var content: some View {
        VStack(spacing: 16) {
            Spacer()

            if beat == .arrival || beat == .investiture || beat == .spoils {
                Text("RANK GATE \(crossing.world.numeral)")
                    .font(Font.unbound.captionS.weight(.heavy)).tracking(3)
                    .foregroundStyle(crossing.tint)
            }

            if (beat == .investiture || beat == .spoils) && titleShown {
                Text(crossing.investitureTitle)
                    .font(.system(size: 52, weight: .black)).tracking(2)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .minimumScaleFactor(0.5).lineLimit(1)
                    .shadow(color: crossing.fillTint.opacity(0.6), radius: 24)
                    .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
            }

            if beat == .arrival || beat == .investiture {
                Text(crossing.dwellLine)
                    .font(Font.unbound.titleS).foregroundStyle(Color.unbound.textSecondary)
                    .multilineTextAlignment(.center).transition(.opacity)
            }

            Spacer()

            if beat == .spoils { spoils.transition(.opacity) }
        }
        .padding(.horizontal, 24).padding(.bottom, 40)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var spoils: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                Text(crossing.unlockChip).font(Font.unbound.captionS.weight(.heavy)).tracking(1.4)
            }
            .foregroundStyle(crossing.tint)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Capsule().fill(Color.unbound.surface))

            GateCardView(world: crossing.world, dateText: dateText,
                         definingNumber: definingNumber, stamped: true)
                .frame(maxWidth: 360)

            HStack(spacing: 12) {
                if let onReplay {
                    Button { onReplay(); Task { await run() } } label: {
                        Label("REPLAY", systemImage: "arrow.counterclockwise")
                            .font(Font.unbound.captionS.weight(.bold)).tracking(1)
                            .foregroundStyle(Color.unbound.textSecondary)
                    }.buttonStyle(.plain)
                }
                Button { onShare?() } label: {
                    Label("SHARE", systemImage: "square.and.arrow.up")
                        .font(Font.unbound.captionS.weight(.heavy)).tracking(1)
                        .foregroundStyle(Color.unbound.bg)
                        .padding(.horizontal, 18).padding(.vertical, 10)
                        .background(Capsule().fill(crossing.fillTint))
                }.buttonStyle(.plain)
                .accessibilityIdentifier("crossing-share")
            }
        }
    }

    // MARK: Beat timeline

    @MainActor private func run() async {
        beat = .hush; kenBurns = false; titleShown = false; montageIndex = 0
        UnboundHaptics.soft()
        await sleep(b.hush)

        withAnimation(.easeOut(duration: 0.4)) { beat = .walk }
        if crossing.tier == .finale {
            await runMontage()
        } else if !reduceMotion {
            withAnimation(.easeOut(duration: b.walk)) { kenBurns = true }
            await sleep(b.walk)
        } else {
            await sleep(b.walk * 0.5)
        }

        withAnimation(.easeInOut(duration: 0.5)) { beat = .arrival }
        UnboundHaptics.medium()
        await sleep(b.arrival)

        withAnimation(.easeOut(duration: 0.4)) { beat = .investiture }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.15)) { titleShown = true }
        UnboundHaptics.heavy()
        await sleep(b.investiture)

        withAnimation(.easeInOut(duration: 0.5)) { beat = .spoils }
        UnboundHaptics.success()
    }

    @MainActor private func runMontage() async {
        for i in 0..<GateWorldCatalog.allOrdered.count {
            withAnimation(.easeInOut(duration: 0.18)) { montageIndex = i }
            if i % 2 == 0 { UnboundHaptics.soft() }
            await sleep(crossing.tier.montageCardInterval)
        }
    }

    private func sleep(_ seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
    }
}
```

- [ ] **Step 2: Add `GateWorldCatalog.allOrdered`** (needed by the finale montage). Edit `UNBOUND/Views/Gates/GateWorlds/GateWorldCatalog.swift`, add inside the enum:

```swift
    /// All eight worlds in gate order (I…VIII) — used by the finale flashback montage.
    static var allOrdered: [GateWorld] {
        RankTrialFormat.allCases.map { world(for: $0) }.sorted { $0.order < $1.order }
    }
```

- [ ] **Step 3: Build (sim)**

```bash
cd /Users/jlin/Documents/toji/UNBOUND-agent-a && xcodegen generate
set -o pipefail
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath /private/tmp/unbound-dd-a 2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:"
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Color Design Check** — read `TheCrossingView.swift`: every color is `Color.unbound.*`, `crossing.tint`, or `crossing.fillTint`. The one literal allowed is `Color.black`/`.clear` for the cinematic letterbox (true-black is the design system bg). Confirm no `Color(red:…)` / hex. ✓

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Views/Gates/Crossing/TheCrossingView.swift UNBOUND/Views/Gates/GateWorlds/GateWorldCatalog.swift
git commit -m "feat(crossing): TheCrossingView — 5-beat cinematic (Ken Burns + finale montage)"
```

---

## Task 6: Demo harness + verdict hook

**Files:**
- Modify: `UNBOUND/Views/Gates/GateExperienceDemoView.swift`
- Modify: `UNBOUND/App/UnboundApp.swift`

- [ ] **Step 1: Add a `crossing` stage to the demo's `Stage` enum** (in `GateExperienceDemoView.swift`):

```swift
        case sealed, open, hall, active, beat, verdictPass, card, verdictFail, records, crossing
```

- [ ] **Step 2: Render it in `stageContent`** (add a case):

```swift
        case .crossing:
            TheCrossingView(crossing: GateCrossingCatalog.crossing(for: format),
                            dateText: "Jun 13, 2026",
                            definingNumber: "\(resolvedStations.count)/\(resolvedStations.count)",
                            onShare: {}, onReplay: {}, onDismiss: {})
```

- [ ] **Step 3: Wire the verdict's Crossing hook** — change the `.verdictPass` case to present the Crossing on minted-card tap. Replace:

```swift
        case .verdictPass:
            GateVerdictView(evaluation: fixtureEvaluation(passed: true), world: world)
```
with:
```swift
        case .verdictPass:
            GateVerdictView(evaluation: fixtureEvaluation(passed: true), world: world,
                            onMintedCardTapped: { showCrossing = true })
                .fullScreenCover(isPresented: $showCrossing) {
                    TheCrossingView(crossing: GateCrossingCatalog.crossing(for: format),
                                    dateText: "Jun 13, 2026",
                                    definingNumber: "\(resolvedStations.count)/\(resolvedStations.count)",
                                    onShare: {}, onReplay: {}, onDismiss: { showCrossing = false })
                }
```
and add the state near the other `@State`:
```swift
    @State private var showCrossing = false
```
(If `GateVerdictView` does not yet accept `onMintedCardTapped`, confirm its signature — Plan 2 created it as the Crossing hook; pass the closure it exposes.)

- [ ] **Step 4: Add the launch-arg branch in `UnboundApp.swift`** (after the existing `-gateExperienceDemo` branch):

```swift
            } else if ProcessInfo.processInfo.arguments.contains("-rankCrossingDemo")
                || ProcessInfo.processInfo.environment["UNBOUND_OPEN_CROSSING"] != nil {
                GateCrossingDemoView()
```
And add a tiny `GateCrossingDemoView` to `GateExperienceDemoView.swift` (under `#if DEBUG`) that reads `UNBOUND_OPEN_CROSSING=<1-8>` and presents `TheCrossingView` full-screen for that gate, OR reuse `GateExperienceDemoView` initialized to `.crossing` (simpler — set initial stage to `.crossing` when `UNBOUND_OPEN_CROSSING` is set). Prefer reuse: extend `initialStage()` to honor `UNBOUND_OPEN_CROSSING` → `.crossing` and `initialFormat()` to read it.

- [ ] **Step 5: Build + screenshot every gate's Crossing**

```bash
cd /Users/jlin/Documents/toji/UNBOUND-agent-a && xcodegen generate
set -o pipefail
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath /private/tmp/unbound-dd-a 2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:"
# install + launch per gate (example: Forged = gate 3), capture each beat by re-launching
APP=$(find /private/tmp/unbound-dd-a -name "UNBOUND.app" -path "*Debug-iphonesimulator*" | head -1)
xcrun simctl install booted "$APP"
for g in 1 3 6 8; do
  SIMCTL_CHILD_UNBOUND_OPEN_CROSSING=$g xcrun simctl launch booted com.unboundapp.ios
  sleep 4   # let the beats run to spoils
  xcrun simctl io booted screenshot /private/tmp/unbound-dd-a/crossing_gate_$g.png
  xcrun simctl terminate booted com.unboundapp.ios
done
```

- [ ] **Step 6: Read each screenshot** (`Read` the PNGs). Verify per gate: correct banner, rank tint on numeral + sigil + share button, investiture title = rank name, dwell line legible, minted card stamped, no clipping. Re-launch + screenshot mid-beat for the walk/investiture if needed.

- [ ] **Step 7: Color Design Check** on the rendered screenshots — tint matches the destination rank (Forged ember, Vessel violet, Unbound gold), AA-legible on the darkened still. ✓

- [ ] **Step 8: Commit**

```bash
git add UNBOUND/Views/Gates/GateExperienceDemoView.swift UNBOUND/App/UnboundApp.swift
git commit -m "feat(crossing): demo stage + -rankCrossingDemo launch arg + verdict→Crossing hook"
```

---

## Task 7: Device-arch build + full suite gate

- [ ] **Step 1: Device-arch build** ([[device-arch-build-is-the-real-gate]])

```bash
cd /Users/jlin/Documents/toji/UNBOUND-agent-a
set -o pipefail
xcodebuild build -scheme UNBOUND -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO \
  -derivedDataPath /private/tmp/unbound-dd-a 2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:"
```
Expected: BUILD SUCCEEDED (watch for SwiftUI metadata cliff on `TheCrossingView` body — if it appears, AnyView-wrap the `montageLayer`/`spoils` children).

- [ ] **Step 2: Full suite** — confirm the 6 new Crossing tests pass and the only failures are the 3 documented pre-existing groups (18 assertions), zero new regressions.

```bash
set -o pipefail
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath /private/tmp/unbound-dd-a 2>&1 | grep -E "Test Suite 'All|passed|failed|error:" | tail -40
```

- [ ] **Step 3: Commit** (only if a metadata-cliff AnyView wrap was needed)

```bash
git add UNBOUND/Views/Gates/Crossing/TheCrossingView.swift
git commit -m "fix(crossing): AnyView-wrap heavy beats to cap device metadata depth"
```

---

## Task 8: The art-generation lane doc (jlin-curated)

**Files:**
- Create: `docs/rank-gates-art-lane.md`

- [ ] **Step 1: Write the doc** with these sections:

  - **Principle:** Stills via Codex `image_gen` (zero credits, [[codex-image-gen-pipeline]]); i2v loops + Crossing clips via Higgsfield/Seedance (credits, jlin-curated, [[scout-aesthetic-before-gen]]). I do NOT run this lane autonomously — jlin curates per gate; the resolver auto-picks up `gate_threshold_<token>` the moment it lands.
  - **Per-gate threshold-still briefs (×8):** a `gen_thresholds.sh`-style block mirroring `.banner-gen/gen_tiers.sh`, but **vertical-safe / full-bleed** composition (the Crossing/header still is portrait, not the banner's 16:9-with-left-deadspace). Each brief: world description from spec §5, the single accent color = spec §3 rank hex, anime-JRPG, "the threshold/gate INTO the world" framing, no text/people/UI. Style-lock with `--image <rank>_v1.png` ([[codex-image-ref-flag]]). Output `gate_threshold_<token>.png`.
  - **i2v briefs (loops + Crossing clips):** 4–6s, end-frame matched to the rank banner composition, HEVC ~1–2MB; the "walk pushes through the threshold into the world."
  - **Color Design Check gate (mandatory, every asset):** dominant palette == destination rank hex (spec §3); anime-JRPG not photoreal; vertical-safe; legible dead space for the title stack; no baked text. Eyes-on before wiring ([[visual-qa-deck-hero-before-schedule]]).
  - **Wire-in:** drop curated PNG → trim → `Assets.xcassets/Cosmetics/gate_threshold_<token>.imageset` → resolver picks it up; clips land as `gate_crossing_<token>` for the Plan-4 AVPlayer seam. Bundling-vs-CDN = jlin infra call (spec §9), deferred.

- [ ] **Step 2: Commit**

```bash
git add docs/rank-gates-art-lane.md
git commit -m "docs(crossing): jlin-curated art-generation lane + per-gate briefs + color-check gate"
```

---

## Task 9: Handoff doc + push

**Files:**
- Create: `docs/HANDOFF-rank-gates-crossing.md`

- [ ] **Step 1: Write the handoff** (Agent Handoff format: branch, worktree, lane, summary, files changed, verification done, deferred-by-design [video-clip AVPlayer wiring, live cutover, legacy RankUpCinematic deletion → Plan 4], risks). State clearly: The Crossing ships on stills+KenBurns+particles (the spec's own fallback), the art lane is ready for jlin to drive, and every design passed the Color Design Check.

- [ ] **Step 2: Commit + push**

```bash
git add docs/HANDOFF-rank-gates-crossing.md
git commit -m "docs(crossing): plan 3 handoff"
git push origin claude/rank-gates-engine
```

---

## Self-Review (run after authoring, before executing)

- **Spec coverage:** §8 Crossing beats (hush/walk/arrival/investiture/spoils) → Task 5 ✓; tiering I–IV/V–VII/VIII → Task 1 ✓; finale montage → Task 5 ✓; replayable → Task 5 ✓; fallback (Ken Burns + particles on still) → Tasks 3–5 ✓; reduced-motion → Tasks 4–5 ✓; share card → spoils reuses GateCardView ✓; §9 art pipeline + §10 asset manager + fallback → Tasks 3, 8 ✓; "every design color-checked" (user) → check step in every view/asset task ✓.
- **Deferred-by-design (Plan 4):** video-clip `.clip` resolution + AVPlayer layer (no clips exist yet); live presentation on a real gate pass (replaces RankUpCinematic for overall ranks); legacy deletion; L10n xcstrings wrapping (literals are LocalizationTests-green, like Plan 2).
- **Type consistency:** `crossing.tier.beats` tuple labels match between Task 1 and Task 5; `GateWorldCatalog.allOrdered` added in Task 5 Step 2 before its use; `GateCardView(world:dateText:definingNumber:stamped:)` matches the Plan-2 signature.
- **Placeholder scan:** none — all steps have full code or exact commands.

## Verification summary (the done bar)
6 new unit tests green · sim build green · device-arch build green · full suite = only the 3 pre-existing failure groups (zero new regressions) · all 8 gates' Crossings screenshot-read · every view + the art lane passed the Color Design Check · branch pushed.
