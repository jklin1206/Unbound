import Combine
import Foundation

// MARK: - HomeViewModel
//
// Owns the Home screen's data state: profile + program, ranks/XP, recent
// training signals, bodyweight logs, travel override, scan cadence, and
// weekly vows. Loading/refresh/save logic moved verbatim from
// `UnboundHomeView+Loading.swift` — presentation state (sheets, animations,
// cosmetics) stays on the view.

@MainActor
final class HomeViewModel: ObservableObject {

    // Profile + program
    @Published var profile: UserProfile?
    @Published var program: TrainingProgram?
    @Published var bodyWeightLogs: [BodyWeightLog] = []
    @Published var isLoading = true

    // Sessions / XP
    @Published var overallLevel: OverallLevelProgress?
    @Published var sessionXP: SessionXPRecord?

    // Ranking + stats
    @Published var aggregateRank: RankTier = .initiate
    @Published var aggregateTier: SkillTier = .initiate
    @Published var overallRankTrialReadiness: OverallRankTrialReadiness?

    // Contextual triggers
    @Published var plateaus: [PlateauedExercise] = []
    @Published var calibrationSkipRatio: Double = 0
    @Published var hasLoggedAnyWorkout: Bool = false
    @Published var lastLog: WorkoutLog?
    @Published var recentLogs: [WorkoutLog] = []
    @Published var weekSessionDays: Set<Int> = [] // Mon=1...Sun=7
    @Published var bodyRegionLoads: [BodyRegion: Double] = [:]
    @Published var bodyRegionStatuses: [BodyRegion: BodyLoadRegionStatus] = [:]
    @Published var progressionStates: [String: ProgressionState] = [:]

    // Attribute profile (Phase 8+)
    @Published var attributeProfile: AttributeProfile = AttributeProfile.empty(userId: "", at: .now)

    // Travel override (user hit the TRAVEL coach action)
    @Published var activeTravelOverride: TravelOverride?

    // Scan cadence — drives ScanDueCard visibility
    @Published var scanCadence: ScanCadenceState = .compute(lastScanAt: nil, now: .now)
    @Published var lastScanAt: Date? = nil

    // Weekly Vows
    @Published var trialsState: TrialsState = .empty

    // Bodyweight save state
    @Published var isSavingBodyWeight = false
    @Published var bodyWeightSaveError: String?

    private let services: ServiceContainer

    init(services: ServiceContainer) {
        self.services = services
    }

    // MARK: - Loading

    func load() async {
        guard let userId = services.auth.currentUserId else {
            LoggingService.shared.log(
                "Home load skipped without authenticated user",
                level: .warning
            )
            isLoading = false
            return
        }

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
        services.trials.checkVowWindow(userId: userId, now: Date())
        trialsState = services.trials.state(userId: userId)
        overallLevel = (try? await services.database.read(collection: "overall_level_progress", documentId: userId)) ?? OverallLevelProgress(userId: userId)

        isLoading = false

        // ── Phase 2: secondary, concurrent, streams into the cards ────────
        async let skillLoad: Void = SkillProgressService.shared.load(userId: userId)
        async let rankDecay: Void = RankDecayService.shared.evaluateOnForeground(userId: userId)
        async let plateausResult: [PlateauedExercise] = {
            let states = await ProgressionStateStore.shared.fetchAll(userId: userId)
            return await PlateauDetector.shared.detect(userId: userId, states: states)
        }()
        async let profileProgram: (UserProfile?, TrainingProgram?) = loadProfileAndProgram(userId)
        async let recentLogs: [WorkoutLog] = fetchRecentLogsSafe(userId: userId, limit: 40)
        async let weightLogs: [BodyWeightLog] = fetchBodyWeightLogsSafe(userId: userId, limit: 30)
        async let travel: TravelOverride? = TravelOverrideStore.shared.activeOverride(for: userId)
        async let progressions: [ProgressionState] = ProgressionStateStore.shared.fetchAll(userId: userId)

        _ = await skillLoad
        _ = await rankDecay
        plateaus = await plateausResult

        let (fetchedProfile, loadedProgram) = await profileProgram
        if let fetchedProfile {
            profile = fetchedProfile
            if let loadedProgram { program = loadedProgram }
        }

        applyRecentLogs(await recentLogs)
        bodyWeightLogs = await weightLogs
        activeTravelOverride = await travel
        progressionStates = Dictionary(
            uniqueKeysWithValues: (await progressions).map { (MovementCatalog.normalized($0.exerciseKey), $0) }
        )

        let history = (try? ScanCheckpointStore.shared.history(userId: userId)) ?? []
        lastScanAt = history.last?.createdAt
        scanCadence = ScanCadenceState.compute(lastScanAt: lastScanAt, now: .now)
        overallRankTrialReadiness = await TrialReadinessService.shared.readiness(
            userId: userId,
            services: services
        )
    }

    /// Instant local program read (no network) for the Phase-1 paint.
    func loadCachedProgram(_ userId: String) -> TrainingProgram? {
        ProgramStore.shared.loadLocal(userId: userId)
    }

    func loadProfileAndProgram(_ userId: String) async -> (UserProfile?, TrainingProgram?) {
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
            let generated = try await ProgramGenerationService.shared.generateFromOnboarding(
                userId: userId,
                targetFrequency: fetched.targetFrequency,
                equipment: Set(fetched.equipment ?? []),
                experience: fetched.experience,
                sessionLength: fetched.sessionLength,
                exerciseStyles: Set(fetched.exerciseStyles ?? []),
                targetAreas: Set(fetched.targetAreas ?? []),
                age: fetched.age ?? 0,
                gender: fetched.gender ?? .unspecified,
                heightCm: fetched.heightCm ?? 0,
                weightKg: fetched.weightKg ?? 0,
                trainingDays: fetched.trainingDays,
                trainingStyleOverride: fetched.trainingStyleOverride,
                trainingFeedbackMode: fetched.trainingFeedbackMode,
                cutModeActive: fetched.cutMode.enabled,
                biologicalSex: fetched.biologicalSex
            )
            store.adopt(generated, userId: userId)
            return (fetched, generated)
        } catch {
            return (nil, nil)
        }
    }

    func loadRanks(_ userId: String) async -> (RankTier, SkillTier) {
        async let r = services.rank.aggregateRank(userId: userId)
        async let t = services.rank.aggregateTier(userId: userId)
        return (await r, await t)
    }

    func fetchRecentLogsSafe(userId: String, limit: Int) async -> [WorkoutLog] {
        (try? await services.workoutLog.fetchRecentLogs(userId: userId, limit: limit)) ?? []
    }

    func fetchBodyWeightLogsSafe(userId: String, limit: Int) async -> [BodyWeightLog] {
        let logs: [BodyWeightLog] = (try? await services.database.query(
            collection: "bodyWeightLogs",
            field: "userId",
            isEqualTo: userId,
            orderBy: "loggedAt",
            descending: true,
            limit: limit
        )) ?? []
        return logs.sorted { $0.loggedAt > $1.loggedAt }
    }

    func applyRecentLogs(_ logs: [WorkoutLog]) {
        recentLogs = logs
        lastLog = HomeLoadDerivations.lastLog(logs)
        hasLoggedAnyWorkout = HomeLoadDerivations.hasLogged(logs)
        weekSessionDays = HomeLoadDerivations.weekSessionDays(logs.map(\.startedAt))
        let statuses = HomeLoadDerivations.bodyRegionStatuses(logs)
        bodyRegionStatuses = statuses
        bodyRegionLoads = statuses.reduce(into: [:]) { result, entry in
            if entry.value.load > 0.05 {
                result[entry.key] = entry.value.load
            }
        }
    }

    // MARK: - Refresh

    func refreshRanksAndStats() async {
        guard let userId = services.auth.currentUserId else { return }
        aggregateRank = await services.rank.aggregateRank(userId: userId)
        aggregateTier = await services.rank.aggregateTier(userId: userId)
        // Recompute the rank-gate readiness too, so passing a gate advances the
        // Home world card to the next gate (and a workout that meets a key flips
        // its requirement) without an app relaunch.
        overallRankTrialReadiness = await TrialReadinessService.shared.readiness(
            userId: userId,
            services: services
        )
    }

    func refreshTravelOverride() async {
        guard let userId = services.auth.currentUserId else { return }
        activeTravelOverride = await TravelOverrideStore.shared.activeOverride(for: userId)
    }

    func refreshRecentTrainingSignals() async {
        guard let userId = services.auth.currentUserId else { return }
        applyRecentLogs(await fetchRecentLogsSafe(userId: userId, limit: 40))
    }

    func refreshBodyWeightLogs() async {
        guard let userId = services.auth.currentUserId else { return }
        bodyWeightLogs = await fetchBodyWeightLogsSafe(userId: userId, limit: 30)
    }

    func refreshWeeklyRhythm() async {
        guard let userId = services.auth.currentUserId else { return }
        let logs = (try? await services.workoutLog.fetchRecentLogs(userId: userId, limit: 14)) ?? []
        weekSessionDays = HomeLoadDerivations.weekSessionDays(logs.map(\.startedAt))
    }

    func refreshSessionXP() async {
        guard let userId = services.auth.currentUserId else { return }
        sessionXP = services.sessionXP.record(userId: userId)
    }

    func refreshCalibrationState() async {
        guard let userId = services.auth.currentUserId else { return }
        calibrationSkipRatio = services.calibration.skipRatio(userId: userId)
        let logs = (try? await services.workoutLog.fetchRecentLogs(userId: userId, limit: 1)) ?? []
        hasLoggedAnyWorkout = !logs.isEmpty
    }

    func refreshLastLog() async {
        guard let userId = services.auth.currentUserId else { return }
        let logs = (try? await services.workoutLog.fetchRecentLogs(userId: userId, limit: 1)) ?? []
        lastLog = logs.first
        hasLoggedAnyWorkout = !logs.isEmpty
    }

    func refreshWorkoutCompletionState() async {
        await refreshSessionXP()
        await refreshRanksAndStats()
        await refreshRecentTrainingSignals()
    }

    // MARK: - Bodyweight

    /// Validates + persists a bodyweight entry and updates local state.
    /// Returns `true` on success — modal choreography (dismiss, haptic,
    /// history sheet) is the view's job.
    @discardableResult
    func saveBodyWeight(weightKg: Double, note: String?) async -> Bool {
        guard let userId = services.auth.currentUserId else {
            bodyWeightSaveError = "Sign in before logging bodyweight."
            return false
        }
        guard weightKg.isFinite, weightKg > 0 else {
            bodyWeightSaveError = "Enter a valid bodyweight."
            return false
        }

        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedNote = trimmedNote?.isEmpty == false ? trimmedNote : nil
        let log = BodyWeightLog(
            userId: userId,
            weightKg: weightKg,
            loggedAt: Date(),
            note: normalizedNote
        )

        isSavingBodyWeight = true
        bodyWeightSaveError = nil
        defer { isSavingBodyWeight = false }

        do {
            try await services.database.create(log, collection: "bodyWeightLogs", documentId: log.id)
        } catch {
            bodyWeightSaveError = "Could not save bodyweight."
            LoggingService.shared.log(
                "Bodyweight log save failed: \(error)",
                level: .error,
                context: ["userId": userId]
            )
            return false
        }

        do {
            try await services.user.updateProfile(userId: userId, fields: ["weightKg": weightKg])
        } catch {
            LoggingService.shared.log(
                "Profile bodyweight refresh failed: \(error)",
                level: .warning,
                context: ["userId": userId]
            )
        }

        if var currentProfile = profile {
            currentProfile.weightKg = weightKg
            profile = currentProfile
        }
        bodyWeightLogs = Array(
            ([log] + bodyWeightLogs.filter { $0.id != log.id })
                .sorted { $0.loggedAt > $1.loggedAt }
                .prefix(30)
        )
        return true
    }

    // MARK: - Derived

    var archetypeName: String {
        "UNBOUND"
    }

    var todayProgramDay: ProgramDay? {
        guard let program else { return nil }
        return ProgramOverviewDayResolver(
            userId: services.auth.currentUserId,
            activeTravelOverride: activeTravelOverride,
            scheduleRevision: 0,
            scheduleStore: ProgramScheduleStore.shared,
            calendar: .current
        )
        .day(for: Date(), in: program)
    }

    /// True when today's displayed program quest has actually been logged — the
    /// signal that drives the Home "cleared" state. Keys off the program day, not
    /// streak XP, so a rank trial or extra session can't falsely clear the quest.
    var todayProgramDayLogged: Bool {
        guard let program,
              let day = todayProgramDay,
              day.canStartWorkoutSession
        else { return false }
        return HomeLoadDerivations.didLogProgramDayToday(
            recentLogs,
            programId: program.id,
            dayNumber: day.dayNumber
        )
    }

    var todayPlannedBodyRegions: [BodyRegion] {
        guard let day = todayProgramDay,
              !day.isRestDay,
              let workout = day.workout
        else { return [] }
        return BodyRegionTrainingLedger.loads(for: workout).map(\.region)
    }

    var latestBodyWeightKg: Double? {
        bodyWeightLogs.first?.weightKg ?? profile?.weightKg
    }

    var hasLoggedBodyWeightToday: Bool {
        guard let loggedAt = bodyWeightLogs.first?.loggedAt else { return false }
        return Calendar.current.isDateInToday(loggedAt)
    }

    var shouldShowCalibrationCard: Bool {
        calibrationSkipRatio > 0.5 && !hasLoggedAnyWorkout
    }

    /// Home's capture card is always shown — it's the daily photo entry
    /// point, not just a rescan nudge.
    var shouldShowScanCTA: Bool { true }

    // Level derivation reads the XP-backed OverallLevelProgress.
    var lvlValue: Int { overallLevel?.level ?? 0 }
    var lvlFraction: Double { overallLevel?.progressToNextLevel ?? 0 }
    var lvlTotalXP: Int { Int(overallLevel?.totalXP ?? 0) }
    var lvlXPInLevel: Int {
        guard let p = overallLevel else { return 0 }
        return max(0, Int(p.totalXP - OverallLevelCurve.xpRequired(forLevel: p.level)))
    }
    var lvlXPForLevel: Int {
        let lvl = overallLevel?.level ?? 0
        return max(1, Int(OverallLevelCurve.xpRequired(forLevel: lvl + 1) - OverallLevelCurve.xpRequired(forLevel: lvl)))
    }
}
