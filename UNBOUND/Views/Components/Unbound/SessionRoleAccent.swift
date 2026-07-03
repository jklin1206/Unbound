import SwiftUI

/// Accent color for a session role — the "pop" color that breaks the
/// gray-on-black monochrome on loadout cards and the daily quest card,
/// mirroring the dungeon cards' category-color language (tinted hairline
/// border + soft glow + colored chip on a dark surface, never accent bars).
/// Hues follow the exercise-visual slot tints: push = ember amber,
/// pull = reward blue, legs = warn orange.
extension SessionRole {
    var accentColor: Color {
        switch self {
        case .push, .pushVertical, .pushHorizontal, .broChest, .broShoulders:
            return Color.unbound.emberGlow
        case .pull, .pullFocus, .broBack:
            return Color.rewardBlue
        case .legs, .lower, .squatFocus:
            return Color.unbound.warnOrange
        case .upper, .cardio:
            return Color.unbound.coachCyan
        case .rest:
            return Color.unbound.rankGreen
        case .broArms, .skillOnly:
            return Color.unbound.impact
        case .fullBody, .custom:
            return Color.unbound.accent
        }
    }
}

extension SessionRole {
    /// Tag short enough for a calendar day cell (≤6 chars) — the Plan
    /// calendar prints this under each date so the split reads at a glance.
    var compactLabel: String {
        switch self {
        case .rest: return "REST"
        case .pull, .pullFocus: return "PULL"
        case .push, .pushVertical, .pushHorizontal: return "PUSH"
        case .legs, .squatFocus: return "LEGS"
        case .upper: return "UPPER"
        case .lower: return "LOWER"
        case .fullBody: return "FULL"
        case .broChest: return "CHEST"
        case .broBack: return "BACK"
        case .broShoulders: return "DELTS"
        case .broArms: return "ARMS"
        case .cardio: return "CARDIO"
        case .skillOnly: return "SKILL"
        case .custom(let value): return String(value.prefix(6)).uppercased()
        }
    }
}

/// Per-exercise accent, keyed by movement slot — the same hue family as the
/// session-role accents so a push exercise and a push day always share a color.
/// Single source for the exercise-visual tile tint and the editor's exercise
/// cards.
extension MovementSlot {
    var accentColor: Color {
        switch self {
        case .squat, .hinge, .calves: return Color.unbound.warnOrange
        case .horizontalPush, .verticalPush: return Color.unbound.emberGlow
        case .horizontalPull, .verticalPull: return Color.rewardBlue
        case .core: return Color.unbound.rankGold
        case .mobility: return Color.rewardTeal
        case .cardio, .carry: return Color.unbound.impact
        case .arms, .routine, .skill: return Color.unbound.accent
        }
    }

    var accentLabel: String {
        switch self {
        case .squat, .hinge, .calves: return "Legs"
        case .horizontalPush, .verticalPush: return "Push"
        case .horizontalPull, .verticalPull: return "Pull"
        case .core: return "Core"
        case .mobility: return "Mobility"
        case .cardio: return "Cardio"
        case .carry: return "Carry"
        case .arms: return "Arms"
        case .routine: return "Routine"
        case .skill: return "Skill"
        }
    }
}

/// The colored "● PUSH" chip used next to a loadout's meta line.
struct SessionRoleChip: View {
    let text: String
    let accent: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(accent)
                .frame(width: 5, height: 5)
            Text(text.uppercased())
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.2)
                .foregroundStyle(accent)
                .lineLimit(1)
        }
    }
}
