import Foundation

struct ProgramBlockRolloverContext {
    let currentBlock: Int
    let nextBlock: Int
    let deltaReport: ScanDeltaReport?
    let proposal: BlockRolloverService.ProgramBlockProposal
}

enum ProgramBlockRolloverCoordinator {
    static func loadContext(
        userId: String,
        database: any DatabaseServiceProtocol
    ) async -> ProgramBlockRolloverContext {
        let latest = await ProgramBlockStore.shared.latestBlock(userId: userId)
        let currentBlock = max(latest?.blockNumber ?? 1, 1)
        let nextBlock = currentBlock + 1
        let deltaReport = await latestDeltaReport(userId: userId, database: database)
        let proposal = BlockRolloverService.proposal(
            currentBlockNumber: currentBlock,
            previousBlock: latest,
            latestDeltaReport: deltaReport
        )
        return ProgramBlockRolloverContext(
            currentBlock: currentBlock,
            nextBlock: nextBlock,
            deltaReport: deltaReport,
            proposal: proposal
        )
    }

    static func generateNextBlock(
        userId: String,
        profile: UserProfile,
        currentBlockNumber: Int,
        proposal: BlockRolloverService.ProgramBlockProposal?,
        deltaReport: ScanDeltaReport?
    ) async throws -> TrainingProgram {
        let previousBlock = await ProgramBlockStore.shared.latestBlock(userId: userId)
        let resolvedProposal = proposal ?? BlockRolloverService.proposal(
            currentBlockNumber: currentBlockNumber,
            previousBlock: previousBlock,
            latestDeltaReport: deltaReport
        )
        let analysis = BlockRolloverService.analysis(from: resolvedProposal, userId: userId)
        return try await BlockRolloverService.performRollover(
            userId: userId,
            profile: profile,
            analysis: analysis,
            scan: nil
        )
    }

    private static func latestDeltaReport(
        userId: String,
        database: any DatabaseServiceProtocol
    ) async -> ScanDeltaReport? {
        do {
            let results: [ScanDeltaReport] = try await database.query(
                collection: "scanDeltaReports",
                field: "userId",
                isEqualTo: userId,
                orderBy: "createdAt",
                descending: true,
                limit: 1
            )
            return results.first
        } catch {
            return nil
        }
    }
}
