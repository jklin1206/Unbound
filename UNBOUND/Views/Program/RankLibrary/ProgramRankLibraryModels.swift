import SwiftUI
import UIKit

struct ProgramRankLibrarySection: Identifiable {
    let title: String
    let rows: [ProgramRankLibraryRow]

    var id: String { title }
}

extension ProgramRankLibrarySection: Hashable {
    // Identity is the stable section title; used by navigationDestination(item:).
    static func == (lhs: ProgramRankLibrarySection, rhs: ProgramRankLibrarySection) -> Bool {
        lhs.title == rhs.title
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(title)
    }
}

struct ProgramRankLibraryRow: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let detail: String
    let metric: String
    let tier: SkillTier
    let visualAssetName: String?
    let totalAP: Double
    let source: ProgramRankLibrarySource
    let sourceId: String
    let sectionTitle: String
    let sectionOrder: Int
    let lastActivityAt: Date?
    let earnedOverride: Bool?
    /// A not-yet feat (earned rank below its floor) has no real rank to show.
    var isRankHidden: Bool = false

    var isEarned: Bool {
        earnedOverride ?? (tier > .initiate || totalAP > 0)
    }

    var searchText: String {
        [
            title,
            subtitle,
            detail,
            metric,
            tier.displayName,
            source.displayName,
            sectionTitle
        ].joined(separator: " ")
    }
}

extension ProgramRankLibraryRow: Hashable {
    // Identity is the stable row id; used by navigationDestination(item:).
    static func == (lhs: ProgramRankLibraryRow, rhs: ProgramRankLibraryRow) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

enum ProgramRankLibrarySource: Equatable {
    case skill
    case exercise

    var displayName: String {
        switch self {
        case .skill: return "Skill"
        case .exercise: return "Exercise"
        }
    }

    var systemImage: String {
        switch self {
        case .skill: return "sparkles"
        case .exercise: return "dumbbell.fill"
        }
    }

    var sortOrder: Int {
        switch self {
        case .skill: return 0
        case .exercise: return 1
        }
    }
}

enum ProgramRankLibraryFilter: String, CaseIterable, Identifiable {
    case all
    case earned
    case skills
    case exercises
    case top

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return "All"
        case .earned: return "Earned"
        case .skills: return "Skills"
        case .exercises: return "Exercises"
        case .top: return "Top"
        }
    }
}
