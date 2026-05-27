import Foundation

// MARK: - AISessionGeneratorService
//
// Retired compatibility shell. Production skill sessions are authored and
// RPE-adjusted by `RPESessionService`; weekly split optimization is handled
// by `ProgramScheduler`. There is intentionally no shared instance or public
// API here, so accidental rewiring fails at compile time.

@MainActor
final class AISessionGeneratorService {
    private init() {}
}
