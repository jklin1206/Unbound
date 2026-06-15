# Rank Gates Experience Spine — Implementation Plan (Plan 2 of 4)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the shared "experience spine" UI for the 8 destination-world rank gates — discovery card, gate hall + entry ceremony, world-stage active header over the calm logging surface, station-clear beats, pass/fail verdict, minted gate cards, and the Trial Records shelf — all reachable through a launch-arg demo harness and screenshot-verified. **No live cutover, no legacy deletion, no per-gate visualizer art, no Crossing** (those are Plans 3–4).

**Architecture:** New `UNBOUND/Views/Gates/` module. A declarative `GateWorld` config layer (one entry per `RankTrialFormat`, derives tint + destination banner + numeral + promise from the engine) feeds a set of shared, format-agnostic SwiftUI views. Pure derivation logic (card presentation, verdict accounting) lives in small `*Model` structs that are unit-tested; the views are screenshot-verified. The active view reuses the existing calm logging components (`ExerciseLogCard`) under a new world-stage header. The old mode views stay wired in the live flow until Plan 4 cuts over and deletes them; Plan 2 ships entirely behind a `--unbound-open-gate` demo harness so users never see a half-built gate.

**Tech Stack:** Swift, SwiftUI, XCTest, xcodegen project. View verification is launch-arg screenshot (see CLAUDE.md `--unbound-open-*` + simctl pattern), not snapshot tests. Logic verification is XCTest.

**Spec:** `docs/superpowers/specs/2026-06-12-rank-gates-redesign-design.md` — §6 (the shared experience spine) and §10 (technical architecture) are the source of truth. §3 is the world↔banner map.

**Engine (Plan 1, done):** `claude/rank-gates-engine`. The UI consumes: `OverallRankTrialReadiness`, `OverallRankTrialDefinition`, `OverallRankTrialEvaluation` / `OverallRankTrialStationResult`, `OverallRankTrialAttempt`, `RankTrialFormat`, `TrialLoadout`, `RankTitle` (= `RankTier`). It does **not** modify the engine.

**Lanes:** Tasks tagged `[CLAUDE]` (shared views, models, wiring — judgment) or `[CODEX-OK]` (the 7 remaining `GateWorld` configs after the exemplar lands, mechanical). Codex lanes: isolated worktree per CLAUDE.md's lane table, explicit-path staging only, every result re-verified (build + screenshot) before merge.

**Roadmap context:** Plan 1 engine (done) · **Plan 2 experience spine UI (this doc)** · Plan 3 The Crossing + asset manager + Higgsfield/Seedance art lane · Plan 4 per-gate `GateVisualizer` plugins + live cutover + legacy deletion.

---

## Task 0: Decisions checkpoint with jlin `[CLAUDE]` — BLOCKING

**Files:** none (conversation gate). Defaults below are what the plan is written against; confirm or adjust before Task 1.

- [ ] **D1 — Cutover timing (the structural fork).** *Default:* **build alongside.** Plan 2 ships the spine reachable only via `--unbound-open-gate`; the live Profile → ready → active flow keeps the 8 old mode views. Live cutover (Profile shows `NextGateCard`, `GateActiveView` replaces the per-format dispatch) **and** deletion of the old mode views land in Plan 4, after the visualizers + Crossing exist. *Alternative:* cut over + delete now (higher risk — users would see generic placeholder visualizers and no Crossing until Plan 4). The handoff (`docs/HANDOFF-rank-gates-engine.md`) assumes the default.
- [ ] **D2 — Art placeholders.** *Default:* Plan 2 uses the **existing rank banners** (`profile_banner_<token>`, spec §3 maps every gate to one) as the world backdrop everywhere a threshold still will later go. Plan 3 generates the bespoke per-gate threshold art and swaps it behind the same `GateWorld.bannerAssetName` accessor. No art generation in Plan 2.
- [ ] **D3 — Records data source.** *Default:* `TrialRecordsShelf` reads real attempts from `OverallRankTrialStore.shared.load(userId:)`; the demo harness feeds a fixture progress so screenshots show populated + empty states. No new persistence.
- [ ] **D4 — GateWorld config home.** *Default:* one `GateWorldCatalog.swift` holding all 8 lean configs (numeral/promise/element/destination/pips). Plan 4 may split per-gate when it adds visualizer overlay coordinates. Exemplar (Gate I) by Claude; remaining 7 are `[CODEX-OK]`.

---

## File Structure

**Create (all under `UNBOUND/Views/Gates/`):**
- `GateWorlds/GateWorld.swift` — `GateWorld` config struct + `GateWorldElement` enum.
- `GateWorlds/GateWorldCatalog.swift` — `GateWorldCatalog.world(for:)`, 8 entries.
- `NextGateCard.swift` — discovery card (sealed / open / cleared).
- `NextGateCardModel.swift` — pure presentation derivation (unit-tested).
- `GateHallView.swift` — entry sheet: full-bleed banner + centered JRPG title stack + stations preview + loadout pick + past attempts + BEGIN. Hosts the entry ceremony.
- `GateEntryCeremony.swift` — the line-by-line type-on of the title stack (a modifier/overlay used by `GateHallView`).
- `GateVisualizer.swift` — `GateVisualizer` protocol + `DefaultGateVisualizer` (generic tint+progress living-world layer; Plan 4 specializes per gate).
- `GateActiveHeaderView.swift` — world-stage header (banner top ~28%, bleeds into true black) holding trial name, station N/M, progress rail, the visualizer.
- `GateActiveView.swift` — header + the calm logging surface (reuses `ExerciseLogCard`); demo cards in Plan 2.
- `GateBeatOverlay.swift` — station-clear beat (world floods, one line, haptic, recedes).
- `GateVerdictView.swift` — pass + fail verdict.
- `GateVerdictModel.swift` — pure accounting derivation (unit-tested).
- `GateCardView.swift` — minted gate card (stamped / unstamped); the share card.
- `TrialRecordsShelf.swift` — Profile records shelf (all gate cards + attempt history).
- `GateExperienceDemoView.swift` — `#if DEBUG` launch-arg harness flipping through every gate × every state.

**Modify:**
- `UNBOUND/App/UnboundApp.swift` — add the `--unbound-open-gate` / `-gateExperienceDemo` launch-arg branch.
- `UNBOUND/Resources/Localizable.xcstrings` — new copy keys (edited as TEXT, never `json.dump` — [[l10n-key-needs-xcstrings-entry]]).

**Create (tests, under `UNBOUNDTests/Views/Gates/`):**
- `GateWorldCatalogTests.swift` · `NextGateCardModelTests.swift` · `GateVerdictModelTests.swift`.

---

## Task 1: `GateWorld` config + catalog `[CLAUDE]` (Gate I) / `[CODEX-OK]` (gates II–VIII)

**Files:**
- Create: `UNBOUND/Views/Gates/GateWorlds/GateWorld.swift`
- Create: `UNBOUND/Views/Gates/GateWorlds/GateWorldCatalog.swift`
- Test: `UNBOUNDTests/Views/Gates/GateWorldCatalogTests.swift`

- [ ] **Step 1: Failing test**

```swift
import XCTest
import SwiftUI
@testable import UNBOUND

final class GateWorldCatalogTests: XCTestCase {
    func testEveryFormatResolvesToAWorld() {
        for format in RankTrialFormat.allCases {
            let world = GateWorldCatalog.world(for: format)
            XCTAssertEqual(world.format, format)
            XCTAssertFalse(world.promise.isEmpty, "promise for \(format)")
            XCTAssertFalse(world.numeral.isEmpty, "numeral for \(format)")
        }
    }

    func testNumeralsAreRomanOneThroughEight() {
        let expected = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII"]
        let numerals = RankTrialFormat.allCases.map { GateWorldCatalog.world(for: $0).numeral }
        XCTAssertEqual(numerals, expected)
    }

    func testDestinationRankMatchesTheGateLadder() {
        XCTAssertEqual(GateWorldCatalog.world(for: .firstLight).destinationRank, .novice)
        XCTAssertEqual(GateWorldCatalog.world(for: .theForging).destinationRank, .forged)
        XCTAssertEqual(GateWorldCatalog.world(for: .theLastGate).destinationRank, .unbound)
    }

    func testBannerAssetsAllExistInTheBundle() {
        for format in RankTrialFormat.allCases {
            let name = GateWorldCatalog.world(for: format).bannerAssetName
            XCTAssertNotNil(UIImage(named: name), "missing banner asset \(name)")
        }
    }

    func testDifficultyPipsAreMonotonicByGateOrder() {
        let pips = RankTrialFormat.allCases.map { GateWorldCatalog.world(for: $0).difficultyPips }
        XCTAssertEqual(pips, [1, 2, 3, 4, 5, 6, 7, 8])
    }
}
```

- [ ] **Step 2: Run → FAIL** (`xcodegen generate` first — new files). Expected: `GateWorld` / `GateWorldCatalog` undefined.

- [ ] **Step 3: Implement `GateWorld.swift`**

```swift
import SwiftUI

/// The living-world element each gate's active layer animates. Plan 2 renders a
/// generic treatment for all of them (DefaultGateVisualizer); Plan 4 ships eight
/// bespoke GateVisualizer plugins keyed off this.
enum GateWorldElement: String, Equatable, Sendable {
    case lanterns   // I  — courtyard lanterns ignite
    case bell       // II — the dojo bell
    case forge      // III— blade glows hotter, the quench
    case deck       // IV — the road-worn deck
    case ascent     // V  — altitude rising through cloud
    case seals      // VI — ritual circles shatter
    case siege      // VII— the portal opens across the trial
    case landings   // VIII—golden stairway landings
}

/// Declarative theme for one rank gate. Derives all visuals from the destination
/// rank so a balance/rename in the engine flows through automatically. Art is the
/// existing rank banner in Plan 2 (spec §3); Plan 3 swaps bespoke threshold art
/// behind `bannerAssetName`.
struct GateWorld: Identifiable, Equatable, Sendable {
    let format: RankTrialFormat
    let numeral: String           // "I" … "VIII"
    let order: Int                // 1 … 8
    let promise: String           // one-line, world-language, non-negging
    let beatVerb: String          // station-clear beat verb ("lit", "struck", …)
    let destinationRank: RankTitle
    let element: GateWorldElement

    var id: RankTrialFormat { format }
    var trialName: String { format.displayName }
    var difficultyPips: Int { order }

    /// Foreground-safe tint for text/icons on dark UI.
    var tint: Color { destinationRank.rewardTextTint }
    /// Saturated fill tint for sigils, progress fills, stamps.
    var fillTint: Color { destinationRank.rewardTint }
    /// Existing rank banner (Plan 2). `profile_banner_<token>` exists for all 9 ranks.
    var bannerAssetName: String { "profile_banner_\(destinationRank.token)" }

    /// "FORGED → VETERAN" style transition label.
    func transitionLabel(from origin: RankTitle) -> String {
        "\(origin.displayName.uppercased()) → \(destinationRank.displayName.uppercased())"
    }
}
```

- [ ] **Step 4: Implement `GateWorldCatalog.swift`** (all 8 entries — values from spec §3/§5, copy is brand-safe and non-negging):

```swift
import Foundation

enum GateWorldCatalog {
    static func world(for format: RankTrialFormat) -> GateWorld {
        switch format {
        case .firstLight:
            return GateWorld(format: .firstLight, numeral: "I", order: 1,
                promise: "Step out of the dark and light the courtyard.",
                beatVerb: "lit", destinationRank: .novice, element: .lanterns)
        case .theCount:
            return GateWorld(format: .theCount, numeral: "II", order: 2,
                promise: "Move with the bell, not against it.",
                beatVerb: "counted", destinationRank: .apprentice, element: .bell)
        case .theForging:
            return GateWorld(format: .theForging, numeral: "III", order: 3,
                promise: "The fire waits. The steel doesn't rush.",
                beatVerb: "struck", destinationRank: .forged, element: .forge)
        case .deckOfProof:
            return GateWorld(format: .deckOfProof, numeral: "IV", order: 4,
                promise: "Fifty-two battles. Clear the whole deck.",
                beatVerb: "drawn", destinationRank: .veteran, element: .deck)
        case .theAscent:
            return GateWorld(format: .theAscent, numeral: "V", order: 5,
                promise: "Ten floors of cloud. Climb to the temple doors.",
                beatVerb: "climbed", destinationRank: .master, element: .ascent)
        case .sevenSeals:
            return GateWorld(format: .sevenSeals, numeral: "VI", order: 6,
                promise: "Seven seals, one for each part of you.",
                beatVerb: "sealed", destinationRank: .vessel, element: .seals)
        case .theThreshold:
            return GateWorld(format: .theThreshold, numeral: "VII", order: 7,
                promise: "Hold the line until the portal opens.",
                beatVerb: "breached", destinationRank: .ascendant, element: .siege)
        case .theLastGate:
            return GateWorld(format: .theLastGate, numeral: "VIII", order: 8,
                promise: "Every gate you've answered, one last time.",
                beatVerb: "answered", destinationRank: .unbound, element: .landings)
        }
    }
}
```

- [ ] **Step 5: Run → PASS.** **Step 6: Commit** — `git add UNBOUND/Views/Gates/GateWorlds/ UNBOUNDTests/Views/Gates/GateWorldCatalogTests.swift project.yml` (xcodegen may touch `project.yml`/pbxproj is gitignored — stage `project.yml` only if changed) · `git commit -m "feat(gates): GateWorld config layer + catalog for all 8 destination worlds"`.

---

## Task 2: `NextGateCardModel` — discovery derivation `[CLAUDE]`

The card has three presentations (spec §6.1): **sealed** (accumulating — darkened, quest items + key fragments), **open** (eligible — seal-cracked, BEGIN), **cleared** (no next gate / already passed).

**Files:**
- Create: `UNBOUND/Views/Gates/NextGateCardModel.swift`
- Test: `UNBOUNDTests/Views/Gates/NextGateCardModelTests.swift`

- [ ] **Step 1: Failing test**

```swift
import XCTest
@testable import UNBOUND

final class NextGateCardModelTests: XCTestCase {
    private func readiness(
        status: OverallRankTrialStatus,
        requirements: [OverallRankTrialRequirementLine]
    ) -> OverallRankTrialReadiness {
        OverallRankTrialReadiness(
            status: status, currentRank: .apprentice, targetRank: .forged,
            definition: OverallRankTrialDefinitions.theForging,
            resolvedTrial: nil, blockerSummary: nil,
            requirements: requirements, latestAttempt: nil
        )
    }

    private func req(_ id: String, _ kind: OverallRankTrialRequirementKind, met: Bool) -> OverallRankTrialRequirementLine {
        .init(id: id, kind: kind, label: id, current: "", required: "", isMet: met)
    }

    func testLockedWithUnmetRequirementsIsSealed() {
        let model = NextGateCardModel(
            readiness: readiness(status: .locked, requirements: [req("lvl", .overallLevel, met: false)]),
            world: GateWorldCatalog.world(for: .theForging))
        XCTAssertEqual(model.presentation, .sealed)
        XCTAssertNil(model.ctaTitle)
    }

    func testReadyIsOpenWithBeginCTA() {
        let model = NextGateCardModel(
            readiness: readiness(status: .ready, requirements: [req("lvl", .overallLevel, met: true)]),
            world: GateWorldCatalog.world(for: .theForging))
        XCTAssertEqual(model.presentation, .open)
        XCTAssertEqual(model.ctaTitle, "OPEN THE GATE")
    }

    func testFailedIsOpenWithReenterCTA() {
        let model = NextGateCardModel(
            readiness: readiness(status: .failed, requirements: []),
            world: GateWorldCatalog.world(for: .theForging))
        XCTAssertEqual(model.presentation, .open)
        XCTAssertEqual(model.ctaTitle, "ENTER AGAIN")
    }

    func testKeyFragmentsComeFromGateKeyRequirementsOnly() {
        let model = NextGateCardModel(
            readiness: readiness(status: .locked, requirements: [
                req("lvl", .overallLevel, met: true),
                req("key-forge-pullups", .gateKey, met: true),
                req("key-forge-hinge", .gateKey, met: false)
            ]),
            world: GateWorldCatalog.world(for: .theForging))
        XCTAssertEqual(model.keyFragments.map(\.id), ["key-forge-pullups", "key-forge-hinge"])
        XCTAssertEqual(model.keyFragments.filter(\.isLit).count, 1)
        // Quest items are the NON-key requirements.
        XCTAssertEqual(model.questItems.map(\.id), ["lvl"])
    }

    func testNoDefinitionIsCleared() {
        let r = OverallRankTrialReadiness(status: .passed, currentRank: .unbound, targetRank: nil,
            definition: nil, resolvedTrial: nil, blockerSummary: nil, requirements: [], latestAttempt: nil)
        let model = NextGateCardModel(readiness: r, world: GateWorldCatalog.world(for: .theLastGate))
        XCTAssertEqual(model.presentation, .cleared)
    }
}
```

- [ ] **Step 2: Run → FAIL.** **Step 3: Implement:**

```swift
import Foundation

struct NextGateCardModel: Equatable {
    enum Presentation: Equatable { case sealed, open, cleared }

    struct QuestItem: Identifiable, Equatable { let id: String; let label: String; let isMet: Bool }
    struct KeyFragment: Identifiable, Equatable { let id: String; let label: String; let isLit: Bool }

    let presentation: Presentation
    let numeral: String
    let trialName: String
    let promise: String
    let transitionLabel: String
    let questItems: [QuestItem]
    let keyFragments: [KeyFragment]
    let ctaTitle: String?

    init(readiness: OverallRankTrialReadiness, world: GateWorld) {
        numeral = world.numeral
        trialName = world.trialName
        promise = world.promise
        transitionLabel = world.transitionLabel(from: readiness.currentRank)

        let keyLines = readiness.requirements.filter { $0.kind == .gateKey }
        keyFragments = keyLines.map { .init(id: $0.id, label: $0.label, isLit: $0.isMet) }
        questItems = readiness.requirements
            .filter { $0.kind != .gateKey }
            .map { .init(id: $0.id, label: $0.label, isMet: $0.isMet) }

        if readiness.definition == nil {
            presentation = .cleared
            ctaTitle = nil
        } else if readiness.isReady {       // .ready || .failed
            presentation = .open
            ctaTitle = (readiness.status == .failed) ? "ENTER AGAIN" : "OPEN THE GATE"
        } else {
            presentation = .sealed
            ctaTitle = nil
        }
    }
}
```

- [ ] **Step 4: Run → PASS.** **Step 5: Commit** — `feat(gates): NextGateCard presentation model`.

---

## Task 3: `NextGateCard` view `[CLAUDE]`

**Files:** Create `UNBOUND/Views/Gates/NextGateCard.swift`. (Verified by screenshot in Task 13, not a unit test.)

- [ ] **Step 1: Implement** (sealed = darkened banner + gate sigil + quest log + key fragments; open = brightened banner + BEGIN; cleared = quiet "answered" state):

```swift
import SwiftUI

struct NextGateCard: View {
    let readiness: OverallRankTrialReadiness
    let world: GateWorld
    var onBegin: (() -> Void)? = nil

    private var model: NextGateCardModel { .init(readiness: readiness, world: world) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            banner
            content
        }
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.unbound.surface))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(world.tint.opacity(model.presentation == .open ? 0.55 : 0.22), lineWidth: 1))
        .accessibilityIdentifier("next-gate-card")
    }

    private var banner: some View {
        ZStack(alignment: .bottomLeading) {
            Image(world.bannerAssetName)
                .resizable().scaledToFill()
                .frame(height: 168).clipped()
                .saturation(model.presentation == .sealed ? 0.15 : 1)
                .overlay(Color.black.opacity(model.presentation == .sealed ? 0.62 : 0.12))
                .overlay(LinearGradient(colors: [.clear, Color.unbound.surface],
                    startPoint: .center, endPoint: .bottom))

            if model.presentation == .sealed {
                Image(systemName: "lock.fill")
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(world.tint.opacity(0.9))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            HStack(spacing: 8) {
                Text("RANK GATE \(world.numeral)")
                    .font(Font.unbound.captionS.weight(.heavy)).tracking(2)
                    .foregroundStyle(world.tint)
                Spacer(minLength: 0)
                difficultyPips
            }
            .padding(14)
        }
        .frame(height: 168)
    }

    private var difficultyPips: some View {
        HStack(spacing: 3) {
            ForEach(0..<8, id: \.self) { i in
                Circle().fill(i < world.difficultyPips ? world.tint : Color.white.opacity(0.18))
                    .frame(width: 5, height: 5)
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.trialName.uppercased())
                .font(Font.unbound.titleS).foregroundStyle(Color.unbound.textPrimary)
            Text(model.transitionLabel)
                .font(Font.unbound.captionS.weight(.heavy)).tracking(1.4)
                .foregroundStyle(world.tint)
            Text(model.promise)
                .font(Font.unbound.bodyMStrong).foregroundStyle(Color.unbound.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if model.presentation == .sealed {
                questLog
                if !model.keyFragments.isEmpty { keyFragmentRow }
            }

            if let cta = model.ctaTitle {
                Button { onBegin?() } label: {
                    Text(cta).font(Font.unbound.captionS.weight(.heavy)).tracking(1.6)
                        .foregroundStyle(Color.unbound.bg)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(Capsule().fill(world.fillTint))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("next-gate-begin")
            }
        }
        .padding(16)
    }

    private var questLog: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(model.questItems) { item in
                Label {
                    Text(item.label).font(Font.unbound.captionS.weight(.semibold))
                        .foregroundStyle(Color.unbound.textPrimary)
                } icon: {
                    Image(systemName: item.isMet ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(item.isMet ? Color.unbound.success : world.tint.opacity(0.7))
                }
            }
        }
    }

    private var keyFragmentRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("GATE KEYS").font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(1.6).foregroundStyle(Color.unbound.textTertiary)
            ForEach(model.keyFragments) { frag in
                Label {
                    Text(frag.label).font(Font.unbound.captionS.weight(.semibold))
                        .foregroundStyle(frag.isLit ? Color.unbound.textPrimary : Color.unbound.textSecondary)
                } icon: {
                    Image(systemName: frag.isLit ? "key.fill" : "key")
                        .foregroundStyle(frag.isLit ? world.fillTint : world.tint.opacity(0.4))
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(world.tint.opacity(0.08)))
    }
}
```

- [ ] **Step 2: Commit** — `feat(gates): NextGateCard discovery view`. (Screenshot deferred to Task 13.)

---

## Task 4: `GateHallView` — entry sheet `[CLAUDE]`

Full-bleed banner + ambient overlay; centered JRPG title stack (numeral → divider → trial name → promise → rank transition → difficulty pips → format meta); stations preview in world language (the engine's station titles already read as world-language, e.g. "The Path Lantern"); loadout picker; past-attempt cards; BEGIN (spec §6.2). The ceremony (Task 5) animates the title stack on appear.

**Files:** Create `UNBOUND/Views/Gates/GateHallView.swift`.

- [ ] **Step 1: Implement**

```swift
import SwiftUI

struct GateHallView: View {
    let world: GateWorld
    let resolvedTrial: ResolvedRankTrial?     // station list for the chosen loadout
    let latestAttempt: OverallRankTrialAttempt?
    @State var loadout: TrialLoadout
    var onBegin: (TrialLoadout) -> Void
    var onClose: (() -> Void)? = nil

    @State private var ceremonyComplete = false

    var body: some View {
        ZStack(alignment: .top) {
            Color.unbound.bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 22) {
                    titleCard
                    loadoutPicker
                    stationsPreview
                    if let latestAttempt { attemptRow(latestAttempt) }
                }
                .padding(.horizontal, 18).padding(.bottom, 120)
            }
            beginBar
        }
    }

    private var titleCard: some View {
        ZStack {
            Image(world.bannerAssetName).resizable().scaledToFill()
                .frame(height: 320).clipped()
                .overlay(RadialGradient(colors: [Color.black.opacity(0.1), Color.black.opacity(0.72)],
                    center: .center, startRadius: 40, endRadius: 260))
            GateEntryCeremony(world: world, onComplete: { ceremonyComplete = true })
        }
        .frame(height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var loadoutPicker: some View {
        HStack(spacing: 8) {
            ForEach(TrialLoadout.allCases, id: \.self) { option in
                Button { loadout = option } label: {
                    Text(option.displayName.uppercased())
                        .font(Font.unbound.captionS.weight(.heavy)).tracking(1)
                        .foregroundStyle(loadout == option ? Color.unbound.bg : Color.unbound.textSecondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(Capsule().fill(loadout == option ? world.fillTint : Color.unbound.surfaceElevated))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var stationsPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("THE STATIONS").font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(1.6).foregroundStyle(Color.unbound.textTertiary)
            ForEach(Array((resolvedTrial?.stations ?? []).enumerated()), id: \.element.id) { idx, station in
                HStack(spacing: 12) {
                    Text("\(idx + 1)").font(Font.unbound.monoS.weight(.bold))
                        .foregroundStyle(world.tint).frame(width: 20)
                    Text(station.station.title).font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Spacer(minLength: 0)
                    Text(station.selectedMovement.displayName).font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary).lineLimit(1)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.unbound.surface))
            }
        }
    }

    private func attemptRow(_ attempt: OverallRankTrialAttempt) -> some View {
        HStack(spacing: 8) {
            Image(systemName: attempt.passed ? "checkmark.seal.fill" : "xmark.seal.fill")
                .foregroundStyle(attempt.passed ? Color.unbound.success : Color.unbound.warnOrange)
            Text(attempt.passed ? "LAST: PASSED" : "LAST: HELD")
                .font(Font.unbound.captionS.weight(.heavy)).tracking(1.2)
                .foregroundStyle(attempt.passed ? Color.unbound.success : Color.unbound.warnOrange)
            Spacer(minLength: 0)
            Text(attempt.completedAt, style: .date).font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.unbound.surface))
    }

    private var beginBar: some View {
        VStack {
            Spacer()
            Button { UnboundHaptics.success(); onBegin(loadout) } label: {
                Text("BEGIN").font(Font.unbound.titleS.weight(.heavy)).tracking(2)
                    .foregroundStyle(Color.unbound.bg)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Capsule().fill(world.fillTint))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 18).padding(.bottom, 28)
            .accessibilityIdentifier("gate-hall-begin")
        }
    }
}
```

- [ ] **Step 2: Commit** — `feat(gates): GateHallView entry sheet`.

---

## Task 5: `GateEntryCeremony` — title types on `[CLAUDE]`

The centered title stack reveals line-by-line with haptic beats over the banner (spec §6.3); reduced-motion shows all lines instantly.

**Files:** Create `UNBOUND/Views/Gates/GateEntryCeremony.swift`.

- [ ] **Step 1: Implement**

```swift
import SwiftUI

struct GateEntryCeremony: View {
    let world: GateWorld
    var onComplete: (() -> Void)? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealedLines = 0

    private var lines: [String] {
        ["RANK GATE \(world.numeral)", world.trialName.uppercased(), world.promise]
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(lines[0]).font(Font.unbound.captionS.weight(.heavy)).tracking(3)
                .foregroundStyle(world.tint).opacity(revealedLines > 0 ? 1 : 0)
            Rectangle().fill(world.tint.opacity(0.6)).frame(width: 44, height: 1)
                .opacity(revealedLines > 0 ? 1 : 0)
            Text(lines[1]).font(Font.unbound.titleL.weight(.black))
                .foregroundStyle(Color.unbound.textPrimary).opacity(revealedLines > 1 ? 1 : 0)
            Text(lines[2]).font(Font.unbound.bodyMStrong).foregroundStyle(Color.unbound.textSecondary)
                .multilineTextAlignment(.center).opacity(revealedLines > 2 ? 1 : 0)
            difficultyPips.opacity(revealedLines > 2 ? 1 : 0)
        }
        .padding(.horizontal, 24)
        .task { await runCeremony() }
    }

    private var difficultyPips: some View {
        HStack(spacing: 4) {
            ForEach(0..<8, id: \.self) { i in
                Circle().fill(i < world.difficultyPips ? world.tint : Color.white.opacity(0.18))
                    .frame(width: 6, height: 6)
            }
        }
    }

    private func runCeremony() async {
        guard !reduceMotion else { revealedLines = lines.count + 1; onComplete?(); return }
        for step in 1...(lines.count) {
            try? await Task.sleep(nanoseconds: 420_000_000)
            withAnimation(.easeOut(duration: 0.3)) { revealedLines = step }
            UnboundHaptics.soft()
        }
        try? await Task.sleep(nanoseconds: 300_000_000)
        revealedLines = lines.count + 1
        onComplete?()
    }
}
```

> Verify `Font.unbound.titleL` exists (`grep -n "titleL\|titleM\|titleS" UNBOUND/Utilities/**/Font*`); if not, use `titleM`.

- [ ] **Step 2: Commit** — `feat(gates): GateEntryCeremony title type-on`.

---

## Task 6: `GateVisualizer` + `GateActiveHeaderView` `[CLAUDE]`

The world-stage header: banner top ~28% bleeding into true black, holding trial name, station N/M, a progress rail, and the living-world layer. Plan 2 ships a generic visualizer; Plan 4 specializes per gate.

**Files:** Create `UNBOUND/Views/Gates/GateVisualizer.swift`, `UNBOUND/Views/Gates/GateActiveHeaderView.swift`.

- [ ] **Step 1: Implement `GateVisualizer.swift`**

```swift
import SwiftUI

/// A gate's living-world layer, advancing with progress. Plan 4 ships eight
/// bespoke implementations (lanterns igniting, blade glowing, seals shattering);
/// Plan 2 uses DefaultGateVisualizer for every gate.
protocol GateVisualizer: View {
    init(world: GateWorld, stationsCleared: Int, stationCount: Int)
}

/// Generic treatment: N pips fill as stations clear, tinted to the world.
struct DefaultGateVisualizer: GateVisualizer {
    let world: GateWorld
    let stationsCleared: Int
    let stationCount: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<max(stationCount, 1), id: \.self) { i in
                Capsule()
                    .fill(i < stationsCleared ? world.fillTint : Color.white.opacity(0.16))
                    .frame(height: 6)
                    .overlay(i < stationsCleared
                        ? Capsule().fill(world.fillTint).blur(radius: 4).opacity(0.5) : nil)
            }
        }
        .animation(.easeOut(duration: 0.4), value: stationsCleared)
    }
}
```

- [ ] **Step 2: Implement `GateActiveHeaderView.swift`**

```swift
import SwiftUI

struct GateActiveHeaderView: View {
    let world: GateWorld
    let stationIndex: Int       // 0-based current
    let stationCount: Int
    let stationsCleared: Int
    let currentStationTitle: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(world.bannerAssetName).resizable().scaledToFill()
                .frame(height: 240).clipped()
                .overlay(LinearGradient(colors: [.clear, .clear, Color.unbound.bg],
                    startPoint: .top, endPoint: .bottom))

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(world.trialName.uppercased())
                        .font(Font.unbound.captionS.weight(.heavy)).tracking(2)
                        .foregroundStyle(world.tint)
                    Spacer(minLength: 0)
                    Text("STATION \(stationIndex + 1)/\(stationCount)")
                        .font(Font.unbound.monoS.weight(.bold)).foregroundStyle(Color.unbound.textSecondary)
                }
                Text(currentStationTitle).font(Font.unbound.titleM)
                    .foregroundStyle(Color.unbound.textPrimary).lineLimit(1).minimumScaleFactor(0.7)
                DefaultGateVisualizer(world: world, stationsCleared: stationsCleared, stationCount: stationCount)
            }
            .padding(16)
        }
        .frame(height: 240)
        .accessibilityIdentifier("gate-active-header")
    }
}
```

- [ ] **Step 3: Commit** — `feat(gates): GateVisualizer protocol + world-stage active header`.

---

## Task 7: `GateActiveView` — header over the calm surface `[CLAUDE]`

Header (Task 6) at full brightness over the true-black calm logging surface, reusing `ExerciseLogCard` (one logging spine — spec §6.4). Plan 2 renders demo cards; Plan 4 wires the live `ActiveWorkoutSession` grid and replaces the per-format dispatch in `WorkoutLogGridView`.

**Files:** Create `UNBOUND/Views/Gates/GateActiveView.swift`.

- [ ] **Step 1: Implement** (the body takes an injected logging-surface view so the demo can pass sample `ExerciseLogCard`s and Plan 4 can pass the real grid):

```swift
import SwiftUI

struct GateActiveView<LoggingSurface: View>: View {
    let world: GateWorld
    let stationIndex: Int
    let stationCount: Int
    let stationsCleared: Int
    let currentStationTitle: String
    @ViewBuilder var loggingSurface: () -> LoggingSurface

    var body: some View {
        ZStack(alignment: .top) {
            Color.unbound.bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    GateActiveHeaderView(
                        world: world, stationIndex: stationIndex, stationCount: stationCount,
                        stationsCleared: stationsCleared, currentStationTitle: currentStationTitle)
                    loggingSurface()
                        .padding(.horizontal, 16)
                }
                .padding(.bottom, 60)
            }
        }
        .accessibilityIdentifier("gate-active-view")
    }
}
```

- [ ] **Step 2: Commit** — `feat(gates): GateActiveView world-stage header over calm logging surface`.

---

## Task 8: `GateBeatOverlay` — station-clear beat `[CLAUDE]`

Full-bleed world floods back, the world element advances, one line of copy, signature haptic, recedes (spec §6.5). Reduced-motion shows a brief static flash.

**Files:** Create `UNBOUND/Views/Gates/GateBeatOverlay.swift`.

- [ ] **Step 1: Implement**

```swift
import SwiftUI

struct GateBeatOverlay: View {
    let world: GateWorld
    let stationTitle: String
    var onFinished: (() -> Void)? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    private var line: String { "\(stationTitle) — \(world.beatVerb)." }

    var body: some View {
        ZStack {
            Image(world.bannerAssetName).resizable().scaledToFill().ignoresSafeArea()
                .overlay(world.fillTint.opacity(0.18)).overlay(Color.black.opacity(0.32))
            Text(line.uppercased()).font(Font.unbound.titleM.weight(.black)).tracking(1.5)
                .foregroundStyle(Color.unbound.textPrimary).multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .opacity(shown ? 1 : 0)
        .task { await play() }
        .accessibilityIdentifier("gate-beat-overlay")
    }

    private func play() async {
        UnboundHaptics.success()
        withAnimation(.easeOut(duration: reduceMotion ? 0.05 : 0.28)) { shown = true }
        try? await Task.sleep(nanoseconds: reduceMotion ? 400_000_000 : 1_100_000_000)
        withAnimation(.easeIn(duration: 0.3)) { shown = false }
        try? await Task.sleep(nanoseconds: 320_000_000)
        onFinished?()
    }
}
```

- [ ] **Step 2: Commit** — `feat(gates): GateBeatOverlay station-clear beat`.

---

## Task 9: `GateVerdictModel` — accounting derivation `[CLAUDE]`

Pass and fail both show a station-by-station accounting (your numbers vs floors); fail turns failed scored stations into named training targets ("what stands between you", spec §6.7). Unscored stations are excluded.

**Files:**
- Create: `UNBOUND/Views/Gates/GateVerdictModel.swift`
- Test: `UNBOUNDTests/Views/Gates/GateVerdictModelTests.swift`

- [ ] **Step 1: Failing test**

```swift
import XCTest
@testable import UNBOUND

final class GateVerdictModelTests: XCTestCase {
    private func result(_ id: String, status: OverallRankTrialStationStatus,
                        total: Int, required: Int, scored: Bool = true) -> OverallRankTrialStationResult {
        .init(id: id, title: id, category: .push, movementId: "m", required: required,
              qualifyingSetsRequired: 1, qualifyingSetsCompleted: status == .passed ? 1 : 0,
              totalValue: total, failedQualityFlags: [], status: status, failureReason: nil, isScored: scored)
    }

    func testPassedAccountsEveryScoredStation() {
        let eval = OverallRankTrialEvaluation(definitionId: "g", passed: true, stationResults: [
            result("a", status: .passed, total: 20, required: 15),
            result("stoke", status: .missing, total: 0, required: 0, scored: false)
        ])
        let model = GateVerdictModel(evaluation: eval, world: GateWorldCatalog.world(for: .firstLight))
        XCTAssertEqual(model.outcome, .passed)
        XCTAssertEqual(model.stationRows.map(\.id), ["a"])   // unscored "stoke" excluded
        XCTAssertTrue(model.standingBetween.isEmpty)
    }

    func testFailedSurfacesNamedTargetsFromFailedScoredStations() {
        let eval = OverallRankTrialEvaluation(definitionId: "g", passed: false, stationResults: [
            result("push", status: .passed, total: 18, required: 18),
            result("pull", status: .failed, total: 2, required: 3)
        ])
        let model = GateVerdictModel(evaluation: eval, world: GateWorldCatalog.world(for: .theForging))
        XCTAssertEqual(model.outcome, .failed)
        XCTAssertEqual(model.standingBetween.count, 1)
        XCTAssertTrue(model.standingBetween[0].contains("pull"))
    }
}
```

- [ ] **Step 2: Run → FAIL.** **Step 3: Implement:**

```swift
import Foundation

struct GateVerdictModel: Equatable {
    enum Outcome: Equatable { case passed, failed }
    struct StationRow: Identifiable, Equatable {
        let id: String; let title: String; let yours: String; let floor: String; let passed: Bool
    }

    let outcome: Outcome
    let stationRows: [StationRow]
    let standingBetween: [String]   // fail only: named training targets

    init(evaluation: OverallRankTrialEvaluation, world: GateWorld) {
        outcome = evaluation.passed ? .passed : .failed
        let scored = evaluation.stationResults.filter(\.isScored)
        stationRows = scored.map {
            .init(id: $0.id, title: $0.title, yours: "\($0.totalValue)",
                  floor: "\($0.required)", passed: $0.status == .passed)
        }
        standingBetween = evaluation.passed ? [] : scored
            .filter { $0.status != .passed }
            .map { "\($0.title): \($0.totalValue) of \($0.required)" }
    }
}
```

- [ ] **Step 4: Run → PASS.** **Step 5: Commit** — `feat(gates): GateVerdict accounting model`.

---

## Task 10: `GateVerdictView` — pass / fail `[CLAUDE]`

Pass: the hush → station accounting → "Gate Card minted" hand-off slot (the Crossing trigger is a Plan 3 hook — Plan 2 ends on the minted card). Fail: world steady ("The gate holds.") → accounting → "What stands between you" → rematch CTA (spec §6.6/§6.7).

**Files:** Create `UNBOUND/Views/Gates/GateVerdictView.swift`.

- [ ] **Step 1: Implement**

```swift
import SwiftUI

struct GateVerdictView: View {
    let evaluation: OverallRankTrialEvaluation
    let world: GateWorld
    var onMintedCardTapped: (() -> Void)? = nil   // Plan 3: triggers The Crossing
    var onRematch: (() -> Void)? = nil

    private var model: GateVerdictModel { .init(evaluation: evaluation, world: world) }

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headline
                    accounting
                    if model.outcome == .failed { standingBetween; rematchButton }
                    else { mintedCardSlot }
                }
                .padding(18).padding(.bottom, 60)
            }
        }
        .accessibilityIdentifier("gate-verdict-view")
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.outcome == .passed ? "THE GATE IS ANSWERED." : "THE GATE HOLDS.")
                .font(Font.unbound.titleM.weight(.black))
                .foregroundStyle(model.outcome == .passed ? world.tint : Color.unbound.textPrimary)
            Text(model.outcome == .passed
                 ? "\(world.trialName) cleared."
                 : "The gate isn't going anywhere.")
                .font(Font.unbound.bodyMStrong).foregroundStyle(Color.unbound.textSecondary)
        }
    }

    private var accounting: some View {
        VStack(spacing: 8) {
            ForEach(model.stationRows) { row in
                HStack(spacing: 10) {
                    Image(systemName: row.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(row.passed ? Color.unbound.success : Color.unbound.warnOrange)
                    Text(row.title).font(Font.unbound.bodyMStrong).foregroundStyle(Color.unbound.textPrimary)
                    Spacer(minLength: 0)
                    Text("\(row.yours) / \(row.floor)").font(Font.unbound.monoS.weight(.bold))
                        .foregroundStyle(row.passed ? Color.unbound.textSecondary : Color.unbound.warnOrange)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.unbound.surface))
            }
        }
    }

    private var standingBetween: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WHAT STANDS BETWEEN YOU").font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(1.5).foregroundStyle(Color.unbound.textTertiary)
            ForEach(model.standingBetween, id: \.self) { target in
                Text(target).font(Font.unbound.captionS.weight(.semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(world.tint.opacity(0.1)))
            }
        }
    }

    private var rematchButton: some View {
        Button { onRematch?() } label: {
            Text("ENTER AGAIN").font(Font.unbound.captionS.weight(.heavy)).tracking(1.6)
                .foregroundStyle(Color.unbound.bg).frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(Capsule().fill(world.fillTint))
        }.buttonStyle(.plain)
    }

    private var mintedCardSlot: some View {
        Button { UnboundHaptics.success(); onMintedCardTapped?() } label: {
            GateCardView(world: world, dateText: nil, definingNumber: "\(model.stationRows.filter(\.passed).count)/\(model.stationRows.count)", stamped: true)
        }.buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: Commit** — `feat(gates): GateVerdictView pass/fail accounting`.

---

## Task 11: `GateCardView` — the minted gate card `[CLAUDE]`

The share card: banner + numeral + trial name + date + defining number + destination crest stamp. Stamped (passed) vs unstamped (failed/in-progress, with attempt count). Spec §6.6/§6.8.

**Files:** Create `UNBOUND/Views/Gates/GateCardView.swift`.

- [ ] **Step 1: Implement**

```swift
import SwiftUI

struct GateCardView: View {
    let world: GateWorld
    let dateText: String?
    let definingNumber: String?
    let stamped: Bool
    var attemptCount: Int? = nil

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(world.bannerAssetName).resizable().scaledToFill()
                .frame(height: 220).clipped()
                .saturation(stamped ? 1 : 0.4)
                .overlay(LinearGradient(colors: [.clear, Color.black.opacity(0.7)], startPoint: .center, endPoint: .bottom))

            if stamped {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 30, weight: .black))
                    .foregroundStyle(world.fillTint)
                    .padding(12).frame(maxWidth: .infinity, alignment: .topTrailing)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("RANK GATE \(world.numeral)").font(Font.unbound.captionS.weight(.heavy)).tracking(2)
                    .foregroundStyle(world.tint)
                Text(world.trialName.uppercased()).font(Font.unbound.titleM.weight(.black))
                    .foregroundStyle(Color.unbound.textPrimary)
                HStack(spacing: 10) {
                    if let definingNumber {
                        Text(definingNumber).font(Font.unbound.monoS.weight(.heavy)).foregroundStyle(world.tint)
                    }
                    if let dateText {
                        Text(dateText).font(Font.unbound.captionS).foregroundStyle(Color.unbound.textTertiary)
                    }
                    if !stamped, let attemptCount {
                        Text("ATTEMPT \(attemptCount)").font(Font.unbound.captionS.weight(.bold))
                            .foregroundStyle(Color.unbound.warnOrange)
                    }
                }
            }
            .padding(16)
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(world.tint.opacity(stamped ? 0.6 : 0.25), lineWidth: 1))
        .accessibilityIdentifier("gate-card")
    }
}
```

- [ ] **Step 2: Commit** — `feat(gates): GateCardView minted gate card`.

---

## Task 12: `TrialRecordsShelf` `[CLAUDE]`

All gate cards + attempt history (spec §6.8). Reads `OverallRankTrialProgress.attempts`; renders one `GateCardView` per gate at its best state (stamped if any passing attempt), plus an attempt count. Replayable Crossings are Plan 3 (a tap hook only here).

**Files:** Create `UNBOUND/Views/Gates/TrialRecordsShelf.swift`.

- [ ] **Step 1: Implement**

```swift
import SwiftUI

struct TrialRecordsShelf: View {
    let progress: OverallRankTrialProgress
    var onSelectGate: ((RankTrialFormat) -> Void)? = nil

    private func bestAttempt(for format: RankTrialFormat) -> OverallRankTrialAttempt? {
        let def = OverallRankTrialDefinitions.definition(for: format)
        let attempts = progress.attempts.filter { def?.matchesAttemptDefinitionId($0.definitionId) ?? false }
        return attempts.first(where: \.passed) ?? attempts.sorted { $0.completedAt > $1.completedAt }.first
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("TRIAL RECORDS").font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(2).foregroundStyle(Color.unbound.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(RankTrialFormat.allCases, id: \.self) { format in
                    let world = GateWorldCatalog.world(for: format)
                    let attempt = bestAttempt(for: format)
                    Button { onSelectGate?(format) } label: {
                        GateCardView(
                            world: world,
                            dateText: attempt.map { DateFormatter.gateShort.string(from: $0.completedAt) },
                            definingNumber: nil,
                            stamped: attempt?.passed ?? false,
                            attemptCount: attempt == nil ? nil : progress.attempts.filter {
                                OverallRankTrialDefinitions.definition(for: format)?.matchesAttemptDefinitionId($0.definitionId) ?? false
                            }.count)
                    }
                    .buttonStyle(.plain)
                    .opacity(attempt == nil ? 0.5 : 1)
                }
            }
            .padding(18)
        }
        .background(Color.unbound.bg.ignoresSafeArea())
        .accessibilityIdentifier("trial-records-shelf")
    }
}

private extension DateFormatter {
    static let gateShort: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none; return f
    }()
}
```

> Verify the lookup accessor: `grep -n "static func definition" UNBOUND/Services/Ranking/OverallRankTrialDefinitions.swift`. If there is no `definition(for format:)`, add a tiny helper there (`first { $0.format == format }`) or map via `nextTrial`/the static `all` array — whichever exists. Do **not** invent an accessor.

- [ ] **Step 2: Commit** — `feat(gates): TrialRecordsShelf records + share cards`.

---

## Task 13: `GateExperienceDemoView` + launch arg `[CLAUDE]`

A `#if DEBUG` harness to render any gate in any spine state for screenshots (spec §12: `--unbound-open-gate <n>` + the screenshot gauntlet). This is the **only** way the spine is reachable in Plan 2.

**Files:**
- Create: `UNBOUND/Views/Gates/GateExperienceDemoView.swift`
- Modify: `UNBOUND/App/UnboundApp.swift` (RootView `body`, the `#if DEBUG` launch-arg ladder — locate via `grep -n "rankTrialDemos" UNBOUND/App/UnboundApp.swift`)

- [ ] **Step 1: Implement `GateExperienceDemoView.swift`** (gate picker 1–8 + state stepper over the spine views; builds a fixture readiness/evaluation/progress per gate from `OverallRankTrialDefinitions` — reuse `RankTrialDemoScenario.makeContext()` for a resolved trial + sample session if available, else a minimal fixture):

```swift
#if DEBUG
import SwiftUI

struct GateExperienceDemoView: View {
    enum Stage: String, CaseIterable { case sealed, open, hall, active, beat, verdictPass, card, verdictFail, records }

    @State private var format: RankTrialFormat = Self.initialFormat()
    @State private var stage: Stage = Self.initialStage()

    private var world: GateWorld { GateWorldCatalog.world(for: format) }

    var body: some View {
        ZStack(alignment: .bottom) {
            stageContent.id("\(format.rawValue)-\(stage.rawValue)")
            controls
        }
        .accessibilityIdentifier("gateExperienceDemo")
    }

    @ViewBuilder private var stageContent: some View {
        switch stage {
        case .sealed:      NextGateCard(readiness: fixtureReadiness(open: false), world: world).padding(18)
        case .open:        NextGateCard(readiness: fixtureReadiness(open: true), world: world, onBegin: {}).padding(18)
        case .hall:        GateHallView(world: world, resolvedTrial: fixtureResolved(), latestAttempt: nil, loadout: .homeKit, onBegin: { _ in })
        case .active:      GateActiveView(world: world, stationIndex: 1, stationCount: 5, stationsCleared: 1, currentStationTitle: fixtureResolved()?.stations.first?.station.title ?? "Station") { sampleCards }
        case .beat:        GateBeatOverlay(world: world, stationTitle: fixtureResolved()?.stations.first?.station.title ?? "The Path")
        case .verdictPass: GateVerdictView(evaluation: fixtureEvaluation(passed: true), world: world)
        case .card:        GateCardView(world: world, dateText: "Jun 13, 2026", definingNumber: "5/5", stamped: true).padding(18)
        case .verdictFail: GateVerdictView(evaluation: fixtureEvaluation(passed: false), world: world)
        case .records:     TrialRecordsShelf(progress: fixtureProgress())
        }
    }

    @ViewBuilder private var sampleCards: some View { /* 2 representative ExerciseLogCard previews */ EmptyView() }

    private var controls: some View {
        VStack(spacing: 6) {
            Picker("", selection: $stage) { ForEach(Stage.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                .pickerStyle(.menu)
            Stepper("Gate \(world.numeral)", onIncrement: { cycle(+1) }, onDecrement: { cycle(-1) })
        }
        .padding(10).background(.ultraThinMaterial).cornerRadius(12).padding(12)
    }

    private func cycle(_ d: Int) {
        let all = RankTrialFormat.allCases
        let i = (all.firstIndex(of: format)! + d + all.count) % all.count
        format = all[i]
    }

    // Fixtures — build from the real definitions so screenshots reflect production data.
    private func fixtureReadiness(open: Bool) -> OverallRankTrialReadiness { /* see step 2 */ fatalError() }
    private func fixtureResolved() -> ResolvedRankTrial? { nil }
    private func fixtureEvaluation(passed: Bool) -> OverallRankTrialEvaluation { .init(definitionId: "demo", passed: passed, stationResults: []) }
    private func fixtureProgress() -> OverallRankTrialProgress { .empty }

    private static func initialFormat() -> RankTrialFormat {
        if let raw = ProcessInfo.processInfo.environment["UNBOUND_OPEN_GATE"], let n = Int(raw),
           (1...8).contains(n) { return RankTrialFormat.allCases[n - 1] }
        return .firstLight
    }
    private static func initialStage() -> Stage {
        if let raw = ProcessInfo.processInfo.environment["UNBOUND_GATE_STAGE"], let s = Stage(rawValue: raw) { return s }
        return .sealed
    }
}
#endif
```

- [ ] **Step 2: Flesh out the fixtures** — `fixtureReadiness` builds an `OverallRankTrialReadiness` from `OverallRankTrialDefinitions` for the gate (status `.ready`/`.locked` per `open`, requirement lines incl. a couple `.gateKey` lines so fragments render); `fixtureResolved` resolves the gate's `.homeKit` loadout to a `ResolvedRankTrial` (use the engine's resolver — `grep -n "func resolve\|makeResolved\|ResolvedRankTrial(" UNBOUND/Services/Ranking/*.swift` for the real constructor/path); `fixtureEvaluation` builds station results from the gate's stations (passing all for pass; failing one scored station for fail); `fixtureProgress` seeds 3–4 `OverallRankTrialAttempt`s across gates (some passed). Reuse `RankTrialDemoScenario` (`UNBOUND/Views/Program/RankTrials/RankTrialDemoRecorderView.swift`) helpers if they already build these — do not duplicate fixture logic.

- [ ] **Step 3: Wire the launch arg** in `UnboundApp.swift` RootView body, alongside the existing `-rankTrialDemos` branch:

```swift
} else if ProcessInfo.processInfo.arguments.contains("-gateExperienceDemo")
    || ProcessInfo.processInfo.environment["UNBOUND_OPEN_GATE"] != nil {
    GateExperienceDemoView()
}
```

- [ ] **Step 4: Build + screenshot gauntlet.** `cd /Users/jlin/Documents/toji/UNBOUND-agent-a && xcodegen generate`. Build to sim (iPhone 17, DerivedData `/private/tmp/unbound-dd-a`). For each gate 1–8 and each Stage, launch with `UNBOUND_OPEN_GATE=<n> UNBOUND_GATE_STAGE=<stage>` (or `-gateExperienceDemo` + in-view picker), `xcrun simctl io booted screenshot`, and **Read every PNG** ([[ui-claims-need-onsim-screenshot]]). Confirm: no clipped titles/prices/labels (UI Quality Bar), banner art reads as the destination world, tint matches the rank, copy is non-negging (Brand Language Guardrail). Fix and re-shoot until clean. **Step 5: Commit** — `feat(gates): gate experience demo harness + --unbound-open-gate launch arg`.

---

## Task 14: L10n + integration sweep + full gauntlet `[CLAUDE]`

- [ ] **Step 1: L10n.** Move every user-facing literal added in Tasks 3–12 (e.g. "OPEN THE GATE", "ENTER AGAIN", "THE GATE IS ANSWERED.", "THE GATE HOLDS.", "WHAT STANDS BETWEEN YOU", "GATE KEYS", "THE STATIONS", "BEGIN", the gate promises) into `Localizable.xcstrings` with real entries, edited as **TEXT** (never `json.dump` — [[l10n-key-needs-xcstrings-entry]]). Keep gate promises in `GateWorldCatalog` as `String(localized:)` keys. Run `LocalizationTests` → green.
- [ ] **Step 2: Hygiene sweep.** `grep -rn "EMOM\|AMRAP\|WOD\|metcon\|limiter\|weak link\|holding you back" UNBOUND/Views/Gates` → expect none (Brand Language Guardrail). Confirm no new file exceeds ~400 lines (split if so — [[modularity-not-for-tokens]]); confirm no engine files were modified (`git diff --stat` touches only `Views/Gates`, `App/UnboundApp.swift`, `Resources/Localizable.xcstrings`, tests, `project.yml`).
- [ ] **Step 3: Full suite.** Run the gate unit suites + full suite; expect green except the 3 pre-existing failures noted in `docs/HANDOFF-rank-gates-engine.md` (asset-PNG dupes, weight-rounding, band-swap — none touch gates). Verify each `-only-testing` suite actually ran ([[xcodebuild-pipe-masks-failure]]).
- [ ] **Step 4: Device-arch gate.** `set -o pipefail; xcodebuild build -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO -scheme UNBOUND -derivedDataPath /private/tmp/unbound-dd-a 2>&1 | grep "BUILD SUCCEEDED"` (never two xcodebuilds concurrently; AnyView-wrap any view body that risks the device metadata cliff — [[device-arch-build-is-the-real-gate]]).
- [ ] **Step 5: Handoff.** Update `docs/HANDOFF-rank-gates-engine.md` (or a new `HANDOFF-rank-gates-spine.md`) with the Agent Handoff format: what shipped, screenshots taken, what's deferred to Plans 3–4 (live cutover, deletion, Crossing, bespoke visualizers, art). Commit + push checkpoint to jlin.

## Self-review (done at authoring)

- **Spec coverage:** §6.1 NextGateCard → Tasks 2–3; §6.2 Gate Hall → Task 4; §6.3 entry ceremony → Task 5; §6.4 in-trial world-stage + calm surface → Tasks 6–7; §6.5 station beats → Task 8; §6.6 pass verdict + minted card → Tasks 9–11; §6.7 fail verdict + "what stands between you" → Tasks 9–10; §6.8 Trial Records + share cards → Tasks 11–12; §10 GateWorlds + shared views → Tasks 1–12; §12 launch-arg screenshots → Task 13. **Deliberately out (Plans 3–4):** TheCrossingView + asset manager + art generation (Plan 3); 8 bespoke GateVisualizer plugins, live cutover, legacy deletion (Plan 4).
- **Type consistency:** `GateWorld` fields used identically across NextGateCard/Hall/Header/Beat/Card/Verdict; `NextGateCardModel`/`GateVerdictModel` constructors match their tests; `DefaultGateVisualizer` conforms to `GateVisualizer`; all engine types (`OverallRankTrialReadiness`, `OverallRankTrialEvaluation`, `OverallRankTrialStationResult`, `OverallRankTrialAttempt`, `RankTrialFormat`, `TrialLoadout`, `RankTitle`) are consumed, never modified.
- **Known judgment calls left to implementer:** exact engine resolver/lookup accessors (`OverallRankTrialDefinitions.definition(for:)`, the `ResolvedRankTrial` builder) located by grep — verify, never invent ([[skill-tiercriteria-name-resolution]]); `Font.unbound.titleL` existence (fall back to `titleM`); whether `RankTrialDemoScenario` fixtures can be reused for Task 13.
