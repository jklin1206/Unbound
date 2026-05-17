import SwiftUI

/// Optional per-set RPE picker. Real strength scale (6–10) with the
/// reps-in-reserve meaning beside each number — this is where RPE is explained
/// in context. Returns Int? (nil = Clear).
struct RPEPickerSheet: View {
    let current: Int?
    let onPick: (Int?) -> Void
    @Environment(\.dismiss) private var dismiss

    private static let rows: [(Int, String)] = [
        (10, "Nothing left"),
        (9,  "1 rep left"),
        (8,  "2 reps left"),
        (7,  "3 reps left"),
        (6,  "4+ reps left"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("HOW HARD? — RPE")
                .font(Font.unbound.captionS).tracking(2)
                .foregroundStyle(Color.unbound.textTertiary)
                .padding(.bottom, 16)

            ForEach(Self.rows, id: \.0) { value, meaning in
                Button {
                    onPick(value)
                    UnboundHaptics.tick()
                    dismiss()
                } label: {
                    HStack(spacing: 16) {
                        Text("\(value)")
                            .font(Font.unbound.monoL)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .frame(width: 40, alignment: .leading)
                        Text(meaning)
                            .font(Font.unbound.bodyM)
                            .foregroundStyle(Color.unbound.textSecondary)
                        Spacer()
                        if current == value {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.unbound.accent)
                        }
                    }
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if value != Self.rows.last?.0 {
                    Divider().overlay(Color.unbound.borderSubtle)
                }
            }

            Button {
                onPick(nil)
                dismiss()
            } label: {
                Text("Clear")
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding(24)
        .background(Color.unbound.bg.ignoresSafeArea())
    }
}
