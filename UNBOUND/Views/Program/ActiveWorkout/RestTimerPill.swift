import SwiftUI

struct RestTimerPill: View {
    @ObservedObject var model: RestTimerModel
    let onAddThirty: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        if model.isVisible {
            HStack(spacing: 16) {
                Text("REST")
                    .font(Font.unbound.captionS).tracking(2)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text(timeString)
                    .font(Font.unbound.monoL)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .monospacedDigit()
                Spacer()
                Button("+30s", action: onAddThirty)
                    .font(Font.unbound.captionS).tracking(1)
                    .foregroundStyle(Color.unbound.accent)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.unbound.surfaceElevated)
                    .shadow(color: .black.opacity(0.4), radius: 18, y: 6))
            .overlay(RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.unbound.border, lineWidth: 1))
            .padding(.horizontal, 16)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var timeString: String {
        let m = model.remaining / 60, s = max(0, model.remaining % 60)
        return String(format: "%d:%02d", m, s)
    }
}
