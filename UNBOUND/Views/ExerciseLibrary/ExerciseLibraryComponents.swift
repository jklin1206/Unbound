import SwiftUI

struct ExerciseLibrarySearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.caption(14))
                .foregroundColor(.theme.textMuted)

            TextField("Search exercises...", text: $text)
                .font(.bodyText(15))
                .foregroundColor(.theme.textPrimary)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct ExerciseLibraryStatCard: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption(10))
                .foregroundColor(.theme.textMuted)
            Text(value)
                .font(.bodyMedium(16))
                .foregroundColor(tint)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct ExerciseLibraryProgressChip: View {
    let row: ExerciseLibraryDisplayRow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Text(row.tier?.displayName.uppercased() ?? "LOGGED")
                    .font(.caption(9))
                    .foregroundColor(row.tier?.rewardTint ?? .theme.success)
                if row.totalAP > 0 {
                    Text("\(Int(row.totalAP.rounded())) XP")
                        .font(.caption(9))
                        .foregroundColor(.theme.textMuted)
                        .monospacedDigit()
                }
            }

            Text(row.item.name)
                .font(.caption(12))
                .foregroundColor(.theme.textPrimary)
                .lineLimit(1)

            if let summary = row.bestMetricSummary {
                Text(summary)
                    .font(.caption(10))
                    .foregroundColor(.theme.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 148, alignment: .leading)
        .padding(10)
        .background(Color.theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct ExerciseLibraryFilterChip: View {
    let title: String
    let isSelected: Bool
    var fontSize: CGFloat = 13
    var horizontalPadding: CGFloat = 14
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption(fontSize))
                .foregroundColor(isSelected ? .white : .theme.textSecondary)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 7)
                .background(isSelected ? Color.theme.primary : Color.theme.surface)
                .clipShape(Capsule())
        }
    }
}

struct ExerciseLibrarySummaryItem: View {
    let count: Int
    let label: String
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .font(.bodyMedium(14))
                .foregroundColor(count > 0 ? tint : .theme.textMuted)
            Text(label)
                .font(.caption(13))
                .foregroundColor(.theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ExerciseLibraryPill: View {
    let text: String
    let tint: Color
    var horizontalPadding: CGFloat = 7
    var verticalPadding: CGFloat = 3
    var minimumScaleFactor: CGFloat = 0.75

    var body: some View {
        Text(text)
            .font(.caption(11))
            .foregroundColor(tint)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(tint.opacity(0.12))
            .clipShape(Capsule())
            .minimumScaleFactor(minimumScaleFactor)
    }
}
