# Program-Aware Logging Surface Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Surface the program's prescription on every set row (pre-populated SUGGESTED → solid LOGGED on confirm-or-edit) and make exercise detail reachable inline, without touching the save/reward/loadContext path.

**Architecture:** Thin model additions (suggestion fields + `confirmAsPlanned` + `recomputeLogged` + `RepRange`, back-compat Codable) feed a two-state row; `ExerciseDetailView`'s sections are extracted for inline reuse; the container wires confirm/edit→log transitions (one haptic + rest, once) and backfills suggested weights after `loadContext`. `assembleWorkoutLog`/`saveLog`/`complete()`/reward/`loadContext` stay byte-identical.

**Tech Stack:** Swift 5.9, SwiftUI, XCTest, xcodegen (`xcodegen generate` after adding files), `xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' test`.

**Spec:** `docs/superpowers/specs/2026-05-17-program-aware-logging-design.md`

---

## File structure

| File | Responsibility | Change |
|---|---|---|
| `UNBOUND/Models/ActiveWorkoutSession.swift` | Session state machine | Add `RepRange`; `ActiveSet.suggested*`; `ActiveExercise.targetRPE/formCues/substitution`; seed in `init(workout:)`; `confirmAsPlanned`; `recomputeLogged`; back-compat decoders. `assembleWorkoutLog`/`logSet`/`logCurrentSet` UNCHANGED. |
| `UNBOUND/Views/Program/ExerciseDetailSections.swift` | Reusable detail sections + FlowLayout | **Create** (extracted from ExerciseDetailView) |
| `UNBOUND/Views/Program/ExerciseDetailView.swift` | Standalone detail screen | Becomes thin wrapper over `ExerciseDetailSections` — no visual change |
| `UNBOUND/Views/Program/ActiveWorkout/SetLogGridRow.swift` | One set row | Rewrite: two-state (dim suggested / solid logged), confirm ring vs ✓ |
| `UNBOUND/Views/Program/ActiveWorkout/ExerciseLogCard.swift` | One exercise card | Target caption + inline expand + passthrough |
| `UNBOUND/Views/Program/ActiveWorkout/WorkoutLogGridView.swift` | Session scroll | Passthrough + own expand state; `onLog`→`onConfirmAsPlanned` |
| `UNBOUND/Views/Program/ActiveWorkout/ActiveWorkoutContainerView.swift` | Orchestrator | Wire confirm/edit→transition; backfill suggested weights; preserve save/reward/loadContext |
| `UNBOUNDTests/Models/ProgramAwareLoggingTests.swift` | Model tests | **Create** |

Branch: `program-redesign`. Frequent commits, co-authored trailer:
`Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`

---

### Task 1: Model — RepRange, suggestion fields, confirmAsPlanned, recomputeLogged, back-compat

**Files:**
- Modify: `UNBOUND/Models/ActiveWorkoutSession.swift`
- Create: `UNBOUNDTests/Models/ProgramAwareLoggingTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `UNBOUNDTests/Models/ProgramAwareLoggingTests.swift`:

```swift
import XCTest
@testable import UNBOUND

@MainActor
final class ProgramAwareLoggingTests: XCTestCase {

    private func ex(_ name: String, sets: Int = 3, reps: String = "8-10",
                    rpe: Int? = 8, notes: String? = "Brace hard",
                    sub: String? = "Machine variant") -> Exercise {
        Exercise(id: UUID().uuidString, name: name, muscleGroups: [.chest],
                 sets: sets, reps: reps, restSeconds: 150, rpe: rpe,
                 notes: notes, substitution: sub)
    }

    private func workout(_ exs: [Exercise]) -> Workout {
        Workout(name: "Push Day", targetMuscleGroups: [.chest],
                warmup: [], mainExercises: exs, cooldown: [],
                estimatedMinutes: 50, notes: nil, blockType: nil)
    }

    func test_repRange_lowerBound() {
        XCTAssertEqual(RepRange.lowerBound("8-10"), 8)
        XCTAssertEqual(RepRange.lowerBound("8"), 8)
        XCTAssertEqual(RepRange.lowerBound("12 each side"), 12)
        XCTAssertEqual(RepRange.lowerBound("30s"), 30)
        XCTAssertNil(RepRange.lowerBound("AMRAP"))
        XCTAssertNil(RepRange.lowerBound(""))
    }

    func test_initWorkout_seedsSuggestionsAndCarriesPrescription() {
        let s = ActiveWorkoutSession(workout: workout([ex("Bench Press")]),
                                     programId: "p", dayNumber: 1)
        let e = s.exercises[0]
        XCTAssertEqual(e.targetRPE, 8)
        XCTAssertEqual(e.formCues, "Brace hard")
        XCTAssertEqual(e.substitution, "Machine variant")
        XCTAssertEqual(e.sets.count, 3)
        XCTAssertEqual(e.sets[0].suggestedReps, 8)
        XCTAssertEqual(e.sets[0].suggestedRPE, 8)
        XCTAssertNil(e.sets[0].suggestedWeightKg)   // backfilled later by container
        XCTAssertFalse(e.sets[0].logged)
    }

    func test_confirmAsPlanned_copiesSuggestedToActualAndLogs() {
        let s = ActiveWorkoutSession(workout: workout([ex("Bench Press")]),
                                     programId: "p", dayNumber: 1)
        s.exercises[0].sets[0].suggestedWeightKg = 60
        s.confirmAsPlanned(exerciseIndex: 0, setIndex: 0)
        let set = s.exercises[0].sets[0]
        XCTAssertTrue(set.logged)
        XCTAssertEqual(set.weightKg, 60)
        XCTAssertEqual(set.reps, 8)
        XCTAssertEqual(set.rpe, 8)
    }

    func test_confirmAsPlanned_noopWhenAlreadyLogged() {
        let s = ActiveWorkoutSession(workout: workout([ex("Bench Press")]),
                                     programId: "p", dayNumber: 1)
        s.exercises[0].sets[0].weightKg = 99
        s.exercises[0].sets[0].reps = 5
        s.exercises[0].sets[0].logged = true
        s.confirmAsPlanned(exerciseIndex: 0, setIndex: 0)
        XCTAssertEqual(s.exercises[0].sets[0].weightKg, 99)   // untouched
        XCTAssertEqual(s.exercises[0].sets[0].reps, 5)
    }

    func test_recomputeLogged_transitionsOnceAndNeverUnlogs() {
        let s = ActiveWorkoutSession(workout: workout([ex("Bench Press")]),
                                     programId: "p", dayNumber: 1)
        // only weight → not logged yet
        s.exercises[0].sets[0].weightKg = 62
        XCTAssertFalse(s.recomputeLogged(exerciseIndex: 0, setIndex: 0))
        XCTAssertFalse(s.exercises[0].sets[0].logged)
        // add reps → transitions true (returns true exactly once)
        s.exercises[0].sets[0].reps = 9
        XCTAssertTrue(s.recomputeLogged(exerciseIndex: 0, setIndex: 0))
        XCTAssertTrue(s.exercises[0].sets[0].logged)
        // editing again → still logged, no second transition
        s.exercises[0].sets[0].weightKg = 64
        XCTAssertFalse(s.recomputeLogged(exerciseIndex: 0, setIndex: 0))
        XCTAssertTrue(s.exercises[0].sets[0].logged)
    }

    func test_assembleWorkoutLog_onlyLoggedSets_unchangedContract() {
        let s = ActiveWorkoutSession(workout: workout([ex("Bench Press", sets: 2)]),
                                     programId: "p", dayNumber: 1)
        s.exercises[0].sets[0].suggestedWeightKg = 60
        s.confirmAsPlanned(exerciseIndex: 0, setIndex: 0)   // set 1 logged
        let log = s.assembleWorkoutLog(userId: "u")
        XCTAssertEqual(log.exerciseEntries[0].sets.count, 1) // set 2 not logged
        XCTAssertEqual(log.exerciseEntries[0].sets[0].weightKg, 60)
        XCTAssertEqual(log.exerciseEntries[0].sets[0].reps, 8)
        XCTAssertEqual(log.exerciseEntries[0].sets[0].rpe, 8)
    }

    func test_activeSet_decodesLegacyJSON_withoutSuggestionKeys() throws {
        let legacy = """
        {"id":"abc","weightKg":null,"reps":null,"rpe":null,
         "isWarmup":false,"logged":false}
        """.data(using: .utf8)!
        let set = try JSONDecoder().decode(
            ActiveWorkoutSession.ActiveSet.self, from: legacy)
        XCTAssertEqual(set.id, "abc")
        XCTAssertFalse(set.logged)
        XCTAssertNil(set.suggestedWeightKg)
        XCTAssertNil(set.suggestedReps)
        XCTAssertNil(set.suggestedRPE)
    }

    func test_activeExercise_decodesLegacyJSON_withoutNewKeys() throws {
        let legacy = """
        {"id":"e1","name":"Bench","plannedSets":3,"plannedReps":"8",
         "restSeconds":150,"muscleGroups":["chest"],"sets":[],
         "skipped":false,"notes":""}
        """.data(using: .utf8)!
        let e = try JSONDecoder().decode(
            ActiveWorkoutSession.ActiveExercise.self, from: legacy)
        XCTAssertEqual(e.name, "Bench")
        XCTAssertNil(e.targetRPE)
        XCTAssertNil(e.formCues)
        XCTAssertNil(e.substitution)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/jlin/Documents/toji/UNBOUND && xcodegen generate >/dev/null && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:UNBOUNDTests/ProgramAwareLoggingTests 2>&1 | tail -20`
Expected: FAIL — `RepRange`, `confirmAsPlanned`, `recomputeLogged`, `suggested*`, `targetRPE/formCues/substitution` undefined.

- [ ] **Step 3: Add `RepRange` to `ActiveWorkoutSession.swift`**

At the top of the file, after `import Combine`, insert:

```swift
/// First integer run in a rep prescription string. "8-10"→8, "30s"→30,
/// "12 each side"→12, "AMRAP"→nil, ""→nil.
enum RepRange {
    static func lowerBound(_ s: String) -> Int? {
        var digits = ""
        for ch in s {
            if ch.isNumber { digits.append(ch) }
            else if !digits.isEmpty { break }
        }
        return Int(digits)
    }
}
```

- [ ] **Step 4: Extend `ActiveSet` with suggestion fields + back-compat decoder**

Replace the `struct ActiveSet` declaration with:

```swift
    struct ActiveSet: Identifiable, Codable, Sendable {
        let id: String
        var weightKg: Double?
        var reps: Int?
        var rpe: Int?
        var isWarmup: Bool
        var logged: Bool
        var suggestedWeightKg: Double?
        var suggestedReps: Int?
        var suggestedRPE: Int?

        init(id: String, weightKg: Double?, reps: Int?, rpe: Int?,
             isWarmup: Bool, logged: Bool,
             suggestedWeightKg: Double? = nil,
             suggestedReps: Int? = nil,
             suggestedRPE: Int? = nil) {
            self.id = id; self.weightKg = weightKg; self.reps = reps
            self.rpe = rpe; self.isWarmup = isWarmup; self.logged = logged
            self.suggestedWeightKg = suggestedWeightKg
            self.suggestedReps = suggestedReps
            self.suggestedRPE = suggestedRPE
        }

        enum CodingKeys: String, CodingKey {
            case id, weightKg, reps, rpe, isWarmup, logged
            case suggestedWeightKg, suggestedReps, suggestedRPE
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            weightKg = try c.decodeIfPresent(Double.self, forKey: .weightKg)
            reps = try c.decodeIfPresent(Int.self, forKey: .reps)
            rpe = try c.decodeIfPresent(Int.self, forKey: .rpe)
            isWarmup = try c.decodeIfPresent(Bool.self, forKey: .isWarmup) ?? false
            logged = try c.decodeIfPresent(Bool.self, forKey: .logged) ?? false
            suggestedWeightKg = try c.decodeIfPresent(Double.self, forKey: .suggestedWeightKg)
            suggestedReps = try c.decodeIfPresent(Int.self, forKey: .suggestedReps)
            suggestedRPE = try c.decodeIfPresent(Int.self, forKey: .suggestedRPE)
        }
    }
```

- [ ] **Step 5: Extend `ActiveExercise` with prescription fields + back-compat decoder**

Replace the `struct ActiveExercise` declaration with:

```swift
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
        var targetRPE: Int?
        var formCues: String?
        var substitution: String?

        init(id: String, name: String, plannedSets: Int, plannedReps: String,
             restSeconds: Int, muscleGroups: [MuscleGroup], sets: [ActiveSet],
             skipped: Bool, notes: String,
             targetRPE: Int? = nil, formCues: String? = nil,
             substitution: String? = nil) {
            self.id = id; self.name = name; self.plannedSets = plannedSets
            self.plannedReps = plannedReps; self.restSeconds = restSeconds
            self.muscleGroups = muscleGroups; self.sets = sets
            self.skipped = skipped; self.notes = notes
            self.targetRPE = targetRPE; self.formCues = formCues
            self.substitution = substitution
        }

        enum CodingKeys: String, CodingKey {
            case id, name, plannedSets, plannedReps, restSeconds
            case muscleGroups, sets, skipped, notes
            case targetRPE, formCues, substitution
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            name = try c.decode(String.self, forKey: .name)
            plannedSets = try c.decodeIfPresent(Int.self, forKey: .plannedSets) ?? 0
            plannedReps = try c.decodeIfPresent(String.self, forKey: .plannedReps) ?? ""
            restSeconds = try c.decodeIfPresent(Int.self, forKey: .restSeconds) ?? 0
            muscleGroups = try c.decodeIfPresent([MuscleGroup].self, forKey: .muscleGroups) ?? []
            sets = try c.decodeIfPresent([ActiveSet].self, forKey: .sets) ?? []
            skipped = try c.decodeIfPresent(Bool.self, forKey: .skipped) ?? false
            notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
            targetRPE = try c.decodeIfPresent(Int.self, forKey: .targetRPE)
            formCues = try c.decodeIfPresent(String.self, forKey: .formCues)
            substitution = try c.decodeIfPresent(String.self, forKey: .substitution)
        }
    }
```

- [ ] **Step 6: Seed suggestions + carry prescription in `init(workout:)`**

In `init(workout: Workout, programId: String, dayNumber: Int)`, replace the `self.exercises = workout.mainExercises.map { ex in ... }` block with:

```swift
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
                              rpe: nil, isWarmup: false, logged: false,
                              suggestedWeightKg: nil,
                              suggestedReps: RepRange.lowerBound(ex.reps),
                              suggestedRPE: ex.rpe)
                },
                skipped: false,
                notes: "",
                targetRPE: ex.rpe,
                formCues: ex.notes,
                substitution: ex.substitution
            )
        }
```

- [ ] **Step 7: Add `confirmAsPlanned` and `recomputeLogged`**

After the `func setRPE(exerciseIndex:setIndex:_:)` method, add:

```swift
    /// One-tap "did it as planned": copy the program's suggestion into the
    /// actual values and log. No-op if already logged or indices invalid.
    func confirmAsPlanned(exerciseIndex ei: Int, setIndex si: Int) {
        guard exercises.indices.contains(ei),
              exercises[ei].sets.indices.contains(si),
              !exercises[ei].sets[si].logged else { return }
        exercises[ei].sets[si].weightKg = exercises[ei].sets[si].suggestedWeightKg
        exercises[ei].sets[si].reps = exercises[ei].sets[si].suggestedReps
        exercises[ei].sets[si].rpe = exercises[ei].sets[si].suggestedRPE
        exercises[ei].sets[si].logged = true
    }

    /// Implicit logging: a set is logged once weight AND reps are both set.
    /// Never un-logs. Returns true only on the false→true edge so the caller
    /// can fire the haptic + rest exactly once.
    @discardableResult
    func recomputeLogged(exerciseIndex ei: Int, setIndex si: Int) -> Bool {
        guard exercises.indices.contains(ei),
              exercises[ei].sets.indices.contains(si) else { return false }
        let was = exercises[ei].sets[si].logged
        let complete = exercises[ei].sets[si].weightKg != nil
            && exercises[ei].sets[si].reps != nil
        if complete { exercises[ei].sets[si].logged = true }
        return complete && !was
    }
```

- [ ] **Step 8: Run tests to verify they pass**

Run: `cd /Users/jlin/Documents/toji/UNBOUND && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:UNBOUNDTests/ProgramAwareLoggingTests 2>&1 | tail -20`
Expected: PASS (all 8 tests).

- [ ] **Step 9: Regression — existing session tests stay green**

Run: `cd /Users/jlin/Documents/toji/UNBOUND && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:UNBOUNDTests/ActiveWorkoutSessionTests -only-testing:UNBOUNDTests/ActiveWorkoutSessionV2Tests 2>&1 | tail -15`
Expected: PASS (no regressions; `logSet`/`logCurrentSet`/`assembleWorkoutLog` unchanged).

- [ ] **Step 10: Commit**

```bash
cd /Users/jlin/Documents/toji/UNBOUND
git add UNBOUND/Models/ActiveWorkoutSession.swift UNBOUNDTests/Models/ProgramAwareLoggingTests.swift project.pbxproj 2>/dev/null; git add -A
git commit -m "feat(logging): model — RepRange, suggestion fields, confirmAsPlanned, recomputeLogged, back-compat decoders

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Extract `ExerciseDetailSections` (no behavior change to standalone screen)

**Files:**
- Create: `UNBOUND/Views/Program/ExerciseDetailSections.swift`
- Modify: `UNBOUND/Views/Program/ExerciseDetailView.swift`

- [ ] **Step 1: Create `ExerciseDetailSections.swift`**

```swift
import SwiftUI

/// The four detail sections (Target Muscles / Programming / Form Cues /
/// Substitution) shared by the standalone ExerciseDetailView and the inline
/// expansion inside ExerciseLogCard. Field-based so callers need not hold an
/// `Exercise`.
struct ExerciseDetailSections: View {
    let muscleGroups: [MuscleGroup]
    let sets: Int
    let reps: String
    let restSeconds: Int
    let formCues: String?
    let substitution: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            muscleGroupsSection
                .padding(.top, 8)
            programmingSection
                .padding(.top, 26)
            if let notes = formCues, !notes.isEmpty {
                formCuesSection(notes: notes)
                    .padding(.top, 26)
            }
            if let sub = substitution, !sub.isEmpty {
                substitutionSection(sub: sub)
                    .padding(.top, 26)
            }
        }
    }

    private var muscleGroupsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("TARGET MUSCLES")
                .font(Font.unbound.captionS)
                .tracking(1.5)
                .foregroundColor(Color.unbound.textTertiary)
            FlowLayout(spacing: 8) {
                ForEach(muscleGroups, id: \.self) { group in
                    Text(group.displayName)
                        .font(Font.unbound.captionS)
                        .foregroundColor(Color.unbound.accent)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.unbound.accent.opacity(0.14))
                        .clipShape(Capsule())
                }
            }
        }
    }

    private var programmingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("PROGRAMMING")
                .font(Font.unbound.captionS)
                .tracking(1.5)
                .foregroundColor(Color.unbound.textTertiary)
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.unbound.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.unbound.border, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 4)
                .overlay(
                    programmingColumns
                        .padding(.vertical, 20)
                        .padding(.horizontal, 8)
                )
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var programmingColumns: some View {
        HStack(spacing: 0) {
            programmingColumn(label: "SETS", value: "\(sets)", isMono: true)
            Rectangle().fill(Color.unbound.borderSubtle)
                .frame(width: 1).padding(.vertical, 6)
            programmingColumn(label: "REPS", value: reps, isMono: false)
            Rectangle().fill(Color.unbound.borderSubtle)
                .frame(width: 1).padding(.vertical, 6)
            programmingColumn(label: "REST", value: "\(restSeconds)s", isMono: true)
        }
    }

    private func programmingColumn(label: String, value: String, isMono: Bool) -> some View {
        VStack(spacing: 6) {
            if isMono {
                Text(value)
                    .font(Font.unbound.monoL)
                    .foregroundColor(Color.unbound.textPrimary)
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
            } else {
                Text(value)
                    .font(Font.unbound.bodyM)
                    .foregroundColor(Color.unbound.textPrimary)
                    .lineLimit(2).minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
            }
            Text(label)
                .font(Font.unbound.captionS)
                .tracking(1.5)
                .foregroundColor(Color.unbound.textTertiary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
    }

    private func formCuesSection(notes: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("FORM CUES")
                .font(Font.unbound.captionS)
                .tracking(1.5)
                .foregroundColor(Color.unbound.textTertiary)
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "checklist")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.unbound.accent)
                    .frame(width: 24)
                Text(notes)
                    .font(Font.unbound.bodyM)
                    .foregroundColor(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)
            }
            .padding(18)
            .background(Color.unbound.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.unbound.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.30), radius: 10, x: 0, y: 3)
        }
    }

    private func substitutionSection(sub: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SUBSTITUTION")
                .font(Font.unbound.captionS)
                .tracking(1.5)
                .foregroundColor(Color.unbound.textTertiary)
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.unbound.textSecondary)
                    .frame(width: 24)
                Text(sub)
                    .font(Font.unbound.bodyM)
                    .foregroundColor(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)
            }
            .padding(18)
            .background(Color.unbound.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.unbound.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.30), radius: 10, x: 0, y: 3)
        }
    }
}

// MARK: - FlowLayout (wrap layout for chips — no third-party dependency)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var height: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                height += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
```

- [ ] **Step 2: Replace `ExerciseDetailView.swift` with a thin wrapper**

Replace the entire file with:

```swift
import SwiftUI

struct ExerciseDetailView: View {
    let exercise: Exercise

    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()
            ScrollView {
                ExerciseDetailSections(
                    muscleGroups: exercise.muscleGroups,
                    sets: exercise.sets,
                    reps: exercise.reps,
                    restSeconds: exercise.restSeconds,
                    formCues: exercise.notes,
                    substitution: exercise.substitution
                )
                .padding(16)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ExerciseDetailView(exercise: Exercise(
            id: "1",
            name: "Barbell Back Squat",
            muscleGroups: [.legs, .glutes, .core],
            sets: 4,
            reps: "6-8",
            restSeconds: 120,
            rpe: 8,
            notes: "Keep chest up, brace core, drive through heels.",
            substitution: "Goblet Squat or Leg Press"
        ))
    }
}
```

- [ ] **Step 3: Regenerate project + build**

Run: `cd /Users/jlin/Documents/toji/UNBOUND && xcodegen generate >/dev/null && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`. (SourceKit cross-file noise ignored per project rule.)

- [ ] **Step 4: Commit**

```bash
cd /Users/jlin/Documents/toji/UNBOUND && git add -A
git commit -m "refactor(logging): extract ExerciseDetailSections (standalone screen unchanged)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Rewrite `SetLogGridRow` — two-state (dim suggested / solid logged)

**Files:**
- Modify: `UNBOUND/Views/Program/ActiveWorkout/SetLogGridRow.swift` (full replace)

- [ ] **Step 1: Replace the file**

```swift
import SwiftUI

/// One set row. SUGGESTED while `!logged` (program values shown dim,
/// trailing hollow ring = "log as planned"); LOGGED once `logged`
/// (actual values solid, filled ✓ status glyph). Editing a cell pre-seeds
/// the editor to actual-or-suggested.
struct SetLogGridRow: View {
    let setNumber: Int
    let weightKg: Double?
    let reps: Int?
    let rpe: Int?
    let suggestedWeightKg: Double?
    let suggestedReps: Int?
    let suggestedRPE: Int?
    let logged: Bool
    let onEditWeight: () -> Void
    let onEditReps: () -> Void
    let onPickRPE: () -> Void
    let onConfirmAsPlanned: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            Text("\(setNumber)")
                .font(Font.unbound.monoS)
                .foregroundStyle(Color.unbound.textTertiary)
                .frame(width: 20, alignment: .leading)

            cell(actual: weightKg.map(Self.fmt),
                 suggested: suggestedWeightKg.map(Self.fmt),
                 action: onEditWeight)
            cell(actual: reps.map(String.init),
                 suggested: suggestedReps.map(String.init),
                 action: onEditReps)

            Button(action: onPickRPE) {
                Text(display(actual: rpe.map(String.init),
                             suggested: suggestedRPE.map(String.init)))
                    .font(Font.unbound.monoM)
                    .foregroundStyle(valueColor(hasActual: rpe != nil,
                                                hasSuggested: suggestedRPE != nil))
                    .frame(width: 44)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10)
                        .fill(Color.unbound.surfaceElevated))
            }
            .buttonStyle(.plain)

            confirmControl.frame(width: 40)
        }
        .padding(.vertical, 8)
        .animation(reduceMotion ? nil
                   : .spring(response: 0.3, dampingFraction: 0.65),
                   value: logged)
    }

    @ViewBuilder private var confirmControl: some View {
        if logged {
            ZStack {
                Circle().fill(Color.unbound.accent).frame(width: 30, height: 30)
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.unbound.bg)
            }
            .accessibilityLabel("Set \(setNumber) logged")
        } else {
            Button(action: onConfirmAsPlanned) {
                Circle()
                    .strokeBorder(Color.unbound.textTertiary, lineWidth: 1.5)
                    .frame(width: 30, height: 30)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Log set \(setNumber) as planned")
        }
    }

    private func cell(actual: String?, suggested: String?,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(display(actual: actual, suggested: suggested))
                .font(Font.unbound.monoM)
                .foregroundStyle(valueColor(hasActual: actual != nil,
                                            hasSuggested: suggested != nil))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10)
                    .fill(Color.unbound.surfaceElevated))
        }
        .buttonStyle(.plain)
    }

    /// Actual value wins when present (user touched it); else the dim
    /// program suggestion; else em-dash.
    private func display(actual: String?, suggested: String?) -> String {
        if let a = actual { return a }
        if let s = suggested { return s }
        return "—"
    }

    private func valueColor(hasActual: Bool, hasSuggested: Bool) -> Color {
        if logged || hasActual { return Color.unbound.textPrimary }
        return Color.unbound.textTertiary   // dim suggestion or em-dash
    }

    private static func fmt(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(v)) : String(format: "%.1f", v)
    }
}
```

- [ ] **Step 2: Build (callers updated in Task 4/5/6; this step just type-checks the file in isolation is not possible — defer build to Task 5).**

No build here — `ExerciseLogCard` still references the old signature until Task 4. Proceed directly to commit; the cluster builds green at the end of Task 6.

- [ ] **Step 3: Commit**

```bash
cd /Users/jlin/Documents/toji/UNBOUND && git add -A
git commit -m "feat(logging): SetLogGridRow two-state (dim suggested / solid logged)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: `ExerciseLogCard` — Target caption + inline expand + passthrough

**Files:**
- Modify: `UNBOUND/Views/Program/ActiveWorkout/ExerciseLogCard.swift` (full replace)

- [ ] **Step 1: Replace the file**

```swift
import SwiftUI

struct ExerciseLogCard: View {
    let name: String
    let plannedSets: Int
    let plannedReps: String
    let targetRPE: Int?
    let restSeconds: Int
    let muscleGroups: [MuscleGroup]
    let formCues: String?
    let substitution: String?
    let isWarmupCurrent: Bool
    let sets: [ActiveWorkoutSession.ActiveSet]
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onIntent: (OverflowIntent) -> Void
    let onEditWeight: (Int) -> Void
    let onEditReps: (Int) -> Void
    let onPickRPE: (Int) -> Void
    let onConfirmAsPlanned: (Int) -> Void
    let onAddSet: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Button(action: onToggleExpand) {
                    HStack(spacing: 8) {
                        Text(name)
                            .font(Font.unbound.titleM)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .multilineTextAlignment(.leading)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.unbound.textTertiary)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer()
                ExerciseOverflowMenu(isWarmup: isWarmupCurrent, onIntent: onIntent)
            }

            Text(targetCaption)
                .font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textTertiary)
                .padding(.bottom, isExpanded ? 0 : 6)

            if isExpanded {
                Divider().overlay(Color.unbound.borderSubtle).padding(.vertical, 10)
                ExerciseDetailSections(
                    muscleGroups: muscleGroups,
                    sets: plannedSets,
                    reps: plannedReps,
                    restSeconds: restSeconds,
                    formCues: formCues,
                    substitution: substitution
                )
                .padding(.bottom, 14)
            }

            HStack(spacing: 8) {
                Text("SET").frame(width: 20, alignment: .leading)
                Text("WEIGHT").frame(maxWidth: .infinity)
                Text("REPS").frame(maxWidth: .infinity)
                Text("RPE").frame(width: 44)
                Spacer().frame(width: 40)
            }
            .font(Font.unbound.captionS)
            .tracking(1.2)
            .foregroundStyle(Color.unbound.textTertiary)

            ForEach(Array(sets.enumerated()), id: \.element.id) { idx, set in
                SetLogGridRow(
                    setNumber: idx + 1,
                    weightKg: set.weightKg,
                    reps: set.reps,
                    rpe: set.rpe,
                    suggestedWeightKg: set.suggestedWeightKg,
                    suggestedReps: set.suggestedReps,
                    suggestedRPE: set.suggestedRPE,
                    logged: set.logged,
                    onEditWeight: { onEditWeight(idx) },
                    onEditReps: { onEditReps(idx) },
                    onPickRPE: { onPickRPE(idx) },
                    onConfirmAsPlanned: { onConfirmAsPlanned(idx) }
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
        .overlay(RoundedRectangle(cornerRadius: 20)
            .strokeBorder(Color.unbound.border, lineWidth: 1))
        .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.85),
                   value: isExpanded)
    }

    private var targetCaption: String {
        var parts = ["Target · \(plannedSets) × \(plannedReps)"]
        if let r = targetRPE { parts.append("RPE \(r)") }
        parts.append("rest \(Self.mmss(restSeconds))")
        return parts.joined(separator: " · ")
    }

    private static func mmss(_ s: Int) -> String {
        "\(s / 60):" + String(format: "%02d", s % 60)
    }
}
```

- [ ] **Step 2: Commit** (build deferred to Task 5/6 cluster green)

```bash
cd /Users/jlin/Documents/toji/UNBOUND && git add -A
git commit -m "feat(logging): ExerciseLogCard — Target caption + inline expand + passthrough

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: `WorkoutLogGridView` — passthrough + own expand state

**Files:**
- Modify: `UNBOUND/Views/Program/ActiveWorkout/WorkoutLogGridView.swift` (full replace)

- [ ] **Step 1: Replace the file**

```swift
import SwiftUI

struct WorkoutLogGridView: View {
    @ObservedObject var session: ActiveWorkoutSession
    let onIntent: (Int, OverflowIntent) -> Void
    let onEditWeight: (Int, Int) -> Void
    let onEditReps: (Int, Int) -> Void
    let onPickRPE: (Int, Int) -> Void
    let onConfirmAsPlanned: (Int, Int) -> Void
    let onAddSet: (Int) -> Void
    let onComplete: () -> Void

    @State private var expanded: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(Array(session.exercises.enumerated()), id: \.element.id) { ei, ex in
                    if !ex.skipped {
                        ExerciseLogCard(
                            name: ex.name,
                            plannedSets: ex.plannedSets,
                            plannedReps: ex.plannedReps,
                            targetRPE: ex.targetRPE,
                            restSeconds: ex.restSeconds,
                            muscleGroups: ex.muscleGroups,
                            formCues: ex.formCues,
                            substitution: ex.substitution,
                            isWarmupCurrent: ex.sets.first?.isWarmup ?? false,
                            sets: ex.sets,
                            isExpanded: expanded.contains(ex.id),
                            onToggleExpand: {
                                if expanded.contains(ex.id) { expanded.remove(ex.id) }
                                else { expanded.insert(ex.id) }
                            },
                            onIntent: { onIntent(ei, $0) },
                            onEditWeight: { onEditWeight(ei, $0) },
                            onEditReps: { onEditReps(ei, $0) },
                            onPickRPE: { onPickRPE(ei, $0) },
                            onConfirmAsPlanned: { onConfirmAsPlanned(ei, $0) },
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
                        .background(RoundedRectangle(cornerRadius: 18)
                            .fill(Color.unbound.accent))
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
                .padding(.bottom, 120)
            }
            .padding(16)
        }
        .background(Color.unbound.bg.ignoresSafeArea())
    }
}
```

- [ ] **Step 2: Commit** (build green at end of Task 6)

```bash
cd /Users/jlin/Documents/toji/UNBOUND && git add -A
git commit -m "feat(logging): WorkoutLogGridView — passthrough + per-exercise expand state

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Wire `ActiveWorkoutContainerView` — confirm/edit→transition, suggested-weight backfill, preserve save/reward/loadContext

**Files:**
- Modify: `UNBOUND/Views/Program/ActiveWorkout/ActiveWorkoutContainerView.swift`

**CRITICAL:** Do NOT touch `complete()`, the `rewardSummary` sheet block, the `RewardSummary` construction, `assembleWorkoutLog` usage, swap/notes/custom sheets, or draft-save cadence. Only the grid wiring, the editor sheet, the RPE pre-seed, and `loadContext`'s tail change. The reviewer will `git diff` these to confirm byte-identical.

- [ ] **Step 1: Replace the `WorkoutLogGridView(...)` call** (currently the `onLog:`/`onPickRPE:`/`onAddSet:` closures)

Replace the entire `WorkoutLogGridView(` invocation in `body` with:

```swift
            WorkoutLogGridView(
                session: session,
                onIntent: { ei, intent in handleIntent(ei, intent) },
                onEditWeight: { ei, si in editing = EditTarget(ei: ei, si: si, isWeight: true) },
                onEditReps:   { ei, si in editing = EditTarget(ei: ei, si: si, isWeight: false) },
                onPickRPE: { ei, si in rpeTarget = RPETarget(ei: ei, si: si) },
                onConfirmAsPlanned: { ei, si in
                    session.confirmAsPlanned(exerciseIndex: ei, setIndex: si)
                    try? draftStore.save(session)
                    transition(ei: ei)
                },
                onAddSet: { ei in
                    session.addSet(toExerciseIndex: ei)
                    try? draftStore.save(session)
                },
                onComplete: { showCompleteConfirm = true }
            )
```

- [ ] **Step 2: Replace `EditorSheet` presentation to recompute + transition**

Replace the `.sheet(item: $editing) { t in ... }` block with:

```swift
        .sheet(item: $editing) { t in
            EditorSheet(
                session: session,
                ei: t.ei,
                si: t.si,
                isWeight: t.isWeight,
                onCommitted: {
                    let didLog = session.recomputeLogged(exerciseIndex: t.ei, setIndex: t.si)
                    try? draftStore.save(session)
                    if didLog { transition(ei: t.ei) }
                }
            )
        }
```

- [ ] **Step 3: Update the RPE picker pre-seed to actual-or-suggested**

In the `.sheet(item: $rpeTarget) { t in RPEPickerSheet(current: ...` block, replace the `current:` argument expression with:

```swift
                current: (session.exercises.indices.contains(t.ei)
                          && session.exercises[t.ei].sets.indices.contains(t.si))
                    ? (session.exercises[t.ei].sets[t.si].rpe
                       ?? session.exercises[t.ei].sets[t.si].suggestedRPE)
                    : nil,
```

- [ ] **Step 4: Add `transition` + backfill helper; call backfill at the end of `loadContext`**

Add these two methods to the struct (next to `startRest`):

```swift
    /// Fired exactly once per set on the SUGGESTED→LOGGED edge.
    private func transition(ei: Int) {
        UnboundHaptics.success()
        startRest(ei: ei)
    }

    /// After loadContext resolves history/working-weight, fill each set's
    /// dim suggested weight via the existing SetPrefill ghost.
    private func applySuggestedWeights() {
        for ei in session.exercises.indices {
            for si in session.exercises[ei].sets.indices
            where session.exercises[ei].sets[si].suggestedWeightKg == nil {
                if let g = SetPrefill.ghost(
                    exerciseName: session.exercises[ei].name,
                    setIndex: si,
                    priorEntries: priorEntries,
                    workingWeightKg: workingWeightKg) {
                    session.exercises[ei].sets[si].suggestedWeightKg = g.weightKg
                }
            }
        }
    }
```

At the very end of `func loadContext() async` (after the `workingWeightKg` assignment block), add:

```swift
        applySuggestedWeights()
```

- [ ] **Step 5: Update `EditorSheet` to take `onCommitted` and pre-seed actual-or-suggested**

In the private `struct EditorSheet`, replace `let onSave: () -> Void` with `let onCommitted: () -> Void`, update the `init` signature param `onSave` → `onCommitted` (and `self.onCommitted = onCommitted`), change the initial-value computation to fall back to the suggestion, and call `onCommitted()` instead of `onSave()` in `commit()`:

Initial value (replace the `if isWeight { initial = ... } else { initial = ... }` block):

```swift
        if isWeight {
            initial = session.exercises.indices.contains(ei)
                && session.exercises[ei].sets.indices.contains(si)
                ? (session.exercises[ei].sets[si].weightKg
                   ?? session.exercises[ei].sets[si].suggestedWeightKg ?? 0)
                : 0
        } else {
            initial = session.exercises.indices.contains(ei)
                && session.exercises[ei].sets.indices.contains(si)
                ? Double(session.exercises[ei].sets[si].reps
                         ?? session.exercises[ei].sets[si].suggestedReps ?? 0)
                : 0
        }
```

`commit()` tail (replace `onSave()` with `onCommitted()`):

```swift
        // Keep .logged unchanged here — the container's recomputeLogged
        // owns the SUGGESTED→LOGGED transition.
        onCommitted()
        dismiss()
```

- [ ] **Step 6: Regenerate + build the whole cluster**

Run: `cd /Users/jlin/Documents/toji/UNBOUND && xcodegen generate >/dev/null && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -8`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Full test suite**

Run: `cd /Users/jlin/Documents/toji/UNBOUND && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' test 2>&1 | tail -25`
Expected: all green except the known pre-existing `FriendChallengeServiceTests`/`SquadMissionServiceTests` RLS flap. Zero NEW failures.

- [ ] **Step 8: Commit**

```bash
cd /Users/jlin/Documents/toji/UNBOUND && git add -A
git commit -m "feat(logging): wire container — confirm/edit→transition, suggested-weight backfill; save/reward/loadContext byte-identical

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: Cluster review + byte-identical guard + on-device install

**Files:** none (review + verification only)

- [ ] **Step 1: Byte-identical guard** — confirm the preserved path is unchanged.

Run: `cd /Users/jlin/Documents/toji/UNBOUND && git log --oneline -7 && git diff e18cf1d -- UNBOUND/Views/Program/ActiveWorkout/ActiveWorkoutContainerView.swift | grep -E '^[+-]' | grep -iE 'saveLog|RewardSummary|rewardSummary|complete\\(\\)|assembleWorkoutLog' || echo "NO CHANGES to save/reward/complete tokens — GOOD"`
Expected: `NO CHANGES to save/reward/complete tokens — GOOD` (the only diffs touch grid wiring / editor / loadContext tail / RPE pre-seed).

- [ ] **Step 2: Spec-compliance review** — verify against `docs/superpowers/specs/2026-05-17-program-aware-logging-design.md`: two-state rows; confirm-as-planned 1 tap; edit-logs; one haptic+rest per set; no session header; inline expandable detail; Target caption; back-compat decoders; tokens only.

- [ ] **Step 3: Code-quality review** — naming, no dead `onLog`, no duplicated `FlowLayout`, reduce-motion paths, no force-unwraps on indices.

- [ ] **Step 4: Install to simulator (freshest build by mtime — never alphabetical)**

```bash
cd /Users/jlin/Documents/toji/UNBOUND
APP=$(ls -dt ~/Library/Developer/Xcode/DerivedData/UNBOUND-*/Build/Products/Debug-iphonesimulator/UNBOUND.app 2>/dev/null | head -1)
xcrun simctl boot "iPhone 17" 2>/dev/null; open -a Simulator
xcrun simctl install booted "$APP" && xcrun simctl launch booted com.unbound.UNBOUND && echo "INSTALLED + LAUNCHED: $APP"
```

- [ ] **Step 5: Hand to jlin for on-device design-bar sign-off** (per impeccable-design memory — on-device verification is jlin-driven): open today's workout → Target caption + dim suggested rows visible → tap name → card expands (muscles/cues/why) inline → tap a confirm ring → row solidifies + haptic + rest pill (one tap) → edit another set's weight → logs on commit → adjust a logged value → stays logged → COMPLETE → existing reward sheet fires → row in Supabase.

---

## Self-review

**Spec coverage:** locked decisions 1 (two-state, confirm/edit) → T1+T3+T6; 2 (one haptic+rest) → T6 `transition`; 3 (adjust later) → T1 `recomputeLogged` never un-logs + T6 editor; 4 (no session header) → T5; 5 (inline expand) → T2+T4; 6 (Target caption) → T4. Byte-identical guard → T7 S1. Back-compat → T1 S4/S5 + tests. All covered.

**Placeholder scan:** no TBD/“similar to”/vague steps; every code step shows full code.

**Type consistency:** `confirmAsPlanned(exerciseIndex:setIndex:)`, `recomputeLogged(exerciseIndex:setIndex:)`, `RepRange.lowerBound(_:)`, `ActiveSet.suggestedWeightKg/Reps/RPE`, `ActiveExercise.targetRPE/formCues/substitution`, `ExerciseDetailSections(muscleGroups:sets:reps:restSeconds:formCues:substitution:)`, `onConfirmAsPlanned`, `EditorSheet.onCommitted` — names identical across T1–T7. `ExerciseLogCard`/`WorkoutLogGridView`/`SetLogGridRow` signatures match their call sites.
