import Foundation

/// Decides + executes the monthly block rollover: prefer a fresh scan at the
/// boundary, prompt for one, auto-roll with existing data after a grace
/// window. Runs fully on-device (deterministic generator) — offline OK.
@MainActor
final class RolloverCoordinator {
    static let shared = RolloverCoordinator()

    enum Decision: Equatable { case noop, rollNow, awaitRescan }

    private var isRolling = false

    /// Pure core. `daysPastBoundary` is 0 until the block ends, then counts up.
    nonisolated static func decide(daysRemaining: Int, hasFreshScan: Bool,
                                   daysPastBoundary: Int, graceDays: Int) -> Decision {
        guard daysRemaining == 0 else { return .noop }
        if hasFreshScan { return .rollNow }
        return daysPastBoundary >= graceDays ? .rollNow : .awaitRescan
    }

    /// Foreground entry point. Reads program + latest scan locally, decides,
    /// and rolls if needed. Single-flight via `isRolling`; after a roll the
    /// new program's `createdAt` resets `daysRemaining`, so the next
    /// foreground decides `.noop` (sequential double-roll protection).
    func evaluateOnForeground(userId: String, services: ServiceContainer) async {
        guard !isRolling, let program = ProgramStore.shared.program else { return }

        let remaining = BlockRolloverScheduler.daysRemaining(program: program)
        let elapsed = Int(Date().timeIntervalSince(program.createdAt) / 86400)
        let daysPastBoundary = max(0, elapsed - program.durationDays)
        let latestScan = try? ScanCheckpointStore.shared.mostRecent(userId: userId)
        let hasFresh = (latestScan?.createdAt ?? .distantPast) > program.createdAt

        guard Self.decide(daysRemaining: remaining, hasFreshScan: hasFresh,
                          daysPastBoundary: daysPastBoundary, graceDays: 5) == .rollNow
        else { return }

        isRolling = true
        defer { isRolling = false }
        guard let profile = try? await services.user.fetchProfile(userId: userId) else { return }
        let prevBlockNum = (await ProgramBlockStore.shared.latestBlock(userId: userId))?.blockNumber ?? 0
        do {
            let newProgram = try await BlockRolloverService.performRollover(
                userId: userId, profile: profile, analysis: nil, scan: nil)
            let newBlockNum = (await ProgramBlockStore.shared.latestBlock(userId: userId))?.blockNumber ?? 0
            guard newBlockNum > prevBlockNum else { return }
            await ProgramStore.shared.save(newProgram, userId: userId)
        } catch {
            LoggingService.shared.log("Rollover failed: \(error)",
                                      level: .error, context: [:])
        }
    }
}
