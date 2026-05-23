# Ascension Tier (Additive) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace SubRank E-S display with a 9-tier ladder (Initiate → Ascendant) for per-skill, per-lift, and aggregate rank — preserving session-flow Home.

**Architecture:** Reuse `RankTitle` enum already on trunk (added in #1+#2). Add tier criteria, evaluator, state, store, migration. Wire `TierBadge` into skill tree nodes; swap aggregate rank chip text-source on Home. Cinematic only fires for top 3 tiers (Vessel/Unbound/Ascendant); lower crossings get `TierBloomToast`. One-time migration replays existing workout logs.

**Tech Stack:** Swift 5.9+, SwiftUI iOS 17+, XCTest, UserDefaults, NotificationCenter.

**Spec:** [`docs/superpowers/specs/2026-05-14-ascension-tier-additive-design.md`](../specs/2026-05-14-ascension-tier-additive-design.md).

**Reference branch:** `/Users/jlin/Documents/toji/UNBOUND-ascension-tier/` — has the salvageable models, evaluators, criteria JSON, TierBadge, migration logic. Copy verbatim where indicated.

**Worktree:** Create `/Users/jlin/Documents/toji/UNBOUND-ascension-v2` on new branch `ascension-tier-v2` off `program-redesign` HEAD (which now has #1+#2 merged).

---

## File Structure

### CREATE (copy from reference unless noted)

```
UNBOUND/Models/
├── SkillTier.swift                       (NEW — typealias SkillTier = RankTitle, or wrapper enum)
├── TierCriterion.swift                   (copy)
├── UserSkillTierState.swift              (copy)
├── LiftTierState.swift                   (NEW — separate file; reference may co-locate)
└── LiftTierCriteria.swift                (copy)

UNBOUND/Resources/
├── SkillTierCriteria.json                (copy)
└── LiftTierCriteria.json                 (copy if reference has it)

UNBOUND/Services/Ranking/
├── TierCriterionEvaluator.swift          (copy)
├── UserSkillTierStore.swift              (copy)
├── LiftTierService.swift                 (NEW or copy if reference has)
└── SkillTierMigration.swift              (copy)

UNBOUND/Views/Components/Unbound/
├── TierBadge.swift                       (copy)
└── TierBloomToast.swift                  (NEW — light-touch toast for crossings #1-#6)

UNBOUNDTests/Models/
├── SkillTierTests.swift                  (copy)
├── TierCriterionTests.swift              (copy)
├── UserSkillTierStateTests.swift         (copy)
├── LiftTierCriteriaTests.swift           (copy)
└── *SkillTiersTests.swift                (cluster-specific tier tests — copy all)

UNBOUNDTests/Services/
├── TierCriterionEvaluatorTests.swift     (copy)
├── UserSkillTierStoreTests.swift         (copy)
└── SkillTierMigrationTests.swift         (copy)
```

### MODIFY

```
UNBOUND/Views/Home/UnboundHomeView.swift                    (aggregate rank chip text-source swap)
UNBOUND/Views/Home/UnboundSkillTreeTabView.swift            (TierBadge on each node)
UNBOUND/Views/Profile/ProfileView.swift                     (tier names in rank surfaces)
UNBOUND/Views/Components/Cinematic/RankUpCinematic.swift    (gate to top-3-tier crossings)
UNBOUND/Services/WorkoutLog/WorkoutLogService.swift         (add TierCriterionEvaluator.evaluate hook)
UNBOUND/Services/Ranking/RankService.swift                  (aggregateTier(userId:) returns RankTitle)
UNBOUND/Services/Ranking/RankServiceProtocol.swift          (match RankService)
UNBOUND/Services/ServiceContainer.swift                     (wire UserSkillTierStore + LiftTierService)
UNBOUND/Models/SkillTreeContent.swift                       (cluster tier criteria tables)
UNBOUND/App/AniBodyApp.swift                                (first-launch migration hook)
```

### DELETE (legacy display types — keep SubRank for internal math)

```
UNBOUND/Models/LiftRank.swift                               (replaced by LiftTierState)
UNBOUND/Views/Components/RankBadge.swift                    (replaced by TierBadge)
```

**KEEP intact:**
- `SubRank.swift` — internal math, AttributeValue uses it; not user-facing
- `RankTitle` enum (inside SubRank.swift) — this IS our SkillTier
- `RankState.swift` — only its API surface is letter-grade-deprecated; structure stays
- All session-flow Home elements

---

## Standing rules

Apply to **every task**:

1. All subagent dispatches `model: "sonnet"` or higher.
2. SourceKit cross-file errors are NOISE. `xcodebuild` is authoritative.
3. `xcodegen` after any new Swift file.
4. Build: `xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' build`
5. Test: `xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/<Suite>`
6. Reference branch: `/Users/jlin/Documents/toji/UNBOUND-ascension-tier/`. Literal `cp` for salvageable files.
7. **Don't delete SubRank.swift.** AttributeValue (from #1) depends on it. The 9-tier RankTitle ALREADY lives inside SubRank.swift.
8. **Don't touch scan flow.** That's #3's scope.
9. Use `RankTitle` everywhere — don't create a parallel `SkillTier` enum.

---

# Phase 1 — Pre-flight setup

## Task 1.1: Worktree + baseline

- [ ] **Step 1: Create worktree**

```bash
cd /Users/jlin/Documents/toji/UNBOUND
git worktree add /Users/jlin/Documents/toji/UNBOUND-ascension-v2 -b ascension-tier-v2 program-redesign
```

- [ ] **Step 2: Copy Secrets**

```bash
cp /Users/jlin/Documents/toji/UNBOUND/UNBOUND/Services/Secrets/Secrets.swift /Users/jlin/Documents/toji/UNBOUND-ascension-v2/UNBOUND/Services/Secrets/Secrets.swift
```

- [ ] **Step 3: Baseline build + test**

```bash
cd /Users/jlin/Documents/toji/UNBOUND-ascension-v2
xcodegen
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "Executed |TEST SUCCEEDED|TEST FAILED" | tail -3
```

Expected: TEST SUCCEEDED. Note test count for comparison after the PR.

---

# Phase 2 — Models

## Task 2.1: SkillTier typealias (or rename helper)

**Files:**
- Create: `UNBOUND/Models/SkillTier.swift`

- [ ] **Step 1: Add typealias + helper**

```swift
import Foundation

/// SkillTier is the same 9-tier ladder as RankTitle.
/// This typealias gives the new domain (per-skill/per-lift/aggregate)
/// a name that reads naturally at call sites.
typealias SkillTier = RankTitle

extension SkillTier {
    /// The 3 cinematic-tier values. Crossings into these tiers fire
    /// RankUpCinematic; lower crossings fire TierBloomToast.
    static let cinematicTiers: Set<SkillTier> = [.vessel, .unbound, .ascendant]

    var isCinematic: Bool { Self.cinematicTiers.contains(self) }
}
```

- [ ] **Step 2: Build**

```bash
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
```

- [ ] **Step 3: Commit**

```bash
git add UNBOUND/Models/SkillTier.swift
git commit -m "feat(rank): add SkillTier typealias + cinematic-tier set"
```

## Task 2.2: TierCriterion + tests

```bash
cp /Users/jlin/Documents/toji/UNBOUND-ascension-tier/UNBOUND/Models/TierCriterion.swift UNBOUND/Models/TierCriterion.swift
cp /Users/jlin/Documents/toji/UNBOUND-ascension-tier/UNBOUNDTests/Models/TierCriterionTests.swift UNBOUNDTests/Models/TierCriterionTests.swift
xcodegen
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/TierCriterionTests 2>&1 | tail -8
git add UNBOUND/Models/TierCriterion.swift UNBOUNDTests/Models/TierCriterionTests.swift
git commit -m "feat(rank): add TierCriterion model + tests"
```

## Task 2.3: UserSkillTierState + tests

```bash
cp /Users/jlin/Documents/toji/UNBOUND-ascension-tier/UNBOUND/Models/UserSkillTierState.swift UNBOUND/Models/UserSkillTierState.swift
cp /Users/jlin/Documents/toji/UNBOUND-ascension-tier/UNBOUNDTests/Models/UserSkillTierStateTests.swift UNBOUNDTests/Models/UserSkillTierStateTests.swift
xcodegen
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/UserSkillTierStateTests 2>&1 | tail -8
git add UNBOUND/Models/UserSkillTierState.swift UNBOUNDTests/Models/UserSkillTierStateTests.swift
git commit -m "feat(rank): add UserSkillTierState model + tests"
```

## Task 2.4: LiftTierCriteria + tests

```bash
cp /Users/jlin/Documents/toji/UNBOUND-ascension-tier/UNBOUND/Models/LiftTierCriteria.swift UNBOUND/Models/LiftTierCriteria.swift
cp /Users/jlin/Documents/toji/UNBOUND-ascension-tier/UNBOUNDTests/Models/LiftTierCriteriaTests.swift UNBOUNDTests/Models/LiftTierCriteriaTests.swift
xcodegen
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/LiftTierCriteriaTests 2>&1 | tail -8
git add UNBOUND/Models/LiftTierCriteria.swift UNBOUNDTests/Models/LiftTierCriteriaTests.swift
git commit -m "feat(rank): add LiftTierCriteria + tests"
```

## Task 2.5: SkillTier model tests + per-cluster tier table tests

The reference branch has multiple `*SkillTiersTests.swift` (CalSkillTiersTests, HsSkillTiersTests, etc.) — one per skill cluster. These exercise the cluster-specific tier criteria tables.

```bash
cp /Users/jlin/Documents/toji/UNBOUND-ascension-tier/UNBOUNDTests/Models/SkillTierTests.swift UNBOUNDTests/Models/SkillTierTests.swift
for f in CalSkillTiersTests CoSkillTiersTests HsSkillTiersTests OahSkillTiersTests PlSkillTiersTests PpSkillTiersTests; do
    cp "/Users/jlin/Documents/toji/UNBOUND-ascension-tier/UNBOUNDTests/Models/${f}.swift" "UNBOUNDTests/Models/${f}.swift"
done
xcodegen
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/SkillTierTests 2>&1 | tail -8
```

If `*SkillTiersTests` reference cluster-specific tier tables that haven't been wired yet, expect failures — fix in Phase 4. For now, commit what compiles:

```bash
git add UNBOUNDTests/Models/SkillTierTests.swift UNBOUNDTests/Models/*SkillTiersTests.swift
git commit -m "feat(rank): add SkillTier + per-cluster tier table tests (gated until criteria wired)"
```

---

# Phase 3 — Resources

## Task 3.1: SkillTierCriteria.json

```bash
cp /Users/jlin/Documents/toji/UNBOUND-ascension-tier/UNBOUND/Resources/SkillTierCriteria.json UNBOUND/Resources/SkillTierCriteria.json 2>/dev/null || \
  echo "If reference doesn't have this exact file, check Resources/ for tier criteria JSON"

# Verify Resources/ is a bundle path in project.yml
grep -A 3 "resources\|UNBOUND/Resources" project.yml | head
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/Resources/SkillTierCriteria.json project.yml
git commit -m "feat(rank): add SkillTierCriteria.json"
```

If the criteria are encoded directly in Swift code (no JSON) in the reference branch, skip this task — they'll land via Phase 4 instead.

## Task 3.2: LiftTierCriteria.json (if applicable)

Same pattern as 3.1. If `LiftTierCriteria` is data-only (lives in `Models/LiftTierCriteria.swift` as static constants), this task is skipped.

---

# Phase 4 — TierCriterionEvaluator

## Task 4.1: Evaluator + tests

```bash
cp /Users/jlin/Documents/toji/UNBOUND-ascension-tier/UNBOUND/Services/Ranking/TierCriterionEvaluator.swift UNBOUND/Services/Ranking/TierCriterionEvaluator.swift
cp /Users/jlin/Documents/toji/UNBOUND-ascension-tier/UNBOUNDTests/Services/TierCriterionEvaluatorTests.swift UNBOUNDTests/Services/TierCriterionEvaluatorTests.swift
xcodegen
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/TierCriterionEvaluatorTests 2>&1 | tail -10
git add UNBOUND/Services/Ranking/TierCriterionEvaluator.swift UNBOUNDTests/Services/TierCriterionEvaluatorTests.swift
git commit -m "feat(rank): add TierCriterionEvaluator + tests"
```

## Task 4.2: SkillTreeContent cluster tier tables

The reference branch added `static let tierCriteria: [...]` properties to each skill cluster definition inside `SkillTreeContent.swift`. We need those criteria tables for the `*SkillTiersTests` to pass.

```bash
diff -u UNBOUND/Models/SkillTreeContent.swift /Users/jlin/Documents/toji/UNBOUND-ascension-tier/UNBOUND/Models/SkillTreeContent.swift | head -60
```

If the diff is large, copy verbatim:

```bash
cp /Users/jlin/Documents/toji/UNBOUND-ascension-tier/UNBOUND/Models/SkillTreeContent.swift UNBOUND/Models/SkillTreeContent.swift
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -5
```

If the copy doesn't compile (trunk has things reference branch doesn't), manually port only the `tierCriteria` additions.

```bash
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/CalSkillTiersTests -only-testing:UNBOUNDTests/PlSkillTiersTests 2>&1 | tail -8
git add UNBOUND/Models/SkillTreeContent.swift
git commit -m "feat(rank): wire per-cluster tier criteria tables into SkillTreeContent"
```

Expected: all `*SkillTiersTests` pass now.

---

# Phase 5 — Persistence (UserSkillTierStore + LiftTierService)

## Task 5.1: UserSkillTierStore + tests

```bash
cp /Users/jlin/Documents/toji/UNBOUND-ascension-tier/UNBOUND/Services/Ranking/UserSkillTierStore.swift UNBOUND/Services/Ranking/UserSkillTierStore.swift
cp /Users/jlin/Documents/toji/UNBOUND-ascension-tier/UNBOUNDTests/Services/UserSkillTierStoreTests.swift UNBOUNDTests/Services/UserSkillTierStoreTests.swift
xcodegen
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/UserSkillTierStoreTests 2>&1 | tail -8
git add UNBOUND/Services/Ranking/UserSkillTierStore.swift UNBOUNDTests/Services/UserSkillTierStoreTests.swift
git commit -m "feat(rank): add UserSkillTierStore (UserDefaults persistence)"
```

## Task 5.2: LiftTierService

If the reference branch has `LiftTierService.swift`, copy. Otherwise create one with this minimal surface:

```swift
// UNBOUND/Services/Ranking/LiftTierService.swift
import Foundation

@MainActor
final class LiftTierService {
    static let shared = LiftTierService()
    private let key = "unbound.liftTier."
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Returns the current tier for the given lift across all users.
    /// Maintained per user via UserDefaults.
    func tier(lift: String, userId: String) -> SkillTier {
        let saved = defaults.string(forKey: key + "\(userId).\(lift)")
        return saved.flatMap(SkillTier.init(rawValue:)) ?? .initiate
    }

    func save(tier: SkillTier, lift: String, userId: String) {
        defaults.set(tier.rawValue, forKey: key + "\(userId).\(lift)")
    }
}
```

```bash
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/Services/Ranking/LiftTierService.swift
git commit -m "feat(rank): add LiftTierService (per-lift tier persistence)"
```

---

# Phase 6 — Migration

## Task 6.1: SkillTierMigration

```bash
cp /Users/jlin/Documents/toji/UNBOUND-ascension-tier/UNBOUND/Services/Ranking/SkillTierMigration.swift UNBOUND/Services/Ranking/SkillTierMigration.swift
cp /Users/jlin/Documents/toji/UNBOUND-ascension-tier/UNBOUNDTests/Services/SkillTierMigrationTests.swift UNBOUNDTests/Services/SkillTierMigrationTests.swift 2>/dev/null || echo "no migration tests in reference"
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
```

If tests exist, run them:

```bash
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/SkillTierMigrationTests 2>&1 | tail -8
```

```bash
git add UNBOUND/Services/Ranking/SkillTierMigration.swift UNBOUNDTests/Services/SkillTierMigrationTests.swift 2>/dev/null
git commit -m "feat(rank): add SkillTierMigration (one-time replay of existing logs)"
```

## Task 6.2: Wire migration into app launch

Find the root view `.task` block (was modified in #1 for AttributeService backfill):

```bash
grep -n "backfillFromExistingLogs\|attribute.backfill" UNBOUND/App/AniBodyApp.swift
```

Adjacent to the existing attribute backfill call, add:

```swift
await SkillTierMigration.shared.migrateIfNeeded(userId: userId)
```

(Adapt to the actual function name in the reference branch's SkillTierMigration.swift.)

```bash
git add UNBOUND/App/AniBodyApp.swift
git commit -m "feat(rank): wire SkillTierMigration into first-launch task"
```

---

# Phase 7 — WorkoutLogService hook

## Task 7.1: TierCriterionEvaluator.evaluate hook in saveLog

In `UNBOUND/Services/WorkoutLog/WorkoutLogService.swift`, after the `AttributeService.ingest(...)` call (added in #1) and before the trailing `logger.log(...)`, add:

```swift
// Ascension Tier: evaluate this log against tier criteria.
// Fires .skillTierAdvance / .liftTierAdvance / .aggregateTierAdvance notifications
// for any crossings. Listeners decide cinematic vs TierBloomToast.
let crossings = await TierCriterionEvaluator.shared.evaluate(log: log, userId: log.userId)
for crossing in crossings {
    NotificationCenter.default.post(name: .skillTierAdvance, object: crossing)
}
```

Adapt the API to whatever `TierCriterionEvaluator` actually exposes. Check:

```bash
grep -n "func evaluate" UNBOUND/Services/Ranking/TierCriterionEvaluator.swift
```

The crossing struct will be something like `SkillTierAdvance(skillId: String, from: SkillTier, to: SkillTier)`.

Add the Notification.Name to `AttributeRankUpEvent.swift` (existing notification-names file):

```swift
extension Notification.Name {
    // existing names...
    static let skillTierAdvance = Notification.Name("unbound.skillTierAdvance")
}
```

```bash
xcodegen
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/WorkoutLogServiceTests 2>&1 | tail -8 || echo "no WorkoutLogServiceTests — skip"
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/Services/WorkoutLog/WorkoutLogService.swift UNBOUND/Models/AttributeRankUpEvent.swift
git commit -m "feat(rank): hook TierCriterionEvaluator into WorkoutLogService.saveLog"
```

---

# Phase 8 — UI components

## Task 8.1: TierBadge

```bash
cp /Users/jlin/Documents/toji/UNBOUND-ascension-tier/UNBOUND/Views/Components/Unbound/TierBadge.swift UNBOUND/Views/Components/Unbound/TierBadge.swift
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/Views/Components/Unbound/TierBadge.swift
git commit -m "feat(rank): add TierBadge pill chip for SkillTier"
```

## Task 8.2: TierBloomToast

Create new file (lower-tier crossings need a quiet bloom-style notification).

```swift
// UNBOUND/Views/Components/Unbound/TierBloomToast.swift
import SwiftUI

struct TierBloomToast: View {
    let tier: SkillTier
    let skillName: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.unbound.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(skillName.uppercased())
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text(tier.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.unbound.accent)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.unbound.accent.opacity(0.5), lineWidth: 1)
        )
    }
}

/// View modifier listening for .skillTierAdvance with non-cinematic tiers,
/// slides up the toast for 2.5 seconds.
struct TierBloomToastModifier: ViewModifier {
    @State private var visible: TierBloomData?

    private struct TierBloomData: Identifiable {
        let id = UUID()
        let tier: SkillTier
        let skillName: String
    }

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let toast = visible {
                    TierBloomToast(tier: toast.tier, skillName: toast.skillName)
                        .padding(.bottom, 80)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .id(toast.id)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .skillTierAdvance)) { note in
                guard let advance = note.object as? SkillTierAdvance else { return }
                guard !advance.toTier.isCinematic else { return }  // Cinematic handles top 3
                withAnimation(.easeOut(duration: 0.3)) {
                    visible = TierBloomData(tier: advance.toTier, skillName: advance.displayName)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(.easeIn(duration: 0.25)) {
                        visible = nil
                    }
                }
            }
    }
}

extension View {
    func tierBloomToast() -> some View {
        modifier(TierBloomToastModifier())
    }
}
```

(Adjust `SkillTierAdvance` struct to match what `TierCriterionEvaluator` actually emits — it might be named differently or have different fields. Look at the reference branch's evaluator output type.)

```bash
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/Views/Components/Unbound/TierBloomToast.swift
git commit -m "feat(rank): add TierBloomToast for non-cinematic tier crossings"
```

---

# Phase 9 — Wire TierBadge into skill tree nodes

## Task 9.1: SkillNodeView TierBadge

Find skill node rendering code:

```bash
grep -rn "SkillNodeView\|nodeChip\|RankBadge(" UNBOUND/Views/ --include="*.swift" | head
```

For each node-rendering site that currently shows a `RankBadge` or rank chip, replace with:

```swift
TierBadge(tier: services.userSkillTier.tier(for: node.id, userId: userId))
```

(Adjust API to match `UserSkillTierStore`'s actual surface.)

If the reference branch already has these wirings:

```bash
cp /Users/jlin/Documents/toji/UNBOUND-ascension-tier/UNBOUND/Views/Home/SkillNodeView.swift UNBOUND/Views/Home/SkillNodeView.swift 2>/dev/null
cp /Users/jlin/Documents/toji/UNBOUND-ascension-tier/UNBOUND/Views/Home/SkillDetailView.swift UNBOUND/Views/Home/SkillDetailView.swift 2>/dev/null
```

Fix any consumers of the old `RankBadge` and rebuild.

```bash
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/Views/Home/
git commit -m "feat(rank): wire TierBadge into skill-tree node chips + detail view"
```

---

# Phase 10 — Home aggregate rank swap

## Task 10.1: Replace aggregate rank chip text-source

In `UNBOUND/Views/Home/UnboundHomeView.swift`, find:

```bash
grep -n "RANK \\\\(\|aggregateRank.letter\|aggregateRank.displayName" UNBOUND/Views/Home/UnboundHomeView.swift | head
```

Replace `Text("RANK \(aggregateRank.letter)")` with `Text(aggregateTier.displayName.uppercased())`.

Add `@State private var aggregateTier: SkillTier = .initiate` near the existing rank state.

Load in `.task`:

```swift
aggregateTier = services.rank.aggregateTier(userId: userId)
```

Refresh on rank-up notification:

```swift
.onReceive(NotificationCenter.default.publisher(for: .skillTierAdvance)) { _ in
    if let userId = services.auth.currentUserId {
        Task {
            aggregateTier = await services.rank.aggregateTier(userId: userId)
        }
    }
}
```

Apply toast modifier at view root:

```swift
.tierBloomToast()
```

**DO NOT TOUCH:**
- Move greeting
- Foundation subhead
- TODAY STATUS card structure
- BEGIN SESSION button
- SESSION PLAN list
- COACH CUE
- WEEK PATH
- HomeBuildChipCard (from #1)

Build + verify session-flow snapshot test still passes:

```bash
xcodegen
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/UnboundHomeViewSessionFlowTests 2>&1 | tail -8
```

Sim smoke:

```bash
xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/asc-v2-home build 2>&1 | tail -3
xcrun simctl install booted /tmp/asc-v2-home/Build/Products/Debug-iphonesimulator/UNBOUND.app
xcrun simctl terminate booted com.unboundapp.ios 2>&1 | tail -1
xcrun simctl launch booted com.unboundapp.ios
sleep 5
xcrun simctl io booted screenshot /tmp/asc-v2-home.png
```

Confirm session-flow elements visible. Confirm rank chip now shows tier name (e.g. "FORGED") instead of letter.

```bash
git add UNBOUND/Views/Home/UnboundHomeView.swift
git commit -m "feat(rank): swap aggregate rank chip from letter grade to SkillTier name on Home"
```

## Task 10.2: RankService.aggregateTier method

Add `aggregateTier(userId:)` to `UNBOUND/Services/Ranking/RankService.swift` + protocol + mock:

```swift
/// Aggregate skill tier across all per-skill + per-lift tier states.
/// Returns the highest tier reached as a simple max for now.
/// TODO(future): weighted-by-volume aggregation.
func aggregateTier(userId: String) async -> SkillTier {
    let skillTiers = await UserSkillTierStore.shared.allTiers(userId: userId)
    let liftTiers = ["bench", "squat", "deadlift", "ohp"].map {
        LiftTierService.shared.tier(lift: $0, userId: userId)
    }
    let all = skillTiers + liftTiers
    return all.max() ?? .initiate
}
```

(`SkillTier` is Comparable per RankTitle's existing ordering. Verify with `grep "Comparable" UNBOUND/Models/SubRank.swift`.)

```bash
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/Services/Ranking/RankService.swift UNBOUND/Services/Ranking/RankServiceProtocol.swift
git commit -m "feat(rank): add RankService.aggregateTier (max across skill + lift states)"
```

---

# Phase 11 — RankUpCinematic gate

## Task 11.1: Gate cinematic to top-3 tiers

Modify `UNBOUND/Views/Components/Cinematic/RankUpCinematic.swift`. The cinematic should accept a `SkillTier` param and ONLY fire when `tier.isCinematic` is true.

```bash
grep -n "RankUpCinematic\|@Published.*cinematic" UNBOUND/Views/Components/Cinematic/RankUpCinematic.swift | head
```

Adopt reference branch's version if it has the gate already:

```bash
cp /Users/jlin/Documents/toji/UNBOUND-ascension-tier/UNBOUND/Views/Components/Cinematic/RankUpCinematic.swift UNBOUND/Views/Components/Cinematic/RankUpCinematic.swift
```

If trunk version has different inputs (e.g. accepts BuildIdentity from #1), manually port only the tier gate:

```swift
.onReceive(NotificationCenter.default.publisher(for: .skillTierAdvance)) { note in
    guard let advance = note.object as? SkillTierAdvance else { return }
    guard advance.toTier.isCinematic else { return }  // Top 3 only
    presenter.show(advance: advance)
}
```

```bash
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/Views/Components/Cinematic/RankUpCinematic.swift
git commit -m "feat(rank): RankUpCinematic gates on cinematic tiers (Vessel/Unbound/Ascendant)"
```

---

# Phase 12 — Profile rank surfaces

## Task 12.1: ProfileView tier display

`UNBOUND/Views/Profile/ProfileView.swift` currently shows rank surfaces using letter grades. Swap to tier names where appropriate.

```bash
grep -n "displayName\|RANK\|aggregateRank\|rankJourneyCard" UNBOUND/Views/Profile/ProfileView.swift | head
```

If the reference branch added "Rank-Ups" or "Ascendant Skills" sections, copy those into ProfileView body. Otherwise update existing sections to use `services.rank.aggregateTier`.

```bash
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/Views/Profile/ProfileView.swift
git commit -m "feat(rank): Profile shows aggregate tier name + per-skill/per-lift surfaces"
```

---

# Phase 13 — ServiceContainer wiring + deletions

## Task 13.1: Wire UserSkillTierStore + LiftTierService

In `UNBOUND/Services/ServiceContainer.swift`, add slots:

```swift
let userSkillTier: UserSkillTierStore
let liftTier: LiftTierService
```

Default to `.shared`. Update `.mock` if used. Don't remove anything else.

```bash
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/Services/ServiceContainer.swift
git commit -m "feat(rank): wire UserSkillTierStore + LiftTierService into ServiceContainer"
```

## Task 13.2: Delete LiftRank + RankBadge

```bash
grep -rn "LiftRank\b\|RankBadge\b" UNBOUND/ UNBOUNDTests/ --include="*.swift" | grep -v "LiftRank.swift\|RankBadge.swift" | head -20
```

For each remaining consumer, migrate to `LiftTierService` / `TierBadge`. Then:

```bash
git rm UNBOUND/Models/LiftRank.swift
git rm UNBOUND/Views/Components/RankBadge.swift
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add -A
git commit -m "chore(rank): delete LiftRank + RankBadge (replaced by LiftTierService + TierBadge)"
```

---

# Phase 14 — Final regression

## Task 14.1: Full test suite

```bash
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "Executed |TEST SUCCEEDED|TEST FAILED" | tail -5
```

Expected: TEST SUCCEEDED with new tests added. Pre-existing failures from `SkillProgressXPTests` and `SkillClusterUnlockTests` may persist — they're unrelated to ascension tier.

## Task 14.2: Grep verification

```bash
echo "=== Should be empty ==="
grep -rn "\bLiftRank\b\|\bRankBadge\b" UNBOUND/ --include="*.swift"

echo "=== Should have hits ==="
grep -rn "SkillTier\|TierBadge\|TierBloomToast\|aggregateTier" UNBOUND/ --include="*.swift" | head -10
```

## Task 14.3: Sim smoke

```bash
xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/asc-v2-final build 2>&1 | tail -3
xcrun simctl install booted /tmp/asc-v2-final/Build/Products/Debug-iphonesimulator/UNBOUND.app
xcrun simctl terminate booted com.unboundapp.ios 2>&1 | tail -1
xcrun simctl launch booted com.unboundapp.ios
sleep 5
xcrun simctl io booted screenshot /tmp/asc-v2-final-home.png
```

Verify:
- [ ] Home rank chip shows tier name (not letter grade)
- [ ] Session-flow modules unchanged (Move/Foundation/BEGIN SESSION/SESSION PLAN/COACH CUE/WEEK PATH)
- [ ] HomeBuildChipCard still visible (from #1)
- [ ] Profile tab → tier rendering correct
- [ ] Skill tree → TierBadge on nodes

## Task 14.4: Handoff doc

```bash
cat > docs/superpowers/handoff/2026-05-14-ascension-tier-v2-smoke.md << 'EOF'
# Ascension Tier (Additive) — Final Smoke

Sub-project #4 shipped on `ascension-tier-v2`. Ready for merge into `program-redesign`.

## What changed
- 9-tier ladder (Initiate → Ascendant) replaces SubRank letter grades on user-facing surfaces
- Cinematic gated to top 3 tiers (Vessel/Unbound/Ascendant); lower crossings → TierBloomToast
- TierBadge wired into skill-tree nodes + lift detail screens
- Home aggregate rank chip text-source: letter → tier name
- One-time migration replays existing workout logs

## What's preserved
- Session-flow Home (Move/Foundation/BEGIN SESSION/SESSION PLAN/COACH CUE/WEEK PATH)
- HomeBuildChipCard from #1
- All existing scan flow (out of scope — #3's territory)
- SubRank.swift internals (still used by AttributeValue from #1)

## Known follow-ups
- LocalProgramGenerator parameter naming (`archetypeRank: SubRank`) — leftover from #1, still cosmetic
- AttributeValue still uses SubRank internally (not exposed to UI; future refactor optional)
EOF
git add docs/superpowers/handoff/2026-05-14-ascension-tier-v2-smoke.md
git commit -m "chore(rank): final smoke + handoff doc — sub-project #4 ready for merge"
```

---

## Self-Review Notes

**Spec coverage:**
- ✅ SkillTier typealias → Phase 2.1
- ✅ TierCriterion + UserSkillTierState + LiftTierCriteria → Phase 2.2-2.4
- ✅ TierCriterionEvaluator → Phase 4.1
- ✅ Per-cluster tier criteria tables → Phase 4.2
- ✅ UserSkillTierStore + LiftTierService → Phase 5
- ✅ SkillTierMigration → Phase 6
- ✅ WorkoutLogService hook → Phase 7
- ✅ TierBadge + TierBloomToast → Phase 8
- ✅ Skill-tree node wiring → Phase 9
- ✅ Home aggregate rank swap → Phase 10
- ✅ RankUpCinematic gate (top 3 tiers) → Phase 11
- ✅ Profile tier display → Phase 12
- ✅ LiftRank + RankBadge deletion → Phase 13
- ✅ Final regression + smoke → Phase 14

**Placeholder scan:** No TBD/TODO/incomplete steps in critical path. Some tasks fall back to "if reference branch has X, copy" — this is intentional given the heavy reuse from reference.

**Type consistency:** `SkillTier` typealiased to `RankTitle`. `SkillTierAdvance` is referenced as the evaluator's emitted struct — implementer should verify the actual name in `TierCriterionEvaluator.swift` matches.

**Known soft spots:**
1. `SkillTierAdvance` struct name may differ from reference branch. Tasks 7, 8, 11 reference it — adapt to actual name.
2. `LiftTierService` is created fresh if reference doesn't have it. Verify before Phase 5.2.
3. `RankService.aggregateTier` aggregation algorithm uses simple max. Future PR can refine to weighted-by-volume.
4. `SkillTierMigration.migrateIfNeeded(userId:)` API name may differ — verify.
5. The first-launch `.task` in `AniBodyApp.swift` was modified in #1. Phase 6.2 appends to it — don't create a duplicate.
