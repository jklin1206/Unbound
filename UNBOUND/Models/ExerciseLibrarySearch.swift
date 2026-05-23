import Foundation

struct ExerciseLibrarySearchSignals: Equatable {
    var isRecent: Bool
    var preferenceStatus: ExercisePreferenceStatus?

    var badges: [String] {
        var values: [String] = []
        if isRecent {
            values.append("Recent")
        }
        switch preferenceStatus {
        case .available:
            values.append("Favorite")
        case .substitute:
            values.append("Substitute")
        case .avoid:
            values.append("Avoid")
        case nil:
            break
        }
        return values
    }
}

struct ExerciseLibraryCompatibilityState: Equatable {
    enum Level: Equatable {
        case compatible
        case unavailable
        case avoided
    }

    let level: Level
    let title: String
    let detail: String

    var isSelectable: Bool {
        switch level {
        case .compatible:
            return true
        case .unavailable, .avoided:
            return false
        }
    }

    var badgeTitle: String {
        switch level {
        case .compatible:
            return "Fits"
        case .unavailable:
            return "Unavailable"
        case .avoided:
            return "Avoid"
        }
    }
}

enum ExerciseLibraryContextFilter: String, CaseIterable, Hashable {
    case best
    case recent
    case favorites
    case available

    var displayName: String {
        switch self {
        case .best: return "Best"
        case .recent: return "Recent"
        case .favorites: return "Favorites"
        case .available: return "Available"
        }
    }
}

enum ExerciseLibrarySearch {
    static func availableSlots(in alternatives: [CatalogExercise]) -> [MovementSlot] {
        let slots = alternatives.compactMap { alt in
            MovementCatalog.canonicalExercise(named: alt.name)?.movementSlot
        }
        var seen = Set<MovementSlot>()
        return slots.filter { seen.insert($0).inserted }
    }

    static func filteredAlternatives(
        _ alternatives: [CatalogExercise],
        searchText: String,
        selectedSlot: MovementSlot? = nil,
        contextFilter: ExerciseLibraryContextFilter = .best,
        recentExerciseNames: Set<String> = [],
        preferenceStatusesByKey: [String: ExercisePreferenceStatus] = [:],
        availableEquipment: [Equipment]? = nil
    ) -> [CatalogExercise] {
        let query = MovementCatalog.normalized(searchText.trimmingCharacters(in: .whitespacesAndNewlines))
        return alternatives
            .filter { matchesSelectedSlot($0, selectedSlot: selectedSlot) }
            .filter {
                matchesContextFilter(
                    $0,
                    contextFilter: contextFilter,
                    recentExerciseNames: recentExerciseNames,
                    preferenceStatusesByKey: preferenceStatusesByKey
                )
            }
            .filter { matchesSearch($0, query: query) }
            .sorted {
                let lhsScore = searchScore(
                    $0,
                    query: query,
                    selectedSlot: selectedSlot,
                    recentExerciseNames: recentExerciseNames,
                    preferenceStatusesByKey: preferenceStatusesByKey,
                    availableEquipment: availableEquipment
                )
                let rhsScore = searchScore(
                    $1,
                    query: query,
                    selectedSlot: selectedSlot,
                    recentExerciseNames: recentExerciseNames,
                    preferenceStatusesByKey: preferenceStatusesByKey,
                    availableEquipment: availableEquipment
                )
                if lhsScore != rhsScore { return lhsScore > rhsScore }
                return $0.displayName < $1.displayName
            }
    }

    static func compatibilityState(
        for alt: CatalogExercise,
        preferredSlot: MovementSlot? = nil,
        availableEquipment: [Equipment]? = nil,
        preferenceStatusesByKey: [String: ExercisePreferenceStatus] = [:]
    ) -> ExerciseLibraryCompatibilityState {
        if preferenceStatus(for: alt, preferenceStatusesByKey: preferenceStatusesByKey) == .avoid {
            return ExerciseLibraryCompatibilityState(
                level: .avoided,
                title: "Avoid list",
                detail: "This exercise is saved as avoid. Remove the preference before adding it back."
            )
        }

        guard let definition = MovementCatalog.canonicalExercise(named: alt.name) else {
            return ExerciseLibraryCompatibilityState(
                level: .compatible,
                title: "Custom-compatible",
                detail: "No catalog limits found."
            )
        }

        if let preferredSlot, definition.movementSlot != preferredSlot {
            return ExerciseLibraryCompatibilityState(
                level: .unavailable,
                title: "Different pattern",
                detail: "This is \(definition.movementSlot.displayName), not \(preferredSlot.displayName)."
            )
        }

        if let availableEquipment {
            let style: TrainingStyle = availableEquipment == [.bodyweight] ? .bodyweight : .hybrid
            if !MovementCatalog.isProgramCompatible(definition, style: style, userEquipment: availableEquipment) {
                let required = ExerciseLibrary.equipmentLabels(for: definition).prefix(3).joined(separator: " · ")
                let available = availableEquipment.map(\.displayName).prefix(3).joined(separator: " · ")
                return ExerciseLibraryCompatibilityState(
                    level: .unavailable,
                    title: "Equipment mismatch",
                    detail: "\(required) required; current setup is \(available.isEmpty ? "not set" : available)."
                )
            }
        }

        return ExerciseLibraryCompatibilityState(
            level: .compatible,
            title: "Program fit",
            detail: compatibilityDetail(for: definition)
        )
    }

    static func signals(
        for alt: CatalogExercise,
        recentExerciseNames: Set<String> = [],
        preferenceStatusesByKey: [String: ExercisePreferenceStatus] = [:]
    ) -> ExerciseLibrarySearchSignals {
        ExerciseLibrarySearchSignals(
            isRecent: isRecent(alt, recentExerciseNames: recentExerciseNames),
            preferenceStatus: preferenceStatus(for: alt, preferenceStatusesByKey: preferenceStatusesByKey)
        )
    }

    static func matchesSearch(_ alt: CatalogExercise, query: String) -> Bool {
        guard !query.isEmpty else { return true }
        return searchTerms(for: alt)
            .map { MovementCatalog.normalized($0) }
            .joined(separator: " ")
            .contains(query)
    }

    private static func matchesSelectedSlot(_ alt: CatalogExercise, selectedSlot: MovementSlot?) -> Bool {
        guard let selectedSlot else { return true }
        return MovementCatalog.canonicalExercise(named: alt.name)?.movementSlot == selectedSlot
    }

    private static func matchesContextFilter(
        _ alt: CatalogExercise,
        contextFilter: ExerciseLibraryContextFilter,
        recentExerciseNames: Set<String>,
        preferenceStatusesByKey: [String: ExercisePreferenceStatus]
    ) -> Bool {
        switch contextFilter {
        case .best:
            return true
        case .recent:
            return isRecent(alt, recentExerciseNames: recentExerciseNames)
        case .favorites, .available:
            return preferenceStatus(for: alt, preferenceStatusesByKey: preferenceStatusesByKey) == .available
        }
    }

    private static func searchScore(
        _ alt: CatalogExercise,
        query: String,
        selectedSlot: MovementSlot?,
        recentExerciseNames: Set<String>,
        preferenceStatusesByKey: [String: ExercisePreferenceStatus],
        availableEquipment: [Equipment]?
    ) -> Int {
        let definition = MovementCatalog.canonicalExercise(named: alt.name)
        let compatibility = compatibilityState(
            for: alt,
            preferredSlot: selectedSlot,
            availableEquipment: availableEquipment,
            preferenceStatusesByKey: preferenceStatusesByKey
        )
        var score = 0
        let display = MovementCatalog.normalized(alt.displayName)
        let canonical = MovementCatalog.normalized(alt.name)

        if !query.isEmpty {
            if display == query || canonical == query { score += 60 }
            if display.hasPrefix(query) || canonical.hasPrefix(query) { score += 35 }
            if definition?.aliases.map(MovementCatalog.normalized).contains(where: { $0.hasPrefix(query) }) == true {
                score += 20
            }
        }

        if selectedSlot == nil { score += 8 }
        if isRecent(alt, recentExerciseNames: recentExerciseNames) { score += 28 }
        switch preferenceStatus(for: alt, preferenceStatusesByKey: preferenceStatusesByKey) {
        case .available:
            score += 40
        case .substitute:
            score -= 6
        case .avoid:
            score -= 80
        case nil:
            break
        }
        switch compatibility.level {
        case .compatible:
            score += 18
        case .unavailable:
            score -= 120
        case .avoided:
            score -= 160
        }
        if definition?.equipment.contains(.bodyweight) == true { score += 2 }
        score -= definition?.difficulty.sortPenalty ?? 0
        return score
    }

    private static func isRecent(
        _ alt: CatalogExercise,
        recentExerciseNames: Set<String>
    ) -> Bool {
        guard !recentExerciseNames.isEmpty else { return false }
        return ExercisePreferenceLookup.keys(for: alt).contains { recentExerciseNames.contains($0) }
    }

    private static func preferenceStatus(
        for alt: CatalogExercise,
        preferenceStatusesByKey: [String: ExercisePreferenceStatus]
    ) -> ExercisePreferenceStatus? {
        ExercisePreferenceLookup.keys(for: alt).compactMap { preferenceStatusesByKey[$0] }.first
    }

    private static func searchTerms(for alt: CatalogExercise) -> [String] {
        var terms: [String] = [
            alt.name,
            alt.displayName,
            alt.muscleGroups.map(\.displayName).joined(separator: " ")
        ]

        if let definition = MovementCatalog.canonicalExercise(named: alt.name) {
            terms.append(definition.aliases.joined(separator: " "))
            terms.append(ExerciseLibrary.equipmentLabels(for: definition).joined(separator: " "))
            terms.append(definition.movementSlot.displayName)
            terms.append(definition.rankTemplate.displayName)
            terms.append(definition.loggerMode.displayName)
        }

        return terms
    }

    private static func compatibilityDetail(for definition: MovementDefinition) -> String {
        let equipment = ExerciseLibrary.equipmentLabels(for: definition).prefix(2).joined(separator: " · ")
        return [
            definition.movementSlot.displayName,
            definition.rankTemplate.displayName,
            equipment
        ]
        .filter { !$0.isEmpty }
        .joined(separator: " · ")
    }
}

private extension MovementDifficulty {
    var sortPenalty: Int {
        switch self {
        case .beginner: return 0
        case .intermediate: return 1
        case .advanced: return 2
        case .elite: return 3
        }
    }
}
