import Foundation

// MARK: - ProgramPhase
//
// Phase is the current training block + how long we've held it. No
// 12-week countdown — this is evergreen. The engine picks the phase
// week-by-week from progression + recovery signals.

struct ProgramPhase: Sendable, Equatable {
    let blockType: BlockType
    let weekInBlock: Int
    let rationale: String
    let nextPhaseHint: String
}

// MARK: - ProgramPhaseEngineProtocol

@MainActor
protocol ProgramPhaseEngineProtocol: AnyObject {
    func currentPhase(userId: String) async -> ProgramPhase
}

// MARK: - ProgramPhaseEngine

@MainActor
final class ProgramPhaseEngine: ProgramPhaseEngineProtocol {
    static let shared = ProgramPhaseEngine()

    private let defaults = UserDefaults.standard
    private let phaseKeyPrefix = "unbound.phase.last."   // cached last phase
    private let phaseStartKeyPrefix = "unbound.phase.start." // ISO date phase started

    private init() {}

    func currentPhase(userId: String) async -> ProgramPhase {
        let states = await ProgressionStateStore.shared.fetchAll(userId: userId)
        let plateaus = await PlateauDetector.shared.detect(userId: userId, states: states)
        let logs = (try? await WorkoutLogService.shared.fetchRecentLogs(userId: userId, limit: 60)) ?? []
        let record = SessionXPService.shared.record(userId: userId)

        // Count rank advances in last 4 weeks across all lifts.
        let ranks = await RankService.shared.fetchAll(userId: userId)
        let fourWeeksAgo = Calendar.current.date(byAdding: .day, value: -28, to: Date()) ?? Date()
        let recentAdvances = ranks.filter { $0.lastAdvanceAt >= fourWeeksAgo }.count

        // Recent plateau signals: 2+ plateaued lifts → deload.
        let plateauCount = plateaus.count

        // Weeks since last advance on emphasis lifts (coarse stagnation check).
        let weeksSinceAnyAdvance: Int = {
            guard let latest = ranks.map(\.lastAdvanceAt).max() else { return 99 }
            return max(0, Calendar.current.dateComponents([.weekOfYear], from: latest, to: Date()).weekOfYear ?? 0)
        }()

        // Archetype aggregate rank for realization gating.
        let archetype = await currentArchetype(userId: userId)
        let aggregateRank = await RankService.shared.archetypeRank(userId: userId, archetype: archetype)

        // Recovery proxy: use recent session density as a stress proxy when
        // we have no explicit HRV. More than 5 sessions in the last 7 days
        // with multiple plateaus → recovery compromised.
        let last7 = logs.filter { $0.startedAt >= Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date() }
        let recoveryCompromised = (last7.count >= 5 && plateauCount >= 1) || plateauCount >= 2

        let block = decideBlock(
            recentAdvances: recentAdvances,
            plateauCount: plateauCount,
            weeksSinceAnyAdvance: weeksSinceAnyAdvance,
            aggregateRank: aggregateRank,
            recoveryCompromised: recoveryCompromised,
            hasAnyLogs: !logs.isEmpty,
            weeklyCount: record.weeklyCount
        )

        let weekInBlock = weeksInCurrentBlock(userId: userId, current: block)

        let rationale = rationaleText(
            block: block,
            recentAdvances: recentAdvances,
            plateauCount: plateauCount,
            weeksSinceAnyAdvance: weeksSinceAnyAdvance,
            recoveryCompromised: recoveryCompromised
        )
        let hint = nextPhaseHint(for: block, aggregateRank: aggregateRank)

        return ProgramPhase(
            blockType: block,
            weekInBlock: weekInBlock,
            rationale: rationale,
            nextPhaseHint: hint
        )
    }

    // MARK: Decision tree

    private func decideBlock(
        recentAdvances: Int,
        plateauCount: Int,
        weeksSinceAnyAdvance: Int,
        aggregateRank: SubRank,
        recoveryCompromised: Bool,
        hasAnyLogs: Bool,
        weeklyCount: Int
    ) -> BlockType {
        // Deload triggers take priority.
        if plateauCount >= 2 || weeksSinceAnyAdvance >= 4 || recoveryCompromised {
            return .deload
        }
        // Realization window — requires rank floor + clean recovery + recent
        // advances demonstrating intensification readiness.
        if aggregateRank.ordinal >= SubRank.bMinus.ordinal
            && recentAdvances >= 2
            && plateauCount == 0 {
            return .realization
        }
        // Intensification — advancing steadily without plateaus.
        if recentAdvances >= 3 && plateauCount == 0 {
            return .intensification
        }
        // Default accumulation — always the safe landing zone.
        return .accumulation
    }

    // MARK: Phase persistence (week tracking)

    private func weeksInCurrentBlock(userId: String, current: BlockType) -> Int {
        let phaseKey = phaseKeyPrefix + userId
        let startKey = phaseStartKeyPrefix + userId

        let stored = defaults.string(forKey: phaseKey).flatMap { BlockType(rawValue: $0) }
        let storedStart = (defaults.object(forKey: startKey) as? Date) ?? Date()

        if stored == current {
            let weeks = Calendar.current.dateComponents([.weekOfYear], from: storedStart, to: Date()).weekOfYear ?? 0
            return max(1, weeks + 1)
        } else {
            defaults.set(current.rawValue, forKey: phaseKey)
            defaults.set(Date(), forKey: startKey)
            return 1
        }
    }

    // MARK: Current archetype

    private func currentArchetype(userId: String) async -> Archetype {
        let profile: UserProfile? = try? await DatabaseService.shared.read(
            collection: "user_profiles",
            documentId: userId
        )
        return profile?.preferredArchetype ?? .vTaper
    }

    // MARK: Rationale + hint copy

    private func rationaleText(
        block: BlockType,
        recentAdvances: Int,
        plateauCount: Int,
        weeksSinceAnyAdvance: Int,
        recoveryCompromised: Bool
    ) -> String {
        switch block {
        case .accumulation:
            if recentAdvances == 0 {
                return "Building a base. Volume in, rep ranges locked."
            }
            return "You're laying down volume. \(recentAdvances) rank advance\(recentAdvances == 1 ? "" : "s") in the last four weeks."
        case .intensification:
            return "You've advanced \(recentAdvances) times recently without stalls. Loads climb, reps tighten."
        case .realization:
            return "You've earned the heavy window. Low reps, high intent — test what the accumulation built."
        case .peaking:
            return "Peaking for a test lift. Singles and doubles only."
        case .deload:
            if plateauCount >= 2 {
                return "\(plateauCount) lifts have stalled. Pulling volume back so the nervous system resets."
            }
            if weeksSinceAnyAdvance >= 4 {
                return "No advances in \(weeksSinceAnyAdvance) weeks. A short deload clears the stagnation."
            }
            if recoveryCompromised {
                return "Density is high. Dropping intensity this week to bank recovery."
            }
            return "Backing off so the next push lands clean."
        }
    }

    private func nextPhaseHint(for block: BlockType, aggregateRank: SubRank) -> String {
        switch block {
        case .accumulation:
            return "Intensification opens when current rep ranges start to feel comfortable."
        case .intensification:
            if aggregateRank.ordinal >= SubRank.bMinus.ordinal {
                return "Realization window unlocks once recovery markers stay clean for a week."
            }
            return "Realization window unlocks at rank B- with clean recovery."
        case .realization:
            return "Peaking opens at rank A- if you want to chase a max."
        case .peaking:
            return "Test lift, then deload."
        case .deload:
            return "Returning to accumulation at refreshed working weights next week."
        }
    }
}

// MARK: - MockProgramPhaseEngine

@MainActor
final class MockProgramPhaseEngine: ProgramPhaseEngineProtocol {
    var phase: ProgramPhase = ProgramPhase(
        blockType: .accumulation,
        weekInBlock: 1,
        rationale: "Mock: building a base.",
        nextPhaseHint: "Mock: intensification next."
    )
    func currentPhase(userId: String) async -> ProgramPhase { phase }
}
