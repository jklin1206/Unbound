# Workout Logging Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace UNBOUND's modal-heavy workout logging with a focused active-set flow (one set on screen → LOG SET → auto rest ring → next), backed by a pure, fully-tested session state machine, autosave/resume, and a byte-compatible `WorkoutLogService.saveLog` call.

**Architecture:** Pure logic units (`EffortRPEMap`, `RestPrescription`, `SetPrefill`, `ActiveWorkoutSession`, `WorkoutDraftStore`) built TDD-first with XCTest. SwiftUI views (`StepperControl`, `ActiveSetView`, `RestTimerView`, `ExerciseDotNavigator`, `ExerciseOverflowMenu`, `ActiveWorkoutContainerView`) built to the spec's non-negotiable design bar. `ActiveWorkoutContainerView` assembles the existing `WorkoutLog` model and calls the unchanged `services.workoutLog.saveLog`, so the 11-step reward/skill/rank cascade keeps working untouched.

**Tech Stack:** Swift 5.9, SwiftUI, XCTest, xcodegen project. Branch: `program-redesign`. Sim: iPhone 17.

**Spec:** `docs/superpowers/specs/2026-05-16-workout-logging-redesign-design.md` (read its "Design system & quality bar" before any UI task).

---

## Verified existing signatures (use exactly; do not invent)

```swift
// Models/WorkoutLog.swift
struct WorkoutLog: Codable, Identifiable {
  let id: String; let userId: String; let programId: String; let dayNumber: Int
  let plannedWorkoutName: String; var startedAt: Date; var completedAt: Date?
  var exerciseEntries: [ExerciseLogEntry]; var overallNotes: String?
  var overallRPE: Int?; var durationMinutes: Int?
}
struct ExerciseLogEntry: Codable, Identifiable {
  let id: String; var exerciseName: String; var plannedSets: Int
  var plannedReps: String; var sets: [SetLog]; var skipped: Bool; var notes: String?
}
struct SetLog: Codable, Identifiable {
  let id: String; var setNumber: Int; var weightKg: Double?; var reps: Int
  var rpe: Int?; var isWarmup: Bool
}
// Models/Workout.swift
struct Workout { var name: String; var mainExercises: [Exercise]; ... }
struct Exercise: Codable, Identifiable, Hashable {
  let id: String; var name: String; var muscleGroups: [MuscleGroup]
  var sets: Int; var reps: String; var restSeconds: Int; var rpe: Int?
  var notes: String?; var substitution: String?
}
// Save path (WorkoutLoggingViewModel.saveLog reference)
services.auth.currentUserId            // String?
services.workoutLog.saveLog(log)       // async throws  (cascade lives inside; DO NOT change)
services.workingWeight.fetchWeight(userId:exerciseName:)  // -> has .weightKg: Double, .lastReps: Int
HapticManager.notification(.success)   // and .error
// Tokens (Color+Unbound.swift / Font+Unbound.swift)
Color.unbound.{bg,surface,surfaceElevated,textPrimary,textSecondary,textTertiary,border,borderSubtle,accent,impact,success}
Font.unbound.{titleL,titleM,bodyL,bodyM,bodyMStrong,caption,captionS,monoXL,monoL,monoM,monoS}
UnboundHaptics.{soft(),medium(),heavy(),tick(),success()}
// Rest-ring pattern source: Views/Routine/RoutinePlayerView.swift
//   Circle().trim(from:0,to:restProgress).stroke(...) ; Timer.publish(every:1...).autoconnect()
//   restProgress = Double(remaining)/Double(total) ; UnboundHaptics.tick() when remaining<=5
// Logging entry point: Views/Program/WorkoutDetailView.swift:100-109
//   .fullScreenCover(isPresented:$showLogging){ NavigationStack { WorkoutLoggingView(workout:liveWorkout, programId:programId, dayNumber:dayNumber, services:services) } }
```

**Commit convention:** `git add <files> && git commit -m "<msg>` ending with a line:
`Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`. Work on `program-redesign`.

**Test command (authoritative):**
`cd /Users/jlin/Documents/toji/UNBOUND && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' test 2>&1 | tail -25`
SourceKit cross-file "Cannot find" diagnostics are noise when xcodebuild passes — ignore them.

---

## File Structure

| File | Responsibility |
|---|---|
| `UNBOUND/Models/EffortRPEMap.swift` | `Effort` enum + Int RPE mapping (pure) |
| `UNBOUND/Services/WorkoutLog/RestPrescription.swift` | rest seconds for an exercise (pure) |
| `UNBOUND/Models/ActiveWorkoutSession.swift` | session state machine + Codable Snapshot (pure logic, ObservableObject) |
| `UNBOUND/Services/WorkoutLog/SetPrefill.swift` | per-set prefill/ghost from history → working weight → nil (pure) |
| `UNBOUND/Services/WorkoutLog/WorkoutDraftStore.swift` | persist/restore/clear the Snapshot |
| `UNBOUND/Views/Program/ActiveWorkout/StepperControl.swift` | the big weight/reps stepper |
| `UNBOUND/Views/Program/ActiveWorkout/ActiveSetView.swift` | the focused current-set screen |
| `UNBOUND/Views/Program/ActiveWorkout/RestTimerView.swift` | full-screen rest ring |
| `UNBOUND/Views/Program/ActiveWorkout/ExerciseDotNavigator.swift` | dot strip + session clock |
| `UNBOUND/Views/Program/ActiveWorkout/ExerciseOverflowMenu.swift` | warmup/notes/swap/add-remove/skip menu |
| `UNBOUND/Views/Program/ActiveWorkout/ActiveWorkoutContainerView.swift` | host: owns session, autosave, routes set↔rest, COMPLETE→save |
| `UNBOUND/Views/Program/WorkoutDetailView.swift` (modify) | point fullScreenCover at the container; resume |
| `UNBOUND/Views/Program/ProgramOverviewView.swift` (modify) | minimal "Resume your workout?" affordance |
| `UNBOUNDTests/Models/EffortRPEMapTests.swift` etc. | XCTest for each pure unit |

---

## Task 1: EffortRPEMap (TDD)

**Files:**
- Create: `UNBOUND/Models/EffortRPEMap.swift`
- Test: `UNBOUNDTests/Models/EffortRPEMapTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import UNBOUND

final class EffortRPEMapTests: XCTestCase {
    func test_rpeValues() {
        XCTAssertEqual(Effort.easy.rpe, 6)
        XCTAssertEqual(Effort.solid.rpe, 8)
        XCTAssertEqual(Effort.hard.rpe, 9)
    }
    func test_fromRPE_bucketsCorrectly() {
        XCTAssertEqual(Effort(rpe: 5), .easy)
        XCTAssertEqual(Effort(rpe: 7), .solid)
        XCTAssertEqual(Effort(rpe: 8), .solid)
        XCTAssertEqual(Effort(rpe: 9), .hard)
        XCTAssertEqual(Effort(rpe: 10), .hard)
        XCTAssertNil(Effort(rpe: nil))
    }
    func test_allCasesHaveLabels() {
        for e in Effort.allCases { XCTAssertFalse(e.label.isEmpty) }
    }
}
```

- [ ] **Step 2: Run test, verify it fails** — `... test 2>&1 | tail -25` → FAIL (Effort not found).

- [ ] **Step 3: Implement**

```swift
import Foundation

/// User-facing effort the lifter taps after a set. Maps to the Int RPE the
/// existing ProgressionEngine consumes via SetLog.rpe.
enum Effort: String, CaseIterable, Codable, Sendable {
    case easy, solid, hard

    var rpe: Int {
        switch self {
        case .easy: return 6
        case .solid: return 8
        case .hard: return 9
        }
    }

    var label: String {
        switch self {
        case .easy: return "Easy"
        case .solid: return "Solid"
        case .hard: return "Hard"
        }
    }

    /// Reverse-bucket a stored RPE back to an effort (for resumed drafts /
    /// prefill display). nil RPE → nil effort.
    init?(rpe: Int?) {
        guard let rpe else { return nil }
        switch rpe {
        case ..<7: self = .easy
        case 7...8: self = .solid
        default: self = .hard
        }
    }
}
```

- [ ] **Step 4: Run test, verify PASS.**

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Models/EffortRPEMap.swift UNBOUNDTests/Models/EffortRPEMapTests.swift
git commit -m "feat(logging): Effort→RPE map (TDD)
Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: RestPrescription (TDD)

**Files:**
- Create: `UNBOUND/Services/WorkoutLog/RestPrescription.swift`
- Test: `UNBOUNDTests/Services/WorkoutLog/RestPrescriptionTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import UNBOUND

final class RestPrescriptionTests: XCTestCase {
    private func ex(name: String, muscles: [MuscleGroup], rest: Int) -> Exercise {
        Exercise(id: "x", name: name, muscleGroups: muscles, sets: 3,
                 reps: "8", restSeconds: rest, rpe: nil, notes: nil, substitution: nil)
    }
    func test_explicitRestWins_whenSane() {
        XCTAssertEqual(RestPrescription.restSeconds(for: ex(name: "Bench Press", muscles: [.chest], rest: 120)), 120)
    }
    func test_zeroOrInsaneRest_fallsBackToClassification() {
        // compound (keyword) → 150
        XCTAssertEqual(RestPrescription.restSeconds(for: ex(name: "Back Squat", muscles: [.quads], rest: 0)), 150)
        // isolation → 90
        XCTAssertEqual(RestPrescription.restSeconds(for: ex(name: "Cable Curl", muscles: [.biceps], rest: 0)), 90)
        // absurd value clamped → classification
        XCTAssertEqual(RestPrescription.restSeconds(for: ex(name: "Cable Curl", muscles: [.biceps], rest: 5000)), 90)
    }
    func test_multiMuscleCountsAsCompound() {
        XCTAssertEqual(RestPrescription.restSeconds(for: ex(name: "Pendlay", muscles: [.back, .biceps], rest: 0)), 150)
    }
}
```

- [ ] **Step 2: Run test, verify it fails.**

- [ ] **Step 3: Implement** (self-contained heuristic; do NOT depend on ExerciseEquipmentClassifier — its API is unverified)

```swift
import Foundation

/// Default rest after a logged set. Honors the program's explicit
/// Exercise.restSeconds when sane; otherwise classifies compound vs isolation.
enum RestPrescription {
    static let compoundRest = 150
    static let isolationRest = 90
    private static let saneRange = 20...600

    private static let compoundKeywords = [
        "squat", "deadlift", "bench", "press", "row", "pull-up", "pullup",
        "chin-up", "chinup", "clean", "snatch", "thruster", "lunge", "dip"
    ]

    static func restSeconds(for exercise: Exercise) -> Int {
        if saneRange.contains(exercise.restSeconds) { return exercise.restSeconds }
        return isCompound(exercise) ? compoundRest : isolationRest
    }

    private static func isCompound(_ e: Exercise) -> Bool {
        if e.muscleGroups.count >= 2 { return true }
        let n = e.name.lowercased()
        return compoundKeywords.contains { n.contains($0) }
    }
}
```

- [ ] **Step 4: Run test, verify PASS.**

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Services/WorkoutLog/RestPrescription.swift UNBOUNDTests/Services/WorkoutLog/RestPrescriptionTests.swift
git commit -m "feat(logging): RestPrescription (explicit > classified) (TDD)
Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: ActiveWorkoutSession state machine (TDD)

**Files:**
- Create: `UNBOUND/Models/ActiveWorkoutSession.swift`
- Test: `UNBOUNDTests/Models/ActiveWorkoutSessionTests.swift`

This is the spine. Pure logic + Codable Snapshot. `@MainActor final class … ObservableObject` so SwiftUI can observe, but every mutation is a plain testable method.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import UNBOUND

@MainActor
final class ActiveWorkoutSessionTests: XCTestCase {
    private func workout() -> Workout {
        Workout(name: "Push", targetMuscleGroups: [],
            warmup: [],
            mainExercises: [
                Exercise(id: "e1", name: "Bench", muscleGroups: [.chest], sets: 2, reps: "8",
                         restSeconds: 120, rpe: nil, notes: nil, substitution: nil),
                Exercise(id: "e2", name: "Fly", muscleGroups: [.chest], sets: 1, reps: "12",
                         restSeconds: 60, rpe: nil, notes: nil, substitution: nil),
            ],
            cooldown: [], estimatedMinutes: 30, notes: nil, blockType: nil)
    }

    func test_buildsFromWorkout() {
        let s = ActiveWorkoutSession(workout: workout(), programId: "p", dayNumber: 1)
        XCTAssertEqual(s.exercises.count, 2)
        XCTAssertEqual(s.exercises[0].sets.count, 2)
        XCTAssertEqual(s.exercises[1].sets.count, 1)
        XCTAssertEqual(s.currentExerciseIndex, 0)
        XCTAssertEqual(s.currentSetIndex, 0)
        XCTAssertFalse(s.isLastSetOfWorkout)
    }

    func test_logCurrentSet_recordsAndAdvances() {
        let s = ActiveWorkoutSession(workout: workout(), programId: "p", dayNumber: 1)
        s.logCurrentSet(weightKg: 80, reps: 8)
        XCTAssertTrue(s.exercises[0].sets[0].logged)
        XCTAssertEqual(s.exercises[0].sets[0].weightKg, 80)
        XCTAssertEqual(s.exercises[0].sets[0].reps, 8)
        s.advance()
        XCTAssertEqual(s.currentExerciseIndex, 0)
        XCTAssertEqual(s.currentSetIndex, 1)
    }

    func test_advance_rollsToNextExercise() {
        let s = ActiveWorkoutSession(workout: workout(), programId: "p", dayNumber: 1)
        s.logCurrentSet(weightKg: 80, reps: 8); s.advance()
        s.logCurrentSet(weightKg: 80, reps: 7); s.advance()
        XCTAssertEqual(s.currentExerciseIndex, 1)
        XCTAssertEqual(s.currentSetIndex, 0)
    }

    func test_isLastSetOfWorkout_trueOnFinalSet() {
        let s = ActiveWorkoutSession(workout: workout(), programId: "p", dayNumber: 1)
        s.logCurrentSet(weightKg: 80, reps: 8); s.advance()
        s.logCurrentSet(weightKg: 80, reps: 7); s.advance()
        XCTAssertTrue(s.isLastSetOfWorkout)
    }

    func test_setEffort_storesOnCurrentSet() {
        let s = ActiveWorkoutSession(workout: workout(), programId: "p", dayNumber: 1)
        s.logCurrentSet(weightKg: 80, reps: 8)
        s.setEffort(.hard)
        XCTAssertEqual(s.exercises[0].sets[0].effort, .hard)
    }

    func test_addAndRemoveSet() {
        let s = ActiveWorkoutSession(workout: workout(), programId: "p", dayNumber: 1)
        s.addSetToCurrentExercise()
        XCTAssertEqual(s.exercises[0].sets.count, 3)
        s.removeLastSetFromCurrentExercise()
        XCTAssertEqual(s.exercises[0].sets.count, 2)
    }

    func test_skipCurrentExercise_marksAndJumps() {
        let s = ActiveWorkoutSession(workout: workout(), programId: "p", dayNumber: 1)
        s.skipCurrentExercise()
        XCTAssertTrue(s.exercises[0].skipped)
        XCTAssertEqual(s.currentExerciseIndex, 1)
    }

    func test_jumpToExercise() {
        let s = ActiveWorkoutSession(workout: workout(), programId: "p", dayNumber: 1)
        s.jumpToExercise(1)
        XCTAssertEqual(s.currentExerciseIndex, 1)
        XCTAssertEqual(s.currentSetIndex, 0)
        s.jumpToExercise(99) // out of range → no-op
        XCTAssertEqual(s.currentExerciseIndex, 1)
    }

    func test_assembleWorkoutLog_matchesModel() {
        let s = ActiveWorkoutSession(workout: workout(), programId: "p", dayNumber: 1)
        s.logCurrentSet(weightKg: 80, reps: 8); s.setEffort(.solid); s.advance()
        s.logCurrentSet(weightKg: 82.5, reps: 6); s.setEffort(.hard); s.advance()
        s.skipCurrentExercise()
        let log = s.assembleWorkoutLog(userId: "u")
        XCTAssertEqual(log.userId, "u")
        XCTAssertEqual(log.programId, "p")
        XCTAssertEqual(log.dayNumber, 1)
        XCTAssertEqual(log.plannedWorkoutName, "Push")
        XCTAssertEqual(log.exerciseEntries.count, 2)
        let bench = log.exerciseEntries[0]
        XCTAssertEqual(bench.exerciseName, "Bench")
        XCTAssertEqual(bench.sets.count, 2)
        XCTAssertEqual(bench.sets[0].setNumber, 1)
        XCTAssertEqual(bench.sets[0].weightKg, 80)
        XCTAssertEqual(bench.sets[0].reps, 8)
        XCTAssertEqual(bench.sets[0].rpe, 8)        // .solid → 8
        XCTAssertEqual(bench.sets[1].rpe, 9)        // .hard → 9
        XCTAssertTrue(log.exerciseEntries[1].skipped)
        XCTAssertNotNil(log.completedAt)
        XCTAssertNotNil(log.durationMinutes)
    }

    func test_snapshotRoundTrip() throws {
        let s = ActiveWorkoutSession(workout: workout(), programId: "p", dayNumber: 1)
        s.logCurrentSet(weightKg: 80, reps: 8); s.setEffort(.solid); s.advance()
        let data = try JSONEncoder().encode(s.snapshot())
        let snap = try JSONDecoder().decode(ActiveWorkoutSession.Snapshot.self, from: data)
        let restored = ActiveWorkoutSession(snapshot: snap)
        XCTAssertEqual(restored.exercises[0].sets[0].weightKg, 80)
        XCTAssertEqual(restored.exercises[0].sets[0].effort, .solid)
        XCTAssertEqual(restored.currentSetIndex, 1)
        XCTAssertEqual(restored.plannedWorkoutName, "Push")
    }
}
```

- [ ] **Step 2: Run test, verify it fails.**

- [ ] **Step 3: Implement**

```swift
import Foundation
import Combine

@MainActor
final class ActiveWorkoutSession: ObservableObject {

    struct ActiveSet: Identifiable, Codable, Sendable {
        let id: String
        var weightKg: Double?
        var reps: Int?
        var effort: Effort?
        var isWarmup: Bool
        var logged: Bool
    }

    struct ActiveExercise: Identifiable, Codable, Sendable {
        let id: String
        var name: String
        var plannedSets: Int
        var plannedReps: String
        var restSeconds: Int
        var muscleGroups: [MuscleGroup]
        var sets: [ActiveSet]
        var skipped: Bool
        var notes: String
    }

    struct Snapshot: Codable, Sendable {
        let id: String
        let programId: String
        let dayNumber: Int
        let plannedWorkoutName: String
        let startedAt: Date
        var exercises: [ActiveExercise]
        var currentExerciseIndex: Int
        var currentSetIndex: Int
    }

    let id: String
    let programId: String
    let dayNumber: Int
    let plannedWorkoutName: String
    let startedAt: Date

    @Published var exercises: [ActiveExercise]
    @Published var currentExerciseIndex: Int = 0
    @Published var currentSetIndex: Int = 0

    // MARK: Build from a planned workout

    init(workout: Workout, programId: String, dayNumber: Int) {
        self.id = UUID().uuidString
        self.programId = programId
        self.dayNumber = dayNumber
        self.plannedWorkoutName = workout.name
        self.startedAt = Date()
        self.exercises = workout.mainExercises.map { ex in
            ActiveExercise(
                id: ex.id,
                name: ex.name,
                plannedSets: ex.sets,
                plannedReps: ex.reps,
                restSeconds: RestPrescription.restSeconds(for: ex),
                muscleGroups: ex.muscleGroups,
                sets: (0..<max(1, ex.sets)).map { _ in
                    ActiveSet(id: UUID().uuidString, weightKg: nil, reps: nil,
                              effort: nil, isWarmup: false, logged: false)
                },
                skipped: false,
                notes: ""
            )
        }
    }

    // MARK: Restore from a draft

    init(snapshot s: Snapshot) {
        self.id = s.id
        self.programId = s.programId
        self.dayNumber = s.dayNumber
        self.plannedWorkoutName = s.plannedWorkoutName
        self.startedAt = s.startedAt
        self.exercises = s.exercises
        self.currentExerciseIndex = min(s.currentExerciseIndex, max(0, s.exercises.count - 1))
        self.currentSetIndex = s.currentSetIndex
    }

    func snapshot() -> Snapshot {
        Snapshot(id: id, programId: programId, dayNumber: dayNumber,
                 plannedWorkoutName: plannedWorkoutName, startedAt: startedAt,
                 exercises: exercises, currentExerciseIndex: currentExerciseIndex,
                 currentSetIndex: currentSetIndex)
    }

    // MARK: Derived

    var currentExercise: ActiveExercise? {
        exercises.indices.contains(currentExerciseIndex) ? exercises[currentExerciseIndex] : nil
    }

    var isLastSetOfWorkout: Bool {
        guard let last = exercises.indices.last else { return true }
        // last non-skipped exercise, last set
        let lastActiveIdx = exercises.lastIndex(where: { !$0.skipped }) ?? last
        guard currentExerciseIndex == lastActiveIdx else { return false }
        return currentSetIndex >= exercises[lastActiveIdx].sets.count - 1
    }

    // MARK: Mutations

    func logCurrentSet(weightKg: Double?, reps: Int?) {
        guard exercises.indices.contains(currentExerciseIndex),
              exercises[currentExerciseIndex].sets.indices.contains(currentSetIndex) else { return }
        exercises[currentExerciseIndex].sets[currentSetIndex].weightKg = weightKg
        exercises[currentExerciseIndex].sets[currentSetIndex].reps = reps
        exercises[currentExerciseIndex].sets[currentSetIndex].logged = true
    }

    func setEffort(_ effort: Effort) {
        guard exercises.indices.contains(currentExerciseIndex),
              exercises[currentExerciseIndex].sets.indices.contains(currentSetIndex) else { return }
        exercises[currentExerciseIndex].sets[currentSetIndex].effort = effort
    }

    func toggleCurrentWarmup() {
        guard exercises.indices.contains(currentExerciseIndex),
              exercises[currentExerciseIndex].sets.indices.contains(currentSetIndex) else { return }
        exercises[currentExerciseIndex].sets[currentSetIndex].isWarmup.toggle()
    }

    func advance() {
        guard exercises.indices.contains(currentExerciseIndex) else { return }
        if currentSetIndex < exercises[currentExerciseIndex].sets.count - 1 {
            currentSetIndex += 1
        } else {
            advanceToNextUnskippedExercise(after: currentExerciseIndex)
        }
    }

    private func advanceToNextUnskippedExercise(after idx: Int) {
        var next = idx + 1
        while next < exercises.count && exercises[next].skipped { next += 1 }
        if next < exercises.count {
            currentExerciseIndex = next
            currentSetIndex = 0
        }
        // else: stay (workout effectively complete)
    }

    func jumpToExercise(_ index: Int) {
        guard exercises.indices.contains(index) else { return }
        currentExerciseIndex = index
        currentSetIndex = 0
    }

    func addSetToCurrentExercise() {
        guard exercises.indices.contains(currentExerciseIndex) else { return }
        exercises[currentExerciseIndex].sets.append(
            ActiveSet(id: UUID().uuidString, weightKg: nil, reps: nil,
                      effort: nil, isWarmup: false, logged: false))
    }

    func removeLastSetFromCurrentExercise() {
        guard exercises.indices.contains(currentExerciseIndex),
              exercises[currentExerciseIndex].sets.count > 1 else { return }
        exercises[currentExerciseIndex].sets.removeLast()
        if currentSetIndex >= exercises[currentExerciseIndex].sets.count {
            currentSetIndex = exercises[currentExerciseIndex].sets.count - 1
        }
    }

    func skipCurrentExercise() {
        guard exercises.indices.contains(currentExerciseIndex) else { return }
        exercises[currentExerciseIndex].skipped = true
        advanceToNextUnskippedExercise(after: currentExerciseIndex)
    }

    func setNotes(_ text: String, forExerciseAt index: Int) {
        guard exercises.indices.contains(index) else { return }
        exercises[index].notes = text
    }

    // MARK: Assemble the existing WorkoutLog (byte-compatible with WorkoutLogService)

    func assembleWorkoutLog(userId: String) -> WorkoutLog {
        let entries = exercises.map { ex in
            ExerciseLogEntry(
                id: UUID().uuidString,
                exerciseName: ex.name,
                plannedSets: ex.plannedSets,
                plannedReps: ex.plannedReps,
                sets: ex.sets.enumerated().compactMap { (i, set) in
                    guard set.logged else { return nil }
                    return SetLog(
                        id: set.id,
                        setNumber: i + 1,
                        weightKg: set.weightKg,
                        reps: set.reps ?? 0,
                        rpe: set.effort?.rpe,
                        isWarmup: set.isWarmup
                    )
                },
                skipped: ex.skipped,
                notes: ex.notes.isEmpty ? nil : ex.notes
            )
        }
        return WorkoutLog(
            id: id,
            userId: userId,
            programId: programId,
            dayNumber: dayNumber,
            plannedWorkoutName: plannedWorkoutName,
            startedAt: startedAt,
            completedAt: Date(),
            exerciseEntries: entries,
            overallNotes: nil,
            overallRPE: nil,
            durationMinutes: max(0, Int(Date().timeIntervalSince(startedAt) / 60))
        )
    }
}
```

- [ ] **Step 4: Run test, verify PASS (all 11 cases).**

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Models/ActiveWorkoutSession.swift UNBOUNDTests/Models/ActiveWorkoutSessionTests.swift
git commit -m "feat(logging): ActiveWorkoutSession state machine + Codable snapshot (TDD)
Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: SetPrefill (TDD)

Pure function over passed-in history (no service fetch inside → testable). The container will source `priorEntries` via the existing workout-log read API (implementer reads `WorkoutLogServiceProtocol` to find it) and `workingWeightKg` via `services.workingWeight`.

**Files:**
- Create: `UNBOUND/Services/WorkoutLog/SetPrefill.swift`
- Test: `UNBOUNDTests/Services/WorkoutLog/SetPrefillTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import UNBOUND

final class SetPrefillTests: XCTestCase {
    private func entry(_ name: String, _ sets: [(Double?, Int)]) -> ExerciseLogEntry {
        ExerciseLogEntry(id: "x", exerciseName: name, plannedSets: sets.count,
            plannedReps: "8",
            sets: sets.enumerated().map { (i, s) in
                SetLog(id: "s\(i)", setNumber: i + 1, weightKg: s.0, reps: s.1,
                       rpe: nil, isWarmup: false) },
            skipped: false, notes: nil)
    }

    func test_usesLastSessionMatchingSetIndex() {
        let history = [entry("Bench", [(80, 8), (82.5, 6)])]
        let g = SetPrefill.ghost(exerciseName: "Bench", setIndex: 1,
                                 priorEntries: history, workingWeightKg: 50)
        XCTAssertEqual(g?.weightKg, 82.5)
        XCTAssertEqual(g?.reps, 6)
    }

    func test_fallsBackToLastSetWhenIndexBeyondHistory() {
        let history = [entry("Bench", [(80, 8)])]
        let g = SetPrefill.ghost(exerciseName: "Bench", setIndex: 3,
                                 priorEntries: history, workingWeightKg: 50)
        XCTAssertEqual(g?.weightKg, 80)
        XCTAssertEqual(g?.reps, 8)
    }

    func test_fallsBackToWorkingWeightWhenNoHistory() {
        let g = SetPrefill.ghost(exerciseName: "Bench", setIndex: 0,
                                 priorEntries: [], workingWeightKg: 60)
        XCTAssertEqual(g?.weightKg, 60)
        XCTAssertNil(g?.reps)
    }

    func test_nilWhenNothingKnown() {
        XCTAssertNil(SetPrefill.ghost(exerciseName: "Bench", setIndex: 0,
                                      priorEntries: [], workingWeightKg: nil))
    }

    func test_caseInsensitiveNameMatch() {
        let history = [entry("bench press", [(100, 5)])]
        let g = SetPrefill.ghost(exerciseName: "Bench Press", setIndex: 0,
                                 priorEntries: history, workingWeightKg: nil)
        XCTAssertEqual(g?.weightKg, 100)
    }
}
```

- [ ] **Step 2: Run test, verify it fails.**

- [ ] **Step 3: Implement**

```swift
import Foundation

/// Per-set "previous" ghost shown above the steppers.
/// Priority: last session's matching set → last session's last set →
/// working weight (weight only) → nil.
enum SetPrefill {
    struct Ghost: Equatable { var weightKg: Double?; var reps: Int? }

    static func ghost(exerciseName: String,
                      setIndex: Int,
                      priorEntries: [ExerciseLogEntry],
                      workingWeightKg: Double?) -> Ghost? {
        let target = exerciseName.lowercased()
        if let last = priorEntries.last(where: { $0.exerciseName.lowercased() == target }),
           !last.sets.isEmpty {
            let set = last.sets.indices.contains(setIndex) ? last.sets[setIndex] : last.sets[last.sets.count - 1]
            return Ghost(weightKg: set.weightKg, reps: set.reps)
        }
        if let ww = workingWeightKg { return Ghost(weightKg: ww, reps: nil) }
        return nil
    }
}
```

- [ ] **Step 4: Run test, verify PASS.**

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Services/WorkoutLog/SetPrefill.swift UNBOUNDTests/Services/WorkoutLog/SetPrefillTests.swift
git commit -m "feat(logging): SetPrefill ghost (history>workingWeight>nil) (TDD)
Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: WorkoutDraftStore (TDD)

**Files:**
- Create: `UNBOUND/Services/WorkoutLog/WorkoutDraftStore.swift`
- Test: `UNBOUNDTests/Services/WorkoutLog/WorkoutDraftStoreTests.swift`

- [ ] **Step 1: Write the failing test** (inject a temp directory so tests don't touch real app-support)

```swift
import XCTest
@testable import UNBOUND

@MainActor
final class WorkoutDraftStoreTests: XCTestCase {
    private func tmpStore() -> WorkoutDraftStore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return WorkoutDraftStore(directory: dir)
    }
    private func session() -> ActiveWorkoutSession {
        ActiveWorkoutSession(workout: Workout(name: "Pull", targetMuscleGroups: [],
            warmup: [], mainExercises: [
                Exercise(id: "e1", name: "Row", muscleGroups: [.back], sets: 2, reps: "10",
                         restSeconds: 90, rpe: nil, notes: nil, substitution: nil)],
            cooldown: [], estimatedMinutes: 20, notes: nil, blockType: nil),
            programId: "p", dayNumber: 2)
    }

    func test_saveThenLoadRoundTrips() throws {
        let store = tmpStore()
        let s = session()
        s.logCurrentSet(weightKg: 60, reps: 10)
        try store.save(s)
        let restored = try XCTUnwrap(store.load())
        XCTAssertEqual(restored.plannedWorkoutName, "Pull")
        XCTAssertEqual(restored.exercises[0].sets[0].weightKg, 60)
    }

    func test_loadReturnsNilWhenNoDraft() {
        XCTAssertNil(tmpStore().load())
    }

    func test_clearRemovesDraft() throws {
        let store = tmpStore()
        try store.save(session())
        XCTAssertNotNil(store.load())
        store.clear()
        XCTAssertNil(store.load())
    }

    func test_hasDraftReflectsState() throws {
        let store = tmpStore()
        XCTAssertFalse(store.hasDraft)
        try store.save(session())
        XCTAssertTrue(store.hasDraft)
        store.clear()
        XCTAssertFalse(store.hasDraft)
    }
}
```

- [ ] **Step 2: Run test, verify it fails.**

- [ ] **Step 3: Implement**

```swift
import Foundation

/// Local autosave of an in-progress workout. Survives app kill / network drop.
/// Supabase save still happens only on COMPLETE (via WorkoutLogService).
@MainActor
final class WorkoutDraftStore {
    private let fileURL: URL

    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("UNBOUND", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        self.fileURL = base.appendingPathComponent("workout-draft.json")
    }

    var hasDraft: Bool { FileManager.default.fileExists(atPath: fileURL.path) }

    func save(_ session: ActiveWorkoutSession) throws {
        let data = try JSONEncoder().encode(session.snapshot())
        try data.write(to: fileURL, options: .atomic)
    }

    func load() -> ActiveWorkoutSession? {
        guard let data = try? Data(contentsOf: fileURL),
              let snap = try? JSONDecoder().decode(ActiveWorkoutSession.Snapshot.self, from: data)
        else { return nil }
        return ActiveWorkoutSession(snapshot: snap)
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
```

- [ ] **Step 4: Run test, verify PASS.**

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Services/WorkoutLog/WorkoutDraftStore.swift UNBOUNDTests/Services/WorkoutLog/WorkoutDraftStoreTests.swift
git commit -m "feat(logging): WorkoutDraftStore autosave/restore/clear (TDD)
Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: StepperControl (UI — design bar applies)

**Before starting:** re-read the spec's "Design system & quality bar". The stepper is a hero. Big central value (`Font.unbound.monoXL`), ▲/▼ with `UnboundHaptics.tick()` per increment, long-press to repeat, tap the value to type. ≥56pt hit targets. Use `Color.unbound` tokens only.

**Files:**
- Create: `UNBOUND/Views/Program/ActiveWorkout/StepperControl.swift`

- [ ] **Step 1: Implement**

```swift
import SwiftUI

/// Big glove-friendly numeric stepper. Tap value to type; ▲/▼ step;
/// long-press to repeat. One `tick` haptic per increment.
struct StepperControl: View {
    let label: String
    @Binding var value: Double
    var step: Double
    var unit: String?
    var allowsDecimal: Bool

    @State private var typing = false
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 8) {
            Text(label.uppercased())
                .font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textTertiary)
                .tracking(1.5)

            HStack(spacing: 18) {
                stepButton(system: "minus", delta: -step)

                Group {
                    if typing {
                        TextField("", text: $draft)
                            .keyboardType(allowsDecimal ? .decimalPad : .numberPad)
                            .multilineTextAlignment(.center)
                            .focused($focused)
                            .onSubmit(commit)
                            .onChange(of: focused) { _, isFocused in
                                if !isFocused { commit() }
                            }
                    } else {
                        Text(display)
                            .contentTransition(.numericText())
                            .onTapGesture {
                                draft = display
                                typing = true
                                focused = true
                                UnboundHaptics.soft()
                            }
                    }
                }
                .font(Font.unbound.monoXL)
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(minWidth: 132)

                stepButton(system: "plus", delta: step)
            }

            if let unit {
                Text(unit)
                    .font(Font.unbound.monoS)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var display: String {
        allowsDecimal
            ? (value.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(value)) : String(format: "%.1f", value))
            : String(Int(value))
    }

    private func commit() {
        if let n = Double(draft.replacingOccurrences(of: ",", with: ".")) {
            value = max(0, n)
        }
        typing = false
    }

    private func stepButton(system: String, delta: Double) -> some View {
        Button {
            value = max(0, value + delta)
            UnboundHaptics.tick()
        } label: {
            Image(systemName: system)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color.unbound.surfaceElevated))
                .overlay(Circle().strokeBorder(Color.unbound.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(delta < 0 ? "Decrease \(label)" : "Increase \(label)")
    }
}
```

- [ ] **Step 2: Build (no test target — visual component).**
Run: `... build 2>&1 | tail -5` → expect `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add UNBOUND/Views/Program/ActiveWorkout/StepperControl.swift
git commit -m "feat(logging): StepperControl — glove-friendly value stepper
Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: ExerciseDotNavigator (UI)

**Files:**
- Create: `UNBOUND/Views/Program/ActiveWorkout/ExerciseDotNavigator.swift`

- [ ] **Step 1: Implement**

```swift
import SwiftUI

/// Tertiary, edge-parked: progress dots + session clock. Tap a dot to jump.
struct ExerciseDotNavigator: View {
    let exerciseCount: Int
    let currentIndex: Int
    let completedIndices: Set<Int>
    let elapsedSeconds: Int
    let onJump: (Int) -> Void

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 7) {
                ForEach(0..<max(exerciseCount, 1), id: \.self) { i in
                    Circle()
                        .fill(color(for: i))
                        .frame(width: i == currentIndex ? 9 : 6,
                               height: i == currentIndex ? 9 : 6)
                        .onTapGesture {
                            UnboundHaptics.soft()
                            onJump(i)
                        }
                        .animation(.spring(response: 0.3, dampingFraction: 0.8),
                                   value: currentIndex)
                }
            }
            Spacer(minLength: 8)
            Text(clock)
                .font(Font.unbound.monoS)
                .foregroundStyle(Color.unbound.textTertiary)
                .monospacedDigit()
        }
    }

    private func color(for i: Int) -> Color {
        if i == currentIndex { return Color.unbound.accent }
        if completedIndices.contains(i) { return Color.unbound.textSecondary }
        return Color.unbound.textTertiary.opacity(0.5)
    }

    private var clock: String {
        let m = elapsedSeconds / 60, s = elapsedSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
```

- [ ] **Step 2: Build → `BUILD SUCCEEDED`.**

- [ ] **Step 3: Commit**

```bash
git add UNBOUND/Views/Program/ActiveWorkout/ExerciseDotNavigator.swift
git commit -m "feat(logging): ExerciseDotNavigator — progress dots + clock
Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: RestTimerView (UI — the one allowed quiet-drama)

**Before starting:** re-read the spec's rest-timer paragraph. Adapt the ring math from `Views/Routine/RoutinePlayerView.swift` (`Circle().trim(from:0,to:progress).stroke`, `Timer.publish(every:1...).autoconnect()`, `UnboundHaptics.tick()` when remaining ≤ 5, final `success()` + spring out). Full-screen, near-black, single large draining ring, big mono countdown, "next: <exercise> set N", skip / +30s low-emphasis.

**Files:**
- Create: `UNBOUND/Views/Program/ActiveWorkout/RestTimerView.swift`

- [ ] **Step 1: Implement**

```swift
import SwiftUI

struct RestTimerView: View {
    let totalSeconds: Int
    let nextLabel: String          // e.g. "Bench · set 3"
    let onFinished: () -> Void
    let onSkip: () -> Void

    @State private var remaining: Int
    @State private var ringPulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(totalSeconds: Int, nextLabel: String,
         onFinished: @escaping () -> Void, onSkip: @escaping () -> Void) {
        self.totalSeconds = totalSeconds
        self.nextLabel = nextLabel
        self.onFinished = onFinished
        self.onSkip = onSkip
        _remaining = State(initialValue: totalSeconds)
    }

    private var progress: Double {
        totalSeconds > 0 ? Double(remaining) / Double(totalSeconds) : 0
    }

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            VStack(spacing: 36) {
                Text("REST")
                    .font(Font.unbound.captionS)
                    .tracking(4)
                    .foregroundStyle(Color.unbound.textTertiary)

                ZStack {
                    Circle()
                        .strokeBorder(Color.unbound.surfaceElevated, lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.unbound.accent,
                                style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: remaining)
                    Text(timeString)
                        .font(Font.unbound.monoXL)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .monospacedDigit()
                }
                .frame(width: 240, height: 240)
                .scaleEffect(ringPulse && !reduceMotion ? 1.03 : 1.0)
                .animation(.easeInOut(duration: 0.5), value: ringPulse)

                Text("NEXT · \(nextLabel.uppercased())")
                    .font(Font.unbound.monoS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .tracking(1.5)

                HStack(spacing: 28) {
                    Button("SKIP") { finish(skipped: true) }
                        .font(Font.unbound.captionS)
                        .tracking(2)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Button("+30s") {
                        remaining += 30
                        UnboundHaptics.soft()
                    }
                        .font(Font.unbound.captionS)
                        .tracking(2)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
                .padding(.top, 8)
            }
            .padding(40)
        }
        .onReceive(clock) { _ in tick() }
    }

    private var timeString: String {
        let m = remaining / 60, s = remaining % 60
        return String(format: "%d:%02d", m, s)
    }

    private func tick() {
        if remaining <= 1 { finish(skipped: false); return }
        remaining -= 1
        if remaining <= 5 {
            UnboundHaptics.tick()
            ringPulse.toggle()
        }
    }

    private func finish(skipped: Bool) {
        clock.upstream.connect().cancel()
        if skipped {
            UnboundHaptics.soft()
            onSkip()
        } else {
            UnboundHaptics.success()
            onFinished()
        }
    }
}
```

- [ ] **Step 2: Build → `BUILD SUCCEEDED`.**

- [ ] **Step 3: Commit**

```bash
git add UNBOUND/Views/Program/ActiveWorkout/RestTimerView.swift
git commit -m "feat(logging): RestTimerView — full-screen draining ring
Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: ExerciseOverflowMenu (UI — relocate existing entry points)

**Before starting:** read `Views/Program/ExerciseSwapSheet*` and the custom-exercise builder for their exact init signatures (do NOT rebuild them). This menu just routes to them + session mutations.

**Files:**
- Create: `UNBOUND/Views/Program/ActiveWorkout/ExerciseOverflowMenu.swift`

- [ ] **Step 1: Implement** (Menu of actions; sheet presentation handled by the container — this view emits intents)

```swift
import SwiftUI

enum OverflowIntent {
    case toggleWarmup
    case editNotes
    case swapExercise
    case addSet
    case removeSet
    case skipExercise
}

struct ExerciseOverflowMenu: View {
    let isWarmup: Bool
    let onIntent: (OverflowIntent) -> Void

    var body: some View {
        Menu {
            Button {
                onIntent(.toggleWarmup)
            } label: {
                Label(isWarmup ? "Unmark warmup" : "Mark as warmup",
                      systemImage: "flame")
            }
            Button { onIntent(.addSet) } label: {
                Label("Add set", systemImage: "plus.circle")
            }
            Button { onIntent(.removeSet) } label: {
                Label("Remove last set", systemImage: "minus.circle")
            }
            Button { onIntent(.editNotes) } label: {
                Label("Notes", systemImage: "note.text")
            }
            Button { onIntent(.swapExercise) } label: {
                Label("Swap exercise", systemImage: "arrow.triangle.2.circlepath")
            }
            Divider()
            Button(role: .destructive) { onIntent(.skipExercise) } label: {
                Label("Skip exercise", systemImage: "forward.end")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.unbound.textTertiary)
                .frame(width: 44, height: 44)
        }
    }
}
```

- [ ] **Step 2: Build → `BUILD SUCCEEDED`.**

- [ ] **Step 3: Commit**

```bash
git add UNBOUND/Views/Program/ActiveWorkout/ExerciseOverflowMenu.swift
git commit -m "feat(logging): ExerciseOverflowMenu — recede secondary actions
Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: ActiveSetView (UI — the hero screen, design bar is the bar)

**Before starting:** re-read the ENTIRE "Design system & quality bar". Hierarchy: exercise name (`titleL`) → "Set X of Y" + prev ghost (`monoS`, `textTertiary`) → the two `StepperControl`s (dominant) → LOG SET (full-width, violet, weighted) → post-log inline effort chip → dot navigator + `⋯` edge-parked. LOG SET press = `soft()` + 0.97 scale; release = `success()` + brief violet bloom. Effort chip appears only after LOG SET, collapses on tap. `prefers-reduced-motion` → fades only, keep haptics.

**Files:**
- Create: `UNBOUND/Views/Program/ActiveWorkout/ActiveSetView.swift`

- [ ] **Step 1: Implement** (pure view over bindings/closures; the container owns state, prefill, rest routing)

```swift
import SwiftUI

struct ActiveSetView: View {
    let exerciseName: String
    let setNumber: Int
    let totalSets: Int
    let ghost: SetPrefill.Ghost?
    let isWarmup: Bool
    let isFinalSet: Bool
    let exerciseCount: Int
    let currentExerciseIndex: Int
    let completedExerciseIndices: Set<Int>
    let elapsedSeconds: Int

    @Binding var weight: Double
    @Binding var reps: Double
    @State private var pressed = false
    @State private var bloom = false
    @State private var loggedThisSet = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onLogSet: () -> Void
    let onPickEffort: (Effort) -> Void
    let onJumpExercise: (Int) -> Void
    let onIntent: (OverflowIntent) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(exerciseName)
                        .font(Font.unbound.titleL)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text(setLine)
                        .font(Font.unbound.monoS)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
                Spacer()
                ExerciseOverflowMenu(isWarmup: isWarmup, onIntent: onIntent)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer()

            // Steppers (dominant)
            HStack(spacing: 12) {
                StepperControl(label: "Weight", value: $weight, step: 2.5,
                               unit: "kg", allowsDecimal: true)
                StepperControl(label: "Reps", value: $reps, step: 1,
                               unit: nil, allowsDecimal: false)
            }
            .padding(.horizontal, 16)

            // Effort chip — only after a log this set
            if loggedThisSet {
                HStack(spacing: 8) {
                    ForEach(Effort.allCases, id: \.self) { e in
                        Button {
                            onPickEffort(e)
                            UnboundHaptics.soft()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                loggedThisSet = false
                            }
                        } label: {
                            Text(e.label)
                                .font(Font.unbound.bodyMStrong)
                                .foregroundStyle(Color.unbound.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.unbound.surfaceElevated))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(Color.unbound.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .transition(reduceMotion ? .opacity
                            : .move(edge: .bottom).combined(with: .opacity))
            }

            Spacer()

            // LOG SET (primary)
            Button {
                UnboundHaptics.success()
                bloom = true
                onLogSet()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    loggedThisSet = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { bloom = false }
            } label: {
                Text(isFinalSet ? "FINISH" : "LOG SET")
                    .font(Font.unbound.bodyLStrong)
                    .tracking(2)
                    .foregroundStyle(Color.unbound.bg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.unbound.accent)
                            .shadow(color: Color.unbound.accent.opacity(bloom ? 0.6 : 0.0),
                                    radius: bloom ? 24 : 0))
                    )
            }
            .buttonStyle(.plain)
            .scaleEffect(pressed && !reduceMotion ? 0.97 : 1.0)
            .onLongPressGesture(minimumDuration: 0, pressing: { p in
                pressed = p
                if p { UnboundHaptics.soft() }
            }, perform: {})
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            ExerciseDotNavigator(
                exerciseCount: exerciseCount,
                currentIndex: currentExerciseIndex,
                completedIndices: completedExerciseIndices,
                elapsedSeconds: elapsedSeconds,
                onJump: onJumpExercise
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .background(Color.unbound.bg.ignoresSafeArea())
    }

    private var setLine: String {
        var s = "SET \(setNumber) OF \(totalSets)"
        if let g = ghost {
            let w = g.weightKg.map { $0.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int($0)) : String(format: "%.1f", $0) } ?? "—"
            let r = g.reps.map(String.init) ?? "—"
            s += "    PREV \(w)kg × \(r)"
        }
        if isWarmup { s += "    · WARMUP" }
        return s
    }
}
```

- [ ] **Step 2: Build → `BUILD SUCCEEDED`.**

- [ ] **Step 3: Commit**

```bash
git add UNBOUND/Views/Program/ActiveWorkout/ActiveSetView.swift
git commit -m "feat(logging): ActiveSetView — the focused current-set screen
Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 11: ActiveWorkoutContainerView (orchestration)

Owns the `ActiveWorkoutSession`, prefill, autosave after every log, set↔rest routing, COMPLETE → assemble `WorkoutLog` → `services.workoutLog.saveLog` (UNCHANGED) → clear draft → existing reward sheet path. **Read `WorkoutLoggingView.swift` lines ~540-560 + its reward sheet binding and reproduce the exact same `rewardSummary` trigger so sub-project B's wiring is unaffected.** Match `WorkoutLoggingView`'s constructor params (`workout, programId, dayNumber, services`).

**Files:**
- Create: `UNBOUND/Views/Program/ActiveWorkout/ActiveWorkoutContainerView.swift`

- [ ] **Step 1: Implement**

```swift
import SwiftUI

struct ActiveWorkoutContainerView: View {
    @StateObject private var session: ActiveWorkoutSession
    @State private var phase: Phase = .set
    @State private var elapsed = 0
    @State private var weight: Double = 0
    @State private var reps: Double = 0
    @State private var priorEntries: [ExerciseLogEntry] = []
    @State private var workingWeightKg: Double? = nil
    @State private var saving = false
    @State private var showCompleteConfirm = false
    @Environment(\.dismiss) private var dismiss

    private let services: ServiceContainer
    private let draftStore: WorkoutDraftStore
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    enum Phase { case set, rest }

    init(workout: Workout, programId: String, dayNumber: Int,
         services: ServiceContainer, resuming: ActiveWorkoutSession? = nil) {
        self.services = services
        self.draftStore = WorkoutDraftStore()
        _session = StateObject(wrappedValue: resuming
            ?? ActiveWorkoutSession(workout: workout, programId: programId, dayNumber: dayNumber))
    }

    var body: some View {
        ZStack {
            switch phase {
            case .set:
                if let ex = session.currentExercise {
                    ActiveSetView(
                        exerciseName: ex.name,
                        setNumber: session.currentSetIndex + 1,
                        totalSets: ex.sets.count,
                        ghost: SetPrefill.ghost(
                            exerciseName: ex.name,
                            setIndex: session.currentSetIndex,
                            priorEntries: priorEntries,
                            workingWeightKg: workingWeightKg),
                        isWarmup: ex.sets[safe: session.currentSetIndex]?.isWarmup ?? false,
                        isFinalSet: session.isLastSetOfWorkout,
                        exerciseCount: session.exercises.count,
                        currentExerciseIndex: session.currentExerciseIndex,
                        completedExerciseIndices: completedIndices,
                        elapsedSeconds: elapsed,
                        weight: $weight,
                        reps: $reps,
                        onLogSet: logSet,
                        onPickEffort: { session.setEffort($0); afterLog() },
                        onJumpExercise: { session.jumpToExercise($0); syncInputs() },
                        onIntent: handle
                    )
                }
            case .rest:
                RestTimerView(
                    totalSeconds: session.currentExercise?.restSeconds ?? 90,
                    nextLabel: nextLabel,
                    onFinished: { withAnimation { phase = .set } },
                    onSkip: { withAnimation { phase = .set } }
                )
                .transition(.opacity)
            }
        }
        .onReceive(clock) { _ in elapsed = Int(Date().timeIntervalSince(session.startedAt)) }
        .task { await loadContext(); syncInputs() }
        .interactiveDismissDisabled(true)
        .confirmationDialog("Finish with sets remaining?",
                            isPresented: $showCompleteConfirm, titleVisibility: .visible) {
            Button("Finish workout", role: .destructive) { Task { await complete() } }
            Button("Keep training", role: .cancel) {}
        }
    }

    // MARK: derived
    private var completedIndices: Set<Int> {
        Set(session.exercises.enumerated()
            .filter { $0.element.skipped || $0.element.sets.allSatisfy(\.logged) }
            .map(\.offset))
    }
    private var nextLabel: String {
        guard let ex = session.currentExercise else { return "" }
        return "\(ex.name) · set \(session.currentSetIndex + 1)"
    }

    // MARK: flow
    private func logSet() {
        session.logCurrentSet(weightKg: weight > 0 ? weight : nil,
                              reps: Int(reps) > 0 ? Int(reps) : nil)
        try? draftStore.save(session)
    }
    private func afterLog() {
        if session.isLastSetOfWorkout {
            let remaining = session.exercises.contains {
                !$0.skipped && !$0.sets.allSatisfy(\.logged) }
            if remaining { showCompleteConfirm = true } else { Task { await complete() } }
        } else {
            session.advance()
            try? draftStore.save(session)
            syncInputs()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { phase = .rest }
        }
    }
    private func syncInputs() {
        let g = SetPrefill.ghost(
            exerciseName: session.currentExercise?.name ?? "",
            setIndex: session.currentSetIndex,
            priorEntries: priorEntries, workingWeightKg: workingWeightKg)
        weight = g?.weightKg ?? 0
        reps = Double(g?.reps ?? 0)
    }
    private func handle(_ intent: OverflowIntent) {
        switch intent {
        case .toggleWarmup: session.toggleCurrentWarmup()
        case .addSet: session.addSetToCurrentExercise()
        case .removeSet: session.removeLastSetFromCurrentExercise()
        case .skipExercise: session.skipCurrentExercise(); syncInputs()
        case .editNotes, .swapExercise: break // present existing sheets (read ExerciseSwapSheet init; wire here)
        }
        try? draftStore.save(session)
    }
    private func loadContext() async {
        guard let uid = services.auth.currentUserId else { return }
        // priorEntries: read WorkoutLogServiceProtocol for the fetch-recent API and populate.
        // workingWeightKg: services.workingWeight.fetchWeight(userId:exerciseName:) for the
        //   current exercise (normalized name lowercased, spaces→underscore as in
        //   WorkoutLoggingViewModel.loadWorkingWeights). Set @State accordingly.
        _ = uid
    }
    private func complete() async {
        guard let uid = services.auth.currentUserId, !saving else { return }
        saving = true
        let log = session.assembleWorkoutLog(userId: uid)
        do {
            try await services.workoutLog.saveLog(log)
            HapticManager.notification(.success)
            draftStore.clear()
            // Reproduce WorkoutLoggingView's reward trigger EXACTLY (read that file)
            // so sub-project B's wiring is unaffected; then dismiss().
            dismiss()
        } catch {
            HapticManager.notification(.error)
            saving = false
        }
    }
}

private extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
```

- [ ] **Step 2: Build → `BUILD SUCCEEDED`.** Resolve the two read-and-wire TODOs (priorEntries fetch, ExerciseSwapSheet/notes presentation, reward trigger) against the real APIs in `WorkoutLogServiceProtocol`, `ExerciseSwapSheet`, and `WorkoutLoggingView` — these are reads of existing code, not invention. No placeholder may remain in the committed file.

- [ ] **Step 3: Commit**

```bash
git add UNBOUND/Views/Program/ActiveWorkout/ActiveWorkoutContainerView.swift
git commit -m "feat(logging): ActiveWorkoutContainerView — orchestrate set↔rest↔save
Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 12: Wire entry point + resume affordance

**Files:**
- Modify: `UNBOUND/Views/Program/WorkoutDetailView.swift:100-109`
- Modify: `UNBOUND/Views/Program/ProgramOverviewView.swift` (minimal — add a "Resume your workout?" banner when `WorkoutDraftStore().hasDraft`, tapping it opens `ActiveWorkoutContainerView(resuming: WorkoutDraftStore().load())`)

- [ ] **Step 1: Repoint the fullScreenCover** in `WorkoutDetailView.swift`

```swift
.fullScreenCover(isPresented: $showLogging) {
    ActiveWorkoutContainerView(
        workout: liveWorkout,
        programId: programId,
        dayNumber: dayNumber,
        services: services
    )
}
```

- [ ] **Step 2: Add resume banner** to `ProgramOverviewView` near the top of its main scroll content (calm restore, not an alert — a single tappable surface using `Color.unbound.surfaceElevated`, `Font.unbound.bodyMStrong`, copy "Resume your workout?"). Present `ActiveWorkoutContainerView(workout:.init(name:"",targetMuscleGroups:[],warmup:[],mainExercises:[],cooldown:[],estimatedMinutes:0,notes:nil,blockType:nil), programId:"", dayNumber:0, services:services, resuming: draft)` where `draft = WorkoutDraftStore().load()` (the `resuming` session carries its own programId/dayNumber/workout, so the placeholder workout args are unused when resuming).

- [ ] **Step 3: Build → `BUILD SUCCEEDED`.**

- [ ] **Step 4: Commit**

```bash
git add UNBOUND/Views/Program/WorkoutDetailView.swift UNBOUND/Views/Program/ProgramOverviewView.swift
git commit -m "feat(logging): route logging to ActiveWorkoutContainerView + resume affordance
Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 13: On-device verification + parity guard

- [ ] **Step 1: Full test suite**
Run: `cd /Users/jlin/Documents/toji/UNBOUND && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' test 2>&1 | tail -25`
Expected: all green; the 5 new test files pass; pre-existing tests still pass.

- [ ] **Step 2: Install + launch + screenshot the new flow**

```bash
xcrun simctl boot 810087B3-226D-4398-8ABD-9FF61E642E1D 2>/dev/null; sleep 5
APP=$(ls -d /Users/jlin/Library/Developer/Xcode/DerivedData/UNBOUND-*/Build/Products/Debug-iphonesimulator/UNBOUND.app | head -1)
xcrun simctl install 810087B3-226D-4398-8ABD-9FF61E642E1D "$APP"
xcrun simctl launch 810087B3-226D-4398-8ABD-9FF61E642E1D com.unboundapp.ios
sleep 5; xcrun simctl io 810087B3-226D-4398-8ABD-9FF61E642E1D screenshot /tmp/active-set.png
```
Navigate Program → a day → Log Workout. Screenshot the active-set screen, log a set → screenshot the rest ring, screenshot the effort chip, COMPLETE → confirm the existing reward sheet still appears. Read each screenshot; hold against the spec's design bar (restrained, hero LOG SET, ring is the only drama). If any screen reads as a generic form, fix before proceeding.

- [ ] **Step 3: Parity guard** — confirm a completed session writes to Supabase and the cascade fired:
`cd /Users/jlin/Documents/toji/UNBOUND && supabase db remote query "select id, planned_workout_name, day_number, jsonb_array_length(to_jsonb(exercise_entries)) from workout_logs order by created_at desc limit 1;"` (adjust to the real column/table casing found in the squads migrations). Expect the just-logged session. Confirm a skill/rank/XP side-effect notification or row also moved (spot check one).

- [ ] **Step 4: Commit any design-fix tweaks from Step 2**

```bash
git add -A UNBOUND/Views/Program/ActiveWorkout
git diff --cached --quiet || git commit -m "fix(logging): on-device design polish from review
Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 14: Retire the old logging surface

Only after Task 13 passes and parity is confirmed.

- [ ] **Step 1: Grep for remaining references**
`cd /Users/jlin/Documents/toji/UNBOUND && grep -rn "WorkoutLoggingView\|WorkoutLoggingViewModel\|SetLogRow" --include=*.swift UNBOUND/ | grep -v ActiveWorkout`
Expected: only the three files themselves. If anything else references them, repoint it to the new flow first.

- [ ] **Step 2: Remove the dead files** (move to backups, don't hard-delete, per project rm-safety habit)

```bash
cd /Users/jlin/Documents/toji/UNBOUND
git rm UNBOUND/Views/Program/WorkoutLoggingView.swift \
       UNBOUND/ViewModels/WorkoutLoggingViewModel.swift \
       UNBOUND/Views/Components/SetLogRow.swift
```

- [ ] **Step 3: Regenerate the xcodegen project if needed + build**
`cd /Users/jlin/Documents/toji/UNBOUND && xcodegen generate 2>&1 | tail -3 && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Full test suite once more** → all green.

- [ ] **Step 5: Commit**

```bash
git commit -m "refactor(logging): retire WorkoutLoggingView/ViewModel/SetLogRow (replaced by focused flow)
Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage:** focused active-set flow → Tasks 7,10,11; auto rest ring with skip/+30s/auto-advance → Task 8; effort→RPE → Tasks 1,10,11; per-set prev ghost → Tasks 4,10; autosave/resume → Tasks 5,11,12; session clock + dot nav → Tasks 7,10; byte-compatible WorkoutLog/saveLog cascade → Task 3 (`assembleWorkoutLog`) + Task 11 (unchanged `saveLog` call) + Task 13 (parity guard); modal soup killed → Task 9 (single overflow); old surface retired → Task 14; design bar → enforced in Tasks 6-12 + verified Task 13. Out-of-scope items (rewards choreography, skill→program, visuals) correctly excluded. No gaps.

**Placeholder scan:** Task 11 contains two explicit "read existing API and wire" points (priorEntries fetch, ExerciseSwapSheet/notes presentation, reward trigger) — these are reads of verified-to-exist code, not invented APIs, and Step 2 forbids leaving a placeholder in the committed file. Acceptable: the engineer has the codebase; the alternative (guessing `WorkoutLogServiceProtocol`'s unread fetch signature) would violate type-consistency worse.

**Type consistency:** `Effort.rpe: Int` matches `SetLog.rpe: Int?`. `ActiveWorkoutSession.assembleWorkoutLog` emits exactly `WorkoutLog`/`ExerciseLogEntry`/`SetLog` per verified signatures. `SetPrefill.Ghost` used consistently in Tasks 4/10/11. `OverflowIntent` defined Task 9, consumed Tasks 10/11. Container init mirrors `WorkoutLoggingView(workout:programId:dayNumber:services:)`.
