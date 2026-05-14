import SwiftUI

// MARK: - BodyMapView
//
// The character-sheet figure. Swipeable TabView between front and back
// views, each with a body image plus rank-tinted muscle-region overlays.
// The figure is a GAUGE (not an avatar) — static posture, only animation
// is a brief glow-pulse when a lift advances (2s, settles to steady state).

struct BodyMapView: View {
    let regionRanks: [BodyRegion: RegionRank]
    let onRegionTapped: (BodyRegion) -> Void

    @State private var selectedSide: BodyMapSide = .front
    @State private var pulsingRegions: Set<BodyRegion> = []

    var body: some View {
        VStack(spacing: 10) {
            TabView(selection: $selectedSide) {
                figureLayer(side: .front)
                    .tag(BodyMapSide.front)
                figureLayer(side: .back)
                    .tag(BodyMapSide.back)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            // Body image natural aspect ratio is 768x1376 ≈ 0.558.
            // Drive the TabView height from its width so the figure stays
            // sharp and the overlay polygons line up with the real image.
            .aspectRatio(768.0 / 1376.0, contentMode: .fit)

            sideSelector
        }
        .onReceive(NotificationCenter.default.publisher(for: .rankAdvanced)) { note in
            guard let event = note.userInfo?["event"] as? RankAdvance else { return }
            triggerPulse(forExerciseKey: event.exerciseKey)
        }
    }

    // MARK: Layers

    private func figureLayer(side: BodyMapSide) -> some View {
        let imageName = side == .front ? "body_unbound_front" : "body_unbound_back"
        let ranks = BodyRegion.visible(on: side)

        // The overlay is attached to the Image itself, so the GeometryReader
        // inside reports the exact rendered image rect — not the letterboxed
        // container. This keeps muscle polygons aligned to body geometry at
        // any column width.
        return Image(imageName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .overlay {
                GeometryReader { proxy in
                    ZStack {
                        ForEach(ranks, id: \.self) { region in
                            regionOverlay(region: region, side: side, size: proxy.size)
                        }
                    }
                }
            }
    }

    private func regionOverlay(region: BodyRegion, side: BodyMapSide, size: CGSize) -> some View {
        let rank = regionRanks[region]?.rank ?? .eMinus
        let isPulsing = pulsingRegions.contains(region)

        // Fit the shape into the image bounds — image uses scaledToFit so the
        // visible image occupies the full frame height (portrait crop).
        return MuscleRegionShape(region: region, side: side)
            .fill(rank.regionTint.opacity(isPulsing ? 1.0 : 0.70))
            .overlay(
                MuscleRegionShape(region: region, side: side)
                    .stroke(rank.regionTint.opacity(0.9), lineWidth: 1)
            )
            .shadow(
                color: rank.regionTint.opacity(isPulsing ? 0.9 : 0.35),
                radius: isPulsing ? 12 : (rank.ordinal >= SubRank.aMinus.ordinal ? 6 : 0)
            )
            .frame(width: size.width, height: size.height)
            .scaleEffect(isPulsing ? 1.06 : 1.0)
            .contentShape(MuscleRegionShape(region: region, side: side))
            .onTapGesture {
                UnboundHaptics.medium()
                onRegionTapped(region)
            }
            .animation(.easeInOut(duration: 0.45), value: isPulsing)
    }

    // MARK: Side selector

    private var sideSelector: some View {
        HStack(spacing: 4) {
            sideButton(title: "FRONT", side: .front)
            sideButton(title: "BACK", side: .back)
        }
        .padding(3)
        .fixedSize(horizontal: true, vertical: false)
        .background(
            Capsule().fill(Color.unbound.surface)
        )
        .overlay(
            Capsule().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private func sideButton(title: String, side: BodyMapSide) -> some View {
        Button {
            UnboundHaptics.soft()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selectedSide = side
            }
        } label: {
            Text(title)
                .font(Font.unbound.captionS.weight(.bold))
                .tracking(1.6)
                .foregroundStyle(selectedSide == side ? Color.unbound.textPrimary : Color.unbound.textTertiary)
                .fixedSize(horizontal: true, vertical: false)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(selectedSide == side ? Color.unbound.accent.opacity(0.25) : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: Pulse trigger

    private func triggerPulse(forExerciseKey key: String) {
        // Find every region whose contributing lifts include this key.
        let affected: [BodyRegion] = BodyRegion.allCases.filter { region in
            region.contributingLifts.contains { canonical in
                key.contains(canonical) || canonical.contains(key)
            }
        }
        guard !affected.isEmpty else { return }

        withAnimation(.easeOut(duration: 0.3)) {
            pulsingRegions.formUnion(affected)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeIn(duration: 0.45)) {
                pulsingRegions.subtract(affected)
            }
        }
    }
}

#Preview {
    let sample: [BodyRegion: RegionRank] = [
        .chest: RegionRank(region: .chest, rank: .bPlus, topContributingLifts: [], needsWork: false),
        .shoulders: RegionRank(region: .shoulders, rank: .aMinus, topContributingLifts: [], needsWork: false),
        .biceps: RegionRank(region: .biceps, rank: .cPlus, topContributingLifts: [], needsWork: false),
        .abs: RegionRank(region: .abs, rank: .sMinus, topContributingLifts: [], needsWork: false),
        .quads: RegionRank(region: .quads, rank: .dPlus, topContributingLifts: [], needsWork: true),
        .calves: RegionRank(region: .calves, rank: .eMinus, topContributingLifts: [], needsWork: true),
        .lats: RegionRank(region: .lats, rank: .b, topContributingLifts: [], needsWork: false)
    ]
    return BodyMapView(regionRanks: sample, onRegionTapped: { _ in })
        .background(Color.unbound.bg)
}
