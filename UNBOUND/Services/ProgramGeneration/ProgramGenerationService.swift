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

        let archetype = userProfile.preferredArchetype ?? analysis.targetArchetype

        let inputs = buildInputs(
            archetype: archetype,
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
                archetype: archetype
            )
            logger.log("Program generated via Claude", level: .info, context: [
                "programId": program.id,
                "archetype": archetype.rawValue
            ])
        } else {
            program = await localFallback(
                userProfile: userProfile,
                archetype: archetype,
                scanId: analysis.scanId,
                analysisId: analysis.id
            )
            logger.log("Program generated via local fallback", level: .warning, context: [
                "programId": program.id,
                "archetype": archetype.rawValue
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
        archetype: Archetype,
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
        let inputs = ProgramGenerationPrompt.Inputs(
            archetype: archetype,
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
                archetype: archetype
            )
            logger.log("Onboarding program via Claude", level: .info, context: ["programId": program.id])
        } else {
            let calibrations = await CalibrationService.shared.fetchAll(userId: userId)
            let rank = await resolveArchetypeRank(userId: userId, archetype: archetype)
            let fallback = LocalProgramGenerator.generate(
                archetype: archetype,
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
                preferences: [],
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

        try? await database.create(program, collection: "programs", documentId: program.id)
        try? await database.update(
            ["currentProgramId": program.id],
            collection: "users",
            documentId: userId
        )
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
        archetype: Archetype,
        userProfile: UserProfile,
        analysis: BodyAnalysis
    ) -> ProgramGenerationPrompt.Inputs {
        let focusAreaNames = analysis.focusAreas
            .sorted { $0.priority < $1.priority }
            .map { $0.muscleGroup.displayName }

        return ProgramGenerationPrompt.Inputs(
            archetype: archetype,
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
        archetype: Archetype,
        scanId: String,
        analysisId: String
    ) async -> TrainingProgram {
        let calibrations = await CalibrationService.shared.fetchAll(userId: userProfile.id)
        let rank = await resolveArchetypeRank(userId: userProfile.id, archetype: archetype)
        return LocalProgramGenerator.generate(
            archetype: archetype,
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
            preferences: [],
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

    /// Resolve the user's current archetype aggregate rank. Runs on the
    /// main actor (RankService is @MainActor) and funnels back here via
    /// structured concurrency.
    private func resolveArchetypeRank(userId: String, archetype: Archetype) async -> SubRank {
        await MainActor.run {
            Task { @MainActor in
                await RankService.shared.archetypeRank(userId: userId, archetype: archetype)
            }
        }.value
    }
}
