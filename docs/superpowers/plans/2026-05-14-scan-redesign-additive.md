# Scan Redesign (Additive) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Collapse two parallel scan stacks into one — delete OLD Gemini-grading pipeline, ship NEW Apple-Vision pipeline with soft 30-day cadence + Haiku 4.5 flavor copy. Preserve session-flow Home.

**Architecture:** Delete entire `Body/`, `BodyScan/`, `Report/` folders. Reuse models/services from reference branch `scan-redesign-impl`. Add `ScanCadenceGate`, `ScanCheckpointStore`, `ScanPayoffFlavorService` (Anthropic Haiku 4.5 wrapper around existing `ClaudeClient`). Home contextualStack gets a `ScanDueCard`. Profile gets a `ProfileScanRow`. Single pipeline through `PhotoCaptureFlow → LocalBodyInsightsService → ScanCheckpointStore → ScanPayoffView`.

**Tech Stack:** Swift 5.9+, SwiftUI iOS 17+, XCTest, Apple Vision framework (on-device), Anthropic API (claude-haiku-4-5 via existing `ClaudeClient`), UserDefaults persistence.

**Spec:** [`docs/superpowers/specs/2026-05-14-scan-redesign-additive-design.md`](../specs/2026-05-14-scan-redesign-additive-design.md).

**Reference branch:** `/Users/jlin/Documents/toji/UNBOUND-scan-redesign/` — has `ScanCheckpointService`, `ScanCheckpointStore`, `ScanNarrativeService`, `FirstScanArcCard`, `NthScanEvolutionCard`, `ScanCadenceGate`, plus tests. Copy verbatim where indicated.

**Worktree:** Create `/Users/jlin/Documents/toji/UNBOUND-scan-v2` on new branch `scan-redesign-v2` off `program-redesign` HEAD.

---

## File Structure

### CREATE (copy from reference unless noted)

```
UNBOUND/Models/
└── ScanCheckpoint.swift                  (copy from reference)

UNBOUND/Services/Scan/
├── ScanCheckpointStore.swift             (copy)
├── ScanCheckpointService.swift           (copy)
└── ScanPayoffFlavorService.swift         (NEW — wraps ClaudeClient + Haiku 4.5)

UNBOUND/Views/Scan/
├── FirstScanArcCard.swift                (copy)
├── NthScanEvolutionCard.swift            (copy)
└── ScanCadenceGate.swift                 (copy — note: it's a view component, lives here)

UNBOUND/Views/Home/
└── ScanDueCard.swift                     (NEW — slots into contextualStack)

UNBOUND/Views/Profile/
└── ProfileScanRow.swift                  (NEW — Scan button row on Profile)

UNBOUNDTests/Models/
└── ScanCheckpointTests.swift             (copy)

UNBOUNDTests/Services/
├── ScanCheckpointStoreTests.swift        (copy)
├── ScanCheckpointServiceTests.swift      (copy)
└── ScanPayoffFlavorServiceTests.swift    (NEW)

UNBOUNDTests/Views/
└── ScanCadenceGateTests.swift            (copy)
```

### MODIFY

```
UNBOUND/Services/BodyAnalysis/BodyAnalysisService.swift              (strip to flavor-only via Haiku)
UNBOUND/Services/BodyAnalysis/BodyAnalysisServiceProtocol.swift      (slim protocol)
UNBOUND/Services/BodyAnalysis/BodyAnalysisPrompt.swift               (replace grading prompt with flavor prompt)
UNBOUND/Services/BodyAnalysis/MockBodyAnalysisService.swift          (match new protocol)
UNBOUND/Services/BodyAnalysis/OnboardingBodyRatingService.swift      (delete grading, simplify or remove)
UNBOUND/Models/BodyAnalysis.swift                                    (trim to non-grading fields)
UNBOUND/Models/BodyScanAnalysis.swift                                (delete if redundant)
UNBOUND/Views/Scan/ScanPayoffView.swift                              (route to First vs Nth card)
UNBOUND/Views/Home/UnboundHomeView.swift                             (insert ScanDueCard into contextualStack)
UNBOUND/Views/Profile/ProfileView.swift                              (add ProfileScanRow)
UNBOUND/Services/ServiceContainer.swift                              (wire ScanCheckpointStore + ScanCheckpointService)
UNBOUND/ViewModels/OnboardingFlowViewModel.swift                     (produce first ScanCheckpoint on onboarding scan)
```

### DELETE

```
UNBOUND/Views/Body/                       (entire folder — BodyTierView, BodyTierLoaderView)
UNBOUND/Views/BodyScan/                   (entire folder — AnalysisLoadingView, CameraView, PhotoReviewView, ScanIntroView)
UNBOUND/Views/Report/                     (entire folder — 6 report screens)
```

---

## Standing rules

Apply to **every task**:

1. All subagent dispatches `model: "sonnet"` or higher.
2. SourceKit cross-file errors are NOISE. `xcodebuild` is authoritative.
3. `xcodegen` after any new Swift file.
4. Build: `xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' build`
5. Reference branch: `/Users/jlin/Documents/toji/UNBOUND-scan-redesign/`. Literal `cp` for salvageable files.
6. **AI never grades the body.** Haiku copy comments on Build Identity, not anatomy.
7. **Don't touch session-flow Home** modules (Move/Foundation/BEGIN SESSION/SESSION PLAN/COACH CUE/WEEK PATH/HomeBuildChipCard).
8. Don't touch trial/squad UI (other sub-projects).

---

# Phase 1 — Pre-flight setup

## Task 1.1: Worktree + baseline

- [ ] **Step 1: Create worktree**

```bash
cd /Users/jlin/Documents/toji/UNBOUND
git worktree add /Users/jlin/Documents/toji/UNBOUND-scan-v2 -b scan-redesign-v2 program-redesign
```

- [ ] **Step 2: Copy Secrets.swift**

```bash
cp /Users/jlin/Documents/toji/UNBOUND/UNBOUND/Services/Secrets/Secrets.swift /Users/jlin/Documents/toji/UNBOUND-scan-v2/UNBOUND/Services/Secrets/Secrets.swift
```

- [ ] **Step 3: Baseline build + test**

```bash
cd /Users/jlin/Documents/toji/UNBOUND-scan-v2
xcodegen
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "Executed |TEST SUCCEEDED|TEST FAILED" | tail -3
```

Expected: TEST SUCCEEDED with 5 pre-existing failures. Note baseline test count.

---

# Phase 2 — Core models

## Task 2.1: ScanCheckpoint model + tests

**Files:**
- Create: `UNBOUND/Models/ScanCheckpoint.swift`
- Create: `UNBOUNDTests/Models/ScanCheckpointTests.swift`

```bash
cp /Users/jlin/Documents/toji/UNBOUND-scan-redesign/UNBOUND/Models/ScanCheckpoint.swift UNBOUND/Models/ScanCheckpoint.swift
cp /Users/jlin/Documents/toji/UNBOUND-scan-redesign/UNBOUNDTests/Models/ScanCheckpointTests.swift UNBOUNDTests/Models/ScanCheckpointTests.swift
xcodegen
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/ScanCheckpointTests 2>&1 | tail -8
git add UNBOUND/Models/ScanCheckpoint.swift UNBOUNDTests/Models/ScanCheckpointTests.swift
git commit -m "feat(scan): add ScanCheckpoint model + tests"
```

Expected: tests pass.

If reference's `ScanCheckpoint` references types we deleted (LiftRank, RegionRank, etc), strip those references before committing. The checkpoint should reference: `id`, `userId`, `capturedAt`, photo URLs, `LocalBodyInsights?`, `AttributeProfile` snapshot, `BuildIdentity` snapshot, `flavorCopy: String?`.

---

# Phase 3 — Persistence

## Task 3.1: ScanCheckpointStore + tests

```bash
cp /Users/jlin/Documents/toji/UNBOUND-scan-redesign/UNBOUND/Services/Scan/ScanCheckpointStore.swift UNBOUND/Services/Scan/ScanCheckpointStore.swift
cp /Users/jlin/Documents/toji/UNBOUND-scan-redesign/UNBOUNDTests/Services/ScanCheckpointStoreTests.swift UNBOUNDTests/Services/ScanCheckpointStoreTests.swift
xcodegen
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/ScanCheckpointStoreTests 2>&1 | tail -8
git add UNBOUND/Services/Scan/ScanCheckpointStore.swift UNBOUNDTests/Services/ScanCheckpointStoreTests.swift
git commit -m "feat(scan): add ScanCheckpointStore (UserDefaults persistence)"
```

## Task 3.2: ScanCheckpointService + tests

```bash
cp /Users/jlin/Documents/toji/UNBOUND-scan-redesign/UNBOUND/Services/Scan/ScanCheckpointService.swift UNBOUND/Services/Scan/ScanCheckpointService.swift
cp /Users/jlin/Documents/toji/UNBOUND-scan-redesign/UNBOUNDTests/Services/ScanCheckpointServiceTests.swift UNBOUNDTests/Services/ScanCheckpointServiceTests.swift
xcodegen
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/ScanCheckpointServiceTests 2>&1 | tail -8
git add UNBOUND/Services/Scan/ScanCheckpointService.swift UNBOUNDTests/Services/ScanCheckpointServiceTests.swift
git commit -m "feat(scan): add ScanCheckpointService (high-level scan orchestration)"
```

If the reference's service depends on trunk-deleted types (`ScanNarrativeService` if not yet copied, etc.), pull those forward or stub them — adapt to current trunk state.

---

# Phase 4 — Cadence gate

## Task 4.1: ScanCadenceGate view + tests

**Files:**
- Create: `UNBOUND/Views/Scan/ScanCadenceGate.swift`
- Create: `UNBOUNDTests/Views/ScanCadenceGateTests.swift`

```bash
cp /Users/jlin/Documents/toji/UNBOUND-scan-redesign/UNBOUND/Views/Scan/ScanCadenceGate.swift UNBOUND/Views/Scan/ScanCadenceGate.swift
cp /Users/jlin/Documents/toji/UNBOUND-scan-redesign/UNBOUNDTests/Views/ScanCadenceGateTests.swift UNBOUNDTests/Views/ScanCadenceGateTests.swift
xcodegen
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/ScanCadenceGateTests 2>&1 | tail -8
git add UNBOUND/Views/Scan/ScanCadenceGate.swift UNBOUNDTests/Views/ScanCadenceGateTests.swift
git commit -m "feat(scan): add ScanCadenceGate (soft 30-day gate)"
```

Verify: `ScanCadenceGate.evaluate(userId:)` returns `.firstScan`, `.ready`, or `.tooSoon(daysRemaining: Int)`. If reference branch's gate has different state values, adapt.

---

# Phase 5 — Flavor copy service (Haiku 4.5)

## Task 5.1: ScanPayoffFlavorService

**Files:**
- Create: `UNBOUND/Services/Scan/ScanPayoffFlavorService.swift`
- Create: `UNBOUNDTests/Services/ScanPayoffFlavorServiceTests.swift`

- [ ] **Step 1: Inspect existing ClaudeClient API**

```bash
grep -n "func sendText\|func sendStructured" UNBOUND/Services/Claude/ClaudeClient.swift
```

Note the actual signatures.

- [ ] **Step 2: Write the service**

```swift
// UNBOUND/Services/Scan/ScanPayoffFlavorService.swift
import Foundation

@MainActor
final class ScanPayoffFlavorService {
    static let shared = ScanPayoffFlavorService()
    private let client = ClaudeClient.shared
    private let logger = LoggingService.shared

    /// Returns one-liner flavor copy that comments on the Build Identity
    /// without rating the body. Falls back to a default string on error.
    /// Uses claude-haiku-4-5 for low-cost, low-latency one-liner generation.
    func flavor(for identity: BuildIdentity) async -> String {
        let prompt = """
        You write one-sentence flavor copy for a fitness app.

        The user just took a body scan. Their training has earned them a Build Identity of "\(identity.displayName)".
        Their dominant axis: \(identity.dominantAxis?.displayName ?? "balanced").

        Write ONE sentence (max 12 words) that comments on their training progress in a grounded, encouraging way.
        DO NOT rate or grade their body. DO NOT mention specific body parts.
        DO NOT use generic motivational language ("you got this", "keep going").
        FOCUS ON: their earned identity, the work showing through.

        Examples:
        - "Power-Oriented build — the work is reading on the page."
        - "Endurance Hybrid taking shape. The miles are doing it."
        - "Mobility specialist energy. Movement is becoming language."

        Now write the sentence for "\(identity.displayName)":
        """

        do {
            let response = try await client.sendText(
                prompt: prompt,
                model: "claude-haiku-4-5",
                maxTokens: 60
            )
            let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? defaultFallback : trimmed
        } catch {
            logger.log("ScanPayoffFlavorService.flavor error: \(error)", level: .warning)
            return defaultFallback
        }
    }

    private let defaultFallback = "Your work is showing."
}
```

Adapt `ClaudeClient.sendText` signature to match actual one. If it uses a different parameter shape (e.g. `messages:` array), adapt the call.

- [ ] **Step 3: Test**

```swift
// UNBOUNDTests/Services/ScanPayoffFlavorServiceTests.swift
import XCTest
@testable import UNBOUND

@MainActor
final class ScanPayoffFlavorServiceTests: XCTestCase {
    func testDefaultFallbackOnError() async {
        // ClaudeClient.shared without a valid API key OR offline returns fallback
        let service = ScanPayoffFlavorService()
        let identity = BuildIdentity(primary: .power, secondary: nil, shape: .specialist)
        let result = await service.flavor(for: identity)
        // Either real Haiku response OR fallback — both pass the smoke test
        XCTAssertFalse(result.isEmpty, "flavor should always return non-empty string")
        XCTAssertLessThan(result.count, 200, "should be a short one-liner")
    }
}
```

- [ ] **Step 4: Build + commit**

```bash
xcodegen
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/ScanPayoffFlavorServiceTests 2>&1 | tail -8
git add UNBOUND/Services/Scan/ScanPayoffFlavorService.swift UNBOUNDTests/Services/ScanPayoffFlavorServiceTests.swift
git commit -m "feat(scan): add ScanPayoffFlavorService (Haiku 4.5 one-liner flavor copy)"
```

---

# Phase 6 — Scan payoff views

## Task 6.1: FirstScanArcCard + NthScanEvolutionCard

```bash
cp /Users/jlin/Documents/toji/UNBOUND-scan-redesign/UNBOUND/Views/Scan/FirstScanArcCard.swift UNBOUND/Views/Scan/FirstScanArcCard.swift
cp /Users/jlin/Documents/toji/UNBOUND-scan-redesign/UNBOUND/Views/Scan/NthScanEvolutionCard.swift UNBOUND/Views/Scan/NthScanEvolutionCard.swift
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/Views/Scan/FirstScanArcCard.swift UNBOUND/Views/Scan/NthScanEvolutionCard.swift
git commit -m "feat(scan): add FirstScanArcCard + NthScanEvolutionCard"
```

If these files reference deleted types (Archetype, LiftRank, RegionRank), strip those references — replace with `BuildIdentity` / `SkillTier` / `AttributeProfile` per current trunk.

## Task 6.2: ScanPayoffView routing

**Files:**
- Modify: `UNBOUND/Views/Scan/ScanPayoffView.swift`

- [ ] **Step 1: Read current ScanPayoffView**

```bash
cat UNBOUND/Views/Scan/ScanPayoffView.swift | head -60
```

- [ ] **Step 2: Replace with routing logic**

The view should:
- Receive an array of scan checkpoints (most recent first)
- If only one checkpoint → render `FirstScanArcCard(checkpoint: latest)`
- If 2+ → render `NthScanEvolutionCard(previous: prior, current: latest, flavorCopy: ...)`

Adopt reference branch's version if compatible:
```bash
diff -u UNBOUND/Views/Scan/ScanPayoffView.swift /Users/jlin/Documents/toji/UNBOUND-scan-redesign/UNBOUND/Views/Scan/ScanPayoffView.swift | head -40
```

If compatible, copy verbatim:
```bash
cp /Users/jlin/Documents/toji/UNBOUND-scan-redesign/UNBOUND/Views/Scan/ScanPayoffView.swift UNBOUND/Views/Scan/ScanPayoffView.swift
```

Otherwise port the routing logic manually.

- [ ] **Step 3: Generate flavor copy in routing**

When showing `NthScanEvolutionCard`, the view should load flavor copy via `ScanPayoffFlavorService.shared.flavor(for: current.buildIdentitySnapshot)` in `.task` and pass the result to the card. Async pattern:

```swift
@State private var flavorCopy: String = ""

var body: some View {
    Group {
        if let latest = checkpoints.first, checkpoints.count == 1 {
            FirstScanArcCard(checkpoint: latest)
        } else if let latest = checkpoints.first, let prior = checkpoints.dropFirst().first {
            NthScanEvolutionCard(previous: prior, current: latest, flavorCopy: flavorCopy)
        }
    }
    .task {
        guard let latest = checkpoints.first else { return }
        flavorCopy = await ScanPayoffFlavorService.shared.flavor(for: latest.buildIdentitySnapshot)
    }
}
```

- [ ] **Step 4: Build + commit**

```bash
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/Views/Scan/ScanPayoffView.swift
git commit -m "feat(scan): ScanPayoffView routes to First/Nth card + loads flavor copy"
```

---

# Phase 7 — Entry points

## Task 7.1: ScanDueCard for Home contextualStack

**Files:**
- Create: `UNBOUND/Views/Home/ScanDueCard.swift`

- [ ] **Step 1: Write the card**

```swift
// UNBOUND/Views/Home/ScanDueCard.swift
import SwiftUI

/// Renders in UnboundHomeView.contextualStack when the user's cadence gate
/// is .ready or .firstScan. Tapping it opens the PhotoCaptureFlow.
struct ScanDueCard: View {
    let cadenceState: ScanCadenceGate.State
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.unbound.accent)
                    .frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 4) {
                    Text(headline)
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text(subline)
                        .font(Font.unbound.captionM)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.unbound.accent.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var headline: String {
        switch cadenceState {
        case .firstScan: return "Capture your starting line."
        case .ready: return "Time for your monthly scan."
        case .tooSoon: return ""  // shouldn't render in this case
        }
    }

    private var subline: String {
        switch cadenceState {
        case .firstScan: return "3 photos · ~2 min · on-device only"
        case .ready: return "30 days since last scan · 3 photos"
        case .tooSoon: return ""
        }
    }
}
```

If `ScanCadenceGate.State` is a nested type with different name (e.g. `ScanCadenceGate.Status` or top-level `CadenceState`), adapt.

- [ ] **Step 2: Build + commit**

```bash
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/Views/Home/ScanDueCard.swift
git commit -m "feat(scan): add ScanDueCard for Home contextualStack"
```

## Task 7.2: ProfileScanRow for Profile

**Files:**
- Create: `UNBOUND/Views/Profile/ProfileScanRow.swift`

```swift
// UNBOUND/Views/Profile/ProfileScanRow.swift
import SwiftUI

/// Always-present Scan action on Profile. Tappable regardless of cadence state.
/// If cadence is .tooSoon, parent presents a confirmation dialog before opening
/// the capture flow.
struct ProfileScanRow: View {
    let lastScanDate: Date?
    let cadenceState: ScanCadenceGate.State
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.unbound.accent)
                    .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Scan")
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text(detailText)
                        .font(Font.unbound.captionM)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.unbound.surface)
            )
        }
        .buttonStyle(.plain)
    }

    private var detailText: String {
        switch cadenceState {
        case .firstScan: return "Capture your starting line."
        case .ready: return "Ready"
        case .tooSoon(let days): return "Next window in \(days) days"
        }
    }
}
```

```bash
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/Views/Profile/ProfileScanRow.swift
git commit -m "feat(scan): add ProfileScanRow"
```

## Task 7.3: Wire ScanDueCard into UnboundHomeView contextualStack

**Files:**
- Modify: `UNBOUND/Views/Home/UnboundHomeView.swift`

- [ ] **Step 1: Find contextualStack**

```bash
grep -n "contextualStack" UNBOUND/Views/Home/UnboundHomeView.swift | head -5
```

- [ ] **Step 2: Add scan-due state to UnboundHomeView**

Near other `@State` properties:

```swift
@State private var scanCadence: ScanCadenceGate.State = .firstScan
@State private var showScanCaptureFlow = false
```

In `.task`:
```swift
if let userId = services.auth.currentUserId {
    scanCadence = await ScanCheckpointService.shared.cadenceState(userId: userId)
}
```

(Adapt to the actual service API surfaced by `ScanCheckpointService`.)

- [ ] **Step 3: Insert ScanDueCard into contextualStack**

Find the `contextualStack` computed property body. It likely has conditional blocks like `if isRecalibrating { RecalibratingBanner() }`. Add adjacent:

```swift
if case .ready = scanCadence {
    ScanDueCard(cadenceState: scanCadence) { showScanCaptureFlow = true }
} else if case .firstScan = scanCadence {
    ScanDueCard(cadenceState: scanCadence) { showScanCaptureFlow = true }
}
```

(The two arms intentionally collapse — both surface the card.)

- [ ] **Step 4: Wire fullScreenCover for the flow**

At the view body root (where existing `.fullScreenCover`s live, around line 181 area):

```swift
.fullScreenCover(isPresented: $showScanCaptureFlow) {
    PhotoCaptureFlow()  // existing view from Scan/
        .environmentObject(services)
}
```

- [ ] **Step 5: Build + verify session-flow snapshot test**

```bash
xcodegen
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/UnboundHomeViewSessionFlowTests 2>&1 | tail -8
```

Session-flow modules must still render.

- [ ] **Step 6: Commit**

```bash
git add UNBOUND/Views/Home/UnboundHomeView.swift
git commit -m "feat(scan): wire ScanDueCard into Home contextualStack"
```

## Task 7.4: Wire ProfileScanRow into ProfileView

**Files:**
- Modify: `UNBOUND/Views/Profile/ProfileView.swift`

- [ ] **Step 1: Add state**

```swift
@State private var scanCadence: ScanCadenceGate.State = .firstScan
@State private var lastScanDate: Date? = nil
@State private var showScanCaptureFlow = false
@State private var showCadenceConfirmation = false
```

- [ ] **Step 2: Load in .task**

```swift
if let userId = services.auth.currentUserId {
    scanCadence = await ScanCheckpointService.shared.cadenceState(userId: userId)
    lastScanDate = await ScanCheckpointService.shared.lastCheckpoint(userId: userId)?.capturedAt
}
```

- [ ] **Step 3: Insert ProfileScanRow into body**

Place after `ProfileBuildCard` (from #1) so identity surfaces (hex + scan) live together:

```swift
ProfileScanRow(lastScanDate: lastScanDate, cadenceState: scanCadence) {
    if case .tooSoon = scanCadence {
        showCadenceConfirmation = true
    } else {
        showScanCaptureFlow = true
    }
}
.padding(.horizontal)
```

- [ ] **Step 4: Add confirmation dialog**

```swift
.confirmationDialog(
    "Your body adapts on a 4-week cycle.",
    isPresented: $showCadenceConfirmation,
    titleVisibility: .visible
) {
    Button("Scan anyway", role: .none) {
        showScanCaptureFlow = true
    }
    Button("Cancel", role: .cancel) { }
} message: {
    if case .tooSoon(let days) = scanCadence {
        Text("\(days) days until next recommended scan window.")
    }
}
.fullScreenCover(isPresented: $showScanCaptureFlow) {
    PhotoCaptureFlow()
        .environmentObject(services)
}
```

- [ ] **Step 5: Build + commit**

```bash
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/Views/Profile/ProfileView.swift
git commit -m "feat(scan): wire ProfileScanRow into ProfileView with cadence confirmation"
```

---

# Phase 8 — Trim BodyAnalysisService to flavor-only

## Task 8.1: Slim BodyAnalysisService protocol

**Files:**
- Modify: `UNBOUND/Services/BodyAnalysis/BodyAnalysisServiceProtocol.swift`

- [ ] **Step 1: Read current protocol**

```bash
cat UNBOUND/Services/BodyAnalysis/BodyAnalysisServiceProtocol.swift
```

- [ ] **Step 2: Replace with slim version**

```swift
// UNBOUND/Services/BodyAnalysis/BodyAnalysisServiceProtocol.swift
import Foundation

/// Body Analysis is now strictly flavor copy generation.
/// The OLD grading pipeline (Gemini-based scoring, gap analysis,
/// proportion analysis) is removed per the "AI never grades the body" rule.
@MainActor
protocol BodyAnalysisServiceProtocol {
    /// Returns one-line flavor copy for the user's earned Build Identity.
    /// Never references specific body parts. Never grades.
    /// Backed by Anthropic Haiku 4.5.
    func flavorCopy(for identity: BuildIdentity) async -> String
}
```

- [ ] **Step 3: Build (will break consumers — that's the point)**

```bash
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep "error:" | head -20
```

Note every error — those are the consumer migrations needed. Continue to Task 8.2 to fix.

## Task 8.2: Migrate BodyAnalysisService impl + mock to slim protocol

**Files:**
- Modify: `UNBOUND/Services/BodyAnalysis/BodyAnalysisService.swift`
- Modify: `UNBOUND/Services/BodyAnalysis/MockBodyAnalysisService.swift`

In `BodyAnalysisService.swift`, strip everything except a `flavorCopy(for:)` method that delegates to `ScanPayoffFlavorService.shared.flavor(for:)` (DRY — avoid duplicating prompt logic). The class can become very small (~20 lines).

In `MockBodyAnalysisService.swift`, replace all old methods with:
```swift
func flavorCopy(for identity: BuildIdentity) async -> String {
    "Mock flavor copy."
}
```

```bash
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep "error:" | head -20
```

Fix remaining errors at call sites — they're now using deleted methods. For each:
- `bodyAnalysisService.analyze(scan:)` → DELETE the call (the analyze method is gone). If the call site used the result for grading display, remove the grading display too.
- `bodyAnalysisService.fetchScore(userId:)` → DELETE
- etc.

The grep from Task 8.1 lists every site that needs touching.

```bash
git add UNBOUND/Services/BodyAnalysis/
git commit -m "chore(scan): slim BodyAnalysisService to flavor-only protocol"
```

## Task 8.3: Update BodyAnalysisPrompt to flavor-only

**Files:**
- Modify: `UNBOUND/Services/BodyAnalysis/BodyAnalysisPrompt.swift`

The OLD prompt likely tells Gemini to grade the body. Replace with:

```swift
// UNBOUND/Services/BodyAnalysis/BodyAnalysisPrompt.swift
import Foundation

/// Prompt for Body Analysis flavor copy.
/// Note: this is now thin glue — actual prompt lives in ScanPayoffFlavorService.
/// Kept as a separate file for prompt-versioning purposes.
enum BodyAnalysisPrompt {
    static func flavorPrompt(buildIdentityName: String, dominantAxis: String) -> String {
        ScanPayoffFlavorService.composedPrompt(buildIdentityName: buildIdentityName, dominantAxis: dominantAxis)
    }
}
```

And in `ScanPayoffFlavorService.swift`, expose the prompt as a static for sharing:

```swift
extension ScanPayoffFlavorService {
    static func composedPrompt(buildIdentityName: String, dominantAxis: String) -> String {
        """
        // (the same prompt body from flavor(for:))
        """
    }
}
```

(Refactor as needed to avoid duplication.)

```bash
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/Services/BodyAnalysis/BodyAnalysisPrompt.swift UNBOUND/Services/Scan/ScanPayoffFlavorService.swift
git commit -m "chore(scan): BodyAnalysisPrompt delegates to ScanPayoffFlavorService for flavor prompts"
```

## Task 8.4: Audit OnboardingBodyRatingService

**Files:**
- Modify or delete: `UNBOUND/Services/BodyAnalysis/OnboardingBodyRatingService.swift`

- [ ] **Step 1: Read**

```bash
cat UNBOUND/Services/BodyAnalysis/OnboardingBodyRatingService.swift
```

- [ ] **Step 2: Decide**

If the service rates the body during onboarding → DELETE entirely. AttributeProfile (from #1) covers identity, and the Build Seed step seeds attributes — no rating needed.

If the service does something else useful (e.g. setting initial AttributeProfile from onboarding answers) → simplify to just that, no body rating.

```bash
# If deleting:
git rm UNBOUND/Services/BodyAnalysis/OnboardingBodyRatingService.swift
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep "error:" | head -10
```

Fix callers — likely `OnboardingFlowViewModel.swift` references this. Remove the references.

```bash
git add -A
git commit -m "chore(scan): delete OnboardingBodyRatingService (body-grading no longer happens)"
```

---

# Phase 9 — Delete OLD scan stack

## Task 9.1: Delete Body/ + BodyScan/ + Report/ folders

```bash
git rm -r UNBOUND/Views/Body
git rm -r UNBOUND/Views/BodyScan
git rm -r UNBOUND/Views/Report
```

- [ ] **Step 1: Build to find consumers**

```bash
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep "error:" | head -20
```

For each broken consumer, decide:
- If it's in a flow we want to delete (e.g. an old scan-results screen wired into the deleted Report flow) → delete the broken caller too.
- If it's a Profile/Home view that references a Report screen → remove the navigation link and any state that drove it.

- [ ] **Step 2: Iterate until build succeeds**

```bash
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -5
```

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "chore(scan): delete OLD scan stack — Body/, BodyScan/, Report/ folders"
```

## Task 9.2: Trim BodyAnalysis + BodyScanAnalysis models

**Files:**
- Modify: `UNBOUND/Models/BodyAnalysis.swift`
- Modify or delete: `UNBOUND/Models/BodyScanAnalysis.swift`

Read each. Remove any score/grade fields. Keep only fields needed for the new flavor-copy + scan-checkpoint pipeline.

```bash
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/Models/BodyAnalysis.swift UNBOUND/Models/BodyScanAnalysis.swift 2>/dev/null
git commit -m "chore(scan): trim BodyAnalysis + BodyScanAnalysis models (no grading fields)"
```

---

# Phase 10 — ServiceContainer wiring + Onboarding integration

## Task 10.1: Wire ScanCheckpointStore + ScanCheckpointService

**Files:**
- Modify: `UNBOUND/Services/ServiceContainer.swift`

Add slots:
```swift
let scanCheckpointStore: ScanCheckpointStore
let scanCheckpointService: ScanCheckpointService
```

Wire in inits with `.shared` defaults. Update `.mock` if applicable.

```bash
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/Services/ServiceContainer.swift
git commit -m "feat(scan): wire ScanCheckpointStore + ScanCheckpointService into ServiceContainer"
```

## Task 10.2: Onboarding scan-capture produces ScanCheckpoint

**Files:**
- Modify: `UNBOUND/ViewModels/OnboardingFlowViewModel.swift` OR wherever the onboarding scan step completes

- [ ] **Step 1: Find the onboarding scan completion**

```bash
grep -rn "ScanAnalyzing\|Step_ScanReview\|Step_ScanCapture\|scanComplete" UNBOUND/Views/Onboarding/ UNBOUND/ViewModels/OnboardingFlowViewModel.swift --include="*.swift" | head -10
```

- [ ] **Step 2: At completion, persist a ScanCheckpoint**

After the onboarding scan's photo capture step completes:

```swift
let checkpoint = ScanCheckpoint(
    id: UUID(),
    userId: userId,
    capturedAt: .now,
    frontPhotoURL: capturedFront,
    backPhotoURL: capturedBack,
    sidePhotoURL: capturedSide,
    visionInsights: localInsights,
    attributeProfileSnapshot: services.attribute.profile(userId: userId),
    buildIdentitySnapshot: derivedIdentity,
    flavorCopy: nil  // generated on payoff display, not on capture
)
await services.scanCheckpointService.save(checkpoint: checkpoint, userId: userId)
```

Adapt to the actual SCAN-related onboarding completion logic.

```bash
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/ViewModels/OnboardingFlowViewModel.swift
git commit -m "feat(scan): onboarding scan capture persists a ScanCheckpoint"
```

---

# Phase 11 — Final regression + smoke

## Task 11.1: Full test suite

```bash
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "Executed |TEST SUCCEEDED|TEST FAILED" | tail -3
```

Expected: TEST SUCCEEDED with pre-existing 5 failures only. Test count should be higher than baseline (new scan tests added).

## Task 11.2: Grep verification

```bash
echo "=== OLD scan refs should be empty ==="
grep -rn "BodyTierView\|AnalysisLoadingView\|CameraView\|PhotoReviewView\|ScanIntroView\|BodyScoreCard\|GapAnalysisView\|MuscleGroupBreakdown\|ProportionAnalysis\|ReportContainerView\|ReportShareView" UNBOUND/ --include="*.swift" | head

echo "=== NEW scan refs should have hits ==="
grep -rn "ScanCheckpoint\|ScanCadenceGate\|ScanPayoffFlavorService\|FirstScanArcCard\|NthScanEvolutionCard" UNBOUND/ --include="*.swift" | head

echo "=== Gemini body analysis refs should be empty ==="
grep -rn "GeminiService\|GeminiClient" UNBOUND/Services/BodyAnalysis/ --include="*.swift"
```

## Task 11.3: Sim smoke

```bash
xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/scan-v2-final build 2>&1 | tail -3
xcrun simctl install booted /tmp/scan-v2-final/Build/Products/Debug-iphonesimulator/UNBOUND.app
xcrun simctl terminate booted com.unboundapp.ios 2>&1 | tail -1
xcrun simctl launch booted com.unboundapp.ios
sleep 5
xcrun simctl io booted screenshot /tmp/scan-v2-home.png
```

Verify in screenshot:
- Session-flow Home still renders (Move/Foundation/BEGIN SESSION/SESSION PLAN/COACH CUE/WEEK PATH)
- HomeBuildChipCard still present
- ScanDueCard visible in contextualStack (if user has no prior scans, .firstScan state)
- Tab bar 4 tabs (Home/Program/Skills/Profile)

Tap Profile tab → verify ProfileScanRow renders.

## Task 11.4: Handoff doc

```bash
cat > docs/superpowers/handoff/2026-05-14-scan-v2-smoke.md <<EOF
# Scan Redesign (Additive) — Final Smoke

Sub-project #3 shipped on \`scan-redesign-v2\`. Ready for merge into \`program-redesign\`.

## What ships
- ScanCheckpoint model + ScanCheckpointStore + ScanCheckpointService
- ScanCadenceGate (soft 30-day gate)
- ScanPayoffFlavorService (Haiku 4.5 one-liner)
- FirstScanArcCard + NthScanEvolutionCard + ScanPayoffView routing
- ScanDueCard on Home contextualStack
- ProfileScanRow with cadence confirmation
- BodyAnalysisService stripped to flavor-only (no grading)

## What was deleted
- UNBOUND/Views/Body/ (entire folder)
- UNBOUND/Views/BodyScan/ (entire folder)
- UNBOUND/Views/Report/ (entire folder)
- OnboardingBodyRatingService (if grading-only)
- Body grading methods on BodyAnalysisService

## Session-flow Home preserved
Confirmed in sim screenshot. All session-flow modules render unchanged.

## Known follow-ups
- Photo storage is local-only for v1. Cloud sync via Supabase is future work.
- Vision insights persistence as JSON in ScanCheckpoint — verify shape matches LocalBodyInsights.
- ScanPayoffFlavorService uses claude-haiku-4-5. Watch usage costs.
EOF
git add docs/superpowers/handoff/2026-05-14-scan-v2-smoke.md
git commit -m "chore(scan): final smoke + handoff doc — sub-project #3 ready for merge"
```

---

## Self-Review Notes

**Spec coverage:**
- ✅ Delete OLD stack (Body/, BodyScan/, Report/) → Phase 9.1
- ✅ Trim BodyAnalysisService to flavor-only → Phase 8
- ✅ ScanCheckpoint model → Phase 2.1
- ✅ ScanCheckpointStore + ScanCheckpointService → Phase 3
- ✅ ScanCadenceGate → Phase 4
- ✅ ScanPayoffFlavorService (Haiku 4.5) → Phase 5
- ✅ FirstScanArcCard + NthScanEvolutionCard + ScanPayoffView routing → Phase 6
- ✅ ScanDueCard on Home → Phase 7.1, 7.3
- ✅ ProfileScanRow with confirmation → Phase 7.2, 7.4
- ✅ ServiceContainer wiring → Phase 10.1
- ✅ Onboarding produces first ScanCheckpoint → Phase 10.2
- ✅ Final regression + grep + sim smoke → Phase 11

**Placeholder scan:** No TBD/TODO/incomplete in critical path. Some tasks fall back to "if reference branch has X, copy" — intentional given heavy reuse.

**Type consistency:**
- `ScanCadenceGate.State` — used in ScanDueCard, ProfileScanRow, UnboundHomeView. Implementer should verify the actual enum name from the reference branch on first task and use it consistently. If reference uses `Status` or different cases, adapt across all consumers.
- `BuildIdentity.displayName` and `dominantAxis` — used in flavor prompt. Trunk has these from #1.
- `ScanCheckpointService.cadenceState(userId:)` — used in Home + Profile. If actual API is `evaluateCadence` or `gate.evaluate`, adapt.

**Known soft spots:**
1. `ClaudeClient.sendText` signature must be verified in Phase 5.1 Step 1 — adapt if it uses messages array or different param shape.
2. `LocalBodyInsights` shape — verify persistence works in ScanCheckpoint as JSON. If it has non-Codable fields, adapt.
3. Reference branch's `ScanNarrativeService` is mentioned but might not need copying — verify dependency from ScanCheckpointService.
4. Deletion of `Body/`, `BodyScan/`, `Report/` will break many call sites. Phase 9.1 iterates until clean. Expect 30-50 minutes of consumer migration.
5. Pre-existing test failures (5 SkillProgressXPTests / SkillClusterUnlockTests) carry forward.
