# Workout Logging Redesign v2 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the one-set focused logger + full-screen rest timer with a block/grid logger (all exercises one scroll, per-set traffic-light RPE dot that doubles as the log control), a dismissible rest pop-up that fires a haptic + local notification, a premium exercise-detail screen, and an onboarding RPE teach step — reusing the already-tested core.

**Architecture:** The tested core survives unchanged (`ActiveWorkoutSession`, `WorkoutDraftStore`, `SetPrefill`, `EffortRPEMap`, `RestPrescription`, byte-compatible `WorkoutLog`/`saveLog`). New: index-addressed mutators on `ActiveWorkoutSession` (any-order logging), `RestTimerModel` + `RestNotifier` (countdown state + UNUserNotificationCenter behind a protocol seam), grid views (`SetLogGridRow`/`ExerciseLogCard`/`WorkoutLogGridView`), `RestTimerPill`. `ActiveWorkoutContainerView` is reworked to host the grid + pill overlay while preserving its `loadContext`/draft-autosave/`complete()`→`saveLog`→reward path verbatim. `ActiveSetView`/`RestTimerView`/`ExerciseDotNavigator` retired.

**Tech Stack:** Swift 5.9, SwiftUI, XCTest, UserNotifications, xcodegen. Branch `program-redesign`. Sim iPhone 17.

**Spec:** `docs/superpowers/specs/2026-05-17-workout-logging-redesign-v2-design.md` — read its "Design bar" before any UI task.

---

## Verified signatures (use exactly; confirmed in the codebase this session)

```swift
// Models/ActiveWorkoutSession.swift  — @MainActor final class ObservableObject
struct ActiveSet: Identifiable, Codable, Sendable { let id: String; var weightKg: Double?; var reps: Int?; var effort: Effort?; var isWarmup: Bool; var logged: Bool }
struct ActiveExercise: Identifiable, Codable, Sendable { let id: String; var name: String; var plannedSets: Int; var plannedReps: String; var restSeconds: Int; var muscleGroups: [MuscleGroup]; var sets: [ActiveSet]; var skipped: Bool; var notes: String }
@Published var exercises: [ActiveExercise]; @Published var currentExerciseIndex: Int; @Published var currentSetIndex: Int
// existing methods: logCurrentSet(weightKg:reps:), setEffort(_:), advance(), jumpToExercise(_:), addSetToCurrentExercise(), removeLastSetFromCurrentExercise(), skipCurrentExercise(), setNotes(_:forExerciseAt:), assembleWorkoutLog(userId:), snapshot(), init(workout:programId:dayNumber:), init(snapshot:)
// Models/EffortRPEMap.swift
enum Effort: String, CaseIterable, Codable, Sendable { case easy, solid, hard; var rpe: Int /*6/8/9*/; var label: String; init?(rpe: Int?) }
// Services/WorkoutLog/WorkoutDraftStore.swift  (@MainActor)
init(directory: URL? = nil); var hasDraft: Bool; func save(_:) throws; func load() -> ActiveWorkoutSession?; func clear()
// Services/WorkoutLog/SetPrefill.swift
static func ghost(exerciseName:setIndex:priorEntries:[ExerciseLogEntry],workingWeightKg:Double?) -> SetPrefill.Ghost?  // Ghost{weightKg:Double?,reps:Int?}
// Services/WorkoutLog/RestPrescription.swift
static func restSeconds(for: Exercise) -> Int
// Views/Program/ActiveWorkout/ExerciseOverflowMenu.swift
enum OverflowIntent { case toggleWarmup, editNotes, swapExercise, addSet, removeSet, skipExercise }
struct ExerciseOverflowMenu: View { init(isWarmup: Bool, onIntent: @escaping (OverflowIntent) -> Void) }
// Views/Program/ActiveWorkout/StepperControl.swift
struct StepperControl: View { init(label:String, value:Binding<Double>, step:Double, unit:String?, allowsDecimal:Bool) }
// Views/Program/ActiveWorkout/ActiveWorkoutContainerView.swift
init(workout:Workout, programId:String, dayNumber:Int, services:ServiceContainer, resuming:ActiveWorkoutSession? = nil)
// complete() does: assembleWorkoutLog(userId:) → services.workoutLog.saveLog(log) → HapticManager.notification(.success)
//   → draftStore.clear() → builds RewardSummary{skillTitle,xpGained} → @State rewardSummary → .sheet(item:WorkoutRewardPresentation){ RewardCelebrationView(summary:){…} .presentationDetents([.medium,.large]).presentationDragIndicator(.visible) } → dismiss()
// Tokens: Color.unbound.{bg,surface,surfaceElevated,textPrimary,textSecondary,textTertiary,border,borderSubtle,accent,impact,success,warning,alert}
//         Font.unbound.{titleL,titleM,bodyL,bodyM,bodyMStrong,bodyLStrong,caption,captionS,monoXL,monoL,monoM,monoS}
//         UnboundHaptics.{soft(),medium(),heavy(),tick(),success()}
// WorkoutDetailView.swift: .fullScreenCover(isPresented:$showLogging){ ActiveWorkoutContainerView(workout: liveWorkout, programId: programId, dayNumber: dayNumber, services: services) }
```

**Commit convention:** end every message with `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`. `project.pbxproj` is gitignored — run `xcodegen generate` after adding files before build/test.

**Test command (authoritative):** `cd /Users/jlin/Documents/toji/UNBOUND && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' test 2>&1 | tail -25`. SourceKit cross-file "Cannot find" diagnostics are noise when xcodebuild passes — ignore. Only the pre-existing `SquadMissionServiceTests` flap may fail; zero NEW failures allowed.

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `UNBOUND/Models/ActiveWorkoutSession.swift` | Modify (additive) | index-addressed `logSet`/`setEffort`/`cycleEffort` mutators |
| `UNBOUNDTests/Models/ActiveWorkoutSessionV2Tests.swift` | Create | tests for the new mutators (existing test file untouched) |
| `UNBOUND/Services/WorkoutLog/RestNotifier.swift` | Create | `RestNotifying` protocol + UNUserNotificationCenter impl |
| `UNBOUND/Models/RestTimerModel.swift` | Create | ObservableObject countdown state machine (pure, testable) |
| `UNBOUNDTests/Models/RestTimerModelTests.swift` | Create | countdown/dismiss/+30s/zero-fires/cancel tests |
| `UNBOUND/Views/Program/ActiveWorkout/SetLogGridRow.swift` | Create | one set row: WEIGHT/REPS cells + RPE tap-dot |
| `UNBOUND/Views/Program/ActiveWorkout/ExerciseLogCard.swift` | Create | one exercise block: header + col header + rows + add-set |
| `UNBOUND/Views/Program/ActiveWorkout/WorkoutLogGridView.swift` | Create | scroll of cards + COMPLETE |
| `UNBOUND/Views/Program/ActiveWorkout/RestTimerPill.swift` | Create | dismissible bottom countdown card |
| `UNBOUND/Views/Program/ActiveWorkout/ActiveWorkoutContainerView.swift` | Modify | host grid + pill; wire timer/notifier; preserve complete()/reward |
| `UNBOUND/Views/Program/WorkoutDetailView.swift` | Modify | premium redesign of the detail body |
| `UNBOUND/Views/Onboarding/RPEOnboardingStep.swift` | Create | RPE teach-and-try screen |
| `UNBOUND/Views/Onboarding/OnboardingContainerView.swift` | Modify | insert the RPE step into the router/flow |
| `UNBOUND/Views/Program/ActiveWorkout/ActiveSetView.swift` | Delete (T10) | retired |
| `UNBOUND/Views/Program/ActiveWorkout/RestTimerView.swift` | Delete (T10) | retired |
| `UNBOUND/Views/Program/ActiveWorkout/ExerciseDotNavigator.swift` | Delete (T10) | retired |

---

## Task 1: ActiveWorkoutSession index-addressed mutators (TDD)

**Files:** Modify `UNBOUND/Models/ActiveWorkoutSession.swift`; Create `UNBOUNDTests/Models/ActiveWorkoutSessionV2Tests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import UNBOUND

@MainActor
final class ActiveWorkoutSessionV2Tests: XCTestCase {
    private func workout() -> Workout {
        Workout(name: "Push", targetMuscleGroups: [], warmup: [],
            mainExercises: [
                Exercise(id: "e1", name: "Bench", muscleGroups: [.chest], sets: 3, reps: "8",
                         restSeconds: 90, rpe: nil, notes: nil, substitution: nil),
                Exercise(id: "e2", name: "Fly", muscleGroups: [.chest], sets: 2, reps: "12",
                         restSeconds: 60, rpe: nil, notes: nil, substitution: nil),
            ], cooldown: [], estimatedMinutes: 30, notes: nil, blockType: nil)
    }

    func test_logSet_anyOrder_recordsAndDefaultsEffortSolid() {
        let s = ActiveWorkoutSession(workout: workout(), programId: "p", dayNumber: 1)
        s.logSet(exerciseIndex: 1, setIndex: 0, weightKg: 30, reps: 12)   // log Fly set 1 first
        XCTAssertTrue(s.exercises[1].sets[0].logged)
        XCTAssertEqual(s.exercises[1].sets[0].weightKg, 30)
        XCTAssertEqual(s.exercises[1].sets[0].reps, 12)
        XCTAssertEqual(s.exercises[1].sets[0].effort, .solid)            // default-on-log
        XCTAssertFalse(s.exercises[0].sets[0].logged)
    }

    func test_setEffort_indexAddressed() {
        let s = ActiveWorkoutSession(workout: workout(), programId: "p", dayNumber: 1)
        s.logSet(exerciseIndex: 0, setIndex: 2, weightKg: 80, reps: 8)
        s.setEffort(exerciseIndex: 0, setIndex: 2, .hard)
        XCTAssertEqual(s.exercises[0].sets[2].effort, .hard)
    }

    func test_cycleEffort_order_easySolidHardWrap() {
        let s = ActiveWorkoutSession(workout: workout(), programId: "p", dayNumber: 1)
        s.logSet(exerciseIndex: 0, setIndex: 0, weightKg: 80, reps: 8)   // → .solid
        s.cycleEffort(exerciseIndex: 0, setIndex: 0)                     // solid → hard
        XCTAssertEqual(s.exercises[0].sets[0].effort, .hard)
        s.cycleEffort(exerciseIndex: 0, setIndex: 0)                     // hard → easy
        XCTAssertEqual(s.exercises[0].sets[0].effort, .easy)
        s.cycleEffort(exerciseIndex: 0, setIndex: 0)                     // easy → solid
        XCTAssertEqual(s.exercises[0].sets[0].effort, .solid)
    }

    func test_logSet_outOfRange_isNoOp() {
        let s = ActiveWorkoutSession(workout: workout(), programId: "p", dayNumber: 1)
        s.logSet(exerciseIndex: 9, setIndex: 9, weightKg: 1, reps: 1)    // no crash, no change
        XCTAssertFalse(s.exercises[0].sets[0].logged)
        s.cycleEffort(exerciseIndex: 9, setIndex: 9)                     // no crash
    }

    func test_assembleWorkoutLog_afterAnyOrderLogging() {
        let s = ActiveWorkoutSession(workout: workout(), programId: "p", dayNumber: 1)
        s.logSet(exerciseIndex: 0, setIndex: 0, weightKg: 80, reps: 8)
        s.cycleEffort(exerciseIndex: 0, setIndex: 0)                     // solid → hard
        s.logSet(exerciseIndex: 1, setIndex: 1, weightKg: 30, reps: 11)
        let log = s.assembleWorkoutLog(userId: "u")
        XCTAssertEqual(log.exerciseEntries[0].sets.count, 1)
        XCTAssertEqual(log.exerciseEntries[0].sets[0].rpe, 9)            // hard → 9
        XCTAssertEqual(log.exerciseEntries[1].sets.count, 1)
        XCTAssertEqual(log.exerciseEntries[1].sets[0].rpe, 8)            // solid default → 8
    }
}
```

- [ ] **Step 2:** `xcodegen generate >/dev/null 2>&1; … test … | tail -25` → FAIL (new methods absent).

- [ ] **Step 3: Implement — append these methods inside `ActiveWorkoutSession`** (do not remove existing current-index methods):

```swift
    // MARK: Index-addressed mutators (grid logs any set in any order)

    private static let effortCycle: [Effort] = [.easy, .solid, .hard]

    func logSet(exerciseIndex ei: Int, setIndex si: Int, weightKg: Double?, reps: Int?) {
        guard exercises.indices.contains(ei),
              exercises[ei].sets.indices.contains(si) else { return }
        exercises[ei].sets[si].weightKg = weightKg
        exercises[ei].sets[si].reps = reps
        exercises[ei].sets[si].logged = true
        if exercises[ei].sets[si].effort == nil {
            exercises[ei].sets[si].effort = .solid       // implicit default on log
        }
    }

    func setEffort(exerciseIndex ei: Int, setIndex si: Int, _ effort: Effort) {
        guard exercises.indices.contains(ei),
              exercises[ei].sets.indices.contains(si) else { return }
        exercises[ei].sets[si].effort = effort
    }

    func cycleEffort(exerciseIndex ei: Int, setIndex si: Int) {
        guard exercises.indices.contains(ei),
              exercises[ei].sets.indices.contains(si) else { return }
        let current = exercises[ei].sets[si].effort ?? .solid
        let idx = Self.effortCycle.firstIndex(of: current) ?? 1
        exercises[ei].sets[si].effort = Self.effortCycle[(idx + 1) % Self.effortCycle.count]
    }
```

- [ ] **Step 4:** re-run test → all 5 new pass; existing `ActiveWorkoutSessionTests` still green; only pre-existing SquadMission failure may remain.

- [ ] **Step 5: Commit**

```bash
cd /Users/jlin/Documents/toji/UNBOUND
git add UNBOUND/Models/ActiveWorkoutSession.swift UNBOUNDTests/Models/ActiveWorkoutSessionV2Tests.swift
git commit -m "$(printf 'feat(logging): ActiveWorkoutSession index-addressed log/effort/cycle mutators (TDD)\n\nCo-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>')"
```

---

## Task 2: RestTimerModel + RestNotifier (TDD on the model)

**Files:** Create `UNBOUND/Services/WorkoutLog/RestNotifier.swift`, `UNBOUND/Models/RestTimerModel.swift`, `UNBOUNDTests/Models/RestTimerModelTests.swift`

- [ ] **Step 1: Write the failing test** (the model is the testable core; the notifier is injected via a protocol so tests use a spy)

```swift
import XCTest
@testable import UNBOUND

final class SpyRestNotifier: RestNotifying, @unchecked Sendable {
    var authRequested = 0
    var scheduled: [TimeInterval] = []
    var cancels = 0
    func requestAuthIfNeeded() async { authRequested += 1 }
    func schedule(after seconds: TimeInterval, title: String, body: String) { scheduled.append(seconds) }
    func cancelPending() { cancels += 1 }
}

@MainActor
final class RestTimerModelTests: XCTestCase {
    func test_start_schedulesNotification_andCountsDown() {
        let spy = SpyRestNotifier()
        let m = RestTimerModel(notifier: spy)
        m.start(seconds: 90, nextLabel: "Bench")
        XCTAssertEqual(m.remaining, 90)
        XCTAssertTrue(m.isActive)
        XCTAssertEqual(spy.scheduled, [90])
        m.tick(); m.tick()
        XCTAssertEqual(m.remaining, 88)
    }

    func test_addThirty_extendsAndReschedules() {
        let spy = SpyRestNotifier()
        let m = RestTimerModel(notifier: spy)
        m.start(seconds: 60, nextLabel: "Row")
        m.addThirty()
        XCTAssertEqual(m.remaining, 90)
        XCTAssertEqual(spy.scheduled.last, 90)        // rescheduled to remaining
    }

    func test_dismiss_hidesUIButKeepsRunning() {
        let spy = SpyRestNotifier()
        let m = RestTimerModel(notifier: spy)
        m.start(seconds: 30, nextLabel: "X")
        m.dismiss()
        XCTAssertFalse(m.isVisible)
        XCTAssertTrue(m.isActive)                      // still ticking under the hood
        XCTAssertEqual(spy.cancels, 0)                 // notification NOT cancelled on dismiss
    }

    func test_reachingZero_fires_andClears_andCancelsPending() {
        let spy = SpyRestNotifier()
        let m = RestTimerModel(notifier: spy)
        var fired = false
        m.onElapsed = { fired = true }
        m.start(seconds: 2, nextLabel: "X")
        m.tick(); m.tick()                              // 2 → 1 → fire at <=0
        XCTAssertTrue(fired)
        XCTAssertFalse(m.isActive)
        XCTAssertFalse(m.isVisible)
        XCTAssertEqual(spy.cancels, 1)                  // in-app fire cancels the pending push
    }

    func test_startingNewRest_cancelsPreviousPending() {
        let spy = SpyRestNotifier()
        let m = RestTimerModel(notifier: spy)
        m.start(seconds: 90, nextLabel: "A")
        m.start(seconds: 60, nextLabel: "B")            // new set logged before previous rest ended
        XCTAssertEqual(spy.cancels, 1)
        XCTAssertEqual(spy.scheduled, [90, 60])
        XCTAssertEqual(m.remaining, 60)
    }
}
```

- [ ] **Step 2:** run → FAIL (types absent).

- [ ] **Step 3a: Implement `UNBOUND/Services/WorkoutLog/RestNotifier.swift`**

```swift
import Foundation
import UserNotifications

protocol RestNotifying: Sendable {
    func requestAuthIfNeeded() async
    func schedule(after seconds: TimeInterval, title: String, body: String)
    func cancelPending()
}

/// Thin wrapper over UNUserNotificationCenter. Behaviour is exercised via the
/// RestTimerModel tests using a spy; this concrete impl is build-verified.
final class RestNotifier: RestNotifying, @unchecked Sendable {
    static let shared = RestNotifier()
    private let id = "unbound.rest.timer"
    private let center = UNUserNotificationCenter.current()

    func requestAuthIfNeeded() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    func schedule(after seconds: TimeInterval, title: String, body: String) {
        center.removePendingNotificationRequests(withIdentifiers: [id])
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, seconds), repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    func cancelPending() {
        center.removePendingNotificationRequests(withIdentifiers: [id])
    }
}
```

- [ ] **Step 3b: Implement `UNBOUND/Models/RestTimerModel.swift`**

```swift
import Foundation
import Combine

/// Owns rest-countdown state. Survives its own UI dismissal (isVisible vs
/// isActive). Drives a haptic + local notification at zero. The view starts a
/// 1s Timer and calls `tick()`; the model is otherwise pure and unit-tested.
@MainActor
final class RestTimerModel: ObservableObject {
    @Published private(set) var remaining: Int = 0
    @Published private(set) var isVisible: Bool = false
    @Published private(set) var isActive: Bool = false
    private(set) var nextLabel: String = ""

    var onElapsed: (() -> Void)?
    private let notifier: RestNotifying

    init(notifier: RestNotifying) { self.notifier = notifier }

    func start(seconds: Int, nextLabel: String) {
        if isActive { notifier.cancelPending() }     // restart: drop the old pending push
        self.nextLabel = nextLabel
        remaining = max(1, seconds)
        isVisible = true
        isActive = true
        notifier.schedule(after: TimeInterval(remaining),
                          title: "Rest complete",
                          body: nextLabel.isEmpty ? "Back to it." : "Next: \(nextLabel)")
    }

    func tick() {
        guard isActive else { return }
        remaining -= 1
        if remaining <= 0 { fire() }
    }

    func addThirty() {
        guard isActive else { return }
        remaining += 30
        notifier.schedule(after: TimeInterval(remaining),
                          title: "Rest complete",
                          body: nextLabel.isEmpty ? "Back to it." : "Next: \(nextLabel)")
    }

    /// Hide the card but keep counting (notification still pending).
    func dismiss() { isVisible = false }

    private func fire() {
        isActive = false
        isVisible = false
        notifier.cancelPending()                     // we're in-app; no need for the push too
        onElapsed?()
    }
}
```

- [ ] **Step 4:** re-run → 5 new pass; no new failures.

- [ ] **Step 5: Commit**

```bash
cd /Users/jlin/Documents/toji/UNBOUND
git add UNBOUND/Services/WorkoutLog/RestNotifier.swift UNBOUND/Models/RestTimerModel.swift UNBOUNDTests/Models/RestTimerModelTests.swift
git commit -m "$(printf 'feat(logging): RestTimerModel + RestNotifier seam (TDD)\n\nCo-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>')"
```

---

## Task 3: SetLogGridRow (UI — design bar)

Re-read the spec "Design bar". Compact, no prose. Cells show value (or placeholder); tapping a cell opens a `StepperControl` editor in a small sheet. The trailing **RPE dot** is the log control + effort: empty `◯` (not logged) → tap logs at `.solid`; tapping a filled dot calls `cycleEffort`. Colors: easy=`Color.unbound.success`, solid=`Color.unbound.warning`, hard=`Color.unbound.alert` (tuned via opacity per bar — not garish). Spring + `UnboundHaptics.success()` on log.

**Files:** Create `UNBOUND/Views/Program/ActiveWorkout/SetLogGridRow.swift`

- [ ] **Step 1: Implement**

```swift
import SwiftUI

struct SetLogGridRow: View {
    let setNumber: Int
    let weightKg: Double?
    let reps: Int?
    let effort: Effort?
    let logged: Bool
    let onEditWeight: () -> Void
    let onEditReps: () -> Void
    let onLog: () -> Void          // empty dot tapped → log at solid
    let onCycleEffort: () -> Void  // filled dot tapped → cycle color

    @State private var pop = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 10) {
            Text("\(setNumber)")
                .font(Font.unbound.monoS)
                .foregroundStyle(Color.unbound.textTertiary)
                .frame(width: 22, alignment: .leading)

            cell(text: weightKg.map(Self.fmt) ?? "—", action: onEditWeight)
            cell(text: reps.map(String.init) ?? "—", action: onEditReps)

            Button {
                if logged {
                    onCycleEffort()
                    UnboundHaptics.tick()
                } else {
                    onLog()
                    UnboundHaptics.success()
                    if !reduceMotion {
                        pop = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { pop = false }
                    }
                }
            } label: {
                Circle()
                    .fill(logged ? dotColor : Color.clear)
                    .overlay(Circle().strokeBorder(
                        logged ? Color.clear : Color.unbound.textTertiary, lineWidth: 1.5))
                    .frame(width: 28, height: 28)
                    .scaleEffect(pop && !reduceMotion ? 1.18 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.55), value: pop)
            }
            .buttonStyle(.plain)
            .frame(width: 40)
            .accessibilityLabel(logged ? "Set \(setNumber) effort" : "Log set \(setNumber)")
        }
        .padding(.vertical, 8)
    }

    private var dotColor: Color {
        switch effort ?? .solid {
        case .easy:  return Color.unbound.success
        case .solid: return Color.unbound.warning
        case .hard:  return Color.unbound.alert
        }
    }

    private func cell(text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(Font.unbound.monoM)
                .foregroundStyle(text == "—" ? Color.unbound.textTertiary : Color.unbound.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.unbound.surfaceElevated))
        }
        .buttonStyle(.plain)
    }

    private static func fmt(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(format: "%.1f", v)
    }
}
```

- [ ] **Step 2:** `xcodegen generate …; … build … | tail -6` → `BUILD SUCCEEDED`. If any token name is wrong, read `Color+Unbound.swift`/`Font+Unbound.swift`, substitute the closest real token (no invented tokens/hex), report it.

- [ ] **Step 3: Commit**

```bash
cd /Users/jlin/Documents/toji/UNBOUND
git add UNBOUND/Views/Program/ActiveWorkout/SetLogGridRow.swift
git commit -m "$(printf 'feat(logging): SetLogGridRow — compact set row + RPE/log dot\n\nCo-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>')"
```

---

## Task 4: ExerciseLogCard (UI — design bar)

**Files:** Create `UNBOUND/Views/Program/ActiveWorkout/ExerciseLogCard.swift`

- [ ] **Step 1: Implement**

```swift
import SwiftUI

struct ExerciseLogCard: View {
    let name: String
    let isWarmupCurrent: Bool
    let sets: [ActiveWorkoutSession.ActiveSet]
    let onIntent: (OverflowIntent) -> Void
    let onEditWeight: (Int) -> Void   // setIndex
    let onEditReps: (Int) -> Void
    let onLog: (Int) -> Void
    let onCycleEffort: (Int) -> Void
    let onAddSet: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                    .font(Font.unbound.titleM)
                    .foregroundStyle(Color.unbound.textPrimary)
                Spacer()
                ExerciseOverflowMenu(isWarmup: isWarmupCurrent, onIntent: onIntent)
            }
            .padding(.bottom, 4)

            HStack(spacing: 10) {
                Text("SET").frame(width: 22, alignment: .leading)
                Text("WEIGHT").frame(maxWidth: .infinity)
                Text("REPS").frame(maxWidth: .infinity)
                Text("RPE").frame(width: 40)
            }
            .font(Font.unbound.captionS)
            .tracking(1.2)
            .foregroundStyle(Color.unbound.textTertiary)

            ForEach(Array(sets.enumerated()), id: \.element.id) { idx, set in
                SetLogGridRow(
                    setNumber: idx + 1,
                    weightKg: set.weightKg,
                    reps: set.reps,
                    effort: set.effort,
                    logged: set.logged,
                    onEditWeight: { onEditWeight(idx) },
                    onEditReps: { onEditReps(idx) },
                    onLog: { onLog(idx) },
                    onCycleEffort: { onCycleEffort(idx) }
                )
                if idx < sets.count - 1 {
                    Divider().overlay(Color.unbound.borderSubtle)
                }
            }

            Button(action: onAddSet) {
                Label("Add set", systemImage: "plus")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .padding(.top, 10)
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.unbound.surface))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.unbound.border, lineWidth: 1))
    }
}
```

- [ ] **Step 2:** build → `BUILD SUCCEEDED` (token substitutions per Task 3 rule if needed).

- [ ] **Step 3: Commit**

```bash
cd /Users/jlin/Documents/toji/UNBOUND
git add UNBOUND/Views/Program/ActiveWorkout/ExerciseLogCard.swift
git commit -m "$(printf 'feat(logging): ExerciseLogCard — block of sets w/ RPE column header\n\nCo-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>')"
```

---

## Task 5: WorkoutLogGridView (UI — design bar)

**Files:** Create `UNBOUND/Views/Program/ActiveWorkout/WorkoutLogGridView.swift`

- [ ] **Step 1: Implement** (pure view over the session + closures; container owns state/editing/rest)

```swift
import SwiftUI

struct WorkoutLogGridView: View {
    @ObservedObject var session: ActiveWorkoutSession
    let onIntent: (Int, OverflowIntent) -> Void   // (exerciseIndex, intent)
    let onEditWeight: (Int, Int) -> Void           // (ei, si)
    let onEditReps: (Int, Int) -> Void
    let onLog: (Int, Int) -> Void
    let onCycleEffort: (Int, Int) -> Void
    let onAddSet: (Int) -> Void
    let onComplete: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(Array(session.exercises.enumerated()), id: \.element.id) { ei, ex in
                    if !ex.skipped {
                        ExerciseLogCard(
                            name: ex.name,
                            isWarmupCurrent: ex.sets.first?.isWarmup ?? false,
                            sets: ex.sets,
                            onIntent: { onIntent(ei, $0) },
                            onEditWeight: { onEditWeight(ei, $0) },
                            onEditReps: { onEditReps(ei, $0) },
                            onLog: { onLog(ei, $0) },
                            onCycleEffort: { onCycleEffort(ei, $0) },
                            onAddSet: { onAddSet(ei) }
                        )
                    }
                }

                Button(action: onComplete) {
                    Text("COMPLETE SESSION")
                        .font(Font.unbound.bodyLStrong)
                        .tracking(2)
                        .foregroundStyle(Color.unbound.bg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(RoundedRectangle(cornerRadius: 18).fill(Color.unbound.accent))
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
                .padding(.bottom, 120)   // clearance for the rest pill
            }
            .padding(16)
        }
        .background(Color.unbound.bg.ignoresSafeArea())
    }
}
```

- [ ] **Step 2:** build → `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
cd /Users/jlin/Documents/toji/UNBOUND
git add UNBOUND/Views/Program/ActiveWorkout/WorkoutLogGridView.swift
git commit -m "$(printf 'feat(logging): WorkoutLogGridView — one-scroll block logger\n\nCo-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>')"
```

---

## Task 6: RestTimerPill (UI — design bar)

**Files:** Create `UNBOUND/Views/Program/ActiveWorkout/RestTimerPill.swift`

- [ ] **Step 1: Implement** (driven by `RestTimerModel`; view only renders + emits intents; slide-up; never blocks the grid)

```swift
import SwiftUI

struct RestTimerPill: View {
    @ObservedObject var model: RestTimerModel
    let onAddThirty: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        if model.isVisible {
            HStack(spacing: 16) {
                Text("REST")
                    .font(Font.unbound.captionS).tracking(2)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text(timeString)
                    .font(Font.unbound.monoL)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .monospacedDigit()
                Spacer()
                Button("+30s", action: onAddThirty)
                    .font(Font.unbound.captionS).tracking(1)
                    .foregroundStyle(Color.unbound.accent)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.unbound.surfaceElevated)
                    .shadow(color: .black.opacity(0.4), radius: 18, y: 6))
            .overlay(RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.unbound.border, lineWidth: 1))
            .padding(.horizontal, 16)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var timeString: String {
        let m = model.remaining / 60, s = max(0, model.remaining % 60)
        return String(format: "%d:%02d", m, s)
    }
}
```

- [ ] **Step 2:** build → `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
cd /Users/jlin/Documents/toji/UNBOUND
git add UNBOUND/Views/Program/ActiveWorkout/RestTimerPill.swift
git commit -m "$(printf 'feat(logging): RestTimerPill — dismissible bottom countdown card\n\nCo-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>')"
```

---

## Task 7: Rework ActiveWorkoutContainerView (host grid + pill; preserve complete()/reward)

**Before starting:** READ the current `UNBOUND/Views/Program/ActiveWorkout/ActiveWorkoutContainerView.swift` in full. It already has the correct `init`, `loadContext()` (priorEntries via `WorkoutLogServiceProtocol.fetchRecentLogs`, `workingWeightKg` via `services.workingWeight.fetchWeight` with the normalized name), draft autosave, and `complete()` → `assembleWorkoutLog` → `services.workoutLog.saveLog` → `HapticManager.notification(.success)` → `draftStore.clear()` → the `RewardSummary`/`WorkoutRewardPresentation`/`RewardCelebrationView` trigger → `dismiss()`. **Preserve `loadContext()`, draft autosave, and the entire `complete()` + reward path verbatim** — only change the view body and rest handling.

**Files:** Modify `UNBOUND/Views/Program/ActiveWorkout/ActiveWorkoutContainerView.swift`

- [ ] **Step 1:** Replace the `.set`/`.rest` phase machine with: a `ZStack` whose base is `WorkoutLogGridView(session:…)` and whose bottom overlay is `RestTimerPill(model:restTimer)`. Remove `enum Phase`, the `ActiveSetView` branch, and the `RestTimerView` branch. Keep everything else.

Add state/owned objects:
```swift
@StateObject private var restTimer = RestTimerModel(notifier: RestNotifier.shared)
@State private var editing: (ei: Int, si: Int, isWeight: Bool)? = nil
private let restClock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
```

Body shape (adapt to the file's real surrounding modifiers — keep `.task { await loadContext() }`, `.interactiveDismissDisabled(true)`, the COMPLETE confirmation dialog):
```swift
ZStack(alignment: .bottom) {
    WorkoutLogGridView(
        session: session,
        onIntent: { ei, intent in handleIntent(ei, intent) },
        onEditWeight: { ei, si in editing = (ei, si, true) },
        onEditReps:   { ei, si in editing = (ei, si, false) },
        onLog: { ei, si in
            let g = ghost(ei: ei, si: si)
            session.logSet(exerciseIndex: ei, setIndex: si,
                           weightKg: session.exercises[ei].sets[si].weightKg ?? g?.weightKg,
                           reps: session.exercises[ei].sets[si].reps ?? g?.reps)
            try? draftStore.save(session)
            startRest(ei: ei)
        },
        onCycleEffort: { ei, si in
            session.cycleEffort(exerciseIndex: ei, setIndex: si)
            try? draftStore.save(session)
        },
        onAddSet: { ei in session.addSet(toExerciseIndex: ei); try? draftStore.save(session) },
        onComplete: { confirmOrComplete() }
    )
    RestTimerPill(
        model: restTimer,
        onAddThirty: { restTimer.addThirty() },
        onDismiss: { restTimer.dismiss() }
    )
    .padding(.bottom, 16)
}
.onReceive(restClock) { _ in restTimer.tick() }
.sheet(item: editBinding) { e in editorSheet(e) }   // StepperControl editor
.task { await RestNotifier.shared.requestAuthIfNeeded() }
```

- [ ] **Step 2:** Add the helpers in the same file:

```swift
private func startRest(ei: Int) {
    let secs = session.exercises.indices.contains(ei)
        ? session.exercises[ei].restSeconds : 90
    let next = session.exercises.indices.contains(ei) ? session.exercises[ei].name : ""
    restTimer.onElapsed = { UnboundHaptics.success() }
    restTimer.start(seconds: secs, nextLabel: next)
}

private func ghost(ei: Int, si: Int) -> SetPrefill.Ghost? {
    guard session.exercises.indices.contains(ei) else { return nil }
    return SetPrefill.ghost(exerciseName: session.exercises[ei].name,
                            setIndex: si, priorEntries: priorEntries,
                            workingWeightKg: workingWeightKg)
}

private func handleIntent(_ ei: Int, _ intent: OverflowIntent) {
    switch intent {
    case .toggleWarmup:
        if session.exercises.indices.contains(ei),
           let s0 = session.exercises[ei].sets.indices.first {
            session.exercises[ei].sets[s0].isWarmup.toggle()
        }
    case .addSet:    session.addSet(toExerciseIndex: ei)
    case .removeSet: session.removeLastSet(fromExerciseIndex: ei)
    case .skipExercise:
        if session.exercises.indices.contains(ei) { session.exercises[ei].skipped = true }
    case .editNotes, .swapExercise:
        break   // reuse the existing sheets already wired in this file for these intents
    }
    try? draftStore.save(session)
}
```

NOTE: `addSet(toExerciseIndex:)` / `removeLastSet(fromExerciseIndex:)` — if `ActiveWorkoutSession` only has the current-index `addSetToCurrentExercise()`/`removeLastSetFromCurrentExercise()`, add tiny index-addressed twins in Task 1's file (additive, mirror the guard pattern) and add a one-line test each to Task 1's test file. (Do this in Task 1 if you read ahead; otherwise add here and back-fill the Task 1 test.) Keep `editNotes`/`swapExercise` wired to whatever existing sheet/binding this file already had for them (read the file — the v1 container already implemented notes via a `NotesEditSheet` and swap via `ExerciseSwapSheet`; keep those).

- [ ] **Step 3:** Implement the `StepperControl` editor sheet: `editBinding`/`editorSheet(_:)` present a small sheet with a single `StepperControl` bound to the chosen cell, writing back via `session.logSet`-less direct mutation (set `session.exercises[ei].sets[si].weightKg/reps`) on dismiss; if the set was already `logged`, keep it logged. Reuse `StepperControl(label:value:step:unit:allowsDecimal:)` (weight step 2.5/decimal, reps step 1/non-decimal).

- [ ] **Step 4:** build → `BUILD SUCCEEDED`. Verify (read) that `loadContext()` and the whole `complete()`+reward block are unchanged.

- [ ] **Step 5: Commit**

```bash
cd /Users/jlin/Documents/toji/UNBOUND
git add UNBOUND/Views/Program/ActiveWorkout/ActiveWorkoutContainerView.swift UNBOUND/Models/ActiveWorkoutSession.swift UNBOUNDTests/Models/ActiveWorkoutSessionV2Tests.swift
git commit -m "$(printf 'feat(logging): container hosts grid + rest pill; preserve save/reward path\n\nCo-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>')"
```

---

## Task 8: Premium redesign of the exercise-detail screen

**Before starting:** re-read the spec "Design bar". READ `UNBOUND/Views/Program/WorkoutDetailView.swift` in full to find the body that renders **Target Muscles**, **Programming** (the `2 Sets` / `15 each direction` / `30s Rest` blocks — the giant wrapping monospace is the offender), and **Form Cues**. Do NOT change how it launches logging (the `.fullScreenCover` → `ActiveWorkoutContainerView` from T12 stays). Only restyle the presentational body.

**Files:** Modify `UNBOUND/Views/Program/WorkoutDetailView.swift`

- [ ] **Step 1:** Restyle to premium per these concrete rules:
  - **Programming block:** a single rounded `Color.unbound.surface` card; three inline stat columns `SETS · REPS · REST`. Numbers use `Font.unbound.monoL` (NOT a giant size that wraps); the rep prescription string (e.g. "15 each direction") uses `Font.unbound.bodyM` wrapping naturally on two lines max, never the huge mono. Labels `Font.unbound.captionS` `textTertiary`, 8pt-grid spacing, dividers `borderSubtle`.
  - **Target Muscles:** keep the chips but use `Color.unbound.accent.opacity(0.14)` fill + `accent` text, `Font.unbound.captionS`, consistent chip height.
  - **Form Cues:** `Font.unbound.bodyM`, `textSecondary`, icon in `accent`, on a `surface` card with the same corner radius as the others.
  - Section headers: `Font.unbound.captionS` uppercase tracked, `textTertiary`. Cards: 20pt corner radius, depth via subtle shadow not flat boxes. Generous vertical rhythm. No monospace text larger than `monoL`.

- [ ] **Step 2:** build → `BUILD SUCCEEDED`. (Token substitution rule from Task 3 applies.)

- [ ] **Step 3: Commit**

```bash
cd /Users/jlin/Documents/toji/UNBOUND
git add UNBOUND/Views/Program/WorkoutDetailView.swift
git commit -m "$(printf 'feat(program): premium exercise-detail redesign (kill giant mono wrap)\n\nCo-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>')"
```

---

## Task 9: Onboarding RPE teach-and-try step

**Before starting:** READ `UNBOUND/Views/Onboarding/OnboardingContainerView.swift` (and the `OnboardingRouter`/step enum it switches over — e.g. `Step_ScanAnalyzing`, `Step_Paywall`) to learn the exact step-enum name, the `advance`/`onComplete` mechanism, and where in the ordered flow to insert one screen (place it AFTER calibration/scan and BEFORE the paywall step, so the user has seen training context). This is a read-the-real-API insertion; do not guess the enum.

**Files:** Create `UNBOUND/Views/Onboarding/RPEOnboardingStep.swift`; Modify `UNBOUND/Views/Onboarding/OnboardingContainerView.swift`

- [ ] **Step 1: Create `RPEOnboardingStep.swift`** (one screen; the sample dot is the hero; ≤2 short copy lines; cinematic-restrained per bar; calls an injected `onContinue`)

```swift
import SwiftUI

struct RPEOnboardingStep: View {
    let onContinue: () -> Void
    @State private var demo: Effort = .solid

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Text("HOW HARD WAS THAT SET?")
                .font(Font.unbound.captionS).tracking(2)
                .foregroundStyle(Color.unbound.textTertiary)

            Button {
                let order: [Effort] = [.easy, .solid, .hard]
                demo = order[((order.firstIndex(of: demo) ?? 1) + 1) % 3]
                UnboundHaptics.tick()
            } label: {
                Circle().fill(color(demo))
                    .frame(width: 96, height: 96)
                    .overlay(Circle().strokeBorder(Color.unbound.border, lineWidth: 1))
                    .shadow(color: color(demo).opacity(0.5), radius: 24)
            }
            .buttonStyle(.plain)

            Text(demo == .easy ? "Easy" : demo == .solid ? "Solid" : "Hard")
                .font(Font.unbound.titleM)
                .foregroundStyle(Color.unbound.textPrimary)
                .contentTransition(.opacity)

            Text("Tap it after every set. Green easy, yellow solid, red hard. That's it — it tunes your program for you.")
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
            Spacer()

            Button(action: onContinue) {
                Text("GOT IT")
                    .font(Font.unbound.bodyLStrong).tracking(2)
                    .foregroundStyle(Color.unbound.bg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color.unbound.accent))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Color.unbound.bg.ignoresSafeArea())
    }

    private func color(_ e: Effort) -> Color {
        switch e { case .easy: return .unbound.success
                   case .solid: return .unbound.warning
                   case .hard: return .unbound.alert }
    }
}
```

- [ ] **Step 2: Insert into the flow** — add the new step case to the onboarding step enum and its `switch` in `OnboardingContainerView.swift` (or wherever the router renders steps), positioned after calibration/scan and before the paywall, calling the flow's existing `advance`/`onComplete` for `onContinue`. Match the file's exact pattern (read it first). Persist nothing extra — it's a one-time pass-through like other steps.

- [ ] **Step 3:** build → `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
cd /Users/jlin/Documents/toji/UNBOUND
git add UNBOUND/Views/Onboarding/RPEOnboardingStep.swift UNBOUND/Views/Onboarding/OnboardingContainerView.swift
git commit -m "$(printf 'feat(onboarding): RPE teach-and-try step (green/yellow/red)\n\nCo-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>')"
```

---

## Task 10: Retire the dead one-set views

Only after Tasks 1–9 build and the new flow is wired.

- [ ] **Step 1:** `grep -rn "ActiveSetView\|RestTimerView\|ExerciseDotNavigator" --include=*.swift UNBOUND/ | grep -v ActiveWorkoutContainerView` → expect only the three files themselves. Repoint any stray reference first.
- [ ] **Step 2:**
```bash
cd /Users/jlin/Documents/toji/UNBOUND
git rm UNBOUND/Views/Program/ActiveWorkout/ActiveSetView.swift \
       UNBOUND/Views/Program/ActiveWorkout/RestTimerView.swift \
       UNBOUND/Views/Program/ActiveWorkout/ExerciseDotNavigator.swift
xcodegen generate >/dev/null 2>&1
xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```
Expected `BUILD SUCCEEDED`.
- [ ] **Step 3:** full test suite → only the pre-existing SquadMission flap; zero new failures.
- [ ] **Step 4: Commit**
```bash
git commit -m "$(printf 'refactor(logging): retire one-set ActiveSetView/RestTimerView/DotNavigator\n\nCo-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>')"
```

---

## Task 11: On-device verification + parity (jlin-driven)

- [ ] **Step 1:** full test suite green (only pre-existing SquadMission flap).
- [ ] **Step 2:** build, install to iPhone 17 sim, launch. (jlin is signed in with a persisted program from the `41ff444` fix.)
- [ ] **Step 3:** jlin drives: Program → exercise (premium detail screen — confirm no giant mono wrap, premium) → Log Workout → grid. Screenshot + hold each against the design bar: the block grid, the RPE dot (tap to log = yellow; tap to cycle green/red), the rest pill (appears, dismiss keeps it running, +30s), COMPLETE → existing reward sheet still fires. New install → onboarding shows the RPE step.
- [ ] **Step 4:** parity: `supabase` query confirms a row in `workout_logs`; spot-check a cascade side-effect still fires (skill XP / rank). Confirm a backgrounded rest fires the local notification + haptic.
- [ ] **Step 5:** commit any design-fix tweaks from the on-device review.

---

## Self-Review

**Spec coverage:** block/grid one-scroll → T3/T4/T5; per-set traffic-light RPE dot = log+effort, "RPE" column header, no numerics → T3/T4 + T1 (default-solid-on-log, cycle order); reps-vs-target primary auto-progression → unchanged engine via byte-compatible `assembleWorkoutLog`/`saveLog` (T7 preserves it); no prev column → T3 (ghost not rendered; T7 still prefills the value via `ghost`); dismissible rest pop-up + haptic + local notification + first-use auth → T2 (model+notifier) + T6 (pill) + T7 (wiring, `requestAuthIfNeeded`); premium exercise-detail → T8; onboarding RPE teach → T9; tested core survives → T1 additive only, T7 preserves loadContext/complete/reward verbatim; retire one-set views → T10; design bar enforced T3–T9, verified T11. No gaps.

**Placeholder scan:** T7/T8/T9 contain explicit "READ the real file then apply" points (container current body, WorkoutDetailView body, onboarding step enum) — these are reads of verified-to-exist code with concrete, complete target specs/code, not invented APIs; the engineer has the codebase. No "TBD"/"handle edge cases"/bare "similar to". The one cross-task note (`addSet(toExerciseIndex:)`/`removeLastSet(fromExerciseIndex:)`) is explicitly specified to be added additively in Task 1's file with tests — not a placeholder.

**Type consistency:** `Effort` (.easy/.solid/.hard, `.rpe`) consistent T1/T3/T9; new mutators `logSet(exerciseIndex:setIndex:weightKg:reps:)`, `setEffort(exerciseIndex:setIndex:_:)`, `cycleEffort(exerciseIndex:setIndex:)`, `addSet(toExerciseIndex:)`, `removeLastSet(fromExerciseIndex:)` used identically in T1 and T7; `RestTimerModel` API (`start(seconds:nextLabel:)`, `tick()`, `addThirty()`, `dismiss()`, `onElapsed`, `isVisible/isActive/remaining`) consistent T2/T6/T7; `RestNotifying` (`requestAuthIfNeeded()`, `schedule(after:title:body:)`, `cancelPending()`) consistent T2/T7; `SetLogGridRow`/`ExerciseLogCard`/`WorkoutLogGridView` closure signatures chain consistently T3→T4→T5→T7; tokens are the verified `Color.unbound.*`/`Font.unbound.*`/`UnboundHaptics.*`.
