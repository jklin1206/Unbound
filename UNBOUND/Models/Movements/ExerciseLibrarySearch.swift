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

struct ExerciseLibrarySearchResult: Identifiable, Equatable {
    let exercise: CatalogExercise
    let definition: MovementDefinition?
    let signals: ExerciseLibrarySearchSignals
    let compatibility: ExerciseLibraryCompatibilityState
    let score: Int

    var id: String { exercise.id }
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

    /// Body parts present in this candidate set, in a fixed anatomical order so
    /// the chips never reshuffle between two different exercise lists.
    ///
    /// This is what the picker filters by. It used to offer `MovementSlot`
    /// ("Horizontal Push", "Hinge / Posterior") — programming vocabulary that
    /// answers "what pattern is this" when the person at the rack is asking
    /// "what am I training today". It was also nearly inert in swap mode, where
    /// every candidate is same-slot by construction, so the chips filtered nothing.
    static let muscleFilterOrder: [MuscleGroup] = [
        .chest, .back, .lats, .traps, .shoulders, .biceps, .triceps, .forearms,
        .core, .quads, .hamstrings, .glutes, .calves, .neck, .arms, .legs
    ]

    static func availableMuscleGroups(in alternatives: [CatalogExercise]) -> [MuscleGroup] {
        let present = Set(alternatives.flatMap(\.muscleGroups))
        return muscleFilterOrder.filter { present.contains($0) }
    }

    static func filteredAlternatives(
        _ alternatives: [CatalogExercise],
        searchText: String,
        selectedSlot: MovementSlot? = nil,
        selectedMuscle: MuscleGroup? = nil,
        contextFilter: ExerciseLibraryContextFilter = .best,
        recentExerciseNames: Set<String> = [],
        preferenceStatusesByKey: [String: ExercisePreferenceStatus] = [:],
        availableEquipment: [Equipment]? = nil
    ) -> [CatalogExercise] {
        filteredResults(
            alternatives,
            searchText: searchText,
            selectedSlot: selectedSlot,
            selectedMuscle: selectedMuscle,
            contextFilter: contextFilter,
            recentExerciseNames: recentExerciseNames,
            preferenceStatusesByKey: preferenceStatusesByKey,
            availableEquipment: availableEquipment
        )
        .map(\.exercise)
    }

    static func filteredResults(
        _ alternatives: [CatalogExercise],
        searchText: String,
        selectedSlot: MovementSlot? = nil,
        selectedMuscle: MuscleGroup? = nil,
        contextFilter: ExerciseLibraryContextFilter = .best,
        recentExerciseNames: Set<String> = [],
        preferenceStatusesByKey: [String: ExercisePreferenceStatus] = [:],
        availableEquipment: [Equipment]? = nil
    ) -> [ExerciseLibrarySearchResult] {
        let query = MovementCatalog.normalized(searchText.trimmingCharacters(in: .whitespacesAndNewlines))
        return alternatives
            .compactMap { alt -> ExerciseLibrarySearchResult? in
                let definition = MovementCatalog.canonicalExercise(named: alt.name)
                guard matchesSelectedSlot(definition, selectedSlot: selectedSlot) else { return nil }
                guard matchesSelectedMuscle(alt, selectedMuscle: selectedMuscle) else { return nil }

                let signals = signals(
                    for: alt,
                    recentExerciseNames: recentExerciseNames,
                    preferenceStatusesByKey: preferenceStatusesByKey
                )
                guard matchesContextFilter(
                    signals,
                    contextFilter: contextFilter
                ) else { return nil }

                guard matchesSearch(alt, definition: definition, query: query) else { return nil }

                let compatibility = compatibilityState(
                    for: alt,
                    definition: definition,
                    preferredSlot: selectedSlot,
                    availableEquipment: availableEquipment,
                    preferenceStatusesByKey: preferenceStatusesByKey
                )
                let score = searchScore(
                    alt,
                    definition: definition,
                    compatibility: compatibility,
                    signals: signals,
                    query: query,
                    selectedSlot: selectedSlot
                )

                return ExerciseLibrarySearchResult(
                    exercise: alt,
                    definition: definition,
                    signals: signals,
                    compatibility: compatibility,
                    score: score
                )
            }
            .sorted {
                if $0.score != $1.score { return $0.score > $1.score }
                return $0.exercise.displayName < $1.exercise.displayName
            }
    }
    static func compatibilityState(
        for alt: CatalogExercise,
        preferredSlot: MovementSlot? = nil,
        availableEquipment: [Equipment]? = nil,
        preferenceStatusesByKey: [String: ExercisePreferenceStatus] = [:]
    ) -> ExerciseLibraryCompatibilityState {
        compatibilityState(
            for: alt,
            definition: MovementCatalog.canonicalExercise(named: alt.name),
            preferredSlot: preferredSlot,
            availableEquipment: availableEquipment,
            preferenceStatusesByKey: preferenceStatusesByKey
        )
    }

    private static func compatibilityState(
        for alt: CatalogExercise,
        definition: MovementDefinition?,
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

        guard let definition else {
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
        matchesSearch(alt, definition: MovementCatalog.canonicalExercise(named: alt.name), query: query)
    }

    /// Every word of the query must appear somewhere in the movement's terms —
    /// they do not have to be adjacent. A plain `contains(query)` on the joined
    /// terms only ever matched a *contiguous* run, so "bicep curl" found nothing
    /// (the gym word "bicep" and the name "curl" live in different terms) and
    /// "curl dumbbell" failed purely on word order.
    private static func matchesSearch(
        _ alt: CatalogExercise,
        definition: MovementDefinition?,
        query: String
    ) -> Bool {
        guard !query.isEmpty else { return true }
        let haystack = searchTerms(for: alt, definition: definition)
            .map { MovementCatalog.normalized($0) }
            .joined(separator: " ")
        return query.split(separator: " ").allSatisfy { haystack.contains($0) }
    }

    private static func matchesSelectedSlot(_ alt: CatalogExercise, selectedSlot: MovementSlot?) -> Bool {
        guard let selectedSlot else { return true }
        return MovementCatalog.canonicalExercise(named: alt.name)?.movementSlot == selectedSlot
    }

    private static func matchesSelectedSlot(_ definition: MovementDefinition?, selectedSlot: MovementSlot?) -> Bool {
        guard let selectedSlot else { return true }
        return definition?.movementSlot == selectedSlot
    }

    private static func matchesSelectedMuscle(_ alt: CatalogExercise, selectedMuscle: MuscleGroup?) -> Bool {
        guard let selectedMuscle else { return true }
        return alt.muscleGroups.contains(selectedMuscle)
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

    private static func matchesContextFilter(
        _ signals: ExerciseLibrarySearchSignals,
        contextFilter: ExerciseLibraryContextFilter
    ) -> Bool {
        switch contextFilter {
        case .best:
            return true
        case .recent:
            return signals.isRecent
        case .favorites, .available:
            return signals.preferenceStatus == .available
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

    private static func searchScore(
        _ alt: CatalogExercise,
        definition: MovementDefinition?,
        compatibility: ExerciseLibraryCompatibilityState,
        signals: ExerciseLibrarySearchSignals,
        query: String,
        selectedSlot: MovementSlot?
    ) -> Int {
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
        if signals.isRecent { score += 28 }
        switch signals.preferenceStatus {
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
        searchTerms(for: alt, definition: MovementCatalog.canonicalExercise(named: alt.name))
    }

    private static func searchTerms(
        for alt: CatalogExercise,
        definition: MovementDefinition?
    ) -> [String] {
        var terms: [String] = [
            alt.name,
            alt.displayName,
            alt.muscleGroups.map(\.displayName).joined(separator: " "),
            gymVocabulary(for: alt).joined(separator: " ")
        ]

        if let definition {
            terms.append(definition.aliases.joined(separator: " "))
            terms.append(ExerciseLibrary.equipmentLabels(for: definition).joined(separator: " "))
            terms.append(definition.movementSlot.displayName)
            terms.append(definition.rankTemplate.displayName)
            terms.append(definition.loggerMode.displayName)
        }

        return terms
    }

    /// How lifters actually type. The catalog's own vocabulary is anatomical
    /// ("Arms", "Dumbbell Curl"), so without this a search for the single most
    /// common gym phrase — "bicep curl" — returns nothing at all. Keyed off the
    /// movement name rather than its muscle group, so a Tricep Pushdown never
    /// answers to "bicep" just because both are filed under Arms.
    ///
    /// Search-only. Deliberately NOT added to `MovementDefinition.aliases`, which
    /// is the logging-resolution index: a shared "bicep curl" alias there would
    /// make a logged "bicep curl" resolve to an arbitrary one of a dozen curls.
    static func gymVocabulary(for alt: CatalogExercise) -> [String] {
        let name = MovementCatalog.normalized("\(alt.displayName) \(alt.name)")
        var terms: [String] = []

        let isLimbCurl = name.contains("leg curl") || name.contains("nordic")
        if name.contains("wrist curl") || name.contains("wrist roller") {
            terms += ["forearm", "forearms", "grip", "wrist"]
        } else if name.contains("curl"), !isLimbCurl {
            terms += ["bicep", "biceps", "arm", "arms"]
        }

        if name.contains("tricep") || name.contains("pushdown") || name.contains("skull crusher")
            || name.contains("kickback") || name.contains("dip") || name.contains("close grip") {
            terms += ["tricep", "triceps", "arm", "arms"]
        }
        if name.contains("shrug") { terms += ["trap", "traps", "trapezius"] }
        if name.contains("lateral raise") || name.contains("front raise") || name.contains("rear delt")
            || name.contains("face pull") || name.contains("overhead press") || name.contains("shoulder press") {
            terms += ["delt", "delts", "deltoid", "shoulder"]
        }
        if name.contains("fly") || name.contains("bench press") || name.contains("chest press") || name.contains("pec") {
            terms += ["pec", "pecs", "chest"]
        }
        if name.contains("pulldown") || name.contains("pullup") || name.contains("pull up") || name.contains("row") {
            terms += ["lat", "lats", "back"]
        }
        if name.contains("squat") || name.contains("leg press") || name.contains("leg extension") || name.contains("lunge") {
            terms += ["quad", "quads", "leg", "legs"]
        }
        if name.contains("deadlift") || name.contains("leg curl") || name.contains("nordic")
            || name.contains("good morning") || name.contains("rdl") {
            terms += ["hamstring", "hamstrings", "ham", "posterior"]
        }
        if name.contains("hip thrust") || name.contains("glute") || name.contains("bridge") {
            terms += ["glute", "glutes", "butt"]
        }
        if name.contains("calf") || name.contains("calve") || name.contains("tibialis") {
            terms += ["calf", "calves"]
        }

        if alt.muscleGroups.contains(.core) {
            terms += ["ab", "abs", "abdominal", "core"]
        }

        // Implement shorthand: "db curl", "bb row", "kb swing".
        if name.contains("dumbbell") { terms.append("db") }
        if name.contains("barbell") { terms.append("bb") }
        if name.contains("kettlebell") { terms.append("kb") }
        if name.contains("ez bar") { terms += ["ezbar", "ez"] }

        return terms
    }

    /// What the row says under the name. Body parts first, then what you need to
    /// perform it — the two things you actually pick on. The old line led with
    /// the movement slot and rank template ("Horizontal Push · Barbell Strength ·
    /// Bodyweight Sets"), which is internal vocabulary and pushed the equipment
    /// off the end of the line.
    private static func compatibilityDetail(for definition: MovementDefinition) -> String {
        let equipment = ExerciseLibrary.equipmentLabels(for: definition).prefix(2).joined(separator: " · ")
        return [muscleSummary(for: definition.muscleGroups), equipment]
            .filter { !$0.isEmpty }
            .joined(separator: "  •  ")
    }

    /// Keep the catalog's own ordering — it is authored prime-mover first
    /// (`[.quads, .glutes, .core]` for a squat). Re-sorting these into the chip's
    /// anatomical order surfaced a squat as "Core · Quads · Glutes", which reads
    /// like a core exercise.
    static func muscleSummary(for muscleGroups: [MuscleGroup]) -> String {
        muscleGroups.prefix(3).map(\.displayName).joined(separator: " · ")
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
