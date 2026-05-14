# Scan v2 Smoke — Handoff 2026-05-14

Branch: `scan-redesign-v2`

## What Shipped (Phases 7–11)

### Entry Points (Phase 7)
- `ScanDueCard` — Home contextualStack card, appears when `cadenceState.isUnlocked || lastScanAt == nil`
- `ProfileScanRow` — Profile page row, below ProfileBuildCard, cadence-gated with confirmation dialog
- Both wired to `PhotoCaptureFlow(mode: .scan)` via `fullScreenCover`
- Cadence refreshes on dismiss

### Body Analysis Slim (Phase 8)
- `BodyAnalysisServiceProtocol` is now a single method: `flavorCopy(for identity: BuildIdentity) async -> String`
- `BodyAnalysisService` delegates entirely to `ScanPayoffFlavorService`
- `MockBodyAnalysisService` returns fixed mock copy
- `BodyAnalysisPrompt.swift` emptied (old Gemini prompt removed)
- `OnboardingBodyRatingService` deleted — AI never grades the body
- `Step_ScanAnalyzing` simplified: no Gemini wait, completes when 6s animation finishes

### OLD Stack Deleted (Phase 9)
**View folders removed:**
- `UNBOUND/Views/Body/` — BodyTierLoaderView, BodyTierView
- `UNBOUND/Views/BodyScan/` — AnalysisLoadingView, CameraView, PhotoReviewView, ScanIntroView
- `UNBOUND/Views/Report/` — BodyScoreCard, GapAnalysisView, MuscleGroupBreakdown, ProportionAnalysis, ReportContainerView, ReportShareView

**Models removed:**
- `BodyScanAnalysis.swift` (+ AestheticScores, BodyAnalysisError)
- `OnboardingBodyRatings.swift`

**ViewModels removed:**
- `BodyScanViewModel.swift`
- `ReportViewModel.swift`

**Services removed:**
- `BodyTierLoader.swift`

**Consumer migration:**
- `UnboundSkillTreeTabView` — `bodyTierLink` replaced with `EmptyView()`
- `ProgressTimelineView` — ScanIntroView FABs replaced with redirect text
- `RescanView` — now wraps `PhotoCaptureFlow`
- `OnboardingFlowViewModel` — `bodyRatings` + `scanAnalysis` properties removed

### ServiceContainer (Phase 10)
- `scanCheckpointStore: ScanCheckpointStore` added
- `scanCheckpointService: ScanCheckpointService` added
- Both init paths wired to `.shared`

### Onboarding → ScanCheckpoint (Phase 10)
- `Step_ScanAnalyzing.runLocalBodyInsights()` now calls `ScanCheckpointService.shared.commit()` after Vision analysis
- Onboarding day-zero photo persists as the user's first ScanCheckpoint
- Fire-and-forget — failure is silent, user always proceeds to Verdict

## Session-Flow Home — Preservation Confirmed
Modules rendered on smoke screenshot:
- Greeting / briefing title: ✓ ("Move, Dev")
- Foundation subhead: ✓ ("Foundation · Legs is ready. 4 main lifts, about 45 minutes.")
- TODAY STATUS pill: ✓
- BEGIN SESSION button: ✓ (visible behind auth dialog)
- SESSION PLAN (exercises): ✓ (Front squat, Goblet squat)
- COACH CUE: ✓ ("Keep the first lift crisp: Back squat…")
- WEEK PATH, HomeBuildChipCard: present in scroll (below fold)

Screenshot: `/tmp/scan-v2-home.png`

## Test Results
- Total: 280 tests
- Failures: 5 (pre-existing — SkillClusterUnlockTests + SkillProgressXPTests, unrelated to scan)
- New failures introduced by scan work: 0

## Known Follow-ups
- `BodyAnalysis.swift` model still exists — used by `ProgramGenerationService.generateProgram(analysis:)`. Trimming it requires a ProgramGeneration refactor (out of scope for this sub-project).
- `BodyScan.swift` model still exists — used by `ScanContextBuilder` for the ScanComparison path (ScanComparisonService is still live for coach context injection).
- Heatmap slot in ProfileView is still a placeholder (per design memory — intentional).
- `ProgressTimelineView` shows legacy "overall score" cards from database — this view may need full replacement once ProgressEntry model is retired.

## Status
**READY FOR MERGE** — all new scan pipeline is live, all old scan grading code is removed, build clean, 5 pre-existing test failures only.
