import Foundation

// Program generation runs entirely on-device via LocalProgramGenerator —
// rule-based, deterministic, no network. The Claude API is reserved for
// the coach chat tab; program building is too high-stakes (and too
// frequently hit) to depend on a remote model.
//
// Public API surface is preserved so call sites (BodyScanViewModel,
// ProgramOverviewView, UnboundHomeView) continue working unchanged.
//
// DB writes use `try?` intentionally — a 401 in dev or transient FS
// hiccup must never block the user from seeing their program.

final class ProgramGenerationService: ProgramGenerationServiceProtocol, @unchecked Sendable {
    static let shared = ProgramGenerationService()
    private let database = DatabaseService.shared
    private let logger = LoggingService.shared

    private init() {}

    // MARK: - Post-scan path

    func generateProgram(analysis: BodyAnalysis, userProfile: UserProfile) async throws -> TrainingProgram {
        try? await database.update(
            ["status": ScanStatus.programGenerating.rawValue],
            collection: "scans",
            documentId: analysis.scanId
        )

        let archetype = userProfile.preferredArchetype ?? analysis.targetArchetype
        let calibrations = await CalibrationService.shared.fetchAll(userId: userProfile.id)
        let rank = await resolveArchetypeRank(userId: userProfile.id, archetype: archetype)

        let program = LocalProgramGenerator.generate(
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
            scanId: analysis.scanId,
            analysisId: analysis.id
        )

        logger.log("Program generated locally", level: .info, context: [
            "programId": program.id,
            "archetype": archetype.rawValue,
            "source": "post-scan"
        ])

        await SupabaseProgramService.shared.saveProgram(program, userId: analysis.userId)
        try? await database.update(
            ["programId": program.id, "status": ScanStatus.complete.rawValue],
            collection: "scans",
            documentId: analysis.scanId
        )

        return program
    }

    // MARK: - Onboarding path (no scan yet)

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
        let calibrations = await CalibrationService.shared.fetchAll(userId: userId)
        let rank = await resolveArchetypeRank(userId: userId, archetype: archetype)

        let program = LocalProgramGenerator.generate(
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

        logger.log("Program generated locally", level: .info, context: [
            "programId": program.id,
            "archetype": archetype.rawValue,
            "source": "onboarding"
        ])

        await SupabaseProgramService.shared.saveProgram(program, userId: userId)
        return program
    }

    // MARK: - Helpers

    /// Resolve the user's current archetype aggregate rank. RankService is
    /// `@MainActor`; structured concurrency hops over and back.
    private func resolveArchetypeRank(userId: String, archetype: Archetype) async -> SubRank {
        await MainActor.run {
            Task { @MainActor in
                await RankService.shared.archetypeRank(userId: userId, archetype: archetype)
            }
        }.value
    }
}
