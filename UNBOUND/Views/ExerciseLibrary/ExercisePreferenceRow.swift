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
                ExerciseLibraryPill(text: tier.displayName, tint: tier.rewardTint)
            } else if item.isRankable {
                ExerciseLibraryPill(text: "Ranked", tint: .theme.textMuted)
            }

            if row.totalAP > 0 {
                ExerciseLibraryPill(text: "\(formatWhole(row.totalAP)) XP", tint: .theme.primary)
            }

            if let benchmark = row.nextBenchmarkSummary {
                ExerciseLibraryPill(text: benchmark, tint: .theme.warning)
            }

            if let summary = row.bestMetricSummary {
                ExerciseLibraryPill(text: summary, tint: .theme.success)
            }
        }
        .lineLimit(1)
    }

    private var tagStrip: some View {
        HStack(spacing: 4) {
            if !item.equipmentSummary.isEmpty {
                ExerciseLibraryPill(
                    text: item.equipmentSummary,
                    tint: .theme.warning,
                    horizontalPadding: 6,
                    verticalPadding: 2
                )
                    .lineLimit(1)
            }

            ForEach(item.muscleGroups.prefix(2), id: \.self) { group in
                ExerciseLibraryPill(
                    text: group.displayName,
                    tint: .theme.primary,
                    horizontalPadding: 6,
                    verticalPadding: 2
                )
            }
        }
    }

    private func formatWhole(_ value: Double) -> String {
        "\(Int(value.rounded()))"
    }
}
