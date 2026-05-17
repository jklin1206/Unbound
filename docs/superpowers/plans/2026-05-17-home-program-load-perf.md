# Home / Program Load Performance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Collapse the serial ~15-call Home load and ~4-call Program load into concurrent loads with a single deduped `workout_logs` fetch, so the screen appears in well under 1 s.

**Architecture:** Extract the only non-trivial log-derived logic into a pure, unit-tested `HomeLoadDerivations`; restructure `UnboundHomeView.load()` and `ProgramOverviewView.task` to fire independent loads via `async let` and await them together; one `fetchRecentLogs(limit:40)` feeds last-log/has-logged/week-rhythm; Claude generation only when `currentProgramId == nil` (never on a transient read failure). No UI/render-gating change.

**Tech Stack:** Swift 5.9, SwiftUI structured concurrency (`async let`), XCTest, xcodegen, `xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17'`.

**Spec:** `docs/superpowers/specs/2026-05-17-home-program-load-perf-design.md`

Branch `program-redesign`. Commit trailer: `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`. Scope `git add` to the named files only (no `git add -A`).

---

### Task LP1: `HomeLoadDerivations` (pure, TDD)

**Files:**
- Create: `UNBOUND/Views/Home/HomeLoadDerivations.swift`
- Create: `UNBOUNDTests/Views/HomeLoadDerivationsTests.swift`

- [ ] **Step 1: Write the failing test**

`UNBOUNDTests/Views/HomeLoadDerivationsTests.swift`:

```swift
import XCTest
@testable import UNBOUND

final class HomeLoadDerivationsTests: XCTestCase {

    private func cal() -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    // Wed 2026-05-13 12:00 UTC — ISO week Mon 2026-05-11 .. Sun 2026-05-17
    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        var c = cal()
        return c.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    func test_weekSessionDays_mapsCurrentWeekToMondayIndex() {
        let now = date(2026, 5, 13)            // Wednesday
        let starts = [
            date(2026, 5, 11),                 // Mon  -> 1
            date(2026, 5, 13),                 // Wed  -> 3
            date(2026, 5, 17),                 // Sun  -> 7
            date(2026, 5, 8)                   // prev week -> excluded
        ]
        let days = HomeLoadDerivations.weekSessionDays(starts, now: now, calendar: cal())
        XCTAssertEqual(days, [1, 3, 7])
    }

    func test_weekSessionDays_empty() {
        XCTAssertEqual(
            HomeLoadDerivations.weekSessionDays([], now: date(2026, 5, 13), calendar: cal()),
            [])
    }

    func test_lastLog_and_hasLogged() {
        let logs: [WorkoutLog] = []
        XCTAssertNil(HomeLoadDerivations.lastLog(logs))
        XCTAssertFalse(HomeLoadDerivations.hasLogged(logs))
    }
}
```

- [ ] **Step 2: Run — must FAIL** (symbol missing)

`cd /Users/jlin/Documents/toji/UNBOUND && xcodegen generate >/dev/null && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:UNBOUNDTests/HomeLoadDerivationsTests 2>&1 | tail -15`

- [ ] **Step 3: Create `UNBOUND/Views/Home/HomeLoadDerivations.swift`**

```swift
import Foundation

/// Pure, dependency-free derivations from a single recent-logs fetch.
/// Exists so the Home load can dedupe three `workout_logs` fetches into one
/// and still be unit-tested. The week logic is lifted verbatim from the
/// original `refreshWeeklyRhythm`.
enum HomeLoadDerivations {

    static func lastLog(_ logs: [WorkoutLog]) -> WorkoutLog? { logs.first }

    static func hasLogged(_ logs: [WorkoutLog]) -> Bool { !logs.isEmpty }

    /// Monday-indexed (Mon=1 … Sun=7) set of weekdays with a session this
    /// calendar week. `startedAts` are each log's `startedAt`.
    static func weekSessionDays(_ startedAts: [Date],
                                now: Date = .now,
                                calendar baseCal: Calendar = .current) -> Set<Int> {
        var cal = baseCal
        cal.firstWeekday = 2 // Monday
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        guard let weekStart = cal.date(from: components) else { return [] }
        var days: Set<Int> = []
        for started in startedAts where started >= weekStart {
            let weekday = cal.component(.weekday, from: started)
            let monIndex = ((weekday + 5) % 7) + 1
            days.insert(monIndex)
        }
        return days
    }
}
```

- [ ] **Step 4: Run — must PASS**

`cd /Users/jlin/Documents/toji/UNBOUND && xcodegen generate >/dev/null && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:UNBOUNDTests/HomeLoadDerivationsTests 2>&1 | tail -15`
Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/jlin/Documents/toji/UNBOUND
git add UNBOUND/Views/Home/HomeLoadDerivations.swift UNBOUNDTests/Views/HomeLoadDerivationsTests.swift project.pbxproj
git commit -m "feat(perf): HomeLoadDerivations — pure log derivations (TDD)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task LP2: Parallelize `UnboundHomeView.load()` + dedupe

**Files:**
- Modify: `UNBOUND/Views/Home/UnboundHomeView.swift` — replace `func load()` (currently `:1825-1890`), add 4 private helpers, rewrite `refreshWeeklyRhythm` (`:1911-1929`).

- [ ] **Step 1: Replace the entire `private func load() async { … }` body** (the `@MainActor private func load() async` method) with:

```swift
    @MainActor
    private func load() async {
        let userId = services.auth.currentUserId ?? "anonymous"
        services.badges.bind(userId: userId)

        async let skillLoad: Void = SkillProgressService.shared.load(userId: userId)
        async let rankDecay: Void = RankDecayService.shared.evaluateOnForeground(userId: userId)
        async let plateausResult: [PlateauedExercise] = {
            let states = await ProgressionStateStore.shared.fetchAll(userId: userId)
            return await PlateauDetector.shared.detect(userId: userId, states: states)
        }()
        async let profileProgram: (UserProfile?, TrainingProgram?) = loadProfileAndProgram(userId)
        async let recentLogs: [WorkoutLog] = fetchRecentLogsSafe(userId: userId, limit: 40)
        async let ranks: (SubRank, SkillTier) = loadRanks(userId)
        async let travel: TravelOverride? = TravelOverrideStore.shared.activeOverride(for: userId)
        async let coach: CoachNote? = CoachNotesService.shared.todaysNote(userId: userId)

        _ = await skillLoad
        _ = await rankDecay
        plateaus = await plateausResult

        let (fetchedProfile, loadedProgram) = await profileProgram
        if let fetchedProfile {
            profile = fetchedProfile
            program = loadedProgram
        } else {
            profile = UserProfile(
                id: userId, email: nil, displayName: nil,
                createdAt: Date(), onboardingCompleted: true, totalScans: 0,
                currentProgramId: nil,
                heightCm: nil, weightKg: nil, age: nil, biologicalSex: nil
            )
        }

        applyRecentLogs(await recentLogs)

        let (r, t) = await ranks
        aggregateRank = r
        aggregateTier = t
        activeTravelOverride = await travel
        coachNote = await coach

        // Cheap synchronous reads — keep last, same values as before.
        sessionXP = services.sessionXP.record(userId: userId)
        calibrationSkipRatio = services.calibration.skipRatio(userId: userId)
        attributeProfile = services.attribute.profile(userId: userId)

        let history = (try? ScanCheckpointStore.shared.history(userId: userId)) ?? []
        lastScanAt = history.last?.createdAt
        scanCadence = ScanCadenceState.compute(lastScanAt: lastScanAt, now: .now)

        trialsState = services.trials.state(userId: userId)

        isLoading = false
        // Kick off ambient loops once the content is actually on screen —
        // .onAppear fires while still in the loading state, so the
        // animation bindings never connect to rendered views.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            startAmbientAnimations()
        }
    }

    private func loadProfileAndProgram(_ userId: String) async -> (UserProfile?, TrainingProgram?) {
        do {
            let fetched: UserProfile = try await services.user.fetchProfile(userId: userId)
            if let programId = fetched.currentProgramId {
                if let existing: TrainingProgram = try? await services.database.read(
                    collection: "programs", documentId: programId) {
                    return (fetched, existing)
                }
                // programId present but read failed — do NOT kick a multi-second
                // Claude generate on a transient blip (that was the old stuck
                // regenerate loop). Surface no program; next load retries.
                return (fetched, nil)
            }
            // Genuine first run: no program id yet.
            let generated = await ProgramGenerationService.shared.generateFromOnboarding(
                userId: userId,
                targetFrequency: fetched.targetFrequency,
                equipment: Set(fetched.equipment ?? []),
                experience: fetched.experience,
                sessionLength: fetched.sessionLength,
                exerciseStyles: [],
                targetAreas: Set(fetched.targetAreas ?? [])
            )
            return (fetched, generated)
        } catch {
            return (nil, nil)
        }
    }

    private func loadRanks(_ userId: String) async -> (SubRank, SkillTier) {
        async let r = services.rank.aggregateRank(userId: userId)
        async let t = services.rank.aggregateTier(userId: userId)
        return (await r, await t)
    }

    private func fetchRecentLogsSafe(userId: String, limit: Int) async -> [WorkoutLog] {
        (try? await services.workoutLog.fetchRecentLogs(userId: userId, limit: limit)) ?? []
    }

    @MainActor
    private func applyRecentLogs(_ logs: [WorkoutLog]) {
        lastLog = HomeLoadDerivations.lastLog(logs)
        hasLoggedAnyWorkout = HomeLoadDerivations.hasLogged(logs)
        weekSessionDays = HomeLoadDerivations.weekSessionDays(logs.map(\.startedAt))
    }
```

- [ ] **Step 2: Rewrite `refreshWeeklyRhythm` to share the derivation** (DRY — same behavior, used by `onSessionComplete`/foreground refresh). Replace the existing `@MainActor private func refreshWeeklyRhythm() async { … }` with:

```swift
    @MainActor
    private func refreshWeeklyRhythm() async {
        let userId = services.auth.currentUserId ?? "anonymous"
        let logs = (try? await services.workoutLog.fetchRecentLogs(userId: userId, limit: 14)) ?? []
        weekSessionDays = HomeLoadDerivations.weekSessionDays(logs.map(\.startedAt))
    }
```

Do NOT change `refreshLastLog`, `refreshCalibrationState`, `refreshSessionXP`, `refreshRanksAndStats`, `refreshTravelOverride`, `refreshCoachNote`, or `onSessionComplete` — they remain for the foreground/session-complete refresh paths.

- [ ] **Step 3: Build**

`cd /Users/jlin/Documents/toji/UNBOUND && xcodegen generate >/dev/null && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -8`
Expected: `** BUILD SUCCEEDED **`. If `loadRanks` errors on `services.rank.aggregateRank/aggregateTier` return types, match the types the old `refreshRanksAndStats` assigned (`aggregateRank: SubRank`, `aggregateTier: SkillTier`); adjust the tuple annotation only, report the deviation.

- [ ] **Step 4: Commit**

```bash
cd /Users/jlin/Documents/toji/UNBOUND
git add UNBOUND/Views/Home/UnboundHomeView.swift
git commit -m "perf(home): parallelize load() via async let; one deduped recent-logs fetch

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task LP3: Parallelize `ProgramOverviewView.task`

**Files:**
- Modify: `UNBOUND/Views/Program/ProgramOverviewView.swift` — the `.task { … }` at `:102-142`.

- [ ] **Step 1: Replace the entire `.task { … }` modifier closure body** (lines beginning `let vm = ProgramViewModel(services: services)` through the `for goalId in skillProgress.activeGoalIds { … }` loop) with:

```swift
        .task {
            let vm = ProgramViewModel(services: services)
            self.viewModel = vm
            guard let userId = services.auth.currentUserId else { return }

            // History + travel don't depend on the profile — run them
            // concurrently with the profile→program chain instead of after it.
            async let historyDone: Void = refreshHistory()
            async let travelDone: Void = refreshTravelOverride()

            do {
                let profile: UserProfile = try await services.user.fetchProfile(userId: userId)
                if let programId = profile.currentProgramId {
                    await vm.loadProgram(programId: programId)
                } else {
                    // Onboarding done but currentProgramId not saved yet.
                    vm.state = .loading
                    let generated = await ProgramGenerationService.shared.generateFromOnboarding(
                        userId: userId,
                        targetFrequency: profile.targetFrequency,
                        equipment: Set(profile.equipment ?? []),
                        experience: profile.experience,
                        sessionLength: profile.sessionLength,
                        exerciseStyles: [],
                        targetAreas: Set(profile.targetAreas ?? [])
                    )
                    vm.program = generated
                    vm.state = .loaded(generated)
                }
            } catch {}

            _ = await historyDone
            _ = await travelDone

            // Prefetch today's session for every active goal so tapping
            // TRAIN is instant. Each in its own detached task; failures fall
            // back gracefully when the session view actually opens.
            for goalId in skillProgress.activeGoalIds {
                Task.detached { @MainActor in
                    await RPESessionService.shared.prefetch(
                        skillId: goalId,
                        userId: userId
                    )
                }
            }
        }
```

(Program's branch already only generates when `currentProgramId == nil` and catches a thrown `fetchProfile`; `loadProgram` handles a failed read internally — no guard change needed here, only the concurrency.)

- [ ] **Step 2: Build**

`cd /Users/jlin/Documents/toji/UNBOUND && xcodegen generate >/dev/null && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -6`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd /Users/jlin/Documents/toji/UNBOUND
git add UNBOUND/Views/Program/ProgramOverviewView.swift
git commit -m "perf(program): parallelize task — history/travel concurrent with profile→program

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task LP4: Full suite + install + on-device sign-off

- [ ] **Step 1: Full test suite**

`cd /Users/jlin/Documents/toji/UNBOUND && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' test 2>&1 | tail -25`
Expected: all green except the known pre-existing `FriendChallengeServiceTests`/`SquadMissionServiceTests` RLS flap. Zero NEW failures. `HomeLoadDerivationsTests` + `ProgramAwareLoggingTests` + `ActiveWorkoutSession*` pass.

- [ ] **Step 2: Parity review** — confirm every `@State` the old `load()` set is still set with the same value for the same input (`profile`, `program`, `plateaus`, `lastLog`, `hasLoggedAnyWorkout`, `weekSessionDays`, `aggregateRank`, `aggregateTier`, `activeTravelOverride`, `coachNote`, `sessionXP`, `calibrationSkipRatio`, `attributeProfile`, `lastScanAt`, `scanCadence`, `trialsState`, `isLoading`). The only intentional behavior change: a program-read failure with a present `currentProgramId` no longer triggers a Claude generate (returns no program; next load retries) — flag to jlin.

- [ ] **Step 3: Install freshest binary (by mtime — never alphabetical)**

```bash
cd /Users/jlin/Documents/toji/UNBOUND
APP=$(ls -dt ~/Library/Developer/Xcode/DerivedData/UNBOUND-*/Build/Products/Debug-iphonesimulator/UNBOUND.app 2>/dev/null | head -1)
BID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")
xcrun simctl install booted "$APP" && xcrun simctl launch booted "$BID" && echo "LOAD-PERF BUILD INSTALLED ($BID)"
```

- [ ] **Step 4: jlin on-device** — cold-open Home and Program: appears in well under 1 s (was 2–5 s); every card populates correctly; log a workout then return → Home still refreshes (onSessionComplete intact).

---

## Self-review

**Spec coverage:** decision 1 (parallelize) → LP2/LP3 `async let`; 2 (one logs fetch) → LP2 `fetchRecentLogsSafe`+`applyRecentLogs`+`HomeLoadDerivations`; 3 (rank ∥ tier) → LP2 `loadRanks`; 4 (Claude only when programId nil) → LP2 `loadProfileAndProgram` guard; 5 (helpers intact) → LP2 leaves incremental helpers, only `refreshWeeklyRhythm` shares the now-DRY derivation. Tests → LP1.

**Placeholder scan:** none — every code step is complete.

**Type consistency:** `HomeLoadDerivations.{lastLog,hasLogged,weekSessionDays}`, helper returns `(UserProfile?, TrainingProgram?)`, `(SubRank, SkillTier)`, `[PlateauedExercise]`, `[WorkoutLog]`, `TravelOverride?`, `CoachNote?` — match the verified `@State` types and service signatures.
