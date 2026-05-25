import Foundation

// Program generation is deterministic-first.
// Claude remains an emergency fallback for malformed inputs or unexpected
// generator errors, but the canonical path is local, auditable, and cheap:
// first-time users start with Calibration Week, then normal 28-day Arcs
// are built from scan/profile inputs plus stored progression state.

final class ProgramGenerationService: ProgramGenerationServiceProtocol, @unchecked Sendable {
    static let shared = ProgramGenerationService()
    private let database = DatabaseService.shared
    private let logger = LoggingService.shared
    private let claude = ClaudeClient.shared

    private init() {}

    func generateProgram(analysis: BodyAnalysis, userProfile: UserProfile) async throws -> TrainingProgram {
        try? await database.update(
            ["status": ScanStatus.programGenerating.rawValue],
            collection: "scans",
            documentId: analysis.scanId
        )

        let buildIdentity = await AttributeService.shared.snapshot(userId: userProfile.id, asOf: Date()).buildIdentity

        let program: TrainingProgram
        do {
            let input = await deterministicInput(
                userId: userProfile.id,
                buildIdentity: buildIdentity,
                targetFrequency: userProfile.targetFrequency,
                trainingDays: userProfile.trainingDays,
                equipment: Set(userProfile.equipment ?? []),
                experience: userProfile.experience,
                exerciseStyles: Set(userProfile.exerciseStyles ?? []),
                focusAreas: analysis.focusAreas,
                cutModeActive: userProfile.cutMode.enabled,
                trainingFeedbackMode: userProfile.trainingFeedbackMode,
                trainingStyleOverride: userProfile.trainingStyleOverride,
                age: userProfile.age ?? 0,
                gender: userProfile.gender ?? .unspecified,
                biologicalSex: userProfile.biologicalSex,
                heightCm: userProfile.heightCm ?? 0,
                weightKg: userProfile.weightKg ?? 0,
                scanId: analysis.scanId,
                analysisId: analysis.id
            )
            program = try DeterministicProgramGenerator.generate(input: input)
            logger.log("Program generated deterministically", level: .info, context: [
                "programId": program.id,
                "buildIdentity": buildIdentity.displayName,
                "calibration": "\(input.calibration.requiresLearningWeek)"
            ])
        } catch {
            let inputs = buildInputs(
                buildIdentity: buildIdentity,
                userProfile: userProfile,
                analysis: analysis
            )
            if let llm = try? await callClaude(inputs: inputs) {
                program = ProgramBuilder.build(
                    from: llm,
                    userId: userProfile.id,
                    scanId: analysis.scanId,
                    analysisId: analysis.id,
                    buildIdentity: buildIdentity
                )
                logger.log("Program generated via Claude fallback", level: .warning, context: [
                    "programId": program.id,
                    "buildIdentity": buildIdentity.displayName,
                    "deterministicError": "\(error)"
                ])
            } else {
                program = await localFallback(
                    userProfile: userProfile,
                    buildIdentity: buildIdentity,
                    scanId: analysis.scanId,
                    analysisId: analysis.id
                )
                logger.log("Program generated via legacy local fallback", level: .error, context: [
                    "programId": program.id,
                    "buildIdentity": buildIdentity.displayName,
                    "deterministicError": "\(error)"
                ])
            }
        }

        try? await database.create(program, collection: "programs", documentId: program.id)
        try? await database.update(
            ["programId": program.id, "status": ScanStatus.complete.rawValue],
            collection: "scans",
            documentId: analysis.scanId
        )
        try? await database.update(
            ["currentProgramId": program.id],
            collection: "users",
            documentId: analysis.userId
        )

        return program
    }

    // MARK: - Convenience: generate without a scan

    func generateFromOnboarding(
        userId: String,
        targetFrequency: TargetFrequency?,
        equipment: Set<Equipment>,
        experience: Experience?,
        sessionLength: SessionLength?,
        exerciseStyles: Set<ExerciseStyle>,
        targetAreas: Set<TargetArea>,
        goals: Set<Goal> = [],
        obstacles: Set<Obstacle> = [],
        sleepQuality: Int = 5,
        stressLevel: Int = 5,
        currentFrequency: Frequency? = nil,
        commitment: Int = 8,
        displayHandle: String = "",
        age: Int = 0,
        gender: Gender = .unspecified,
        heightCm: Double = 0,
        weightKg: Double = 0,
        trainingDays: Set<Weekday>? = nil,
        trainingStyleOverride: TrainingStyle? = nil,
        trainingFeedbackMode: TrainingFeedbackMode? = nil,
        cutModeActive: Bool = false,
        biologicalSex: BiologicalSex? = nil
    ) async -> TrainingProgram {
        // MIGRATION: derive BuildIdentity from AttributeService rather than relying
        // on the archetype param. The archetype param is kept for external API
        // compatibility (callers like UnboundHomeView still pass it) until Phase 2g
        // removes it from the call sites.
        let buildIdentity = await AttributeService.shared.snapshot(userId: userId, asOf: Date()).buildIdentity

        let program: TrainingProgram
        do {
            let deterministic = await deterministicInput(
                userId: userId,
                buildIdentity: buildIdentity,
                targetFrequency: targetFrequency,
                trainingDays: trainingDays,
                equipment: equipment,
                experience: experience,
                exerciseStyles: exerciseStyles,
                targetAreas: targetAreas,
                cutModeActive: cutModeActive,
                trainingFeedbackMode: trainingFeedbackMode,
                trainingStyleOverride: trainingStyleOverride,
                age: age,
                gender: gender,
                biologicalSex: biologicalSex,
                heightCm: heightCm,
                weightKg: weightKg,
                scanId: nil,
                analysisId: nil
            )
            program = try DeterministicProgramGenerator.generate(input: deterministic)
            logger.log("Onboarding program via deterministic generator", level: .info, context: [
                "programId": program.id,
                "calibration": "\(deterministic.calibration.requiresLearningWeek)"
            ])
        } catch {
            let calibrations = await CalibrationService.shared.fetchAll(userId: userId)
            let rank = await resolveArchetypeRank(userId: userId)
            let preferences = (try? await ExercisePreferenceService.shared.fetchPreferences(userId: userId)) ?? []
            let fallback = LocalProgramGenerator.generate(
                buildIdentity: buildIdentity,
                targetFrequency: targetFrequency,
                equipment: equipment,
                experience: experience,
                sessionLength: sessionLength,
                exerciseStyles: exerciseStyles,
                targetAreas: targetAreas,
                goals: goals,
                obstacles: obstacles,
                sleepQuality: sleepQuality,
                stressLevel: stressLevel,
                currentFrequency: currentFrequency,
                commitment: commitment,
                displayHandle: displayHandle,
                age: age,
                gender: gender,
                heightCm: heightCm,
                weightKg: weightKg,
                preferences: preferences,
                progressionStates: [],
                familyStates: [],
                customExercises: [],
                calibrations: calibrations,
                archetypeRank: rank,
                userId: userId
            )
            program = fallback
            logger.log("Onboarding program via legacy local fallback", level: .error, context: [
                "programId": program.id,
                "deterministicError": "\(error)"
            ])
        }

        // Persist on a DETACHED task so a torn-down caller cannot abort the
        // writes. These two calls used to run inside the caller's task as
        // `try? await …`; when the SwiftUI `.task` that kicked off generation
        // is cancelled (RootView re-routes the moment sign-in flips
        // `isAuthenticated`, or the user switches tabs), each `await` threw
        // CancellationError, `try?` swallowed it, and the generated program
        // was never saved — so `currentProgramId` never got set and the user
        // was stuck forever on "No program yet" (regenerating + re-cancelling
        // on every appearance). A detached task is independent of the caller's
        // cancellation tree, so the program reliably lands in the DB and the
        // next load short-circuits to it.
        let db = database
        let log = logger
        let savedProgram = program
        let savedUserId = userId
        Task.detached(priority: .userInitiated) {
            do {
                try await db.create(savedProgram, collection: "programs", documentId: savedProgram.id)
                try await db.update(
                    ["currentProgramId": savedProgram.id],
                    collection: "users",
                    documentId: savedUserId
                )
            } catch {
                log.log(
                    "Onboarding program persist failed",
                    level: .error,
                    context: ["programId": savedProgram.id, "error": "\(error)"]
                )
            }
        }
        return program
    }

    // MARK: - Claude call

    private func callClaude(inputs: ProgramGenerationPrompt.Inputs) async throws -> ProgramLLMOutput {
        let schema = try JSONValue.fromJSONString(ProgramGenerationPrompt.schemaJSON)
        let tool = ClaudeClient.Tool(
            name: ProgramGenerationPrompt.toolName,
            description: ProgramGenerationPrompt.toolDescription,
            inputSchema: schema
        )
        return try await claude.sendStructured(
            ProgramLLMOutput.self,
            model: .sonnet46,
            system: ProgramGenerationPrompt.systemPrompt(inputs),
            userText: ProgramGenerationPrompt.userPrompt,
            tool: tool,
            maxTokens: 8192
        )
    }

    // MARK: - Input builders

    private func buildInputs(
        buildIdentity: BuildIdentity,
        userProfile: UserProfile,
        analysis: BodyAnalysis
    ) -> ProgramGenerationPrompt.Inputs {
        let focusAreaNames = analysis.focusAreas
            .sorted { $0.priority < $1.priority }
            .map { $0.muscleGroup.displayName }

        return ProgramGenerationPrompt.Inputs(
            buildIdentity: buildIdentity,
            targetFrequency: days(for: userProfile.targetFrequency),
            equipment: (userProfile.equipment ?? []).map(\.rawValue),
            experience: userProfile.experience?.rawValue ?? "unspecified",
            sessionLengthMinutes: userProfile.sessionLength?.minutes ?? 60,
            exerciseStyles: (userProfile.exerciseStyles ?? []).map(\.rawValue),
            targetAreas: (userProfile.targetAreas ?? []).map(\.rawValue),
            goals: (userProfile.goals ?? []).map(\.rawValue),
            obstacles: (userProfile.obstacles ?? []).map(\.rawValue),
            sleepQuality: userProfile.sleepQuality ?? 5,
            stressLevel: userProfile.stressLevel ?? 5,
            commitment: userProfile.commitment ?? 8,
            displayHandle: userProfile.displayHandle ?? userProfile.displayName ?? "",
            age: userProfile.age,
            gender: userProfile.gender?.rawValue,
            heightCm: userProfile.heightCm,
            weightKg: userProfile.weightKg,
            analysisSummary: analysis.summary,
            focusAreas: focusAreaNames,
            weaknesses: analysis.weaknesses,
            strengths: analysis.strengths
        )
    }

    private func days(for frequency: TargetFrequency?) -> Int {
        switch frequency {
        case .three: return 3
        case .four: return 4
        case .five: return 5
        case .six: return 6
        case .none: return 4
        }
    }

    // MARK: - Deterministic generation input

    private func deterministicInput(
        userId: String,
        buildIdentity: BuildIdentity,
        targetFrequency: TargetFrequency?,
        trainingDays: Set<Weekday>?,
        equipment: Set<Equipment>,
        experience: Experience?,
        exerciseStyles: Set<ExerciseStyle>,
        targetAreas: Set<TargetArea> = [],
        focusAreas: [FocusArea] = [],
        cutModeActive: Bool,
        trainingFeedbackMode: TrainingFeedbackMode?,
        trainingStyleOverride: TrainingStyle?,
        age: Int,
        gender: Gender,
        biologicalSex: BiologicalSex?,
        heightCm: Double,
        weightKg: Double,
        scanId: String?,
        analysisId: String?
    ) async -> ProgramGeneratorInput {
        async let calibrationTask = CalibrationService.shared.fetchAll(userId: userId)
        async let progressionTask = ProgressionStateStore.shared.fetchAll(userId: userId)

        let frequency = targetFrequency ?? .four
        let resolvedExperience = experience ?? .never
        let resolvedEquipment = equipment.isEmpty
            ? [Equipment.bodyweight]
            : Equipment.allCases.filter { equipment.contains($0) }
        let resolvedTrainingDays = resolvedTrainingDays(
            trainingDays,
            frequency: frequency,
            startDate: Date()
        )
        let resolvedStyle = trainingStyleOverride ?? inferredTrainingStyle(
            buildIdentity: buildIdentity,
            equipment: resolvedEquipment,
            exerciseStyles: exerciseStyles
        )
        let resolvedFeedback = trainingFeedbackMode ?? TrainingFeedbackMode.default(for: resolvedExperience)
        let resolvedSex = biologicalSex ?? biologicalSexFallback(from: gender) ?? .male
        let resolvedFocus = focusAreas.isEmpty ? focusAreasFromTargets(targetAreas) : focusAreas

        let calibrations = await calibrationTask
        let progressions = await progressionTask
        let preferences = (try? await ExercisePreferenceService.shared.fetchPreferences(userId: userId)) ?? []
        let progressionStates = progressionStateMap(
            userId: userId,
            progressions: progressions,
            calibrations: calibrations
        )

        return ProgramGeneratorInput(
            userId: userId,
            scanId: scanId,
            analysisId: analysisId,
            buildIdentity: buildIdentity,
            trainingStyle: resolvedStyle,
            equipment: resolvedEquipment,
            targetFrequency: frequency,
            trainingDays: resolvedTrainingDays,
            experience: resolvedExperience,
            focusAreas: resolvedFocus,
            cutModeActive: cutModeActive,
            trainingFeedbackMode: resolvedFeedback,
            progressionStates: progressionStates,
            previousBlock: nil,
            weightKg: weightKg > 0 ? weightKg : 75,
            heightCm: heightCm > 0 ? heightCm : 175,
            age: age > 0 ? age : 30,
            sex: resolvedSex,
            blockStartDate: Date(),
            exercisePreferences: preferences,
            calibration: calibrationInput(
                calibrations: calibrations,
                progressionStates: Array(progressionStates.values)
            )
        )
    }

    private func progressionStateMap(
        userId: String,
        progressions: [ProgressionState],
        calibrations: [CalibrationBaseline]
    ) -> [String: ProgressionState] {
        var map: [String: ProgressionState] = [:]
        for state in progressions {
            map[MovementCatalog.normalized(state.exerciseKey)] = state
        }

        for baseline in calibrations where isUsableCalibrationBaseline(baseline) && baseline.kind == .weight {
            let key = MovementCatalog.normalized(baseline.exerciseKey)
            guard map[key] == nil,
                  let kg = baseline.weightInKg,
                  kg > 0
            else { continue }
            map[key] = ProgressionState.seed(
                userId: userId,
                exercise: baseline.displayName,
                startingWeightKg: kg
            )
        }
        return map
    }

    private func calibrationInput(
        calibrations: [CalibrationBaseline],
        progressionStates: [ProgressionState]
    ) -> ProgramCalibrationInput {
        let knownFromBaselines = calibrations
            .filter(isUsableCalibrationBaseline)
            .map(\.exerciseKey)
        let knownFromProgression = progressionStates.map(\.exerciseKey)
        let knownKeys = Set(knownFromBaselines + knownFromProgression)

        if knownKeys.count >= 2 {
            return .standardReady(knownExerciseKeys: knownKeys)
        }
        return .learningWeek(knownExerciseKeys: knownKeys)
    }

    private func isUsableCalibrationBaseline(_ baseline: CalibrationBaseline) -> Bool {
        guard baseline.isKnown else { return false }
        switch baseline.kind {
        case .weight:
            return (baseline.weightInKg ?? 0) > 0
        case .reps:
            return baseline.value > 0
        }
    }

    private func inferredTrainingStyle(
        buildIdentity: BuildIdentity,
        equipment: [Equipment],
        exerciseStyles: Set<ExerciseStyle>
    ) -> TrainingStyle {
        if buildIdentity.programTemplateKey == "control"
            || exerciseStyles.contains(.calisthenics)
            || (equipment.count == 1 && equipment.contains(.bodyweight)) {
            return .bodyweight
        }
        if exerciseStyles.contains(.machines) || equipment.contains(.machines) {
            return .machines
        }
        if exerciseStyles.contains(.compoundLifts)
            || equipment.contains(.barbell)
            || equipment.contains(.dumbbells)
            || equipment.contains(.bench) {
            return .freeWeights
        }
        return .hybrid
    }

    private func resolvedTrainingDays(
        _ selectedDays: Set<Weekday>?,
        frequency: TargetFrequency,
        startDate: Date
    ) -> Set<Weekday> {
        let targetCount = frequency.numericCount
        let selected = Weekday.allCases.filter { selectedDays?.contains($0) == true }
        if selected.count == targetCount {
            return Set(selected)
        }

        var resolved = Array(selected.prefix(targetCount))
        for day in defaultTrainingDays(frequency: frequency, startDate: startDate) where resolved.count < targetCount {
            if !resolved.contains(day) {
                resolved.append(day)
            }
        }
        return Set(resolved)
    }

    private func defaultTrainingDays(
        frequency: TargetFrequency,
        startDate: Date
    ) -> [Weekday] {
        let start = Weekday(from: startDate) ?? .monday
        let ordered = orderedWeekdays(startingWith: start)
        let indexes: [Int]
        switch frequency {
        case .three:
            indexes = [0, 2, 4]
        case .four:
            indexes = [0, 2, 4, 6]
        case .five:
            indexes = [0, 1, 2, 4, 6]
        case .six:
            indexes = [0, 1, 2, 3, 4, 5]
        }
        return indexes.map { ordered[$0] }
    }

    private func orderedWeekdays(startingWith first: Weekday) -> [Weekday] {
        guard let startIndex = Weekday.allCases.firstIndex(of: first) else {
            return Weekday.allCases
        }
        return Array(Weekday.allCases[startIndex...]) + Array(Weekday.allCases[..<startIndex])
    }

    private func biologicalSexFallback(from gender: Gender) -> BiologicalSex? {
        switch gender {
        case .male:
            return .male
        case .female:
            return .female
        case .unspecified:
            return nil
        }
    }

    private func focusAreasFromTargets(_ targetAreas: Set<TargetArea>) -> [FocusArea] {
        TargetArea.allCases
            .filter { targetAreas.contains($0) }
            .compactMap { target -> MuscleGroup? in
                switch target {
                case .chest: return .chest
                case .back: return .back
                case .shoulders: return .shoulders
                case .arms: return .arms
                case .core: return .core
                case .legs: return .legs
                case .glutes: return .glutes
                case .fullBody: return nil
                }
            }
            .enumerated()
            .map { index, muscle in
                FocusArea(
                    muscleGroup: muscle,
                    priority: index + 1,
                    rationale: "Selected during onboarding",
                    suggestedFocus: "Bias accessory volume toward \(muscle.displayName.lowercased())"
                )
            }
    }

    // MARK: - Local fallback

    private func localFallback(
        userProfile: UserProfile,
        buildIdentity: BuildIdentity,
        scanId: String,
        analysisId: String
    ) async -> TrainingProgram {
        let calibrations = await CalibrationService.shared.fetchAll(userId: userProfile.id)
        let rank = await resolveArchetypeRank(userId: userProfile.id)
        let preferences = (try? await ExercisePreferenceService.shared.fetchPreferences(userId: userProfile.id)) ?? []
        return LocalProgramGenerator.generate(
            buildIdentity: buildIdentity,
            targetFrequency: userProfile.targetFrequency,
            equipment: Set(userProfile.equipment ?? []),
            experience: userProfile.experience,
            sessionLength: userProfile.sessionLength,
            exerciseStyles: Set(userProfile.exerciseStyles ?? []),
            targetAreas: Set(userProfile.targetAreas ?? []),
            goals: Set(userProfile.goals ?? []),
            obstacles: Set(userProfile.obstacles ?? []),
            sleepQuality: userProfile.sleepQuality ?? 5,
            stressLevel: userProfile.stressLevel ?? 5,
            currentFrequency: userProfile.currentFrequency,
            commitment: userProfile.commitment ?? 8,
            displayHandle: userProfile.displayHandle ?? userProfile.displayName ?? "",
            age: userProfile.age ?? 0,
            gender: userProfile.gender ?? .unspecified,
            heightCm: userProfile.heightCm ?? 0,
            weightKg: userProfile.weightKg ?? 0,
            preferences: preferences,
            progressionStates: [],
            familyStates: [],
            customExercises: [],
            calibrations: calibrations,
            archetypeRank: rank,
            userId: userProfile.id,
            scanId: scanId,
            analysisId: analysisId
        )
    }

    /// Resolve the user's current aggregate rank. Runs on the
    /// main actor (RankService is @MainActor) and funnels back here via
    /// structured concurrency.
    private func resolveArchetypeRank(userId: String) async -> SubRank {
        await MainActor.run {
            Task { @MainActor in
                await RankService.shared.aggregateRank(userId: userId)
            }
        }.value
    }
}
