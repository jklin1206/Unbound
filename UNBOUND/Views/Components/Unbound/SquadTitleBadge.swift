// UNBOUND/Views/Components/Unbound/SquadTitleBadge.swift
import SwiftUI

/// Pill chip rendering an earned Squad Title. Wider than TitleBadge with a
/// small `figure.2` SF Symbol prefix indicating crew membership.
/// Color treatment scales with tier rarity (1=bronze, 2=silver, 3=gold).
struct SquadTitleBadge: View {
    let titleId: SquadTitleID
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 4 : 5) {
            Image(systemName: "figure.2")
                .font(.system(size: compact ? 8 : 10, weight: .semibold))
                .foregroundStyle(iconColor)
            Text(SquadTitleCatalog.displayName(for: titleId).uppercased())
                .font(.system(size: compact ? 9 : 11, weight: .heavy, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(textColor)
        }
        .padding(.horizontal, compact ? 8 : 12)
        .padding(.vertical, compact ? 3 : 5)
        .background(
            Capsule().fill(backgroundColor)
        )
        .overlay(
            Capsule().strokeBorder(strokeColor, lineWidth: 1)
        )
        .shadow(color: glowColor, radius: glowRadius)
    }

    private var iconColor: Color {
        switch titleId.tier {
        case 3:  return Color.unbound.accent            // gold — violet glow
        case 2:  return Color(red: 0.75, green: 0.78, blue: 0.82) // silver
        default: return Color(red: 0.68, green: 0.46, blue: 0.28) // bronze
        }
    }

    private var textColor: Color {
        switch titleId.tier {
        case 3:  return Color.unbound.textPrimary
        case 2:  return Color.unbound.textPrimary
        default: return Color.unbound.textSecondary
        }
    }

    private var backgroundColor: Color {
        switch titleId.tier {
        case 3:  return Color.unbound.accent.opacity(0.22)
        case 2:  return Color(red: 0.18, green: 0.20, blue: 0.24)
        default: return Color(red: 0.20, green: 0.16, blue: 0.10)
        }
    }

    private var strokeColor: Color {
        switch titleId.tier {
        case 3:  return Color.unbound.accent
        case 2:  return Color(red: 0.75, green: 0.78, blue: 0.82).opacity(0.5)
        default: return Color(red: 0.68, green: 0.46, blue: 0.28).opacity(0.5)
        }
    }

    private var glowColor: Color {
        titleId.tier == 3 ? Color.unbound.accent.opacity(0.5) : .clear
    }

    private var glowRadius: CGFloat {
        titleId.tier == 3 ? 8 : 0
    }
}

#Preview("All Tiers") {
    VStack(alignment: .leading, spacing: 12) {
        SquadTitleBadge(titleId: SquadTitleID(category: .linkedSessions, axis: nil, tier: 1))
        SquadTitleBadge(titleId: SquadTitleID(category: .squadStreak,    axis: nil, tier: 2))
        SquadTitleBadge(titleId: SquadTitleID(category: .collectiveAxis, axis: .power, tier: 3))
        SquadTitleBadge(titleId: SquadTitleID(category: .linkedSessions, axis: nil, tier: 1), compact: true)
        SquadTitleBadge(titleId: SquadTitleID(category: .squadStreak,    axis: nil, tier: 2), compact: true)
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .background(Color.unbound.bg)
}
