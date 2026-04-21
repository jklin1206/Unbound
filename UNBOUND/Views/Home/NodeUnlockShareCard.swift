import SwiftUI

// MARK: - NodeUnlockShareCard
//
// 1080×1920 vertical card for IG Story / TikTok sharing. Rendered via
// ImageRenderer on tap of the Share button in NodeUnlockedOverlay.
//
// Layout (top → bottom):
//   - UNBOUND wordmark + "[ARCHETYPE]" chip
//   - "NODE UNLOCKED" / "MASTERED" / "MYTHIC ACHIEVED" headline
//   - Giant hex badge with node glyph
//   - Node title (display font)
//   - Cluster + tier meta
//   - Gains awarded
//   - Footer: unboundapp.com
//
// Tone: monochrome with impact-violet bloom behind the badge.

struct NodeUnlockShareCard: View {
    let event: NodeUnlockedEvent
    let archetype: Archetype

    var body: some View {
        ZStack {
            // Base
            Color.unbound.bg.ignoresSafeArea()

            // Impact bloom behind badge
            RadialGradient(
                colors: [
                    Color.unbound.impact.opacity(event.node.isMythic ? 0.55 : 0.42),
                    Color.clear
                ],
                center: .center,
                startRadius: 80,
                endRadius: 780
            )

            VStack(spacing: 0) {
                header
                Spacer(minLength: 20)
                headline
                    .padding(.bottom, 40)
                badge
                    .padding(.bottom, 44)
                titleBlock
                Spacer(minLength: 20)
                footer
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 80)
        }
        .frame(width: 1080, height: 1920)
        .background(Color.unbound.bg)
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 12) {
            Text("UNBOUND")
                .font(.system(size: 44, weight: .heavy, design: .monospaced))
                .tracking(8.0)
                .foregroundStyle(Color.unbound.textPrimary)
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.unbound.accent)
                    .frame(width: 8, height: 8)
                Text(archetype.shortName)
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .tracking(4.0)
                    .foregroundStyle(Color.unbound.textSecondary)
            }
        }
    }

    // MARK: Headline chip

    private var headline: some View {
        let headlineText: String = {
            if event.node.isMythic { return "MYTHIC ACHIEVED" }
            if event.newState == .mastered { return "MASTERED" }
            if event.node.isKeystone { return "KEYSTONE UNLOCKED" }
            return "NODE UNLOCKED"
        }()
        let tone: Color = event.node.isMythic || event.newState == .mastered
            ? Color.unbound.impact
            : Color.unbound.accent
        return Text(headlineText)
            .font(.system(size: 28, weight: .black, design: .monospaced))
            .tracking(6)
            .foregroundStyle(tone)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(
                Capsule().fill(tone.opacity(0.16))
            )
            .overlay(
                Capsule().strokeBorder(tone.opacity(0.6), lineWidth: 2)
            )
    }

    // MARK: Badge

    private var badge: some View {
        let size: CGFloat = 480
        return ZStack {
            Hexagon()
                .fill(Color.unbound.surface)
                .frame(width: size, height: size)
            Hexagon()
                .fill(.thinMaterial)
                .opacity(0.14)
                .frame(width: size, height: size)
            Hexagon()
                .strokeBorder(Color.unbound.impact, lineWidth: 6)
                .frame(width: size, height: size)
            Hexagon()
                .strokeBorder(Color.unbound.impact.opacity(0.5), lineWidth: 3)
                .frame(width: size + 60, height: size + 60)
            if event.node.isMythic {
                Hexagon()
                    .strokeBorder(Color.unbound.impact.opacity(0.25), lineWidth: 2)
                    .frame(width: size + 120, height: size + 120)
            }
            Image(systemName: event.newState == .mastered ? "crown.fill" : event.node.glyph)
                .font(.system(size: 180, weight: .semibold))
                .foregroundStyle(Color.unbound.impact)
        }
        .shadow(color: Color.unbound.impact.opacity(0.8), radius: 60)
    }

    // MARK: Title + meta

    private var titleBlock: some View {
        VStack(spacing: 16) {
            Text(event.node.title)
                .font(.system(size: 72, weight: .black, design: .default))
                .foregroundStyle(Color.unbound.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.6)

            Text(event.node.cluster.displayName.uppercased())
                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                .tracking(3.6)
                .foregroundStyle(Color.unbound.textSecondary)

            HStack(spacing: 18) {
                metaChip(label: "TIER", value: "T\(event.node.tier)")
                metaChip(label: "GAINS", value: "+\(event.gainsAwarded)")
            }
            .padding(.top, 12)
        }
    }

    private func metaChip(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .tracking(1.8)
                .foregroundStyle(Color.unbound.textTertiary)
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.unbound.textPrimary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.unbound.border, lineWidth: 1.5)
        )
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Text("unboundapp.com")
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(Color.unbound.textTertiary)
            Spacer()
            Text("Find the body you were built for.")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(Color.unbound.textTertiary)
                .italic()
        }
    }
}

// MARK: - Render helper

enum NodeUnlockShareCardRenderer {
    /// Render a share card to UIImage at the card's natural 1080×1920.
    @MainActor
    static func render(event: NodeUnlockedEvent, archetype: Archetype) -> UIImage? {
        let card = NodeUnlockShareCard(event: event, archetype: archetype)
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 2.0
        renderer.proposedSize = .init(width: 1080, height: 1920)
        return renderer.uiImage
    }

    /// Write the rendered card to a temp file and return its URL, so it
    /// can be passed to UIActivityViewController / ShareLink.
    @MainActor
    static func renderToTempURL(event: NodeUnlockedEvent, archetype: Archetype) -> URL? {
        guard let image = render(event: event, archetype: archetype),
              let data = image.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("unbound-unlock-\(event.node.id)-\(Int(Date().timeIntervalSince1970)).png")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }
}

#Preview("Share card — keystone") {
    NodeUnlockShareCard(
        event: NodeUnlockedEvent(
            node: SkillGraph.shared.node(id: "pp.muscle-up")!,
            newState: .achieved,
            gainsAwarded: 200
        ),
        archetype: .vTaper
    )
    .scaleEffect(0.3)
}

#Preview("Share card — mythic") {
    NodeUnlockShareCard(
        event: NodeUnlockedEvent(
            node: SkillGraph.shared.node(id: "cal.maltese")!,
            newState: .achieved,
            gainsAwarded: 400
        ),
        archetype: .vTaper
    )
    .scaleEffect(0.3)
}
