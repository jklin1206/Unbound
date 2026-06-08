# Train Screens Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make **My Workouts** list-first (saved workouts inline + readable; Quick Log/Build small) and **Today's Plan** editorial (dissolve the day-card block; fold the fuel band into a meta line).

**Architecture:** Two phases. Phase 4 extracts the saved-workout list out of the modal `SavedWorkoutsListView` into a reusable inline component and rebuilds `MyWorkoutsView` around it (de-boxed rows). Phase 5 turns `ProgramSelectedDayCard` from a container into a flat editorial section and folds the fuel target into the day meta line. Almost entirely view restructuring + reuse of existing data/actions; no data-model changes.

**Tech Stack:** Swift / SwiftUI, XcodeGen, XCTest, iOS Simulator (iPhone 17, udid `810087B3-226D-4398-8ABD-9FF61E642E1D`), bundle `com.unboundapp.ios`, scheme `UNBOUND`.

---

## Conventions (apply to every task)

**Spec:** `docs/superpowers/specs/2026-06-08-train-screens-redesign-design.md`.

**Concurrency (critical):** A Codex session concurrently edits program-gen / weight-policy / ActiveWorkout **model** files + assets + tests. **Always `git add <explicit paths>`, never `git add -A`/`.`** Never touch a file you didn't change for the task.

**New files require XcodeGen:** after creating any new `.swift`, run `xcodegen generate` before building. Stale SourceKit "Cannot find type / no member unbound / No such module" after edits is NOISE — trust `xcodebuild`.

**Strings:** literal `Text("…")`; do NOT add new `L10n.` keys (a key without a `Localizable.xcstrings` entry fails `LocalizationTests`). Reusing an existing key like `common.done` is fine.

**Calm-list rules:** no per-item card fills, no pills/capsules, no `.shadow`, no left/top accent bars. Emphasis = fill-only on the ONE primary element. Dividers use `Color.unbound.border`. Primitives in `UNBOUND/Views/Components/Unbound/CalmList.swift`: `MetaLine`, `CalmSectionHeader`, `activeSurface`.

**Build commands:**
```bash
# sim (fast gate)
xcodebuild build -project UNBOUND.xcodeproj -scheme UNBOUND -destination 'platform=iOS Simulator,id=810087B3-226D-4398-8ABD-9FF61E642E1D' -configuration Debug -derivedDataPath /tmp/unbound-dd CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
# device-arch (the real gate; can be slow)
xcodebuild build -project UNBOUND.xcodeproj -scheme UNBOUND -destination 'generic/platform=iOS' -configuration Debug -derivedDataPath /tmp/unbound-dd-dev CODE_SIGNING_ALLOWED=NO 2>&1 | tail -12
```

**Screenshot the My Workouts harness:**
```bash
xcrun simctl install booted /tmp/unbound-dd/Build/Products/Debug-iphonesimulator/UNBOUND.app
xcrun simctl terminate booted com.unboundapp.ios; xcrun simctl launch booted com.unboundapp.ios -myWorkoutsDemo
sleep 4; xcrun simctl io booted screenshot /tmp/p4_myworkouts.png
```
Today's Plan screenshot: `xcrun simctl launch booted com.unboundapp.ios --unbound-open-program` then screenshot.

**Resolved design decision (was the spec's open question):** A saved row's **whole body is tappable = "use today"** (reuses `applySavedWorkout(_, to: programToday, allowExtraSession: true)`); a trailing ↻ glyph is the visual affordance; the `⋯` menu holds Schedule / Drop to Squad / Delete. No separate "open in editor" path (keeps it simple).

---

## Phase 4 — My Workouts (list-first)

### Task 4.1: Extract `SavedWorkoutsInlineList` from the modal list, de-boxed

**Files:**
- Create: `UNBOUND/Views/Program/MyWorkouts/SavedWorkoutsInlineList.swift`
- Reference (read, copy helpers from): `UNBOUND/Views/Program/SavedWorkoutsListView.swift`

- [ ] **Step 1: Read the source.** Read `SavedWorkoutsListView.swift` fully. Identify the pieces to lift: the `SavedWorkoutLibraryRow` view (lines ~259-355), `roleText(_:)`/`roleKey(_:)`/`roleIcon`/`roleTint` helpers, `delete(_:)`, and the `SquadRoutineDropShareSheet` usage. You will reuse these — copy them, don't reinvent.

- [ ] **Step 2: Create the inline list component.** It owns the data + delete + share sheet, takes use-today/schedule callbacks, and renders **flat de-boxed rows**.

```swift
import SwiftUI

/// The saved-workouts list, rendered inline (no modal/NavigationStack chrome) for
/// the My Workouts tab. Flat calm rows on `bg` separated by hairline rules.
/// Data from SavedWorkoutStore; delete + Squad-share handled locally; use-today /
/// schedule bubble up to the parent (which applies them to the program).
struct SavedWorkoutsInlineList: View {
    @EnvironmentObject private var services: ServiceContainer
    @State private var workouts: [SavedWorkout]
    @State private var sharingWorkout: SavedWorkout?

    let onUseToday: (SavedWorkout) -> Void
    let onSchedule: (SavedWorkout) -> Void

    init(
        workouts: [SavedWorkout] = SavedWorkoutStore.shared.all(),
        onUseToday: @escaping (SavedWorkout) -> Void,
        onSchedule: @escaping (SavedWorkout) -> Void
    ) {
        _workouts = State(initialValue: workouts)
        self.onUseToday = onUseToday
        self.onSchedule = onSchedule
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CalmSectionHeader(title: "SAVED", trailing: workouts.isEmpty ? nil : "\(workouts.count)")
                .padding(.bottom, 8)

            if workouts.isEmpty {
                Text("No saved workouts yet — build one or quick-log a session.")
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .padding(.vertical, 8)
            } else {
                ForEach(Array(workouts.enumerated()), id: \.element.id) { index, workout in
                    SavedWorkoutInlineRow(
                        workout: workout,
                        roleText: roleText(workout),
                        onUseToday: { onUseToday(workout) },
                        onSchedule: { onSchedule(workout) },
                        onShare: { sharingWorkout = workout },
                        onDelete: { delete(workout) }
                    )
                    if index < workouts.count - 1 {
                        Divider().overlay(Color.unbound.border)
                    }
                }
            }
        }
        .sheet(item: $sharingWorkout) { workout in
            SquadRoutineDropShareSheet(workout: workout) { _ in sharingWorkout = nil }
                .environmentObject(services)
        }
    }

    private func delete(_ workout: SavedWorkout) {
        SavedWorkoutStore.shared.delete(id: workout.id)
        workouts.removeAll { $0.id == workout.id }
    }

    // roleText/roleKey/role styling: copy the exact implementations from
    // SavedWorkoutsListView (so the ROLE tag text matches the rest of the app).
}
```

> Confirm the delete API: `grep -n "func delete" UNBOUND/**/SavedWorkoutStore*.swift` — match the real signature (the modal's `delete(_:)` already calls it; copy that call). Copy `roleText(_:)` and its helpers verbatim from `SavedWorkoutsListView`. Confirm `CalmSectionHeader` accepts `trailing:` (it does — added in Phase 2).

- [ ] **Step 3: Add the de-boxed row** (in the same file). Lift `SavedWorkoutLibraryRow`'s content but make the whole row a "use today" button, drop the bordered-card background, and keep the ↻ glyph + `⋯` menu:

```swift
private struct SavedWorkoutInlineRow: View {
    let workout: SavedWorkout
    let roleText: String
    let onUseToday: () -> Void
    let onSchedule: () -> Void
    let onShare: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: { UnboundHaptics.soft(); onUseToday() }) {
            HStack(spacing: 12) {
                WorkoutReferenceImageView(
                    exerciseName: workout.effectiveReferenceExerciseName,
                    fallbackSystemName: "dumbbell.fill",
                    fallbackTint: Color.unbound.textSecondary
                )
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.title)
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                    MetaLine(items: ["\(workout.exerciseCount) exercises", "\(workout.estimatedMinutes)m", roleText.uppercased()])
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.unbound.coachCyan)
                    .accessibilityHidden(true)

                Menu {
                    Button { onSchedule() } label: { Label("Schedule", systemImage: "calendar.badge.plus") }
                    Button { onShare() } label: { Label("Drop to Squad", systemImage: "paperplane.fill") }
                    Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .frame(width: 30, height: 38)
                }
                .menuStyle(.button)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Use \(workout.title) today")
    }
}
```

> Confirm `MetaLine(items:)` is the real initializer (used in Phase 3). Confirm `WorkoutReferenceImageView` init labels by reading its use in `SavedWorkoutsListView` (copy exactly). Confirm `workout.effectiveReferenceExerciseName`, `.exerciseCount`, `.estimatedMinutes`, `.title`, `.id` exist (they're used in the modal today).

- [ ] **Step 4: XcodeGen + build (sim).**
```bash
xcodegen generate
```
Then the sim build. Expected: `BUILD SUCCEEDED`. (Component not yet used; just compiles.)

- [ ] **Step 5: Commit.**
```bash
git add UNBOUND/Views/Program/MyWorkouts/SavedWorkoutsInlineList.swift
git commit -m "feat(train): SavedWorkoutsInlineList — de-boxed inline saved-workout rows"
```

### Task 4.2: Rebuild `MyWorkoutsView` (action pair + inline list)

**Files:**
- Modify: `UNBOUND/Views/Program/MyWorkouts/MyWorkoutsView.swift` (full rewrite of body)

- [ ] **Step 1: Replace the view.** New signature drops `onOpenSaved`, adds saved-list callbacks:

```swift
import SwiftUI

/// "My Workouts" sub-tab: list-first. The saved workouts ARE the content; Quick
/// Log and Build are small secondary actions on top.
struct MyWorkoutsView: View {
    let onQuickLog: () -> Void
    let onBuild: () -> Void
    let onUseToday: (SavedWorkout) -> Void
    let onSchedule: (SavedWorkout) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    actionButton(title: "Quick Log", icon: "bolt.fill") { UnboundHaptics.medium(); onQuickLog() }
                        .accessibilityIdentifier("myWorkouts.quickLog")
                    actionButton(title: "Build", icon: "plus") { UnboundHaptics.soft(); onBuild() }
                        .accessibilityIdentifier("myWorkouts.build")
                }

                SavedWorkoutsInlineList(onUseToday: onUseToday, onSchedule: onSchedule)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.unbound.bg)
    }

    private func actionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon).font(.system(size: 13, weight: .bold))
                Text(title).font(Font.unbound.bodyMStrong)
            }
            .foregroundStyle(Color.unbound.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.unbound.border, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: Build (sim).** Expected: a compile error in `ProgramOverviewView` and `MyWorkoutsDemoHarness` (call sites use the old signature) — that's expected; fix in 4.3. The `MyWorkoutsView.swift` file itself should be error-free.

### Task 4.3: Rewire `ProgramOverviewView` + harness; retire the saved sheet

**Files:**
- Modify: `UNBOUND/Views/Program/ProgramOverviewView.swift` (the `.myWorkouts` case ~line 172; the `showSavedWorkouts` sheet ~line 227; the `@State var showSavedWorkouts` ~line 34)
- Modify: `UNBOUND/Views/Program/MyWorkouts/MyWorkoutsDemoHarness.swift`

- [ ] **Step 1: Update the `.myWorkouts` case** to the new signature, reusing the existing saved-workout handlers:

```swift
                    case .myWorkouts:
                        MyWorkoutsView(
                            onQuickLog: {
                                activeWorkoutDraft = QuickLogDraftFactory.empty(userId: services.auth.currentUserId ?? "")
                            },
                            onBuild: {
                                sessionEditorDraft = QuickLogDraftFactory.empty(userId: services.auth.currentUserId ?? "")
                            },
                            onUseToday: { workout in
                                applySavedWorkout(workout, to: programToday, allowExtraSession: true)
                            },
                            onSchedule: { workout in
                                applySavedWorkout(workout, to: selectedPlanningDate(), allowExtraSession: false)
                            }
                        )
```

> Confirm `applySavedWorkout(_:to:allowExtraSession:)`, `programToday`, `selectedPlanningDate()` exist (they're used by the sheet today — grep to confirm exact names).

- [ ] **Step 2: Remove the now-dead `showSavedWorkouts` sheet** (~lines 227-247, the `.sheet(isPresented: $showSavedWorkouts) { SavedWorkoutsListView(...) }`) and the `@State var showSavedWorkouts = false` (~line 34).

- [ ] **Step 3: Verify nothing else needs the sheet.** Run:
```
grep -rn "showSavedWorkouts\|SavedWorkoutsListView" UNBOUND/
```
Expected: zero remaining references (other than the file `SavedWorkoutsListView.swift` itself). If any other caller exists, keep `SavedWorkoutsListView` as a thin `NavigationStack` wrapper around `SavedWorkoutsInlineList` instead of deleting; otherwise leave `SavedWorkoutsListView.swift` in place but unreferenced is acceptable for this pass (do NOT delete it unless zero refs AND you confirm the file's other types — e.g. `SquadRoutineDropShareSheet` — are not used elsewhere: `grep -rn "SquadRoutineDropShareSheet" UNBOUND/`). If `SquadRoutineDropShareSheet` is only defined in that file and now used by `SavedWorkoutsInlineList`, MOVE it into the inline file or keep `SavedWorkoutsListView.swift` for that definition.

- [ ] **Step 4: Update the harness** (`MyWorkoutsDemoHarness.swift`) to the new signature:

```swift
        MyWorkoutsView(
            onQuickLog: { activeDraft = QuickLogDraftFactory.empty(userId: "demo") },
            onBuild: { editorDraft = QuickLogDraftFactory.empty(userId: "demo") },
            onUseToday: { _ in activeDraft = QuickLogDraftFactory.empty(userId: "demo") },
            onSchedule: { _ in }
        )
```
(Keep the existing `activeDraft`/`editorDraft` covers from Phase 2.)

- [ ] **Step 5: XcodeGen + build (sim + device-arch).** Both `BUILD SUCCEEDED`.

- [ ] **Step 6: Commit.**
```bash
git add UNBOUND/Views/Program/MyWorkouts/MyWorkoutsView.swift \
        UNBOUND/Views/Program/ProgramOverviewView.swift \
        UNBOUND/Views/Program/MyWorkouts/MyWorkoutsDemoHarness.swift
git commit -m "feat(train): My Workouts list-first — inline saved list, small action pair; retire saved sheet"
```

### Task 4.4: Visual checkpoint (Phase 4)

- [ ] **Step 1: Screenshot** the harness (`-myWorkoutsDemo`) → `/tmp/p4_myworkouts.png`. Note: the harness uses `SavedWorkoutStore.shared.all()`; if empty on the sim, the empty-state line shows — that still verifies the action pair + header. To see rows, the live app's saved workouts are needed.
- [ ] **Step 2: STOP for user checkpoint.** Show `/tmp/p4_myworkouts.png`. Confirm action pair is small/secondary, saved list reads as flat rows. Go-ahead before Phase 5.

---

## Phase 5 — Today's Plan (editorial, no container)

### Task 5.1: Fuel summary helper (TDD)

**Files:**
- Create: `UNBOUND/Views/Program/Overview/ProgramDayFuelSummary.swift`
- Create: `UNBOUNDTests/Views/ProgramDayFuelSummaryTests.swift`
- Reference: `UNBOUND/Views/Program/ProgramFuelTargetBand.swift` (existing fuel calc)

- [ ] **Step 1: Read** `ProgramFuelTargetBand.swift` to see exactly how it derives kcal + protein from `nutritionPlan`/`day` (training vs rest day). You will reuse that calculation.

- [ ] **Step 2: Write the failing test.** (Adapt the expected values + types to what `ProgramFuelTargetBand` actually computes — read it first.)

```swift
import XCTest
@testable import UNBOUND

final class ProgramDayFuelSummaryTests: XCTestCase {
    func test_trainingDay_producesKcalAndProteinText() {
        let text = ProgramDayFuelSummary.text(kcal: 2850, proteinGrams: 180, isRestDay: false)
        XCTAssertEqual(text, "2850 kcal · 180g protein")
    }
    func test_restDay_hasNoNumbers() {
        let text = ProgramDayFuelSummary.text(kcal: 2200, proteinGrams: 160, isRestDay: true)
        XCTAssertEqual(text, "rest day")
    }
}
```

- [ ] **Step 3: Run it — verify it fails** (`-only-testing:UNBOUNDTests/ProgramDayFuelSummaryTests`). Expected: FAIL "Cannot find 'ProgramDayFuelSummary'".

- [ ] **Step 4: Implement.**
```swift
import Foundation

/// Builds the plain-text fuel fragment folded into the Today's-Plan meta line
/// (replaces the boxed ProgramFuelTargetBand on that surface).
enum ProgramDayFuelSummary {
    static func text(kcal: Int, proteinGrams: Int, isRestDay: Bool) -> String {
        if isRestDay { return "rest day" }
        return "\(kcal) kcal · \(proteinGrams)g protein"
    }
}
```

- [ ] **Step 5: XcodeGen + run test — passes.**
- [ ] **Step 6: Commit.**
```bash
git add UNBOUND/Views/Program/Overview/ProgramDayFuelSummary.swift UNBOUNDTests/Views/ProgramDayFuelSummaryTests.swift
git commit -m "feat(train): ProgramDayFuelSummary text helper for the day meta line"
```

### Task 5.2: `ProgramSelectedDayCard` → flat editorial section

**Files:**
- Modify: `UNBOUND/Views/Program/Overview/ProgramSelectedDayCard.swift`

- [ ] **Step 1: Remove the container.** Delete the `.activeSurface(true, cornerRadius: 18)` wrapper and any card padding-as-box on the root `VStack`. The root becomes a plain `VStack(alignment: .leading, spacing: 14)` with only horizontal padding (no fill/border/shadow). The eyebrow row (`headerLabel` + status glyph+word) and title stay; replace the metrics `MetaLine` so it appends the fuel fragment (passed in — see Step 2). After the title+meta, add a hairline `Divider().overlay(Color.unbound.border)`, then the `content`.

- [ ] **Step 2: Accept a fuel fragment.** Add `let fuelText: String?` to the struct + init. In the day meta line, append it:
```swift
            MetaLine(items: metrics.map { $0.title } + [fuelText].compactMap { $0 })
```
(So the meta reads e.g. `3 moves · ~55 min · 2850 kcal · 180g protein`.)

- [ ] **Step 3: Build (sim).** Expected: compile error at the `dayCard()` call site (missing `fuelText:` arg) — fixed in 5.3. The card file itself compiles.

### Task 5.3: `dayCard()` — drop the fuel band, pass fuel into the card

**Files:**
- Modify: `UNBOUND/Views/Program/Overview/ProgramOverviewView+WeekAndDay.swift` (the `dayCard()` builder)

- [ ] **Step 1: Compute the fuel fragment and pass it.** In `dayCard()`, before the `return ProgramSelectedDayCard(...)`, derive kcal/protein the same way `ProgramFuelTargetBand` does (call its calc or `ProgramDayFuelSummary` with the same inputs from `program.nutritionPlan` + `day`), and pass `fuelText:` into the card. Then **remove** the `ProgramFuelTargetBand(plan:day:)` line from the card's content closure.

```swift
        let fuelText = day.map { d in
            // reuse the same kcal/protein values ProgramFuelTargetBand computes
            ProgramDayFuelSummary.text(kcal: <kcal expr>, proteinGrams: <protein expr>, isRestDay: d.isRestDay)
        }

        return ProgramSelectedDayCard(
            headerLabel: presentation.headerLabel,
            title: presentation.title,
            contextLabel: presentation.contextLabel,
            badge: presentation.badge,
            heroTint: presentation.heroTint,
            metrics: presentation.metrics,
            skillNodes: presentation.skillNodes,
            fuelText: fuelText
        ) {
            // ProgramFuelTargetBand line REMOVED
            if let day, !day.isRestDay, let workout {
                ProgramModifierSummaryRail(summary: programModifierSummary(for: day))
                ProgramWaveAdjustmentPanel(adjustments: waveAdjustments(for: day), onUndo: revertWaveAdjustment)
                ProgramWorkoutExerciseList(exercises: workout.mainExercises)
            }
            dayActionRow(day: day, isToday: isToday)
        }
```

> Read `ProgramFuelTargetBand.swift` to get the exact kcal/protein expressions; if its calc is non-trivial, extract a small `static func values(plan:day:) -> (kcal: Int, protein: Int)` on `ProgramFuelTargetBand` (or in `ProgramDayFuelSummary`) and call it from both the band (if still used elsewhere) and here. `grep -rn "ProgramFuelTargetBand(" UNBOUND/` to confirm whether the band is used on any OTHER surface (if yes, keep the component; we only remove it from this content closure).

- [ ] **Step 2: Build (sim + device-arch).** Both `BUILD SUCCEEDED`. Device-arch is the metadata-cliff gate; if it fails (EXC_BAD_ACCESS / SubstGenericParameters / type-check timeout), `AnyView`-wrap the card's heavy children and retry.

### Task 5.4: Verify exercise rows flat; checkpoint

**Files:**
- Inspect/Modify (only if needed): `UNBOUND/Views/Program/Overview/ProgramDayPreviewViews.swift` (`ProgramWorkoutExerciseList` rows)

- [ ] **Step 1: Confirm the exercise rows are flat** (thumbnail · name · muscles · reps; hairline or plain separation; no fill/border/shadow). If any residual card fill remains from before, flatten it. Build (sim).

- [ ] **Step 2: Commit Phase 5.**
```bash
git add UNBOUND/Views/Program/Overview/ProgramSelectedDayCard.swift \
        UNBOUND/Views/Program/Overview/ProgramOverviewView+WeekAndDay.swift \
        UNBOUND/Views/Program/Overview/ProgramDayPreviewViews.swift
git commit -m "feat(train): Today's Plan editorial — dissolve day-card block, fold fuel into meta line"
```

- [ ] **Step 3: Screenshot** `--unbound-open-program` → `/tmp/p5_todaysplan.png`. **STOP for user checkpoint** — confirm no wrapping block, fuel is plain text in the meta line, exercises flow flat, BEGIN is the only accent.

---

## Self-review notes (coverage vs spec)
- ✅ My Workouts: action pair small/secondary (4.2); saved list inline + de-boxed rows (4.1); use-today/schedule/share/delete preserved (4.1, 4.3); sheet retired (4.3); role rail dropped (not built — YAGNI per spec).
- ✅ Today's Plan: container dissolved (5.2); fuel folded into meta as plain text (5.1–5.3); exercises flat (5.4); BEGIN lone accent (unchanged from Phase 3).
- ✅ Device-arch gate (5.3). ✅ No data-model changes. ✅ Out-of-scope (Routines/Home/etc.) untouched.
- ⚠️ Interface confirmations the executor must grep before use (flagged inline, not placeholders): `SavedWorkoutStore.delete` signature; `roleText` helpers; `WorkoutReferenceImageView`/`MetaLine`/`CalmSectionHeader(trailing:)` inits; `applySavedWorkout`/`programToday`/`selectedPlanningDate`; the exact kcal/protein expressions in `ProgramFuelTargetBand`; whether `SquadRoutineDropShareSheet`/`ProgramFuelTargetBand` are used elsewhere before removing/moving.
- ⚠️ Harness saved-list renders empty unless the sim has saved workouts — checkpoint screenshot may show the empty state; that still verifies the action pair + header layout.
```
