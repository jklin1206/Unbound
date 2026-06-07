import Foundation
import SwiftUI
import UIKit

extension UnboundHomeView {
    func load() async {
        guard let userId = services.auth.currentUserId else {
            LoggingService.shared.log(
                "Home load skipped without authenticated user",
                level: .warning
            )
            isLoading = false
            return
        }
        services.badges.bind(userId: userId)
        walletStore.bind(userId: userId)
        shopInventoryStore.bind(userId: userId)
        equippedShopProfileBorder = shopInventoryStore.equippedProfileBorder()
        equippedHomeBackdrop = shopInventoryStore.equippedBackdrop(for: .home)

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
        async let weightLogs: [BodyWeightLog] = fetchBodyWeightLogsSafe(userId: userId, limit: 30)
        async let travel: TravelOverride? = TravelOverrideStore.shared.activeOverride(for: userId)

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

    @MainActor
    func applyRecentLogs(_ logs: [WorkoutLog]) {
        lastLog = HomeLoadDerivations.lastLog(logs)
        hasLoggedAnyWorkout = HomeLoadDerivations.hasLogged(logs)
        weekSessionDays = HomeLoadDerivations.weekSessionDays(logs.map(\.startedAt))
        bodyRegionLoads = HomeLoadDerivations.bodyRegionLoads(logs)
    }

    @MainActor
    func refreshRanksAndStats() async {
        guard let userId = services.auth.currentUserId else { return }
        aggregateRank = await services.rank.aggregateRank(userId: userId)
        aggregateTier = await services.rank.aggregateTier(userId: userId)
    }

    @MainActor
    func refreshTravelOverride() async {
        guard let userId = services.auth.currentUserId else { return }
        activeTravelOverride = await TravelOverrideStore.shared.activeOverride(for: userId)
    }

    @MainActor
    func refreshRecentTrainingSignals() async {
        guard let userId = services.auth.currentUserId else { return }
        applyRecentLogs(await fetchRecentLogsSafe(userId: userId, limit: 40))
    }

    @MainActor
    func refreshBodyWeightLogs() async {
        guard let userId = services.auth.currentUserId else { return }
        bodyWeightLogs = await fetchBodyWeightLogsSafe(userId: userId, limit: 30)
    }

    @MainActor
    func saveBodyWeight(weightKg: Double, note: String?) async {
        guard let userId = services.auth.currentUserId else {
            bodyWeightSaveError = "Sign in before logging bodyweight."
            return
        }
        guard weightKg.isFinite, weightKg > 0 else {
            bodyWeightSaveError = "Enter a valid bodyweight."
            return
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
            return
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
        bodyWeightJustLogged = true
        showingBodyWeightLog = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            showingBodyWeightHistory = true
        }
        UnboundHaptics.medium()
    }

    @MainActor
    func refreshWeeklyRhythm() async {
        guard let userId = services.auth.currentUserId else { return }
        let logs = (try? await services.workoutLog.fetchRecentLogs(userId: userId, limit: 14)) ?? []
        weekSessionDays = HomeLoadDerivations.weekSessionDays(logs.map(\.startedAt))
    }

    @MainActor
    func refreshSessionXP() async {
        guard let userId = services.auth.currentUserId else { return }
        sessionXP = services.sessionXP.record(userId: userId)
    }

    @MainActor
    func refreshCalibrationState() async {
        guard let userId = services.auth.currentUserId else { return }
        calibrationSkipRatio = services.calibration.skipRatio(userId: userId)
        let logs = (try? await services.workoutLog.fetchRecentLogs(userId: userId, limit: 1)) ?? []
        hasLoggedAnyWorkout = !logs.isEmpty
    }

    @MainActor
    func refreshLastLog() async {
        guard let userId = services.auth.currentUserId else { return }
        let logs = (try? await services.workoutLog.fetchRecentLogs(userId: userId, limit: 1)) ?? []
        lastLog = logs.first
        hasLoggedAnyWorkout = !logs.isEmpty
    }

    @MainActor
    func refreshWorkoutCompletionState() async {
        await refreshSessionXP()
        await refreshRanksAndStats()
        await refreshRecentTrainingSignals()
    }

    // MARK: - Session flow

    func beginTodaySession() {
        guard let day = todayProgramDay
        else {
            NotificationCenter.default.post(name: .requestNavigateToProgramTab, object: nil)
            return
        }
        guard day.workout != nil || day.userWorkoutDraft != nil else {
            NotificationCenter.default.post(name: .requestNavigateToProgramTab, object: nil)
            return
        }
        guard let userId = services.auth.currentUserId else {
            LoggingService.shared.log(
                "Today session launch skipped without authenticated user",
                level: .warning
            )
            return
        }
        workoutReadyDraft = DailyWorkoutResolver.programDraft(
            from: day,
            userId: userId,
            programId: program?.id,
            date: Date()
        )
    }

    // MARK: - Derived

    var archetypeName: String {
        "UNBOUND"
    }

    var todayProgramDay: ProgramDay? {
        // Travel override short-circuits the normal rotation.
        if let override = activeTravelOverride, let tday = override.day(for: Date()) {
            return synthesizeTravelDay(from: tday, override: override)
        }
        guard let program else { return nil }
        guard !program.days.isEmpty else { return nil }
        let daysSinceStart = max(
            0,
            Calendar.current.dateComponents([.day], from: program.createdAt, to: Date()).day ?? 0
        )
        let dayIndex = daysSinceStart % program.days.count
        return program.days[dayIndex]
    }

    func synthesizeTravelDay(from tday: TravelDay, override: TravelOverride) -> ProgramDay {
        let workout = tday.workout(summary: "Travel block: \(override.summary)")
        return ProgramDay(
            id: "travel-home",
            dayNumber: 0,
            label: tday.isRest ? "TRAVEL · REST" : "TRAVEL · \(tday.title)",
            isRestDay: tday.isRest,
            workout: workout,
            nutritionOverride: nil,
            recoveryActivities: []
        )
    }

    var todayPlannedBodyRegions: [BodyRegion] {
        guard let day = todayProgramDay,
              !day.isRestDay,
              let workout = day.workout
        else { return [] }
        return BodyRegionTrainingLedger.loads(for: workout).map(\.region)
    }

    var selectedWeightUnit: TrainingWeightUnit {
        TrainingWeightUnit(rawValue: weightUnitRaw) ?? .localeDefault
    }

    var latestBodyWeightKg: Double? {
        bodyWeightLogs.first?.weightKg ?? profile?.weightKg
    }

    var bodyWeightValueText: String {
        guard let latestBodyWeightKg else { return "--" }
        return WeightPlatePolicy.formatLoggedWeight(latestBodyWeightKg, unit: selectedWeightUnit)
    }

    var bodyWeightRecencyText: String {
        if let loggedAt = bodyWeightLogs.first?.loggedAt {
            return "LOGGED \(dayWord(for: loggedAt))"
        }
        if latestBodyWeightKg != nil {
            return "FROM PROFILE"
        }
        return "NO ENTRIES YET"
    }

    var hasLoggedBodyWeightToday: Bool {
        guard let loggedAt = bodyWeightLogs.first?.loggedAt else { return false }
        return Calendar.current.isDateInToday(loggedAt)
    }

    var bodyWeightStatusColor: Color {
        hasLoggedBodyWeightToday ? Color.unbound.success : Color.unbound.accent
    }

    var shouldShowCalibrationCard: Bool {
        calibrationSkipRatio > 0.5 && !hasLoggedAnyWorkout
    }

    /// Home's capture card is always shown — it's the daily photo entry
    /// point, not just a rescan nudge.
    var shouldShowScanCTA: Bool { true }
}
