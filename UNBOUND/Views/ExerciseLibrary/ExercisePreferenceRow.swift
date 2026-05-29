import SwiftUI

struct ExercisePreferenceRow: View {
    let row: ExerciseLibraryDisplayRow
    @ObservedObject var viewModel: ExerciseLibraryViewModel

    private var item: ExerciseLibraryItem { row.item }
    private var definition: MovementDefinition? {
        MovementCatalog.definition(for: item.id)
    }

    private var statusBinding: Binding<ExercisePreferenceStatus?> {
        Binding(
            get: { viewModel.statusFor(item) },
            set: { newStatus in
                Task {
                    await viewModel.setPreference(for: item, status: newStatus)
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                if let definition {
                    ExerciseVisualView(definition: definition, size: .thumbnail)
                        .frame(width: 70, height: 70)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.bodyMedium(15))
                        .foregroundColor(.theme.textPrimary)
                        .multilineTextAlignment(.leading)

                    Text(item.metadataSummary)
                        .font(.caption(11))
                        .foregroundColor(.theme.textMuted)
                        .lineLimit(2)
                }

                Spacer()

                TriStateToggle(status: statusBinding)
            }

            if row.hasProgress || row.workingWeight != nil || item.isRankable {
                statusStrip
            }

            if !item.muscleGroups.isEmpty || !item.equipmentSummary.isEmpty {
                tagStrip
            }
        }
        .padding(12)
        .background(Color.theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var statusStrip: some View {
        HStack(spacing: 6) {
            if let tier = row.tier {
                libraryPill(text: tier.displayName, color: tier.rewardTint)
            } else if item.isRankable {
                libraryPill(text: "Ranked", color: .theme.textMuted)
            }

            if row.totalAP > 0 {
                libraryPill(text: "\(formatWhole(row.totalAP)) XP", color: .theme.primary)
            }

            if let benchmark = row.nextBenchmarkSummary {
                libraryPill(text: benchmark, color: .theme.warning)
            }

            if let summary = row.bestMetricSummary {
                libraryPill(text: summary, color: .theme.success)
            }
        }
        .lineLimit(1)
    }

    private var tagStrip: some View {
        HStack(spacing: 4) {
            if !item.equipmentSummary.isEmpty {
                Text(item.equipmentSummary)
                    .font(.caption(11))
                    .foregroundColor(.theme.warning)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.theme.warning.opacity(0.12))
                    .clipShape(Capsule())
                    .lineLimit(1)
            }

            ForEach(item.muscleGroups.prefix(2), id: \.self) { group in
                Text(group.displayName)
                    .font(.caption(11))
                    .foregroundColor(.theme.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.theme.primary.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
    }

    private func libraryPill(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption(11))
            .foregroundColor(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
            .minimumScaleFactor(0.75)
    }

    private func formatWhole(_ value: Double) -> String {
        "\(Int(value.rounded()))"
    }
}
