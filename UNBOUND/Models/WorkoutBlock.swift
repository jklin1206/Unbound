import Foundation

struct WorkoutBlock: Codable, Identifiable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case warmup
        case main
        case accessory
        case cooldown
        case skill
    }

    var id: String
    var kind: Kind
    var title: String
    var skillKind: SkillBlockKind?
    var skillID: String?
    var regionLoad: RegionLoad
    var prescriptions: [TrainingBlockPrescription]

    init(
        id: String = UUID().uuidString,
        kind: Kind,
        title: String,
        skillKind: SkillBlockKind? = nil,
        skillID: String? = nil,
        regionLoad: RegionLoad = RegionLoad(),
        prescriptions: [TrainingBlockPrescription] = []
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.skillKind = skillKind
        self.skillID = skillID
        self.regionLoad = regionLoad
        self.prescriptions = prescriptions
    }
}
