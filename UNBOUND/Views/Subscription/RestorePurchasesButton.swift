import SwiftUI

struct RestorePurchasesButton: View {
    @EnvironmentObject private var services: ServiceContainer
    @State private var isRestoring = false
    @State private var restoreResult: String?

    var body: some View {
        VStack(spacing: 8) {
            Button {
                Task { await restore() }
            } label: {
                HStack(spacing: 8) {
                    if isRestoring {
                        ProgressView()
                            .tint(Color.unbound.accent)
                    } else {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14, weight: .semibold))
                    }

                    Text(isRestoring ? restoringTitle : idleTitle)
                        .font(Font.unbound.bodyM)
                }
                .foregroundStyle(Color.unbound.textSecondary)
            }
            .buttonStyle(.plain)
            .disabled(isRestoring)

            if let restoreResult {
                Text(restoreResult)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: restoreResult)
    }

    private func restore() async {
        guard !isRestoring else { return }
        isRestoring = true
        defer { isRestoring = false }

        do {
            _ = try await services.subscription.restorePurchases()
            restoreResult = services.subscription.isSubscribed
                ? L10n.string(.subscriptionRestoreSuccess, defaultValue: "Restored. Loading UNBOUND...")
                : L10n.string(.subscriptionRestoreNoActive, defaultValue: "No active subscription found.")
        } catch {
            restoreResult = L10n.string(.subscriptionRestoreFailure, defaultValue: "Couldn't restore. Try again.")
        }
    }

    private var idleTitle: String {
        L10n.string(.subscriptionRestoreIdle, defaultValue: "Restore purchases")
    }

    private var restoringTitle: String {
        L10n.string(.subscriptionRestoreRestoring, defaultValue: "Restoring...")
    }
}
