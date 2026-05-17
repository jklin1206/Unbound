# Perceived Load: Incremental Render Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`).

**Goal:** Make Home paint after the essentials (cached program + ranks) instead of after the slowest of ~8 calls, and make the Program screen paint from the local store with no profile fetch on the critical path.

**Architecture:** Pure render-ordering. `UnboundHomeView.load()` → two phases (Phase 1 essentials → `isLoading=false`; Phase 2 concurrent secondary streams into cards). `ProgramOverviewView.task` → local-first paint, profile demoted to background revalidation. No data/feature/schema change.

**Tech Stack:** Swift 5.9, SwiftUI structured concurrency, xcodegen, `xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17'`.

**Spec:** `docs/superpowers/specs/2026-05-17-perceived-load-incremental-render-design.md`

Branch `program-redesign`. Scoped `git add` (NO `git add -A`). Trailer: `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`.

---

### Task IR1: Home two-phase `load()`

**Files:** Modify `UNBOUND/Views/Home/UnboundHomeView.swift` — replace the `@MainActor private func load() async { … }` method only; add one private helper `loadCachedProgram`. Do NOT change `loadProfileAndProgram`, `loadRanks`, `fetchRecentLogsSafe`, `applyRecentLogs`, or any `refresh*`.

- [ ] **Step 1: Replace the entire `load()` method** with:

```swift
    @MainActor
    private func load() async {
        let userId = services.auth.currentUserId ?? "anonymous"
        services.badges.bind(userId: userId)

        // ── Phase 1: essentials → paint ASAP ─────────────────────────────
        // Cached program is an instant local read (no network); ranks are
        // fast; sync reads are free. A placeholder profile guarantees no
        // card renders against nil — the real profile replaces it in Phase 2.
        if let cached = loadCachedProgram(userId) { program = cached }
        profile = UserProfile(
            id: userId, email: nil, displayName: nil,
            createdAt: Date(), onboardingCompleted: true, totalScans: 0,
            currentProgramId: program?.id,
            heightCm: nil, weightKg: nil, age: nil, biologicalSex: nil
        )
        let (r0, t0) = await loadRanks(userId)
        aggregateRank = r0
        aggregateTier = t0
        sessionXP = services.sessionXP.record(userId: userId)
        calibrationSkipRatio = services.calibration.skipRatio(userId: userId)
        attributeProfile = services.attribute.profile(userId: userId)
        trialsState = services.trials.state(userId: userId)

        isLoading = false
        // Kick off ambient loops once content is on screen.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            startAmbientAnimations()
        }

        // ── Phase 2: secondary, concurrent, streams into the cards ────────
        async let skillLoad: Void = SkillProgressService.shared.load(userId: userId)
        async let rankDecay: Void = RankDecayService.shared.evaluateOnForeground(userId: userId)
        async let plateausResult: [PlateauedExercise] = {
            let states = await ProgressionStateStore.shared.fetchAll(userId: userId)
            return await PlateauDetector.shared.detect(userId: userId, states: states)
        }()
        async let profileProgram: (UserProfile?, TrainingProgram?) = loadProfileAndProgram(userId)
        async let recentLogs: [WorkoutLog] = fetchRecentLogsSafe(userId: userId, limit: 40)
        async let travel: TravelOverride? = TravelOverrideStore.shared.activeOverride(for: userId)
        async let coach: CoachNote? = CoachNotesService.shared.todaysNote(userId: userId)

        _ = await skillLoad
        _ = await rankDecay
        plateaus = await plateausResult

        let (fetchedProfile, loadedProgram) = await profileProgram
        if let fetchedProfile {
            profile = fetchedProfile
            if let loadedProgram { program = loadedProgram }
        }

        applyRecentLogs(await recentLogs)
        activeTravelOverride = await travel
        coachNote = await coach

        let history = (try? ScanCheckpointStore.shared.history(userId: userId)) ?? []
        lastScanAt = history.last?.createdAt
        scanCadence = ScanCadenceState.compute(lastScanAt: lastScanAt, now: .now)
    }

    /// Instant local program read (no network) for the Phase-1 paint.
    private func loadCachedProgram(_ userId: String) -> TrainingProgram? {
        ProgramStore.shared.loadLocal(userId: userId)
    }
```

Notes for the implementer: the placeholder `UserProfile(...)` argument list is copied verbatim from the old `load()`'s catch-branch fallback — if `UserProfile`'s initializer differs, match that original fallback exactly (it compiled before). `loadRanks(_:)` already exists and returns `(SubRank, SkillTier)`. Every `@State` the old `load()` set is still set here; only the *phase* differs.

- [ ] **Step 2: Build**

`cd /Users/jlin/Documents/toji/UNBOUND && xcodegen generate >/dev/null && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -8`
Expected: `** BUILD SUCCEEDED **`. Fix real compile errors; SourceKit-only "cannot find" not in xcodebuild output = noise.

- [ ] **Step 3: Commit** (scoped)

```bash
cd /Users/jlin/Documents/toji/UNBOUND
git add UNBOUND/Views/Home/UnboundHomeView.swift
git commit -m "perf(home): two-phase load — essentials paint first, secondary streams in

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task IR2: Program screen — local-first paint, profile off the critical path

**Files:** Modify `UNBOUND/Views/Program/ProgramOverviewView.swift` — replace the `.task { … }` modifier at `:102` only (the closure starting `let vm = ProgramViewModel(services: services)`, ending after the `for goalId in skillProgress.activeGoalIds { Task.detached { … } }` loop). The next modifier `.sheet(isPresented: $showPaywall)` must remain untouched.

- [ ] **Step 1: Replace the entire `.task { … }` closure** with:

```swift
        .task {
            let vm = ProgramViewModel(services: services)
            self.viewModel = vm
            guard let userId = services.auth.currentUserId else { return }

            // History + travel don't depend on the profile — run concurrently.
            async let historyDone: Void = refreshHistory()
            async let travelDone: Void = refreshTravelOverride()

            // Instant: paint today's program from the local store — zero
            // network before the screen appears.
            let store = ProgramStore.shared
            let cached = store.loadLocal(userId: userId)
            if let cached {
                vm.program = cached
                vm.state = .loaded(cached)
                await vm.loadTrackingData()
            }

            // Background: learn the authoritative programId; reconcile only
            // if a new program (rollover) superseded the cache, or load/
            // generate when there was no cache (first run).
            do {
                let profile: UserProfile = try await services.user.fetchProfile(userId: userId)
                if let programId = profile.currentProgramId {
                    if cached == nil {
                        await vm.loadProgram(programId: programId)
                    } else {
                        await store.revalidate(userId: userId, expectedProgramId: programId)
                        if let refreshed = store.program, refreshed.id != cached?.id {
                            vm.program = refreshed
                            vm.state = .loaded(refreshed)
                            await vm.loadTrackingData()
                        }
                    }
                } else if cached == nil {
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
                    store.adopt(generated, userId: userId)
                }
            } catch {}

            _ = await historyDone
            _ = await travelDone

            // Prefetch today's session for every active goal so tapping
            // TRAIN is instant. Each in its own detached task.
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

Implementer: the `generateFromOnboarding` argument list is reproduced from the existing call in this same `.task`; if the real signature differs, copy it verbatim from the code you are replacing and report the difference. `ProgramStore.shared` API in use: `loadLocal(userId:) -> TrainingProgram?`, `revalidate(userId:expectedProgramId:) async`, `adopt(_:userId:)`, `program`. `vm.loadProgram`, `vm.loadTrackingData`, `vm.program`, `vm.state` all already exist.

- [ ] **Step 2: Build**

`cd /Users/jlin/Documents/toji/UNBOUND && xcodegen generate >/dev/null && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -8`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit** (scoped)

```bash
cd /Users/jlin/Documents/toji/UNBOUND
git add UNBOUND/Views/Program/ProgramOverviewView.swift
git commit -m "perf(program): local-first paint; profile demoted to background revalidation

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task IR3: Full suite + install + on-device sign-off

- [ ] **Step 1: Full suite**

`cd /Users/jlin/Documents/toji/UNBOUND && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' test 2>&1 | tail -25`
Expected: all green except the known pre-existing `FriendChallengeServiceTests`/`SquadMissionServiceTests` RLS flap; zero NEW failures. (No new test logic — render ordering only.)

- [ ] **Step 2: Parity review** — confirm every `@State` the old `load()` set is still set with the same value for the same input (`profile`, `program`, `aggregateRank`, `aggregateTier`, `sessionXP`, `calibrationSkipRatio`, `attributeProfile`, `trialsState`, `plateaus`, `weekSessionDays`/`lastLog`/`hasLoggedAnyWorkout` via `applyRecentLogs`, `activeTravelOverride`, `coachNote`, `lastScanAt`, `scanCadence`); only the phase/timing differs. Verify the above-the-fold cards (`topBar`, `homeBriefing`, `trainingConsole`) do not force-unwrap `profile`/`program` (Phase-1 placeholder profile is always non-nil; `program` nil only on cold first run, which already had a no-program state). Program screen renders the same program; rollover still swaps via `revalidate`.

- [ ] **Step 3: Install freshest (by mtime — never alphabetical)**

```bash
cd /Users/jlin/Documents/toji/UNBOUND
APP=$(ls -dt ~/Library/Developer/Xcode/DerivedData/UNBOUND-*/Build/Products/Debug-iphonesimulator/UNBOUND.app 2>/dev/null | head -1)
BID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")
xcrun simctl install booted "$APP" && xcrun simctl launch booted "$BID" && echo "INCREMENTAL-RENDER BUILD INSTALLED ($BID)"
```

- [ ] **Step 4: jlin on-device** — warm cold-open Home: shell + rank + today's training paint near-instantly; coach / plateau / last-session visibly fill in within ~1 s (stream-in, not a 2–3 s blank skeleton). Open Program (warm): today's workout paints with **no spinner**. First-ever run still works (shell → program appears; Program first-run still loads/generates). Rollover/regenerate still swaps the program.

---

## Self-review

**Spec coverage:** Fix A (two-phase, essentials paint, placeholder profile, secondary streams) → IR1; Fix B (Program local-first, profile→background revalidation, first-run fallback) → IR2; parity + no-data-change → IR3 Step 2; on-device perceived-speed proof → IR3 Step 4.

**Placeholder scan:** every code step is full code; no TBD/"similar to".

**Type consistency:** `loadCachedProgram(_:) -> TrainingProgram?` wraps `ProgramStore.shared.loadLocal`; `loadRanks(_:) -> (SubRank, SkillTier)`, `loadProfileAndProgram(_:) -> (UserProfile?, TrainingProgram?)`, `fetchRecentLogsSafe`, `applyRecentLogs` are the existing helpers, signatures unchanged; `UserProfile(...)` placeholder copied verbatim from the prior `load()` fallback; `ProgramStore`/`vm` APIs (`loadLocal`,`revalidate`,`adopt`,`program`,`loadProgram`,`loadTrackingData`,`state`) match prior tasks. `.sheet(isPresented: $showPaywall)` after the `.task` is explicitly preserved.
