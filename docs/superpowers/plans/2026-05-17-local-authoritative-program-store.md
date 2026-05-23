# Local-Authoritative Program Store Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Make the `TrainingProgram` a durable on-device document — instant local reads, write-through edits that survive offline/app-kill, replaced only on a new `programId`.

**Architecture:** New `ProgramStore` (`@MainActor`, mirrors `WorkoutDraftStore`'s file-persistence) owns the active program. It reads/writes a Codable cache file and delegates the network to a `ProgramRemote` seam over `SupabaseProgramService` (reused). `ProgramViewModel` + Home's `loadProfileAndProgram` route through it.

**Tech Stack:** Swift 5.9, SwiftUI, XCTest, xcodegen, `xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17'`.

**Spec:** `docs/superpowers/specs/2026-05-17-local-authoritative-program-store-design.md`

Branch `program-redesign`. Scoped `git add` (NO `git add -A`). Trailer: `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`.

---

### Task PS1: `ProgramRemote` seam + `ProgramStore` (TDD)

**Files:**
- Modify: `UNBOUND/Services/ProgramGeneration/SupabaseProgramService.swift` (add `ProgramRemote` conformance + `persist`)
- Create: `UNBOUND/Services/Program/ProgramStore.swift`
- Create: `UNBOUNDTests/Services/ProgramStoreTests.swift`

- [ ] **Step 1: Write the failing tests** — `UNBOUNDTests/Services/ProgramStoreTests.swift`:

```swift
import XCTest
@testable import UNBOUND

@MainActor
final class ProgramStoreTests: XCTestCase {

    // Reuses the verified fixture shape from BlockRolloverSchedulerTests.
    private func makeProgram(id: String = "p-1", userId: String = "u-1") -> TrainingProgram {
        TrainingProgram(
            id: id, scanId: "s-1", analysisId: "a-1", userId: userId,
            createdAt: Date(), name: "Test", description: "Test program",
            durationDays: 14, days: [],
            nutritionPlan: NutritionPlan(
                dailyCalories: 2000, proteinGrams: 150, carbsGrams: 200, fatGrams: 60,
                mealCount: 4, meals: [], hydrationLiters: 3, supplements: [], notes: "",
                restDayCalories: 1800, restDayProteinGrams: 150,
                restDayCarbsGrams: 150, restDayFatGrams: 60),
            recoveryPlan: RecoveryPlan(sleepHoursTarget: 8, restDaysPerWeek: 3,
                                       activities: [], notes: ""),
            difficultyLevel: .intermediate, requiredEquipment: [],
            estimatedDailyMinutes: 45, rationale: nil)
    }

    private final class MockProgramRemote: ProgramRemote, @unchecked Sendable {
        var programsById: [String: TrainingProgram] = [:]
        var persistSucceeds = true
        private(set) var persistCalls = 0
        private(set) var fetchCalls = 0
        func persist(_ program: TrainingProgram, userId: String) async -> Bool {
            persistCalls += 1
            if persistSucceeds { programsById[program.id] = program }
            return persistSucceeds
        }
        func fetchProgram(id: String) async throws -> TrainingProgram {
            fetchCalls += 1
            guard let p = programsById[id] else { throw NSError(domain: "mock", code: 404) }
            return p
        }
    }

    private func tempDir() -> URL {
        let u = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    func test_save_thenLoadLocal_survivesNewInstance() async {
        let dir = tempDir(); let remote = MockProgramRemote()
        let s1 = ProgramStore(directory: dir, remote: remote)
        await s1.save(makeProgram(), userId: "u-1")
        let s2 = ProgramStore(directory: dir, remote: remote)
        XCTAssertEqual(s2.loadLocal(userId: "u-1")?.id, "p-1")
    }

    func test_save_remoteFailure_keepsDirty_butLocalStillReads() async {
        let dir = tempDir(); let remote = MockProgramRemote()
        remote.persistSucceeds = false
        let s = ProgramStore(directory: dir, remote: remote)
        await s.save(makeProgram(), userId: "u-1")
        // The data-loss-bug regression: edit survives despite remote failure.
        XCTAssertEqual(ProgramStore(directory: dir, remote: remote)
            .loadLocal(userId: "u-1")?.id, "p-1")
        // Recover + flush clears dirty (1 persist on save + 1 on flush).
        remote.persistSucceeds = true
        await s.flushIfDirty(userId: "u-1")
        XCTAssertEqual(remote.persistCalls, 2)
        await s.flushIfDirty(userId: "u-1")          // now clean → no-op
        XCTAssertEqual(remote.persistCalls, 2)
    }

    func test_revalidate_sameId_isNoOp_localWins() async {
        let dir = tempDir(); let remote = MockProgramRemote()
        let s = ProgramStore(directory: dir, remote: remote)
        await s.save(makeProgram(), userId: "u-1")
        await s.revalidate(userId: "u-1", expectedProgramId: "p-1")
        XCTAssertEqual(remote.fetchCalls, 0)          // never refetched
        XCTAssertEqual(s.program?.id, "p-1")
    }

    func test_revalidate_newId_fetchesAndReplaces() async {
        let dir = tempDir(); let remote = MockProgramRemote()
        remote.programsById["p-2"] = makeProgram(id: "p-2")
        let s = ProgramStore(directory: dir, remote: remote)
        await s.save(makeProgram(id: "p-1"), userId: "u-1")
        await s.revalidate(userId: "u-1", expectedProgramId: "p-2")
        XCTAssertEqual(remote.fetchCalls, 1)
        XCTAssertEqual(s.program?.id, "p-2")
        XCTAssertEqual(ProgramStore(directory: dir, remote: remote)
            .loadLocal(userId: "u-1")?.id, "p-2")     // replacement persisted
    }

    func test_loadLocal_wrongUser_nil_andClearWipes() async {
        let dir = tempDir(); let remote = MockProgramRemote()
        let s = ProgramStore(directory: dir, remote: remote)
        await s.save(makeProgram(userId: "u-1"), userId: "u-1")
        XCTAssertNil(s.loadLocal(userId: "u-2"))
        s.clear()
        XCTAssertNil(ProgramStore(directory: dir, remote: remote).loadLocal(userId: "u-1"))
    }

    func test_adopt_isClean_noRemoteWrite() async {
        let dir = tempDir(); let remote = MockProgramRemote()
        let s = ProgramStore(directory: dir, remote: remote)
        s.adopt(makeProgram(), userId: "u-1")
        XCTAssertEqual(remote.persistCalls, 0)
        await s.flushIfDirty(userId: "u-1")           // clean → no-op
        XCTAssertEqual(remote.persistCalls, 0)
        XCTAssertEqual(s.program?.id, "p-1")
    }
}
```

- [ ] **Step 2: Run — must FAIL** (`ProgramRemote`/`ProgramStore` undefined)

`cd /Users/jlin/Documents/toji/UNBOUND && xcodegen generate >/dev/null && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:UNBOUNDTests/ProgramStoreTests 2>&1 | tail -15`

- [ ] **Step 3: Create `UNBOUND/Services/Program/ProgramStore.swift`**

```swift
import Foundation

/// Network seam for the program store. `SupabaseProgramService` conforms.
protocol ProgramRemote: Sendable {
    /// Upsert the program + patch `current_program_id`. True iff it reached
    /// the server (a local-dev/unauth fallback also counts as persisted).
    func persist(_ program: TrainingProgram, userId: String) async -> Bool
    func fetchProgram(id: String) async throws -> TrainingProgram
}

/// The single on-device owner of the active TrainingProgram. Local-first:
/// the cache file is the fast-read source AND the edit surface; remote is
/// sync/backup + the monthly-replacement source. Mirrors WorkoutDraftStore.
@MainActor
final class ProgramStore {
    static let shared = ProgramStore()

    private let fileURL: URL
    private let remote: ProgramRemote
    private(set) var program: TrainingProgram?

    private struct Cached: Codable {
        var program: TrainingProgram
        var userId: String
        var dirty: Bool
        var syncedAt: Date?
    }

    init(directory: URL? = nil, remote: ProgramRemote = SupabaseProgramService.shared) {
        let base = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("UNBOUND", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        self.fileURL = base.appendingPathComponent("program-store.json")
        self.remote = remote
    }

    private func readCache() -> Cached? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(Cached.self, from: data)
    }

    private func writeCache(_ c: Cached) {
        if let data = try? JSONEncoder().encode(c) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    /// Instant synchronous read. Returns the cached program iff it belongs
    /// to `userId` (no cross-account leak). Also publishes it in-memory.
    @discardableResult
    func loadLocal(userId: String) -> TrainingProgram? {
        guard let c = readCache(), c.userId == userId else { return nil }
        program = c.program
        return c.program
    }

    /// Adopt a program obtained from the network/generation as the clean
    /// local authority. No remote write — it is already remote.
    func adopt(_ program: TrainingProgram, userId: String) {
        self.program = program
        writeCache(Cached(program: program, userId: userId, dirty: false, syncedAt: Date()))
    }

    /// Write-through user/coach edit: durable local first (dirty), then
    /// best-effort remote; clears dirty on remote success. The edit is never
    /// lost even if the network write fails.
    func save(_ program: TrainingProgram, userId: String) async {
        self.program = program
        writeCache(Cached(program: program, userId: userId, dirty: true, syncedAt: nil))
        if await remote.persist(program, userId: userId) {
            writeCache(Cached(program: program, userId: userId, dirty: false, syncedAt: Date()))
        }
    }

    /// Replace-on-new-`programId`. Same id → no-op (local wins, even if
    /// dirty). Different id (rollover/regenerate) → push any unsynced edits
    /// to the OLD program first, then fetch + adopt the new one.
    func revalidate(userId: String, expectedProgramId: String) async {
        if program == nil { _ = loadLocal(userId: userId) }
        if let p = program, p.id == expectedProgramId { return }
        await flushIfDirty(userId: userId)
        if let fresh = try? await remote.fetchProgram(id: expectedProgramId) {
            adopt(fresh, userId: userId)
        }
        // fetch failed → keep what we have; a later load retries.
    }

    /// Retry an unsynced local edit (call on foreground / next load).
    func flushIfDirty(userId: String) async {
        guard let c = readCache(), c.userId == userId, c.dirty else { return }
        if await remote.persist(c.program, userId: userId) {
            writeCache(Cached(program: c.program, userId: userId,
                              dirty: false, syncedAt: Date()))
        }
    }

    func clear() {
        program = nil
        try? FileManager.default.removeItem(at: fileURL)
    }
}
```

- [ ] **Step 4: Add `ProgramRemote` conformance + `persist` to `SupabaseProgramService`**

In `UNBOUND/Services/ProgramGeneration/SupabaseProgramService.swift`, change the type declaration line `final class SupabaseProgramService: @unchecked Sendable {` to:

```swift
final class SupabaseProgramService: ProgramRemote, @unchecked Sendable {
```

(`fetchProgram(id:) async throws -> TrainingProgram` already satisfies the protocol.) Then add this method inside the class, immediately after `saveProgram(_:userId:)` (do NOT modify `saveProgram` or `fetchProgram`):

```swift
    /// Like `saveProgram` but reports whether the write reached the server,
    /// so `ProgramStore` knows when to clear its dirty flag. A local-dev /
    /// unauthenticated fallback counts as persisted (matches `saveProgram`).
    func persist(_ program: TrainingProgram, userId: String) async -> Bool {
        do {
            _ = try await supabase.upsert(program, into: "programs")
            try await supabase.patch(
                ["current_program_id": AnyJSON.string(program.id)],
                in: "users", keyedBy: "id", equals: userId)
            return true
        } catch SupabaseDatabaseError.notAuthenticated {
            try? await local.create(program, collection: "programs", documentId: program.id)
            try? await local.update(["currentProgramId": program.id],
                                    collection: "users", documentId: userId)
            return true
        } catch {
            logger.log("SupabaseProgramService.persist failed: \(error)",
                       level: .error, context: ["programId": program.id])
            try? await local.create(program, collection: "programs", documentId: program.id)
            try? await local.update(["currentProgramId": program.id],
                                    collection: "users", documentId: userId)
            return false
        }
    }
```

- [ ] **Step 5: Run — must PASS (6 tests)**

`cd /Users/jlin/Documents/toji/UNBOUND && xcodegen generate >/dev/null && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:UNBOUNDTests/ProgramStoreTests 2>&1 | tail -15`
If `NutritionPlan`/`RecoveryPlan` initializer args mismatch, the fixture is copied verbatim from `UNBOUNDTests/Services/ProgramGeneration/BlockRolloverSchedulerTests.swift:50-72` — diff against that file and match it exactly; do not change production code for a test-fixture mismatch.

- [ ] **Step 6: Commit** (scoped)

```bash
cd /Users/jlin/Documents/toji/UNBOUND
git add UNBOUND/Services/Program/ProgramStore.swift UNBOUND/Services/ProgramGeneration/SupabaseProgramService.swift UNBOUNDTests/Services/ProgramStoreTests.swift project.pbxproj
git commit -m "feat(program): ProgramStore — local-authoritative, write-through, replace-on-new-id (TDD)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task PS2: Route `ProgramViewModel` through the store

**Files:**
- Modify: `UNBOUND/ViewModels/ProgramViewModel.swift` — replace `loadProgram(programId:)` (`:19-30`) and `saveProgram()` (`:113-128`). Do NOT touch other methods.

- [ ] **Step 1: Replace `func loadProgram(programId:) async`** with:

```swift
    func loadProgram(programId: String) async {
        let store = ProgramStore.shared
        let userId = services.auth.currentUserId

        // Local-first: paint instantly from the durable copy, then revalidate
        // (cheap id-compare; only a new programId triggers a network fetch).
        if let userId, let cached = store.loadLocal(userId: userId), cached.id == programId {
            self.program = cached
            state = .loaded(cached)
            services.analytics.track(.programViewed(programId: programId))
            await loadTrackingData()
            await store.revalidate(userId: userId, expectedProgramId: programId)
            if let refreshed = store.program, refreshed.id != cached.id {
                self.program = refreshed
                state = .loaded(refreshed)
                await loadTrackingData()
            }
            return
        }

        // No usable local copy (first run / different id) → network, then
        // adopt as the clean local authority.
        state = .loading
        do {
            let fetched: TrainingProgram = try await services.database.read(
                collection: "programs", documentId: programId)
            self.program = fetched
            state = .loaded(fetched)
            if let userId { store.adopt(fetched, userId: userId) }
            services.analytics.track(.programViewed(programId: programId))
            await loadTrackingData()
        } catch {
            state = .error(.databaseReadFailed(underlying: error))
        }
    }
```

- [ ] **Step 2: Replace `func saveProgram() async`** with:

```swift
    /// Persist the full program. Durable-local-first via ProgramStore (the
    /// edit survives offline / app-kill), then best-effort remote sync.
    func saveProgram() async {
        guard let program else { return }
        guard let userId = services.auth.currentUserId else {
            services.logging.log("saveProgram: no user id", level: .warning,
                                  context: ["programId": program.id])
            return
        }
        await ProgramStore.shared.save(program, userId: userId)
    }
```

- [ ] **Step 3: Build**

`cd /Users/jlin/Documents/toji/UNBOUND && xcodegen generate >/dev/null && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -6`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit** (scoped)

```bash
cd /Users/jlin/Documents/toji/UNBOUND
git add UNBOUND/ViewModels/ProgramViewModel.swift
git commit -m "feat(program): ProgramViewModel local-first load + write-through save via ProgramStore

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task PS3: Home path + sign-out clear

**Files:**
- Modify: `UNBOUND/Views/Home/UnboundHomeView.swift` — `loadProfileAndProgram(_:)` (added in the load-perf work).
- Modify: the sign-out path (located in Step 2).

- [ ] **Step 1: Replace `private func loadProfileAndProgram(_ userId: String) async -> (UserProfile?, TrainingProgram?)`** with:

```swift
    private func loadProfileAndProgram(_ userId: String) async -> (UserProfile?, TrainingProgram?) {
        do {
            let fetched: UserProfile = try await services.user.fetchProfile(userId: userId)
            let store = ProgramStore.shared
            if let programId = fetched.currentProgramId {
                // Instant local paint; revalidate is a no-op unless a new
                // programId (rollover) superseded it.
                if store.loadLocal(userId: userId)?.id == programId {
                    await store.revalidate(userId: userId, expectedProgramId: programId)
                    return (fetched, store.program)
                }
                if let existing: TrainingProgram = try? await services.database.read(
                    collection: "programs", documentId: programId) {
                    store.adopt(existing, userId: userId)
                    return (fetched, existing)
                }
                // programId present but read failed — do NOT generate on a
                // transient blip; surface no program, next load retries.
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
            store.adopt(generated, userId: userId)
            return (fetched, generated)
        } catch {
            return (nil, nil)
        }
    }
```

- [ ] **Step 2: Wire sign-out clear.** Find where the in-progress workout draft is cleared on sign-out (the established pattern):

Run: `cd /Users/jlin/Documents/toji/UNBOUND && grep -rn "WorkoutDraftStore().clear()\|\.clear()\|func signOut\|func logout\|signOut(" UNBOUND/Services/Auth UNBOUND --include="*.swift" 2>/dev/null | grep -i "signout\|logout\|draftstore" | head`

In the same function that performs sign-out (e.g. `AuthService.signOut()` or wherever the session is torn down / `WorkoutDraftStore` is cleared), add — adjacent to the existing clears, inside a `Task { @MainActor in … }` if the context is non-isolated since `ProgramStore` is `@MainActor`:

```swift
            await MainActor.run { ProgramStore.shared.clear() }
```

If sign-out is already `@MainActor`, use `ProgramStore.shared.clear()` directly. If no existing clear-on-signout exists, add the call at the start of the sign-out function. Report exactly where it was placed.

- [ ] **Step 3: Build**

`cd /Users/jlin/Documents/toji/UNBOUND && xcodegen generate >/dev/null && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -6`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit** (scoped — only the two modified files)

```bash
cd /Users/jlin/Documents/toji/UNBOUND
git add UNBOUND/Views/Home/UnboundHomeView.swift <the sign-out file>
git commit -m "feat(program): Home local-first program + ProgramStore.clear() on sign-out

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task PS4: Full suite + install + on-device sign-off

- [ ] **Step 1: Full suite**

`cd /Users/jlin/Documents/toji/UNBOUND && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' test 2>&1 | tail -25`
Expected: all green except the known pre-existing `FriendChallengeServiceTests`/`SquadMissionServiceTests` RLS flap; zero NEW failures. `ProgramStoreTests` (6) + `BlockRolloverSchedulerTests` + `HomeLoadDerivationsTests` + `ProgramAwareLoggingTests` + `ActiveWorkoutSession*` all pass.

- [ ] **Step 2: Spec-compliance + parity review** — local-first read; write-through durable-first; replace-on-new-id (same id never clobbers, even dirty); coach edits flow through `saveProgram`→`store.save` unchanged; `SupabaseProgramService.saveProgram`/`fetchProgram` untouched (only additive `persist` + conformance); no `TrainingProgram` schema change; sign-out clears the store.

- [ ] **Step 3: Install freshest (by mtime — never alphabetical)**

```bash
cd /Users/jlin/Documents/toji/UNBOUND
APP=$(ls -dt ~/Library/Developer/Xcode/DerivedData/UNBOUND-*/Build/Products/Debug-iphonesimulator/UNBOUND.app 2>/dev/null | head -1)
BID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")
xcrun simctl install booted "$APP" && xcrun simctl launch booted "$BID" && echo "PROGRAM-STORE BUILD INSTALLED ($BID)"
```

- [ ] **Step 4: jlin on-device** — cold-open Program: today's workout paints instantly from local (no spinner). **Offline-edit-survives test:** edit an exercise (swap or sets/reps) → kill the app → reopen → the edit is still there (this was the data-loss bug). Force a rollover/regenerate → the new program replaces local.

---

## Self-review

**Spec coverage:** decision 1 (local-authoritative) → PS1 `ProgramStore`+PS2/PS3 wiring; 2 (write-through durable-first) → PS1 `save`; 3 (replace-on-new-id) → PS1 `revalidate`+tests; 4 (coach on-device, no special-case) → coach uses `ProgramViewModel.swapExercise`/`saveProgram`→`store.save`, unchanged; 5 (cross-device deferred) → not implemented, store shape leaves a `syncedAt` for a future version token. Reuse → `SupabaseProgramService` via `ProgramRemote`; `WorkoutDraftStore` pattern. Data-loss bug → PS1 `test_save_remoteFailure_keepsDirty_butLocalStillReads` + PS4 on-device.

**Placeholder scan:** every code step is complete; the only located-at-runtime item (the sign-out file) has an explicit grep + placement rule in PS3 Step 2, not a vague TODO.

**Type consistency:** `ProgramRemote.persist(_:userId:)->Bool`/`fetchProgram(id:)->TrainingProgram`; `ProgramStore.{loadLocal,adopt,save,revalidate,flushIfDirty,clear,program}`; `Cached{program,userId,dirty,syncedAt}`; fixture matches `BlockRolloverSchedulerTests` verbatim; `services.database.read`/`services.auth.currentUserId`/`services.logging.log` signatures match `ProgramViewModel`'s existing usage; `SupabaseProgramService` keeps `supabase`/`local`/`logger` it already has.
