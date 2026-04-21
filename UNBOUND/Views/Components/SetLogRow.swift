import SwiftUI

struct SetLogRow: View {
    let setNumber: Int
    @Binding var weightKg: String
    @Binding var reps: String
    @Binding var rpe: Int?
    @Binding var isWarmup: Bool
    var onDelete: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            // Set number badge
            Text(isWarmup ? "W" : "\(setNumber)")
                .font(.caption(12))
                .fontWeight(.bold)
                .foregroundColor(isWarmup ? .theme.warning : .theme.textPrimary)
                .frame(width: 24, height: 24)
                .background(isWarmup ? Color.theme.warning.opacity(0.15) : Color.theme.surfaceLight)
                .clipShape(Circle())
                .onTapGesture {
                    isWarmup.toggle()
                    HapticManager.selection()
                }

            // Weight
            HStack(spacing: 2) {
                TextField("0", text: $weightKg)
                    .keyboardType(.decimalPad)
                    .frame(width: 50)
                    .multilineTextAlignment(.center)
                Text("kg")
                    .font(.caption(11))
                    .foregroundColor(.theme.textMuted)
            }
            .font(.bodyMedium(14))
            .foregroundColor(.theme.textPrimary)

            // Reps
            HStack(spacing: 2) {
                TextField("0", text: $reps)
                    .keyboardType(.numberPad)
                    .frame(width: 36)
                    .multilineTextAlignment(.center)
                Text("reps")
                    .font(.caption(11))
                    .foregroundColor(.theme.textMuted)
            }
            .font(.bodyMedium(14))
            .foregroundColor(.theme.textPrimary)

            // RPE
            Menu {
                ForEach([6, 7, 8, 9, 10], id: \.self) { value in
                    Button("RPE \(value)") { rpe = value }
                }
                Button("Clear") { rpe = nil }
            } label: {
                Text(rpe.map { "RPE \($0)" } ?? "RPE")
                    .font(.caption(12))
                    .foregroundColor(rpe != nil ? .theme.primary : .theme.textMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.theme.surfaceLight)
                    .clipShape(Capsule())
            }

            Spacer()

            if let onDelete {
                Button { onDelete() } label: {
                    Image(systemName: "trash")
                        .font(.caption(12))
                        .foregroundColor(.theme.danger.opacity(0.6))
                }
            }
        }
        .padding(.vertical, 4)
    }
}
