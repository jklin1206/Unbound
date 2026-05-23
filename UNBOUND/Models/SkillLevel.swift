import Foundation

// MARK: - SkillLevel
//
// A single level within a skill's 1-5 ladder. Each SkillNode carries
// an array of up to five SkillLevels, each with a measurable target
// and an XP reward that fires when the level is cleared.
//
// Phase 1a: type scaffolding only. Phase 1b wires XP accrual into
// SkillProgressService. Phase 1c populates these on existing nodes.

/// A single level within a skill's 1-5 ladder.
public struct SkillLevel: Codable, Hashable, Sendable, Identifiable {
    public let level: Int           // 1...5
    public let target: LevelTarget
    public let criterion: String    // e.g. "3 strict reps with chest to bar"
    public let xpReward: Int        // XP granted on reaching this level

    public var id: Int { level }

    public init(level: Int, target: LevelTarget, criterion: String, xpReward: Int) {
        self.level = level
        self.target = target
        self.criterion = criterion
        self.xpReward = xpReward
    }
}

/// What the user must achieve to clear a level.
public enum LevelTarget: Codable, Hashable, Sendable {
    case firstRep                         // Lv1 for most skills: "do it once cleanly"
    case reps(Int)                        // Lv2-Lv5 rep target
    case hold(seconds: Int)               // static hold in seconds
    case weight(multiplier: Double)       // body-weight multiplier (e.g., 1.5x)
    case distance(meters: Double)         // endurance distance
    case duration(seconds: Int)           // endurance time
    case combined(primary: Box<LevelTarget>, secondary: Box<LevelTarget>)
}

/// Indirect-enum helper so `LevelTarget.combined` can recursively hold other targets.
public final class Box<T: Codable & Hashable & Sendable>: Codable, Hashable, @unchecked Sendable {
    public let value: T
    public init(_ value: T) { self.value = value }
    public static func == (lhs: Box<T>, rhs: Box<T>) -> Bool { lhs.value == rhs.value }
    public func hash(into hasher: inout Hasher) { hasher.combine(value) }

    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(try container.decode(T.self))
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}
