# Scan Redesign — Additive Design (sub-project #3)

**Status:** Spec.
**Branch:** New `scan-redesign-v2` off current `program-redesign` HEAD (which has #1+#2+#4 merged).
**Supersedes:** `2026-05-08-scan-redesign-design.md` and the `scan-redesign-impl` reference branch's spec.
**Reference:** `/Users/jlin/Documents/toji/UNBOUND-scan-redesign/` — partial code reuse (cadence gate, before/after view components).

---

## Goal

Collapse two parallel scan stacks into one. Delete the OLD pipeline (Body/, BodyScan/, Report/ folders + Gemini body-grading). Standardize on the NEW pipeline (Scan/ folder + Apple Vision + ScanBuildDeltaCard from #1). Add a soft 30-day cadence gate and Anthropic-based flavor copy (Haiku 4.5).

## Hard philosophy constraints

Per memory `project_unbound_scan_not_source_of_truth`, `project_unbound_scan_philosophy`, `project_unbound_scans_never_show_setbacks`:

- **Scan = transformation anchor**, NEVER body-rating engine.
- **AI never grades the body.** Sonnet/Haiku writes flavor copy around already-derived attributes; the hex delta comes from training data, not the scan.
- **Apple Vision on-device only** for body measurement extraction. No cloud body analysis.
- **Never surface regression** — scan deltas show gains, holds, or "focus areas" only. ±2-3% is noise.
- **Monthly cadence** — daily training / weekly trials / monthly scan.

## Hard additive constraint

Session-flow Home modules untouched:
- "Move, [Name]" greeting
- Foundation/Push subhead
- TODAY STATUS hero
- BEGIN SESSION
- SESSION PLAN
- COACH CUE
- WEEK PATH
- HomeBuildChipCard (from #1)

The contextualStack slot on Home is where the new "Scan due" card appears. That slot already exists for Recalibrating/Plateau/Day-one cal — Scan due is one more contextual option in the same slot.

## Out of scope

- Trials (#5) — separate spec
- Squads (#6) — separate spec

---

## What dies

### Folders deleted entirely
- `UNBOUND/Views/Body/` — BodyTierView, BodyTierLoaderView (old tier-based body display)
- `UNBOUND/Views/BodyScan/` — AnalysisLoadingView, CameraView, PhotoReviewView, ScanIntroView (old scan flow)
- `UNBOUND/Views/Report/` — BodyScoreCard, GapAnalysisView, MuscleGroupBreakdown, ProportionAnalysis, ReportContainerView, ReportShareView (the Gemini-grading report screens)

### Services modified
- `UNBOUND/Services/BodyAnalysis/BodyAnalysisService.swift` — remove all body-grading methods (anything that returns a score, ranking, or grade). Strip down to ONE method: `func flavorCopy(for buildIdentity: BuildIdentity) async -> String` using Anthropic Haiku 4.5.
- `UNBOUND/Services/BodyAnalysis/BodyAnalysisPrompt.swift` — replace Gemini prompt with Haiku prompt for flavor copy only.
- `UNBOUND/Services/BodyAnalysis/MockBodyAnalysisService.swift` — match new minimal protocol.
- `UNBOUND/Services/BodyAnalysis/OnboardingBodyRatingService.swift` — verify it doesn't grade; if it does, simplify or delete.

### Models deleted
- `UNBOUND/Models/BodyAnalysis.swift` — if it carries grade/score fields, slim to just `buildIdentitySnapshot: String?` (already done in #1) + photo references.
- `UNBOUND/Models/BodyScanAnalysis.swift` — verify it's still needed; delete if redundant with `BodyScan`.

## What ships

### Models (mostly already in trunk)
- `UNBOUND/Models/ScanCheckpoint.swift` — NEW. The per-scan record: id, timestamp, photo URLs, vision measurements snapshot, AttributeProfile snapshot at time of scan, build identity snapshot, optional flavor copy.
- `UNBOUND/Models/BodyScan.swift` — keep, simplify.

### Services
- `UNBOUND/Services/Scan/ScanCadenceGate.swift` — NEW. Returns `.ready` (30+ days elapsed), `.tooSoon(daysRemaining: Int)` (within 30-day window), or `.firstScan` (no scans yet).
- `UNBOUND/Services/Scan/ScanCheckpointStore.swift` — NEW. Persists `[ScanCheckpoint]` per user in UserDefaults.
- `UNBOUND/Services/Scan/ScanComparisonService.swift` — keep (already on trunk). Computes before/after for photo presentation.
- `UNBOUND/Services/Scan/ScanContextBuilder.swift` — keep (LiftRank refs already removed in rank cleanup).
- `UNBOUND/Services/BodyAnalysis/LocalBodyInsightsService.swift` — keep. Apple Vision body measurements (silhouette outline, proportions). On-device only.
- `UNBOUND/Services/Scan/ScanPayoffFlavorService.swift` — NEW. Tiny wrapper around `ClaudeService` (existing Anthropic integration) that requests one-liner flavor copy via Haiku 4.5. Bounded to 1 request per scan, retries on failure, falls back to "Your work is showing." on error.

### UI (most exists, some new)
- `UNBOUND/Views/Scan/PhotoCaptureFlow.swift` — exists. The capture flow.
- `UNBOUND/Views/Scan/ScanConsentModal.swift` — exists. Per-scan consent / opt-out.
- `UNBOUND/Views/Scan/ScanPayoffView.swift` — exists, refined. Renders photos + ScanBuildDeltaCard + flavor copy.
- `UNBOUND/Views/Scan/ScanBuildDeltaCard.swift` — exists (added in #1). Hex delta visualization.
- `UNBOUND/Views/Scan/FirstScanArcCard.swift` — NEW (copy from reference branch). First-scan empty state — different copy than Nth scan.
- `UNBOUND/Views/Scan/NthScanEvolutionCard.swift` — NEW (copy from reference branch). Subsequent-scan payoff variant.
- `UNBOUND/Views/Scan/ScanCadenceGate.swift` — NEW. Tiny view component that renders the "Next scan in N days" or "Scan now" state.
- `UNBOUND/Views/Home/ScanDueCard.swift` — NEW. The contextualStack card on Home when cadence allows scan.
- `UNBOUND/Views/Profile/ProfileScanRow.swift` — NEW. The Profile entry button.

---

## UI integration

### Home (`UnboundHomeView.swift`)
- In `contextualStack` (the existing slot that holds Recalibrating/Plateau/Scan-due cards), conditionally insert `ScanDueCard` when `ScanCadenceGate.evaluate(userId:)` returns `.ready` or `.firstScan`.
- ScanDueCard tap → present PhotoCaptureFlow via `.fullScreenCover`.

### Profile (`ProfileView.swift`)
- Add `ProfileScanRow` somewhere in the existing identity surfaces. Shows last scan date + tap-to-scan button.
- Tap → PhotoCaptureFlow regardless of cadence state. If `.tooSoon(daysRemaining:)`, present soft confirmation dialog: "Your body adapts on a 4-week cycle. {N} days until next scan window. Scan anyway?" with Cancel / Scan Anyway buttons.

### Capture flow
- `PhotoCaptureFlow` captures front + back + side photos (existing).
- Each photo runs through `LocalBodyInsightsService` for on-device Vision analysis.
- After all photos captured: present `ScanPayoffView`.

### Payoff
- If first scan → `FirstScanArcCard` ("Your starting line. The work begins.")
- If Nth scan → `NthScanEvolutionCard` rendering:
  - Before / After photo strip (using `ScanComparisonService`)
  - `ScanBuildDeltaCard` showing hex delta from training (NOT scan-derived)
  - Flavor copy line from `ScanPayoffFlavorService` (Haiku 4.5)
- `ScanCheckpoint` written to `ScanCheckpointStore`.

---

## Data flow

### Scan trigger
User taps ScanDueCard on Home OR Scan row on Profile.

### Cadence check
1. `ScanCadenceGate.evaluate(userId:)` reads store, returns state.
2. If `.firstScan` → proceed directly.
3. If `.ready` → proceed directly.
4. If `.tooSoon(daysRemaining:)` → show soft dialog. User can Cancel or Override.

### Capture
1. `ScanConsentModal` — first time only. Apple Vision on-device disclosure.
2. `PhotoCaptureFlow` — captures 2-3 photos.
3. For each, `LocalBodyInsightsService.analyze(image:)` returns silhouette + measurements (on-device).

### Persist
1. Build `ScanCheckpoint` with photos, vision data, current `AttributeProfile` snapshot, current `BuildIdentity`.
2. `ScanCheckpointStore.save(checkpoint:userId:)`.

### Payoff
1. If first scan: `FirstScanArcCard`.
2. Else:
   - `ScanComparisonService.compare(prior:current:)` → before/after pair.
   - Read current `AttributeProfile` and prior snapshot from previous checkpoint.
   - `ScanPayoffFlavorService.flavor(for: currentBuildIdentity)` returns one-liner via Haiku 4.5.
   - Render `NthScanEvolutionCard` with photo strip + ScanBuildDeltaCard + flavor copy.

---

## ScanPayoffFlavorService (Haiku 4.5 spec)

```swift
@MainActor
final class ScanPayoffFlavorService {
    static let shared = ScanPayoffFlavorService()
    private let claude = ClaudeService.shared  // existing Anthropic integration

    /// Returns one-liner flavor copy that comments on the build identity without rating the body.
    /// Falls back to "Your work is showing." on error.
    /// Uses claude-haiku-4-5.
    func flavor(for identity: BuildIdentity, attributesSnapshot: AttributeProfile) async -> String {
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
            let response = try await claude.complete(
                prompt: prompt,
                model: "claude-haiku-4-5",
                maxTokens: 60
            )
            return response.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return "Your work is showing."
        }
    }
}
```

Adapt the `ClaudeService.complete` signature to whatever the existing service exposes.

---

## ScanCheckpoint model

```swift
struct ScanCheckpoint: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let userId: String
    let capturedAt: Date
    let frontPhotoURL: URL?
    let backPhotoURL: URL?
    let sidePhotoURL: URL?
    let visionInsights: LocalBodyInsights?  // on-device Vision results
    let attributeProfileSnapshot: AttributeProfile
    let buildIdentitySnapshot: BuildIdentity
    let flavorCopy: String?  // pre-generated, persisted on capture
}
```

---

## Deletions list (consolidated)

```
git rm -r UNBOUND/Views/Body
git rm -r UNBOUND/Views/BodyScan
git rm -r UNBOUND/Views/Report
git rm UNBOUND/Models/BodyScanAnalysis.swift  # if redundant
# (BodyAnalysis.swift trimmed, not deleted)
```

Plus all callers of these screens migrated to the new Scan/ flow.

---

## Acceptance criteria

1. **Session-flow snapshot test passes** — `UnboundHomeViewSessionFlowTests` continues to pass.
2. **Old scan screens not referenced** — `grep -rn "BodyTierView\|AnalysisLoadingView\|CameraView\|PhotoReviewView\|ScanIntroView\|BodyScoreCard\|GapAnalysisView\|MuscleGroupBreakdown\|ProportionAnalysis\|ReportContainerView\|ReportShareView" UNBOUND/ --include="*.swift"` returns nothing.
3. **No Gemini in body analysis** — `grep -rn "GeminiService\|GeminiClient" UNBOUND/Services/BodyAnalysis/` returns nothing (Gemini may stay in other contexts like coach copy if it's there, but NOT in body analysis).
4. **Cadence gate** — fresh user state shows `.firstScan` → tapping scan-due card proceeds. Mock a scan from 10 days ago → `.tooSoon(20)`. Mock a scan from 31 days ago → `.ready`.
5. **Manual sim verification** — Home shows ScanDueCard when cadence ready. PhotoCaptureFlow captures and persists. ScanPayoffView renders photo strip + hex delta + flavor copy.
6. **Build clean** — full test suite passes (5 pre-existing failures from earlier OK).

---

## Architecture decisions to lock in the plan

1. **`ClaudeService.complete(prompt:model:maxTokens:)`** — verify the actual signature. If different, adapt.
2. **Photo storage** — local URLs in the user's documents directory? Cloud-synced via Supabase? For v1, local only. Future PR can add sync.
3. **Vision measurement persistence** — `LocalBodyInsights` shape: serialize as JSON inside `ScanCheckpoint`, or only persist photo URLs and re-run Vision on-demand? For v1, persist the snapshot.
4. **First-scan onboarding flow** — onboarding already has a scan-capture step. Make sure that produces a `ScanCheckpoint` so the first post-onboarding cadence is correct.
5. **Photo deletion policy** — what happens when a checkpoint is overwritten or scrolled past 12 scans? For v1, keep all. Future PR can age out old photos.

---

## Related memory
- [[project_unbound_scan_philosophy]] — Apple Vision only, anchor not grade
- [[project_unbound_scan_not_source_of_truth]] — Gemini/AI never grades body
- [[project_unbound_scans_never_show_setbacks]] — gains/holds/focus areas only
- [[project_unbound_create_your_own_arc]] — daily/weekly/monthly cadence
- [[feedback_unbound_additive_not_redesign]] — session-flow Home preserved
- [[feedback_verify_visual_diff_before_claiming_additive]] — screenshot sim before merge
