import Foundation

enum CardioType: String, Codable, CaseIterable, Sendable, Identifiable {
    case run, bike, row, walk, swim, stairs, elliptical

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .run:
            return L10n.string(.cardioRunDisplayName, defaultValue: "Run")
        case .bike:
            return L10n.string(.cardioBikeDisplayName, defaultValue: "Bike")
        case .row:
            return L10n.string(.cardioRowDisplayName, defaultValue: "Row")
        case .walk:
            return L10n.string(.cardioWalkDisplayName, defaultValue: "Walk")
        case .swim:
            return L10n.string(.cardioSwimDisplayName, defaultValue: "Swim")
        case .stairs:
            return L10n.string(.cardioStairsDisplayName, defaultValue: "Stairs")
        case .elliptical:
            return L10n.string(.cardioEllipticalDisplayName, defaultValue: "Elliptical")
        }
    }

    var sfSymbol: String {
        switch self {
        case .run:        return "figure.run"
        case .bike:       return "figure.outdoor.cycle"
        case .row:        return "figure.rower"
        case .walk:       return "figure.walk"
        case .swim:       return "figure.pool.swim"
        case .stairs:     return "figure.stairs"
        case .elliptical: return "figure.elliptical"
        }
    }

    /// Intensity multiplier vs. a reference bike-equivalent minute.
    var intensityFactor: Double {
        switch self {
        case .run:        return 1.2
        case .bike:       return 1.0
        case .row:        return 1.15
        case .walk:       return 0.6
        case .swim:       return 1.1
        case .stairs:     return 1.25
        case .elliptical: return 0.9
        }
    }
}

struct CardioSession: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let userId: String
    var type: CardioType
    var durationMinutes: Int
    var distanceKm: Double?
    var avgHR: Int?
    var perceivedEffort: Int
    var notes: String?
    var date: Date

    init(
        id: UUID = UUID(),
        userId: String,
        type: CardioType,
        durationMinutes: Int,
        distanceKm: Double? = nil,
        avgHR: Int? = nil,
        perceivedEffort: Int,
        notes: String? = nil,
        date: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.type = type
        self.durationMinutes = durationMinutes
        self.distanceKm = distanceKm
        self.avgHR = avgHR
        self.perceivedEffort = perceivedEffort
        self.notes = notes
        self.date = date
    }
}

extension Notification.Name {
    static let cardioLogged = Notification.Name("unbound.cardioLogged")
}
