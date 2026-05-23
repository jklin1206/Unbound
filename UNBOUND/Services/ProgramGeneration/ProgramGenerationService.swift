import Foundation

// Program generation is Claude-first with a local deterministic fallback.
// Claude produces a 7-day weekly template + nutrition + recovery + rationale;
// ProgramBuilder expands it to 84 days. If Claude fails for any reason, we
// quietly use LocalProgramGenerator so the user never sees a broken flow.

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

        let inputs = buildInputs(
            buildIdentity: buildIdentity,
            userProfile: userProfile,
            analysis: analysis
        )

        let program: TrainingProgram
        if let llm = try? await callClaude(inputs: inputs) {
            program = ProgramBuilder.build(
                from: llm,
                userId: userProfile.id,
                scanId: analysis.scanId,
                analysisId: analysis.id,
                buildIdentity: buildIdentity
            )
            logger.log("Program generated via Claude", level: .info, context: [
                "programId": program.id,
                "buildIdentity": buildIdentity.displayName
            ])
        } else {
            program = await localFallback(
                userProfile: userProfile,
                buildIdentity: buildIdentity,
                scanId: analysis.scanId,
                analysisId: analysis.id
            )
            logger.log("Program generated via local fallback", level: .warning, context: [
                "programId": program.id,
                "buildIdentity": buildIdentity.displayName
            ])
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
        weightKg: Double = 0
    ) async -> TrainingProgram {
        // MIGRATION: derive BuildIdentity from AttributeService rather than relying
        // on the archetype param. The archetype param is kept for external API
        // compatibility (callers like UnboundHomeView still pass it) until Phase 2g
        // removes it from the call sites.
        let buildIdentity = await AttributeService.shared.snapshot(userId: userId, asOf: Date()).buildIdentity

        let inputs = ProgramGenerationPrompt.Inputs(
            buildIdentity: buildIdentity,
            targetFrequency: days(for: targetFrequency),
            equipment: equipment.map(\.rawValue),
            experience: experience?.rawValue ?? "unspecified",
            sessionLengthMinutes: sessionLength?.minutes ?? 60,
            exerciseStyles: exerciseStyles.map(\.rawValue),
            targetAreas: targetAreas.map(\.rawValue),
            goals: goals.map(\.rawValue),
            obstacles: obstacles.map(\.rawValue),
            sleepQuality: sleepQuality,
            stressLevel: stressLevel,
            commitment: commitment,
            displayHandle: displayHandle,
            age: age > 0 ? age : nil,
            gender: gender == .unspecified ? nil : gender.rawValue,
            heightCm: heightCm > 0 ? heightCm : nil,
            weightKg: weightKg > 0 ? weightKg : nil,
            analysisSummary: nil,
            focusAreas: [],
            weaknesses: [],
            strengths: []
        )

        let program: TrainingProgram
        if let llm = try? await callClaude(inputs: inputs) {
            program = ProgramBuilder.build(
                from: llm,
                userId: userId,
                scanId: "",
                analysisId: "",
                buildIdentity: buildIdentity
            )
            logger.log("Onboarding program via Claude", level: .info, context: ["programId": program.id])
        } else {
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
            logger.log("Onboarding program via local fallback", level: .warning, context: ["programId": program.id])
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
