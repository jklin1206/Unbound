import SwiftUI
import UIKit

// MARK: - RankUpCinematic
//
// Full-screen takeover presented as a fullScreenCover when a
// `.rankAdvanced` event fires. Beat timeline (~3s):
//   0.0-0.3s: flash + heavy haptic
//   0.3-0.8s: speed lines burst from center
//   0.8-1.8s: "RANK UP" mono slides up, big rank display glows in
//   1.8-2.5s: exercise display name fades in below
//   2.5-3.0s: "Tap to share" hint, then auto-dismiss
//
// Tap anywhere → open system share sheet with the rendered share card.
// Auto-dismiss after 3s even without a tap.

struct RankUpCinematic: View {
    let advance: RankAdvance
    let buildIdentity: BuildIdentity
    let onDismiss: () -> Void

    @State private var showFlash: Bool = false
    @State private var showSpeedLines: Bool = false
    @State private var showRank: Bool = false
    @State private var showExerciseLabel: Bool = false
    @State private var showShareCard: Bool = false
    @State private var showShareHint: Bool = false
    @State private var speedLinesTrigger: UUID = UUID()
    @State private var dismissScheduled: Bool = false
    @State private var shareSheetItems: [Any]?
    @State private var glowPulse: Bool = false

    private let totalDuration: Double = 3.4

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            // Beat 1 — white flash
            if showFlash {
                Color.white
                    .opacity(0.9)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            // Beat 2 — speed lines
            if showSpeedLines {
                SpeedLines(
                    count: 44,
                    length: 220,
                    innerRadius: 80,
                    color: rankGlow,
                    burstDuration: 0.7,
                    trigger: speedLinesTrigger
                )
                .ignoresSafeArea()
            }

            // Radial glow behind the rank
            if showRank {
                RadialGradient(
                    colors: [rankGlow.opacity(0.45), Color.clear],
                    center: .center,
                    startRadius: 10,
                    endRadius: 320
                )
                .scaleEffect(glowPulse ? 1.15 : 0.9)
                .ignoresSafeArea()
                .blendMode(.screen)
            }

            VStack(spacing: 14) {
                Spacer()

                if showRank {
                    Text("RANK UP")
                        .font(Font.unbound.monoM)
                        .tracking(3.2)
                        .foregroundStyle(rankGlow)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if showRank {
                    VStack(spacing: 12) {
                        Image(targetTitle.assetName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 156, height: 156)
                            .shadow(color: rankGlow.opacity(0.72), radius: 28)
                            .shadow(color: rankGlow.opacity(0.36), radius: 60)

                        Text(targetTitle.displayName.uppercased())
                            .font(.system(size: 48, weight: .black, design: .default))
                            .tracking(2.0)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.58)
                    }
                    .scaleEffect(showRank ? 1.0 : 0.6)
                    .transition(.scale.combined(with: .opacity))
                }

                if showExerciseLabel {
                    Text(advance.displayName.uppercased())
                        .font(Font.unbound.titleM)
                        .tracking(1.6)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .padding(.top, 4)
                        .transition(.opacity)
                }

                Spacer()

                if showShareCard {
                    shareCardPreview
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                        .padding(.horizontal, 48)
                }

                if showShareHint {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 12, weight: .semibold))
                        Text("TAP CARD TO SHARE")
                            .font(Font.unbound.monoS)
                            .tracking(2.2)
                    }
                    .foregroundStyle(Color.unbound.textTertiary)
                    .padding(.top, 14)
                    .padding(.bottom, 40)
                    .transition(.opacity)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Tapping outside the card dismisses. The card itself handles
            // tap-to-share below.
            if !showShareCard {
                onDismiss()
            }
        }
        .task {
            runBeats()
        }
        .sheet(isPresented: Binding(
            get: { shareSheetItems != nil },
            set: { if !$0 { shareSheetItems = nil } }
        )) {
            if let items = shareSheetItems {
                ShareSheet(items: items)
            }
        }
    }

    private var shareCardPreview: some View {
        Button {
            presentShare()
        } label: {
            RankUpShareCard(
                rank: advance.toRank,
                exerciseDisplayName: advance.displayName,
                buildIdentity: buildIdentity,
                skin: SkinService.shared.currentSkin
            )
            .scaleEffect(0.18)
            .frame(width: 1080 * 0.18, height: 1620 * 0.18)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(rankGlow.opacity(0.55), lineWidth: 1)
            )
            .shadow(color: rankGlow.opacity(0.45), radius: 24)
        }
        .buttonStyle(.plain)
    }

    // MARK: Beats

    private func runBeats() {
        // 0.0 — flash + heavy haptic
        withAnimation(.easeOut(duration: 0.15)) { showFlash = true }
        UnboundHaptics.heavy()

        // 0.3 — speed lines burst
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.2)) { showFlash = false }
            speedLinesTrigger = UUID()
            showSpeedLines = true
            UnboundHaptics.heavy()
        }

        // 0.8 — rank display in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                showRank = true
            }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
            UnboundHaptics.medium()
        }

        // 1.8 — exercise name in
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeOut(duration: 0.35)) {
                showExerciseLabel = true
            }
        }

        // 2.2 — share card materializes below the rank
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                showShareCard = true
            }
            UnboundHaptics.soft()
        }

        // 2.5 — instruction text
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showShareHint = true
            }
        }

        // 3.4 — auto-dismiss if user didn't tap
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration) {
            guard !dismissScheduled else { return }
            guard shareSheetItems == nil else { return } // share sheet kept us alive
            dismissScheduled = true
            onDismiss()
        }
    }

    private func presentShare() {
        guard !dismissScheduled else { return }
        guard let image = RankUpShareCardRenderer.render(
            rank: advance.toRank,
            exerciseDisplayName: advance.displayName,
            buildIdentity: buildIdentity
        ) else {
            onDismiss()
            return
        }
        let caption = RankUpShareCardRenderer.caption(
            rank: advance.toRank,
            exerciseDisplayName: advance.displayName
        )
        shareSheetItems = [image, caption]
    }

    private var targetTitle: RankTitle {
        advance.toRank
    }

    /// Skin-driven glow matched to the actual named rank badge.
    private var rankGlow: Color {
        targetTitle.rewardTint
    }
}

// MARK: - Share sheet bridge

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

// MARK: - TierCinematicView
//
// Full-screen cinematic for flagship SkillTier crossings (Vessel / Unbound /
// Ascendant). Uses chain-motif hero art as a Ken Burns background.
//
// Beat timeline (~5s):
//   0.0–0.6s: tier art fades/zooms in, content fades in at 0.3s delay
//   0.6–5.0s: slow Ken Burns zoom continues (scale 1.0 → 1.15)
//   5.0s: auto-dismiss (tappable to dismiss earlier)

struct TierCinematicView: View {
    let advance: SkillTierAdvance
    let onDismiss: () -> Void

    @State private var imageScale: CGFloat = 1.0
    @State private var contentOpacity: Double = 0.0
    @State private var dismissScheduled: Bool = false

    var body: some View {
        ZStack {
            // Full-screen tier art with Ken Burns zoom
            Image(assetName(for: advance.to))
                .resizable()
                .scaledToFill()
                .scaleEffect(imageScale)
                .clipped()
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.35))

            // Content overlay
            VStack(spacing: 24) {
                Spacer()
                Spacer()

                Text(advance.to.displayName.uppercased())
                    .font(.system(size: 56, weight: .black, design: .default))
                    .tracking(4)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 8)

                Rectangle()
                    .fill(Color.unbound.accent)
                    .frame(width: 60, height: 2)

                Text(skillTitle.uppercased())
                    .font(.system(size: 14, weight: .heavy, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(.white.opacity(0.85))

                Spacer()

                Button("TAP TO DISMISS") {
                    dismiss()
                }
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.55))
                .padding(.bottom, 60)
            }
            .opacity(contentOpacity)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { dismiss() }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .task {
            // Ken Burns slow zoom-in over 5 seconds
            withAnimation(.easeOut(duration: 5.0)) {
                imageScale = 1.15
            }
            withAnimation(.easeIn(duration: 0.6).delay(0.3)) {
                contentOpacity = 1.0
            }
            UnboundHaptics.heavy()

            // Auto-dismiss after 5s if user hasn't tapped
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                guard !dismissScheduled else { return }
                dismissScheduled = true
                onDismiss()
            }
        }
    }

    private var skillTitle: String {
        SkillGraph.shared.nodes
            .first(where: { $0.id == advance.skillId })?.title
            ?? advance.skillId
    }

    private func dismiss() {
        guard !dismissScheduled else { return }
        dismissScheduled = true
        onDismiss()
    }

    /// Maps a flagship SkillTier to its cinematic hero art asset name.
    /// SkillTier.rawValue is Int, so we use a switch rather than string interpolation.
    private func assetName(for tier: SkillTier) -> String {
        switch tier {
        case .vessel:    return "cinematic_vessel"
        case .unbound:   return "cinematic_unbound"
        case .ascendant: return "cinematic_ascendant"
        default:         return "cinematic_vessel" // fallback — gate ensures never reached
        }
    }
}

// MARK: - Root-level presentation modifier
//
// Attach once at the top of your view hierarchy. Listens for
// `.rankAdvanced` notifications and presents the cinematic as a
// fullScreenCover regardless of which tab the user is on.

struct RankUpCinematicPresenter: ViewModifier {
    @State private var pending: RankAdvance?
    /// Pending flagship SkillTierAdvance (Vessel/Unbound/Ascendant). These
    /// trigger the chain-shatter cinematic. Non-flagship advances use the
    /// quiet TierBloomToast instead.
    @State private var pendingTier: SkillTierAdvance?
    @EnvironmentObject private var services: ServiceContainer
    @State private var buildIdentity: BuildIdentity = BuildIdentity(primary: nil, secondary: nil, shape: .balancedAthlete)

    func body(content: Content) -> some View {
        content
            .task {
                await loadBuildIdentity()
            }
            .onReceive(NotificationCenter.default.publisher(for: .rankAdvanced)) { note in
                guard let event = note.userInfo?["event"] as? RankAdvance else { return }
                pending = event
            }
            .onReceive(NotificationCenter.default.publisher(for: .skillTierAdvanced)) { note in
                guard let advance = note.object as? SkillTierAdvance else { return }
                // Only Vessel/Unbound/Ascendant crossings trigger the full
                // chain-shatter cinematic. Lower-tier advances use TierBloomToast.
                guard advance.isFlagship else { return }
                pendingTier = advance
            }
            // Attribute rank-ups (BuildIdentity axes) — unchanged path
            .fullScreenCover(item: Binding(
                get: { pending },
                set: { if $0 == nil { pending = nil } }
            )) { advance in
                RankUpCinematic(
                    advance: advance,
                    buildIdentity: buildIdentity,
                    onDismiss: { pending = nil }
                )
            }
            // Flagship SkillTier crossings — TierCinematicView with hero art
            .fullScreenCover(item: Binding(
                get: { pendingTier },
                set: { if $0 == nil { pendingTier = nil } }
            )) { tierAdvance in
                TierCinematicView(
                    advance: tierAdvance,
                    onDismiss: { pendingTier = nil }
                )
            }
    }

    private func loadBuildIdentity() async {
        let userId = services.auth.currentUserId ?? "anonymous"
        buildIdentity = services.attribute.snapshot(userId: userId, asOf: Date.now).buildIdentity
    }
}

extension View {
    /// Mount the rank-up cinematic presenter near the root. Must be inside
    /// a `ServiceContainer` environment.
    func rankUpCinematicOverlay() -> some View {
        modifier(RankUpCinematicPresenter())
    }
}
