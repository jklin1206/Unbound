import SwiftUI

enum ExerciseLibrarySort: String, CaseIterable, Identifiable {
    case recommended
    case bestRank
    case mostAP
    case recent
    case name

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .recommended: return "Best"
        case .bestRank: return "Rank"
        case .mostAP: return "AP"
        case .recent: return "Recent"
        case .name: return "A-Z"
        }
    }
}

enum ExerciseLibraryStatusFilter: String, CaseIterable, Identifiable {
    case all
    case ranked
    case hasAP
    case hasWeight
    case available
    case substitute
    case avoid

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return "All"
        case .ranked: return "Ranked"
        case .hasAP: return "Has AP"
        case .hasWeight: return "Loaded"
        case .available: return "Yes"
        case .substitute: return "Sub"
        case .avoid: return "Avoid"
        }
    }
}

struct ExerciseLibraryDisplayRow: Identifiable {
    let item: ExerciseLibraryItem
    let preferenceStatus: ExercisePreferenceStatus?
    let movementProgress: MovementProgressState?
    let workingWeight: WorkingWeight?
    var bodyweightKg: Double?
    var biologicalSex: BiologicalSex?

    var id: String { item.id }

    var tier: SkillTier? {
        movementProgress?.provenTier
    }

    var totalAP: Double {
        movementProgress?.totalAP ?? 0
    }

    var hasProgress: Bool {
        totalAP > 0 || tier != nil
    }

    var latestActivityAt: Date? {
        let dates = [
            movementProgress?.lastLoggedAt,
            movementProgress?.updatedAt,
            workingWeight?.updatedAt
        ].compactMap { $0 }
        return dates.max()
    }

    var bestMetricSummary: String? {
        let unit = WeightPlatePolicy.currentUnit
        if let estimated = movementProgress?.bestEstimatedOneRepMaxKg {
            return "Est. 1RM \(WeightPlatePolicy.formatLoggedWeight(estimated, unit: unit))\(unit.shortLabel)"
        }
        if let load = movementProgress?.bestLoadKg {
            if let reps = movementProgress?.bestReps {
                return "\(WeightPlatePolicy.formatLoggedWeight(load, unit: unit))\(unit.shortLabel) x \(reps)"
            }
            return "\(WeightPlatePolicy.formatLoggedWeight(load, unit: unit))\(unit.shortLabel)"
        }
        if let reps = movementProgress?.bestReps {
            return "\(reps) reps"
        }
        if let seconds = movementProgress?.bestHoldSeconds {
            return "\(seconds)s hold"
        }
        if let seconds = movementProgress?.bestDurationSeconds {
            return "\(seconds / 60)m \(seconds % 60)s"
        }
        if let meters = movementProgress?.bestDistanceMeters {
            return "\(meters)m"
        }
        if let calories = movementProgress?.bestCalories {
            return "\(calories) cal"
        }
        if let workingWeight {
            return "\(WeightPlatePolicy.formatLoggedWeight(workingWeight.weightKg, unit: unit))\(unit.shortLabel) x \(workingWeight.lastReps)"
        }
        return nil
    }

    var nextBenchmarkSummary: String? {
        RankBenchmarkSummary.nextBenchmark(
            for: item,
            currentTier: movementProgress?.provenTier,
            bodyweightKg: bodyweightKg,
            sex: biologicalSex
        )
    }
}

enum RankBenchmarkSummary {
    static func nextBenchmark(
        for item: ExerciseLibraryItem,
        currentTier: SkillTier?,
        bodyweightKg: Double? = nil,
        sex: BiologicalSex? = nil
    ) -> String? {
        guard let targetTier = targetTier(after: currentTier) else { return nil }

        // Skill-tree movements keep their bespoke per-tier criteria.
        if let criteria = skillCriteriaTable(for: item),
           let criterion = criteria[targetTier] {
            return "\(targetTier.displayName): \(criterionSummary(criterion))"
        }

        // Loaded movements: next-tier benchmark from the bodyweight-relative
        // StrengthStandards. Compounds/accessories use a ratio; weighted pullup
        // uses an added-kg anchor.
        let key = MovementCatalog.normalized(item.canonicalName)
        if StrengthStandards.isWeightedPullup(exerciseKey: key),
           let added = StrengthStandards.weightedPullupAdded(tier: targetTier) {
            return "\(targetTier.displayName): +\(Int(added.rounded())) kg added"
        }
        if let ratio = StrengthStandards.ratio(exerciseKey: key, tier: targetTier, sex: sex) {
            let ratioText = String(format: "%.2g", ratio)
            if let bodyweightKg, bodyweightKg > 0 {
                let kg = Int((ratio * bodyweightKg).rounded())
                return "\(targetTier.displayName): \(ratioText)x bodyweight (≈ \(kg) kg)"
            }
            return "\(targetTier.displayName): \(ratioText)x bodyweight"
        }
        return nil
    }

    static func nextBenchmark(for node: SkillNode, currentTier: SkillTier?) -> String? {
        guard let targetTier = targetTier(after: currentTier),
              let criterion = node.tierCriteria[targetTier]
        else { return nil }

        return "\(targetTier.displayName): \(criterionSummary(criterion))"
    }

    private static func targetTier(after currentTier: SkillTier?) -> SkillTier? {
        guard let currentTier else { return .initiate }
        return SkillTier(rawValue: currentTier.rawValue + 1)
    }

    /// Per-tier criteria for skill-tree movements only. Loaded lifts now derive
    /// their benchmark from StrengthStandards (see nextBenchmark).
    private static func skillCriteriaTable(for item: ExerciseLibraryItem) -> [SkillTier: TierCriterion]? {
        guard let definition = MovementCatalog.definition(for: item.id),
              let skillId = definition.skillId,
              let node = SkillGraph.shared.node(id: skillId),
              !node.tierCriteria.isEmpty
        else { return nil }
        return node.tierCriteria
    }

    private static func criterionSummary(_ criterion: TierCriterion) -> String {
        switch criterion {
        case .reps(let count, let exerciseName):
            return "\(count) \(displayExerciseName(exerciseName))"
        case .seconds(let seconds):
            return "\(seconds)-second hold"
        case .weightKg(let weight):
            return "\(Int(weight.rounded())) kg working set"
        case .exerciseWeightKg(let weight, let exerciseName):
            return "\(Int(weight.rounded())) kg \(displayExerciseName(exerciseName))"
        case .bodyweightRatio(let ratio):
            return "\(String(format: "%.2g", ratio))x bodyweight"
        case .exerciseBodyweightRatio(let ratio, let exerciseName):
            return "\(String(format: "%.2g", ratio))x bodyweight \(displayExerciseName(exerciseName))"
        case .variant(let name):
            return "Log \(displayExerciseName(name))"
        case .compound(let criteria):
            return criteria.map(criterionSummary).joined(separator: " + ")
        }
    }

    private static func displayExerciseName(_ name: String) -> String {
        name
            .split(separator: " ")
            .map { part in
                part
                    .split(separator: "-")
                    .map { $0.prefix(1).uppercased() + $0.dropFirst() }
                    .joined(separator: "-")
            }
            .joined(separator: " ")
    }
}

@MainActor
final class ExerciseLibraryViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var selectedCategory: ExerciseCategory?
    @Published var selectedStatusFilter: ExerciseLibraryStatusFilter = .all
    @Published var selectedSort: ExerciseLibrarySort = .recommended
    @Published var preferences: [String: ExercisePreference] = [:]
    @Published var movementProgress: [String: MovementProgressState] = [:]
    @Published var workingWeights: [String: WorkingWeight] = [:]
    @Published var bodyweightKg: Double?
    @Published var biologicalSex: BiologicalSex?
    @Published var state: LoadingState<Void> = .idle

    private let services: ServiceContainer
    private let catalogItems = ExerciseLibrary.all

    init(services: ServiceContainer) {
        self.services = services
    }

    var filteredGroups: [(String, [ExerciseLibraryDisplayRow])] {
        let rows = sortedRows(filteredRows)
        if selectedSort != .recommended || !searchText.isEmpty || selectedStatusFilter != .all {
            return rows.isEmpty ? [] : [("Results", rows)]
        }
        let rowsBySlot = Dictionary(grouping: rows, by: { $0.item.movementSlot })
        return MovementSlot.allCases
            .sorted { ExerciseLibrary.slotOrder($0) < ExerciseLibrary.slotOrder($1) }
            .compactMap { slot in
                guard let rows = rowsBySlot[slot], !rows.isEmpty else { return nil }
                return (slot.displayName, rows)
            }
    }

    var resultCount: Int {
        filteredRows.count
    }

    var rankedCount: Int {
        rows.filter { $0.item.isRankable }.count
    }

    var withAPCount: Int {
        rows.filter { $0.totalAP > 0 }.count
    }

    var availableCount: Int { uniquePreferences.filter { $0.status == .available }.count }
    var substituteCount: Int { uniquePreferences.filter { $0.status == .substitute }.count }
    var avoidCount: Int { uniquePreferences.filter { $0.status == .avoid }.count }

    var topProgressRows: [ExerciseLibraryDisplayRow] {
        sortedRows(rows.filter { $0.totalAP > 0 || $0.workingWeight != nil || $0.tier != nil })
            .prefix(6)
            .map { $0 }
    }

    private var rows: [ExerciseLibraryDisplayRow] {
        catalogItems.map { item in
            ExerciseLibraryDisplayRow(
                item: item,
                preferenceStatus: statusFor(item),
                movementProgress: movementProgress[item.rankStandardMovementId],
                workingWeight: workingWeight(for: item),
                bodyweightKg: bodyweightKg,
                biologicalSex: biologicalSex
            )
        }
    }

    private var filteredRows: [ExerciseLibraryDisplayRow] {
        rows.filter { row in
            let item = row.item
            let searchSource = [
                item.name,
                item.canonicalName,
                item.metadataSummary,
                item.equipmentSummary,
                row.bestMetricSummary ?? "",
                row.tier?.displayName ?? ""
            ].joined(separator: " ")
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesSearch = query.isEmpty
                || searchSource.localizedCaseInsensitiveContains(query)
                || Self.searchKey(searchSource).contains(Self.searchKey(query))
            let matchesCategory = selectedCategory == nil || item.category == selectedCategory
            let matchesStatus: Bool
            switch selectedStatusFilter {
            case .all: matchesStatus = true
            case .ranked: matchesStatus = item.isRankable
            case .hasAP: matchesStatus = row.totalAP > 0
            case .hasWeight: matchesStatus = row.workingWeight != nil
            case .available: matchesStatus = row.preferenceStatus == .available
            case .substitute: matchesStatus = row.preferenceStatus == .substitute
            case .avoid: matchesStatus = row.preferenceStatus == .avoid
            }
            return matchesSearch && matchesCategory && matchesStatus
        }
    }

    private static func searchKey(_ value: String) -> String {
        value
            .lowercased()
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
    }

    private var uniquePreferences: [ExercisePreference] {
        Dictionary(grouping: preferences.values, by: \.id).compactMap { $0.value.first }
    }

    func loadPreferences() async {
        guard let userId = services.auth.currentUserId else { return }
        state = .loading
        do {
            async let prefsLoad = services.exercisePreference.fetchPreferences(userId: userId)
            async let movementLoad: [MovementProgressState] = services.database.query(
                collection: "movement_progress",
                field: "userId",
                isEqualTo: userId,
                orderBy: nil,
                descending: true,
                limit: nil
            )
            async let weightsLoad = services.workingWeight.fetchWeights(userId: userId)
            async let profileLoad: UserProfile = services.database.read(collection: "users", documentId: userId)

            let prefs = try await prefsLoad
            let progressStates = (try? await movementLoad) ?? []
            let weights = (try? await weightsLoad) ?? []
            if let profile = try? await profileLoad {
                bodyweightKg = profile.weightKg
                biologicalSex = profile.biologicalSex
            }
            preferences = ExercisePreferenceLookup.index(prefs)
            movementProgress = Dictionary(uniqueKeysWithValues: progressStates.map { ($0.rankStandardMovementId, $0) })
            workingWeights = weights.reduce(into: [:]) { result, weight in
                for key in ExercisePreferenceLookup.keys(
                    for: weight.exerciseName,
                    displayName: weight.exerciseName,
                    movementId: nil
                ) {
                    result[key] = weight
                }
            }
            state = .loaded(())
        } catch {
            state = .error(.databaseReadFailed(underlying: error))
        }
        services.analytics.track(.exerciseLibraryViewed)
    }

    func setPreference(for item: ExerciseLibraryItem, status: ExercisePreferenceStatus?) async {
        guard let userId = services.auth.currentUserId else { return }
        let key = item.preferenceKey

        if let status {
            let pref = ExercisePreference(
                id: "\(userId):\(key)",
                userId: userId,
                exerciseName: key,
                displayName: item.name,
                status: status,
                muscleGroups: item.muscleGroups,
                substitutePreference: status == .substitute
                    ? MovementCatalog.catalogAlternatives(to: item.name).first?.name
                    : nil,
                notes: nil,
                updatedAt: Date()
            )
            try? await services.exercisePreference.setPreference(pref)
            for lookupKey in item.preferenceLookupKeys {
                preferences[lookupKey] = pref
            }
            services.analytics.track(.exercisePreferenceSet(exerciseName: item.name, status: status.rawValue))
        } else {
            let ids = Set(
                item.preferenceLookupKeys.compactMap { preferences[$0]?.id } + ["\(userId):\(item.preferenceKey)"]
            )
            for id in ids {
                try? await services.exercisePreference.deletePreference(id: id)
            }
            for lookupKey in item.preferenceLookupKeys {
                preferences.removeValue(forKey: lookupKey)
            }
        }
    }

    func statusFor(_ item: ExerciseLibraryItem) -> ExercisePreferenceStatus? {
        preferenceFor(item)?.status
    }

    private func sortedRows(_ rows: [ExerciseLibraryDisplayRow]) -> [ExerciseLibraryDisplayRow] {
        rows.sorted { lhs, rhs in
            switch selectedSort {
            case .recommended:
                return recommendedSort(lhs, rhs)
            case .bestRank:
                if (lhs.tier?.rawValue ?? -1) != (rhs.tier?.rawValue ?? -1) {
                    return (lhs.tier?.rawValue ?? -1) > (rhs.tier?.rawValue ?? -1)
                }
                return lhs.totalAP > rhs.totalAP
            case .mostAP:
                if lhs.totalAP != rhs.totalAP { return lhs.totalAP > rhs.totalAP }
                return lhs.item.name < rhs.item.name
            case .recent:
                if lhs.latestActivityAt != rhs.latestActivityAt {
                    return (lhs.latestActivityAt ?? .distantPast) > (rhs.latestActivityAt ?? .distantPast)
                }
                return lhs.item.name < rhs.item.name
            case .name:
                return lhs.item.name < rhs.item.name
            }
        }
    }

    private func recommendedSort(_ lhs: ExerciseLibraryDisplayRow, _ rhs: ExerciseLibraryDisplayRow) -> Bool {
        let lhsScore = sortScore(lhs)
        let rhsScore = sortScore(rhs)
        if lhsScore != rhsScore { return lhsScore > rhsScore }
        if lhs.item.movementSlot != rhs.item.movementSlot {
            return ExerciseLibrary.slotOrder(lhs.item.movementSlot) < ExerciseLibrary.slotOrder(rhs.item.movementSlot)
        }
        return lhs.item.name < rhs.item.name
    }

    private func sortScore(_ row: ExerciseLibraryDisplayRow) -> Double {
        let tierScore = Double(row.tier?.rawValue ?? 0) * 10_000
        let apScore = min(row.totalAP, 9_999)
        let weightScore = row.workingWeight == nil ? 0.0 : 500.0
        let rankableScore = row.item.isRankable ? 100.0 : 0.0
        let preferenceScore: Double
        switch row.preferenceStatus {
        case .available: preferenceScore = 75
        case .substitute: preferenceScore = 25
        case .avoid: preferenceScore = -1_000
        case nil: preferenceScore = 0
        }
        return tierScore + apScore + weightScore + rankableScore + preferenceScore
    }

    private func preferenceFor(_ item: ExerciseLibraryItem) -> ExercisePreference? {
        item.preferenceLookupKeys.compactMap { preferences[$0] }.first
    }

    private func workingWeight(for item: ExerciseLibraryItem) -> WorkingWeight? {
        item.preferenceLookupKeys.compactMap { workingWeights[$0] }.first
    }
}
