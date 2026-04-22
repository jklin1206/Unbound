import SwiftUI

// MARK: - BodyTierLoaderView
//
// Async-loading wrapper around BodyTierView. Pulls the latest scan via
// BodyTierLoader. Renders a loading spinner while fetching, an empty
// state if the user hasn't scanned yet, otherwise BodyTierView with
// real tier states.

struct BodyTierLoaderView: View {
    @EnvironmentObject var services: ServiceContainer
    @State private var states: [MuscleGroupTierState] = []
    @State private var isLoading = true
    @State private var hasScan = false

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView().tint(Color.unbound.accent)
                    Text("Reading your last scan…")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.unbound.bg.ignoresSafeArea())
            } else if !hasScan {
                emptyState
            } else {
                BodyTierView(states: states)
            }
        }
        .task { await load() }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "figure.stand")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundStyle(Color.unbound.textTertiary)
            Text("No scan on file")
                .font(Font.unbound.titleM)
                .foregroundStyle(Color.unbound.textPrimary)
            Text("Complete a body scan to see your per-muscle tier ranks.")
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.unbound.bg.ignoresSafeArea())
        .navigationTitle("Body")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func load() async {
        let userId = services.auth.currentUserId ?? "anonymous"
        let loaded = await BodyTierLoader.loadLatest(userId: userId)
        states = loaded
        hasScan = !loaded.isEmpty
        isLoading = false
    }
}
