import Foundation
import SwiftUI

/// A Binding Vow lane. Determines how a vow is verified and its accent.
enum VowLane: String, CaseIterable, Codable, Sendable {
    case recovery
    case fuel
    case engine

    enum Verification: Equatable, Sendable { case autoFromLog, selfReport }

    var verification: Verification {
        switch self {
        case .recovery, .engine: return .autoFromLog
        case .fuel: return .selfReport
        }
    }

    var displayLabel: String {
        switch self {
        case .recovery: return "RECOVERY"
        case .fuel: return "FUEL"
        case .engine: return "ENGINE"
        }
    }

    /// Accent tint, tokens only.
    var tintColor: Color {
        switch self {
        case .recovery: return Color.unbound.success
        case .fuel: return Color.unbound.rankGold
        case .engine: return Color.unbound.coachCyan
        }
    }

    /// Interim seal asset (final art deferred). See Phase 5.
    var sealAssetName: String { "vow_seal_\(rawValue)" }

    var sealSymbolName: String {
        switch self {
        case .recovery: return "leaf.fill"
        case .fuel: return "fork.knife"
        case .engine: return "wind"
        }
    }
}
