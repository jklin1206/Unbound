// UNBOUND/Views/Components/Unbound/TitleBadge.swift
import SwiftUI

/// Pill chip rendering an earned Title. Bronze / Silver / Gold treatments
/// scale visual prominence with tier rarity.
struct TitleBadge: View {
    let titleId: TitleID
    var compact: Bool = false

    var body: some View {
        Text(TitleCatalog.displayName(for: titleId).uppercased())
            .font(.system(size: compact ? 9 : 11, weight: .heavy, design: .monospaced))
            .tracking(1.5)
            .foregroundStyle(textColor)
            .padding(.horizontal, compact ? 6 : 10)
            .padding(.vertical, compact ? 3 : 5)
            .background(
                Capsule().fill(backgroundColor)
            )
            .overlay(
                Capsule().strokeBorder(strokeColor, lineWidth: 1)
            )
            .shadow(color: glowColor, radius: glowRadius)
    }

    private var textColor: Color {
        switch titleId.tier {
        case .gold:   return Color.unbound.textPrimary
        case .silver: return Color.unbound.textPrimary
        case .bronze: return Color.unbound.textSecondary
        }
    }

    private var backgroundColor: Color {
        switch titleId.tier {
        case .gold:   return Color.unbound.accent.opacity(0.22)
        case .silver: return Color(red: 0.18, green: 0.20, blue: 0.24)
        case .bronze: return Color(red: 0.20, green: 0.16, blue: 0.10)
        }
    }

    private var strokeColor: Color {
        switch titleId.tier {
        case .gold:   return Color.unbound.accent
        case .silver: return Color(red: 0.75, green: 0.78, blue: 0.82).opacity(0.5)
        case .bronze: return Color(red: 0.68, green: 0.46, blue: 0.28).opacity(0.5)
        }
    }

    private var glowColor: Color {
        titleId.tier == .gold ? Color.unbound.accent.opacity(0.5) : .clear
    }

    private var glowRadius: CGFloat {
        titleId.tier == .gold ? 8 : 0
    }
}

#Preview("All Tiers") {
    VStack(alignment: .leading, spacing: 12) {
        ForEach(TitleCatalog.all.prefix(9), id: \.self) { titleId in
            TitleBadge(titleId: titleId)
        }
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .background(Color.unbound.bg)
}
