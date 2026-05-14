import SwiftUI

// MARK: - TrialPickerPromptCard
//
// Compact card that sits in the Home contextualStack when the user has not
// yet picked a trial for the current week. Taps open TrialPickerSheet.
//
// Intentionally quiet — charcoal card with a subtle violet accent.

struct TrialPickerPromptCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            UnboundHaptics.soft()
            onTap()
        }) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.unbound.accent.opacity(0.15))
                    Image(systemName: "flag.2.crossed.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.unbound.accent)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text("WEEKLY TRIAL")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.6)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text("Pick your trial card")
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.unbound.accent.opacity(0.24), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.unbound.bg.ignoresSafeArea()
        TrialPickerPromptCard(onTap: {})
            .padding(20)
    }
}
