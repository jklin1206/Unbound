import Foundation

struct TrainingBlock: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var kind: TrainingBlockKind
    var title: String
    var subtitle: String?
    var skillId: String?
    var selectedRungId: String?
    var selectedRungSource: SkillTrainingRungSource?
    var selectedRungReason: String?
    var routineId: String?
    var cardioType: CardioType?
    var prescriptions: [TrainingBlockPrescription]
    var notes: String?

    init(
        id: String = UUID().uuidString,
        kind: TrainingBlockKind,
        title: String,
        subtitle: String? = nil,
        skillId: String? = nil,
        selectedRungId: String? = nil,
        selectedRungSource: SkillTrainingRungSource? = nil,
        selectedRungReason: String? = nil,
        routineId: String? = nil,
        cardioType: CardioType? = nil,
        prescriptions: [TrainingBlockPrescription],
        notes: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.skillId = skillId
        self.selectedRungId = selectedRungId
        self.selectedRungSource = selectedRungSource
        self.selectedRungReason = selectedRungReason
        self.routineId = routineId
        self.cardioType = cardioType
        self.prescriptions = prescriptions
        self.notes = notes
    }
}

struct TrainingSetPlan: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var target: TrainingTarget
    var restSeconds: Int
    var rpe: Int?
    var loadPercentOfBodyweight: Double?
    var suggestedWeightKg: Double?
    var isWarmup: Bool
    var notes: String?

    init(
        id: String = UUID().uuidString,
        target: TrainingTarget,
        restSeconds: Int,
        rpe: Int? = nil,
        loadPercentOfBodyweight: Double? = nil,
        suggestedWeightKg: Double? = nil,
        isWarmup: Bool = false,
        notes: String? = nil
    ) {
        self.id = id
        self.target = target
        self.restSeconds = min(max(restSeconds, 0), 600)
        self.rpe = rpe.map { min(max($0, 1), 10) }
        self.loadPercentOfBodyweight = loadPercentOfBodyweight
        self.suggestedWeightKg = suggestedWeightKg
        self.isWarmup = isWarmup
        self.notes = notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    var displayTargetText: String {
        if let suggestedWeightKg {
            return "\(target.displayText) @ \(WeightPlatePolicy.formatSuggestionWeightWithUnit(suggestedWeightKg, separator: " "))"
        }
        if let loadPercentOfBodyweight {
            let value = loadPercentOfBodyweight * 100
            let text = value.rounded() == value
                ? "\(Int(value))% BW"
                : "\(String(format: "%.1f", value))% BW"
            return "\(target.displayText) @ \(text)"
        }
        return target.displayText
    }
}

struct TrainingBlockPrescription: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var exerciseName: String
    var movementId: String?
    var rankStandardMovementId: String?
    var sets: Int
    var target: TrainingTarget
    var restSeconds: Int
    var muscleGroups: [MuscleGroup]
    var rpe: Int?
    var notes: String?
    var loadPercentOfBodyweight: Double?
    var suggestedWeightKg: Double?
    var setPlans: [TrainingSetPlan]?

    init(
        id: String = UUID().uuidString,
        exerciseName: String,
        movementId: String? = nil,
        rankStandardMovementId: String? = nil,
        sets: Int,
        target: TrainingTarget,
        restSeconds: Int,
        muscleGroups: [MuscleGroup] = [],
        rpe: Int? = nil,
        notes: String? = nil,
        loadPercentOfBodyweight: Double? = nil,
        suggestedWeightKg: Double? = nil,
        setPlans: [TrainingSetPlan]? = nil
    ) {
        let resolved = MovementResolver.resolve(exerciseName)
        let cleanedSetPlans = Self.cleanedSetPlans(setPlans)
        self.id = id
        self.exerciseName = exerciseName
        self.movementId = movementId ?? resolved.movementId
        self.rankStandardMovementId = rankStandardMovementId ?? resolved.rankStandardMovementId
        self.sets = cleanedSetPlans.map(\.count) ?? max(1, sets)
        self.target = target
        self.restSeconds = restSeconds
        self.muscleGroups = muscleGroups
        self.rpe = rpe
        self.notes = notes
        self.loadPercentOfBodyweight = loadPercentOfBodyweight
        self.suggestedWeightKg = suggestedWeightKg
        self.setPlans = cleanedSetPlans
    }

    var displayTargetText: String {
        if hasCustomSetPlanValues {
            return "Custom set plan"
        }
        if let loadPercentOfBodyweight, let suggestedWeightKg {
            return "\(target.displayText) @ \(Self.loadText(suggestedWeightKg)) (\(Self.bodyweightPercentText(loadPercentOfBodyweight)))"
        }
        if let loadPercentOfBodyweight {
            return "\(target.displayText) @ \(Self.bodyweightPercentText(loadPercentOfBodyweight))"
        }
        if let suggestedWeightKg {
            return "\(target.displayText) @ \(Self.loadText(suggestedWeightKg))"
        }
        return target.displayText
    }

    private static func bodyweightPercentText(_ percent: Double) -> String {
        let value = percent * 100
        if value.rounded() == value {
            return "\(Int(value))% BW"
        }
        return "\(String(format: "%.1f", value))% BW"
    }

    private static func loadText(_ kilograms: Double) -> String {
        WeightPlatePolicy.formatSuggestionWeightWithUnit(kilograms, separator: " ")
    }
}

extension TrainingBlockPrescription {
    var effectiveSetPlans: [TrainingSetPlan] {
        if let setPlans, !setPlans.isEmpty {
            return setPlans
        }
        return (0..<max(1, sets)).map { index in
            TrainingSetPlan(
                id: "\(id)-set-plan-\(index + 1)",
                target: target,
                restSeconds: restSeconds,
                rpe: rpe,
                loadPercentOfBodyweight: loadPercentOfBodyweight,
                suggestedWeightKg: suggestedWeightKg
            )
        }
    }

    var plannedSetCount: Int {
        effectiveSetPlans.count
    }

    var setPlanSummaryText: String {
        hasCustomSetPlanValues ? "custom sets" : displayTargetText
    }

    var hasCustomSetPlanValues: Bool {
        guard let setPlans, !setPlans.isEmpty else { return false }
        return setPlans.contains { plan in
            plan.target != target
                || plan.restSeconds != restSeconds
                || plan.rpe != rpe
                || plan.loadPercentOfBodyweight != loadPercentOfBodyweight
                || plan.suggestedWeightKg != suggestedWeightKg
                || plan.isWarmup
        }
    }

    mutating func materializeSetPlans() {
        if setPlans?.isEmpty != false {
            setPlans = effectiveSetPlans
        }
        syncSummaryFromSetPlans()
    }

    mutating func addSetPlan() {
        materializeSetPlans()
        var plans = setPlans ?? effectiveSetPlans
        let fallback = plans.last ?? TrainingSetPlan(
            target: target,
            restSeconds: restSeconds,
            rpe: rpe,
            loadPercentOfBodyweight: loadPercentOfBodyweight,
            suggestedWeightKg: suggestedWeightKg
        )
        plans.append(
            TrainingSetPlan(
                target: fallback.target,
                restSeconds: fallback.restSeconds,
                rpe: fallback.rpe,
                loadPercentOfBodyweight: fallback.loadPercentOfBodyweight,
                suggestedWeightKg: fallback.suggestedWeightKg,
                isWarmup: fallback.isWarmup,
                notes: fallback.notes
            )
        )
        setPlans = plans
        syncSummaryFromSetPlans()
    }

    mutating func removeSetPlan(at index: Int) {
        materializeSetPlans()
        guard var plans = setPlans, plans.count > 1, plans.indices.contains(index) else { return }
        plans.remove(at: index)
        setPlans = plans
        syncSummaryFromSetPlans()
    }

    mutating func syncSummaryFromSetPlans() {
        guard let first = setPlans?.first else {
            sets = max(1, sets)
            return
        }
        sets = max(1, setPlans?.count ?? 1)
        target = first.target
        restSeconds = first.restSeconds
        rpe = first.rpe
        loadPercentOfBodyweight = first.loadPercentOfBodyweight
        suggestedWeightKg = first.suggestedWeightKg
    }

    static func cleanedSetPlans(_ plans: [TrainingSetPlan]?) -> [TrainingSetPlan]? {
        guard let plans else { return nil }
        let cleaned = plans.filter { !$0.target.displayText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return cleaned.isEmpty ? nil : Array(cleaned.prefix(30))
    }
}

enum TrainingTarget: Codable, Hashable, Sendable {
    case reps(Int)
    case repsRange(Int, Int)
    case amrap
    case holdSeconds(Int)
    case distanceMeters(Int)
    case calories(Int)
    case timedSeconds(Int)

    var displayText: String {
        switch self {
        case .reps(let count): return "\(count) reps"
        case .repsRange(let low, let high): return "\(low)-\(high) reps"
        case .amrap: return "AMRAP"
        case .holdSeconds(let seconds): return "\(seconds)s hold"
        case .distanceMeters(let meters): return meters >= 1000 ? String(format: "%.1f km", Double(meters) / 1000.0) : "\(meters)m"
        case .calories(let calories): return "\(calories) cal"
        case .timedSeconds(let seconds): return "\(seconds)s"
        }
    }

    var repsLowerBound: Int? {
        switch self {
        case .reps(let count): return count
        case .repsRange(let low, _): return low
        case .amrap, .holdSeconds, .distanceMeters, .calories, .timedSeconds: return nil
        }
    }

    var metricKind: TrainingMetricKind {
        switch self {
        case .reps, .repsRange, .amrap:
            return .reps
        case .holdSeconds:
            return .holdSeconds
        case .distanceMeters:
            return .distanceMeters
        case .calories:
            return .calories
        case .timedSeconds:
            return .durationSeconds
        }
    }

    var metricLowerBound: Int? {
        switch self {
        case .reps(let count):
            return count
        case .repsRange(let low, _):
            return low
        case .holdSeconds(let seconds):
            return seconds
        case .distanceMeters(let meters):
            return meters
        case .calories(let calories):
            return calories
        case .timedSeconds(let seconds):
            return seconds
        case .amrap:
            return nil
        }
    }

    func metricKind(defaultingTo catalogDefault: TrainingMetricKind?) -> TrainingMetricKind {
        switch self {
        case .amrap:
            return catalogDefault ?? .reps
        case .reps, .repsRange, .holdSeconds, .distanceMeters, .calories, .timedSeconds:
            return metricKind
        }
    }
}

extension TrainingTarget {
    init(_ prescriptionTarget: PrescriptionTarget) {
        switch prescriptionTarget {
        case .reps(let count):
            self = .reps(count)
        case .repsRange(let low, let high):
            self = .repsRange(low, high)
        case .amrap:
            self = .amrap
        case .hold(let seconds):
            self = .holdSeconds(seconds)
        case .tempo(let reps, _, _, _):
            self = .reps(reps)
        }
    }
}
