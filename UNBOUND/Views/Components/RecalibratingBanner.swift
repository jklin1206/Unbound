import SwiftUI

// MARK: - RecalibratingBanner
//
// Thin HUD-styled banner shown when `unbound.isRecalibrating` is set
// (days 7+ since last session). Dismissible per session — reappears until
// the user logs again (which RankDecayService.clearRecalibration() clears).

struct RecalibratingBanner: View {
    @State private var isDismissed: Bool = false
    @AppStorage("unbound.isRecalibrating") private var isRecalibrating: Bool = false

    var body: some View {
        Group {
            if isRecalibrating && !isDismissed {
                bannerBody
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: isDismissed)
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: isRecalibrating)
    }

    private var bannerBody: some View {
        HStack(spacing: 12) {
            ZStack {
                ChamferedRectangle(inset: 2)
                    .stroke(Color.unbound.accent.opacity(0.55), lineWidth: 1)
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.unbound.accent)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text("RECALIBRATING")
                    .font(Font.unbound.monoS)
                    .tracking(1.8)
                    .foregroundStyle(Color.unbound.accent)
                Text("Back in the gym restarts your progression.")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Button {
                UnboundHaptics.soft()
                isDismissed = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
                    .padding(8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            ChamferedRectangle(inset: 6)
                .fill(Color.unbound.surface)
        )
        .overlay(
            ChamferedRectangle(inset: 6)
                .stroke(Color.unbound.accent.opacity(0.35), lineWidth: 1)
        )
    }
}

#Preview {
    VStack {
        RecalibratingBanner()
            .onAppear { UserDefaults.standard.set(true, forKey: "unbound.isRecalibrating") }
        Spacer()
    }
    .padding(16)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.unbound.bg)
}
