import Foundation

enum VitalityRewardPolicy {
    static let dailySignalCap: Double = 12
    static let weeklyConsistencyBonus: Double = 15

    struct Award: Equatable, Sendable {
        var signals: [VitalityCheckInSignal] = []
        var signalXP: Double = 0
        var weeklyBonusXP: Double = 0
        var localDay: String = ""
        var localWeek: String = ""

        var totalXP: Double {
            signalXP + weeklyBonusXP
        }
    }

    static func previewAward(for performanceLog: PerformanceLog) -> Award {
        let signals = signals(for: performanceLog)
        guard !signals.isEmpty else { return Award() }
        let signalXP = min(dailySignalCap, baseXP(for: signals))
        return Award(
            signals: signals,
            signalXP: signalXP,
            weeklyBonusXP: 0,
            localDay: localDayKey(for: performanceLog.completedAt),
            localWeek: localWeekKey(for: performanceLog.completedAt)
        )
    }

    static func award(
        for performanceLog: PerformanceLog,
        database: any DatabaseServiceProtocol
    ) async -> Award {
        let signals = signals(for: performanceLog)
        guard !signals.isEmpty else { return Award() }

        let dayKey = localDayKey(for: performanceLog.completedAt)
        let weekKey = localWeekKey(for: performanceLog.completedAt)
        let priorRecords = (try? await database.query(
            collection: "vitality_reward_records",
            field: "userId",
            isEqualTo: performanceLog.userId,
            orderBy: "awardedAt",
            descending: false,
            limit: nil
        ) as [VitalityRewardRecord]) ?? []

        let usedToday = priorRecords
            .filter { $0.localDay == dayKey }
            .reduce(0) { $0 + max(0, $1.signalXP) }
        let remainingToday = max(0, dailySignalCap - usedToday)
        let signalXP = min(remainingToday, baseXP(for: signals))

        let priorWeekRecords = priorRecords.filter { $0.localWeek == weekKey }
        let priorSupportDays = Set(priorWeekRecords.filter { $0.signalXP > 0 }.map(\.localDay))
        let supportDaysAfterCurrent = signalXP > 0
            ? priorSupportDays.union([dayKey])
            : priorSupportDays
        let weeklyAlreadyAwarded = priorWeekRecords.contains { $0.weeklyBonusXP > 0 }
        let weeklyBonusXP = !weeklyAlreadyAwarded
            && priorSupportDays.count < 4
            && supportDaysAfterCurrent.count >= 4
            ? weeklyConsistencyBonus
            : 0

        return Award(
            signals: signals,
            signalXP: signalXP,
            weeklyBonusXP: weeklyBonusXP,
            localDay: dayKey,
            localWeek: weekKey
        )
    }

    static func record(
        award: Award,
        performanceLog: PerformanceLog,
        database: any DatabaseServiceProtocol
    ) async {
        guard award.totalXP > 0 else { return }
        let record = VitalityRewardRecord(
            id: performanceLog.id,
            userId: performanceLog.userId,
            sourceLogId: performanceLog.id,
            awardedAt: performanceLog.completedAt,
            localDay: award.localDay,
            localWeek: award.localWeek,
            signals: award.signals,
            signalXP: award.signalXP,
            weeklyBonusXP: award.weeklyBonusXP
        )
        do {
            try await database.create(
                record,
                collection: "vitality_reward_records",
                documentId: record.id
            )
        } catch {
            LoggingService.shared.log(
                "Vitality reward record write failed: \(error)",
                level: .warning,
                context: ["sourceLogId": performanceLog.id]
            )
        }
    }

    static func signals(for performanceLog: PerformanceLog) -> [VitalityCheckInSignal] {
        let text = searchableText(for: performanceLog)
        var signals: Set<VitalityCheckInSignal> = []

        if text.contains(VitalityCheckInSignal.restDay.token) {
            signals.insert(.restDay)
        }
        if text.contains(VitalityCheckInSignal.deload.token)
            || text.contains("deload") {
            signals.insert(.deload)
        }
        if text.contains(VitalityCheckInSignal.easyWalkOrMobility.token)
            || text.contains("recovery check-in")
            || text.contains("active recovery") {
            signals.insert(.easyWalkOrMobility)
        }
        if text.contains(VitalityCheckInSignal.sleep.token) {
            signals.insert(.sleep)
        }
        if text.contains(VitalityCheckInSignal.hydrationProtein.token) {
            signals.insert(.hydrationProtein)
        }

        return VitalityCheckInSignal.allCases.filter { signals.contains($0) }
    }

    private static func baseXP(for signals: [VitalityCheckInSignal]) -> Double {
        signals.reduce(0) { $0 + $1.baseXP }
    }

    private static func searchableText(for performanceLog: PerformanceLog) -> String {
        var parts: [String] = [
            performanceLog.title,
            performanceLog.notes ?? ""
        ]
        for block in performanceLog.blocks {
            parts.append(block.title)
            parts.append(block.notes ?? "")
            for exercise in block.exercises {
                parts.append(exercise.name)
                parts.append(exercise.plannedTarget)
                parts.append(exercise.notes ?? "")
            }
        }
        return parts.joined(separator: " ").lowercased()
    }

    static func localDayKey(for date: Date, calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
    }

    static func localWeekKey(for date: Date, calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return String(format: "%04d-W%02d", comps.yearForWeekOfYear ?? 0, comps.weekOfYear ?? 0)
    }
}
