import SwiftUI

struct ExercisePreferenceRow: View {
    let item: ExerciseLibraryItem
    @ObservedObject var viewModel: ExerciseLibraryViewModel

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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text(item.name)
                    .font(.bodyMedium(15))
                    .foregroundColor(.theme.textPrimary)
                    .multilineTextAlignment(.leading)

                Spacer()

                TriStateToggle(status: statusBinding)
            }

            if !item.muscleGroups.isEmpty {
                HStack(spacing: 4) {
                    ForEach(item.muscleGroups.prefix(3), id: \.self) { group in
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
        }
        .padding(12)
        .background(Color.theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
