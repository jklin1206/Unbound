protocol ProgramGenerationServiceProtocol: Sendable {
    func generateProgram(analysis: BodyAnalysis, userProfile: UserProfile) async throws -> TrainingProgram
}
