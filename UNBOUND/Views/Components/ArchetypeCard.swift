import SwiftUI

struct ArchetypeCard: View {
    let archetype: Archetype
    var isSelected: Bool = false
    var onTap: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(archetype.displayName)
                    .font(.subheadline(18))
                    .foregroundColor(.theme.textPrimary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.theme.primary)
                        .font(.title3)
                }
            }

            Text(archetype.subtitle)
                .font(.caption())
                .foregroundColor(.theme.primary)

            Text(archetype.animeReferences.joined(separator: " / "))
                .font(.caption())
                .foregroundColor(.theme.textSecondary)

            Text(archetype.primaryMetric)
                .font(.caption(12))
                .foregroundColor(.theme.textMuted)
                .padding(.top, 4)
        }
        .padding(16)
        .background(isSelected ? Color.theme.primary.opacity(0.1) : Color.theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.theme.primary : Color.theme.surfaceLight, lineWidth: isSelected ? 2 : 1)
        )
        .onTapGesture {
            HapticManager.selection()
            onTap?()
        }
    }
}
