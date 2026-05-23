import SwiftUI

// MARK: - ScanConsentModal
//
// Shown ONCE, the first time a user attempts a bi-weekly scan. Explains
// that the photo goes to Anthropic's Claude for coach-style analysis. User
// accepts → persisted in @AppStorage("unbound.scanConsentGranted"). No
// re-prompt on subsequent scans or failure retries.

struct ScanConsentModal: View {
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                Spacer().frame(height: 12)

                ZStack {
                    Circle()
                        .fill(Color.unbound.accent.opacity(0.15))
                    Image(systemName: "sparkle.magnifyingglass")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color.unbound.accent)
                }
                .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 10) {
                    Text("BODY READ · HOW IT WORKS")
                        .font(Font.unbound.captionS.weight(.bold))
                        .tracking(1.8)
                        .foregroundStyle(Color.unbound.accent)

                    Text("Your scan photo is sent to Anthropic's Claude for a 3-sentence coach read.")
                        .font(Font.unbound.titleM)
                        .tracking(0.3)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 12) {
                    bullet(
                        icon: "checkmark",
                        title: "Qualitative only",
                        body: "No body-fat %, no measurements, no medical claims."
                    )
                    bullet(
                        icon: "lock.shield",
                        title: "Delete anytime",
                        body: "Clear all scan analyses from Settings → Privacy."
                    )
                    bullet(
                        icon: "camera",
                        title: "Your choice",
                        body: "Skip this and use plain daily photos instead."
                    )
                }

                Spacer()

                VStack(spacing: 10) {
                    Button {
                        UnboundHaptics.medium()
                        onAccept()
                    } label: {
                        HStack(spacing: 10) {
                            Text("ACCEPT & CONTINUE")
                                .font(Font.unbound.bodyMStrong)
                                .tracking(1.6)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundStyle(Color.unbound.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.unbound.accent)
                        )
                        .shadow(color: Color.unbound.accent.opacity(0.45), radius: 14, y: 2)
                    }
                    .buttonStyle(.plain)

                    Button {
                        UnboundHaptics.soft()
                        onDecline()
                    } label: {
                        Text("NOT NOW")
                            .font(Font.unbound.captionS.weight(.bold))
                            .tracking(1.4)
                            .foregroundStyle(Color.unbound.textTertiary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
        }
    }

    private func bullet(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.unbound.accent)
                .frame(width: 20, alignment: .leading)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text(body)
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
