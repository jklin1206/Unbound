import SwiftUI

// MARK: - UnboundSkillTreeTabView
//
// Full skill tree tab. Renders the universal skill tree with live node
// state from SkillProgressService. Pinch-zoom / scroll navigation.

struct UnboundSkillTreeTabView: View {
    @EnvironmentObject var services: ServiceContainer
    @State private var profile: UserProfile?
    @State private var showCosmetics: Bool = false
    @Bindable private var skillProgress = SkillProgressService.shared
    @StateObject private var skinService = SkinService.shared

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    SkillGraphView(
                        graph: SkillGraph.shared,
                        nodeStates: liveStatesForFullGraph(),
                        nodeProgress: skillProgress.nodeProgress
                    )
                    .padding(.vertical, 4)
                    Spacer().frame(height: 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
        .navigationTitle("Your tree")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    UnboundHaptics.soft()
                    showCosmetics = true
                } label: {
                    Image(systemName: "paintpalette.fill")
                        .foregroundStyle(skinService.currentSkin.primaryColor)
                }
                .accessibilityLabel("Skill tree cosmetics")
                .accessibilityHint("Opens cosmetic themes for the skill tree")
            }
        }
        .task {
            let userId = services.auth.currentUserId ?? "anonymous"
            profile = try? await services.user.fetchProfile(userId: userId)
            await SkillProgressService.shared.load(userId: userId)
        }
        .sheet(isPresented: $showCosmetics) {
            NavigationStack {
                SkinPickerView()
                    .environmentObject(services)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.unbound.bg)
        }
        .skinUnlockToast()
        .task {
            let userId = services.auth.currentUserId ?? "anonymous"
            _ = await skinService.evaluateUnlocks(userId: userId)
        }
    }

    /// Live state from SkillProgressService, with all nodes defaulting to
    /// .locked when no state has been recorded yet. Operates over the full
    /// SkillGraph (universal — same tree for everyone).
    private func liveStatesForFullGraph() -> [String: NodeState] {
        var states = skillProgress.nodeStates
        for node in SkillGraph.shared.nodes where states[node.id] == nil {
            states[node.id] = .locked
        }
        return states
    }
}

// Legacy `SkillNodeDetailSheet` removed in Phase 3a — the unified
// `RankDetailView` replaces it. Presenters now use `.fullScreenCover(item:)`.
