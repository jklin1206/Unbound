import SwiftUI

// MARK: - NodeUnlockedOverlay
//
// Full-screen takeover that plays when a skill tree node flips to
// `.achieved` or `.mastered`. Driven by SkillProgressService.pendingUnlock.
//
// Sequence:
//   1. Black scrim fades in
//   2. Hexagon blooms from 0 scale with violet glow + heavy haptic
//   3. "NODE UNLOCKED" label fades in, then node title
//   4. "+X Gains" ticker counts up
//   5. Tap anywhere OR "Continue" dismisses

struct NodeUnlockedOverlay: View {
    let event: NodeUnlockedEvent
    let onDismiss: () -> Void

    @State private var shareURL: URL?
    @State private var isPreparingShare = false

    @State private var scrimOpacity: Double = 0
    @State private var badgeScale: CGFloat = 0.1
    @State private var labelOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var gainsDisplay: Int = 0

    // Shockwave ripple — 3 concentric rings expanding from center after the
    // badge lands. Each tracked independently so they stagger.
    @State private var shock1Radius: CGFloat = 0
    @State private var shock1Opacity: Double = 0
    @State private var shock2Radius: CGFloat = 0
    @State private var shock2Opacity: Double = 0
    @State private var shock3Radius: CGFloat = 0
    @State private var shock3Opacity: Double = 0

    var body: some View {
        ZStack {
            // Scrim
            Color.unbound.bg
                .opacity(scrimOpacity)
                .ignoresSafeArea()

            // Radial impact-violet bloom behind badge
            RadialGradient(
                colors: [Color.unbound.impact.opacity(0.45), Color.clear],
                center: .center,
                startRadius: 20,
                endRadius: 420
            )
            .ignoresSafeArea()
            .opacity(scrimOpacity)

            // Shockwave rings — fire ~0.7s after scrim lands, staggered.
            ZStack {
                Circle()
                    .stroke(Color.unbound.impact.opacity(shock1Opacity), lineWidth: 2.5)
                    .frame(width: shock1Radius, height: shock1Radius)
                Circle()
                    .stroke(Color.unbound.impact.opacity(shock2Opacity), lineWidth: 2)
                    .frame(width: shock2Radius, height: shock2Radius)
                Circle()
                    .stroke(Color.unbound.accent.opacity(shock3Opacity), lineWidth: 1.5)
                    .frame(width: shock3Radius, height: shock3Radius)
            }
            .allowsHitTesting(false)

            VStack(spacing: 28) {
                // Chip label
                Text(event.newState == .mastered ? "MASTERED" : "NODE UNLOCKED")
                    .font(Font.unbound.captionS)
                    .tracking(2.0)
                    .foregroundStyle(Color.unbound.impact)
                    .opacity(labelOpacity)

                // Hex badge with node glyph
                ZStack {
                    Hexagon()
                        .fill(Color.unbound.surface)
                        .frame(width: 180, height: 180)
                    Hexagon()
                        .fill(.thinMaterial)
                        .opacity(0.12)
                        .frame(width: 180, height: 180)
                    Hexagon()
                        .strokeBorder(Color.unbound.impact, lineWidth: 2.5)
                        .frame(width: 180, height: 180)
                    Hexagon()
                        .strokeBorder(Color.unbound.impact.opacity(0.4), lineWidth: 1)
                        .frame(width: 210, height: 210)

                    glyph
                        .font(.system(size: 64, weight: .semibold))
                        .foregroundStyle(Color.unbound.impact)
                }
                .scaleEffect(badgeScale)
                .shadow(color: Color.unbound.impact.opacity(0.7), radius: 30, x: 0, y: 0)

                // Node title
                VStack(spacing: 8) {
                    Text(event.node.title)
                        .font(Font.unbound.displayM)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 24)
                    Text(event.node.subtitle)
                        .font(Font.unbound.bodyM)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .opacity(titleOpacity)

                // Gains
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .semibold))
                    Text("+\(gainsDisplay) Gains")
                        .font(Font.unbound.monoL)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(gainsDisplay)))
                }
                .foregroundStyle(Color.unbound.accent)
                .opacity(titleOpacity)

                Spacer().frame(height: 20)

                VStack(spacing: 10) {
                    UnboundButton(title: "Continue", icon: "arrow.right", action: onDismiss)
                    shareButton
                }
                .padding(.horizontal, 20)
                .opacity(titleOpacity)
            }
        }
        .onAppear { animate() }
        .onTapGesture {
            // Tap-to-dismiss only in empty areas — button hit-testing
            // handles its own gesture. If the share sheet is up, ignore.
            guard !isPreparingShare else { return }
            onDismiss()
        }
    }

    // MARK: Share

    @ViewBuilder
    private var shareButton: some View {
        if let url = shareURL {
            ShareLink(item: url, preview: SharePreview(
                "\(event.node.title) unlocked on UNBOUND",
                image: Image(systemName: "sparkles")
            )) {
                shareButtonLabel
            }
            .buttonStyle(.plain)
        } else {
            Button {
                Task { await prepareShare() }
            } label: {
                shareButtonLabel
            }
            .buttonStyle(.plain)
            .disabled(isPreparingShare)
        }
    }

    private var shareButtonLabel: some View {
        HStack(spacing: 10) {
            if isPreparingShare {
                ProgressView()
                    .tint(Color.unbound.textSecondary)
            } else {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .semibold))
            }
            Text(isPreparingShare ? "Preparing…" : (shareURL == nil ? "Share" : "Tap to share"))
                .font(Font.unbound.bodyMStrong)
        }
        .foregroundStyle(Color.unbound.textSecondary)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .overlay(
            Capsule()
                .strokeBorder(Color.unbound.border, lineWidth: 1)
        )
    }

    @MainActor
    private func prepareShare() async {
        isPreparingShare = true
        // Render off the main-render-loop tick to avoid jank.
        await Task.yield()
        let url = NodeUnlockShareCardRenderer.renderToTempURL(
            event: event
        )
        shareURL = url
        isPreparingShare = false
    }

    private var glyph: some View {
        Image(systemName: event.newState == .mastered ? "crown.fill" : iconForType)
    }

    private var iconForType: String {
        if event.node.isMythic { return "star.circle.fill" }
        if event.node.isKeystone { return "shield.lefthalf.filled" }
        switch event.node.type {
        case .strength: return "dumbbell.fill"
        case .skill:    return "figure.strengthtraining.functional"
        case .hold:     return "figure.mind.and.body"
        }
    }

    private func animate() {
        UnboundHaptics.heavy()

        withAnimation(.easeOut(duration: 0.35)) {
            scrimOpacity = 0.96
        }

        withAnimation(.spring(response: 0.55, dampingFraction: 0.62).delay(0.15)) {
            badgeScale = 1.0
        }

        // Shockwave — three staggered rings after the badge lands.
        // Ring 1 fires at t=0.7s, ring 2 at 0.85s, ring 3 at 1.0s.
        fireShockRing(delay: 0.70, targetRadius: 720, toOpacity: 0.65,
                      bindRadius: { shock1Radius = $0 },
                      bindOpacity: { shock1Opacity = $0 })
        fireShockRing(delay: 0.85, targetRadius: 780, toOpacity: 0.4,
                      bindRadius: { shock2Radius = $0 },
                      bindOpacity: { shock2Opacity = $0 })
        fireShockRing(delay: 1.00, targetRadius: 840, toOpacity: 0.25,
                      bindRadius: { shock3Radius = $0 },
                      bindOpacity: { shock3Opacity = $0 })

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            UnboundHaptics.heavy()
            withAnimation(.easeOut(duration: 0.4)) {
                labelOpacity = 1.0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.4)) {
                titleOpacity = 1.0
            }

            // Gains count-up
            let target = event.gainsAwarded
            let ticks = 40
            for i in 1...ticks {
                let delay = 1.1 + Double(i) * 0.025
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    gainsDisplay = Int(Double(target) * Double(i) / Double(ticks))
                }
            }
        }
    }

    /// Fires one ring of the shockwave. `bindRadius`/`bindOpacity` are state
    /// writers; animation goes from 0 → targetRadius and initial → 0 opacity
    /// over 0.85s.
    private func fireShockRing(
        delay: Double,
        targetRadius: CGFloat,
        toOpacity startOpacity: Double,
        bindRadius: @escaping (CGFloat) -> Void,
        bindOpacity: @escaping (Double) -> Void
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            bindOpacity(startOpacity)
            bindRadius(40)
            withAnimation(.easeOut(duration: 0.85)) {
                bindRadius(targetRadius)
                bindOpacity(0)
            }
        }
        // Gentle haptic blip on ring 1 only
        if delay < 0.75 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.02) {
                UnboundHaptics.medium()
            }
        }
    }
}

// MARK: - NodeUnlockedOverlayModifier

extension View {
    /// Attaches the unlock overlay, driven by SkillProgressService's
    /// `pendingUnlock`. Put this on a top-level view (home, tree tab).
    @MainActor
    func nodeUnlockOverlay(
        service: SkillProgressService? = nil
    ) -> some View {
        modifier(NodeUnlockedOverlayModifier(
            service: service ?? SkillProgressService.shared
        ))
    }
}

private struct NodeUnlockedOverlayModifier: ViewModifier {
    @Bindable var service: SkillProgressService

    func body(content: Content) -> some View {
        content
            .overlay {
                if let event = service.pendingUnlock {
                    NodeUnlockedOverlay(event: event) {
                        withAnimation(.easeOut(duration: 0.35)) {
                            service.clearPendingUnlock()
                        }
                    }
                    .transition(.opacity)
                    .zIndex(100)
                }
            }
            .animation(.easeOut(duration: 0.35), value: service.pendingUnlock?.id)
    }
}
