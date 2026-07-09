// UNBOUND/Views/Squads/SquadSectionStyles.swift
//
// The squads visual vocabulary: each section is ONE box (surface fill, no
// strokes, no nesting) with a tinted icon chip in its header, and rows inside
// stay flat and left-aligned. The viewer's own row highlights with a
// full-width elevated fill that never shifts the text (no indent).
import SwiftUI

/// One-level section card. `tint` colors the header icon chip and is the
/// section's identity color; content inside sits flat on the card.
struct SquadSectionCard<Content: View>: View {
    let title: String
    let icon: String
    let tint: Color
    var trailing: String? = nil
    var trailingTint: Color? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                ZStack {
                    Circle().fill(tint.opacity(0.16))
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(tint)
                }
                .frame(width: 26, height: 26)

                Text(title)
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.5)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .accessibilityAddTraits(.isHeader)

                Spacer(minLength: 0)

                if let trailing {
                    Text(trailing)
                        .font(Font.unbound.captionS)
                        .foregroundStyle(trailingTint ?? Color.unbound.textTertiary)
                }
            }

            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.unbound.surface)
        )
    }
}

/// Marks the viewer's own row inside a section card: a full-width elevated
/// fill that bleeds slightly past the row's text so the text itself stays
/// aligned with every other row (jlin: no indents).
struct SquadOwnRowHighlight: ViewModifier {
    let isActive: Bool
    var cornerRadius: CGFloat = 12
    var bleed: CGFloat = 10

    func body(content: Content) -> some View {
        content
            .background {
                if isActive {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.unbound.surfaceElevated)
                        .padding(.horizontal, -bleed)
                }
            }
    }
}

extension View {
    func squadOwnRowHighlight(_ isActive: Bool, cornerRadius: CGFloat = 12) -> some View {
        modifier(SquadOwnRowHighlight(isActive: isActive, cornerRadius: cornerRadius))
    }
}

/// Deterministic identity color per member so avatars carry color without
/// storing anything. Stable across launches (UUID bytes, not Hasher).
enum SquadMemberPalette {
    static func tint(for userId: UUID) -> Color {
        let options: [Color] = [
            Color.unbound.coachCyan,
            Color.unbound.warnOrange,
            Color.unbound.success,
            Color.unbound.impact,
            Color.unbound.rankGold,
            Color.unbound.ember,
            Color.unbound.rankSilver,
        ]
        let byte = userId.uuid.0
        return options[Int(byte) % options.count]
    }
}

/// Section identity tints per mission kind — used for the pick sheet target
/// values and anywhere a mission needs an accent.
extension SquadMission.Kind {
    var tint: Color {
        switch self {
        case .totalWeight: return Color.unbound.rankSilver
        case .totalSessions: return Color.unbound.impact
        case .totalReps: return Color.unbound.ember
        case .crewCoverage: return Color.unbound.rankGold
        case .trainTogether: return Color.unbound.coachCyan
        }
    }

    /// Generated emblem asset (SquadMissions/). Raw values are snake_case, so
    /// e.g. total_weight → mission_total_weight.
    var emblemAssetName: String { "mission_\(rawValue)" }
}
