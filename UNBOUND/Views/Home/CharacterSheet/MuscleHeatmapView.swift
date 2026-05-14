import SwiftUI

// MARK: - MuscleHeatmapView
//
// Vector muscle heatmap. Each muscle group is one or more SwiftUI `Path`
// objects parsed from `body_paths.json` (sourced from react-native-body-
// highlighter, MIT license). No PNG, no cream plate, no raster+polygon
// hybrid. Muscles are native Shapes that tint cleanly on any background.
//
// Rendering stack, from bottom to top:
//   1. Decorative parts (head, hair, neck, hands, feet, ankles, knees) as
//      a dim silhouette fill — keeps the body silhouette legible even when
//      no muscle is highlighted.
//   2. Muscle parts filled with their rank tint. Unranked groups fall back
//      to E-tier red so every muscle always reads as "something."
//   3. Thin stroke on every path for anatomical definition.

struct MuscleHeatmapView: View {
    let groupRanks: [MuscleHeatGroup: SubRank]
    let overlayProfile: BodyOverlayProfile
    let onGroupTapped: (MuscleHeatGroup) -> Void

    @State private var selectedSide: BodyMapSide = .front
    @State private var selectedGroup: MuscleHeatGroup?
    @State private var pulsingGroups: Set<MuscleHeatGroup> = []
    @State private var breathingScale: CGFloat = 1.0

    init(
        groupRanks: [MuscleHeatGroup: SubRank],
        overlayProfile: BodyOverlayProfile = .unboundV2,
        onGroupTapped: @escaping (MuscleHeatGroup) -> Void
    ) {
        self.groupRanks = groupRanks
        self.overlayProfile = overlayProfile
        self.onGroupTapped = onGroupTapped
    }

    private var bodyPaths: BodyPaths { BodyPaths.load(profile: overlayProfile) }
    private var usesUnboundRegionOverlay: Bool { overlayProfile == .unboundV2 }

    var body: some View {
        let aspect: CGFloat = usesUnboundRegionOverlay
            ? (768.0 / 1376.0)
            : (max(bodyPaths.frontViewBox.width, bodyPaths.backViewBox.width) /
               max(bodyPaths.frontViewBox.height, bodyPaths.backViewBox.height))
        return VStack(spacing: 10) {
            ZStack {
                bodyFigure(side: .front).opacity(selectedSide == .front ? 1 : 0)
                bodyFigure(side: .back).opacity(selectedSide == .back ? 1 : 0)
            }
            .aspectRatio(aspect, contentMode: .fit)
            .scaleEffect(breathingScale)
            .drawingGroup()
            .animation(.easeInOut(duration: 0.25), value: selectedSide)

            sideSelector
        }
        .onAppear {
            // Idle breathing: ~2.2% scale oscillation over 3s. Perceptible
            // but not distracting — the figure reads as alive instead of
            // static paint.
            guard breathingScale == 1.0 else { return }
            // Delay a beat so the onAppear animation doesn't race the
            // parent view's initial layout.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                    breathingScale = 1.022
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .rankAdvanced)) { note in
            guard let event = note.userInfo?["event"] as? RankAdvance else { return }
            triggerPulse(forExerciseKey: event.exerciseKey)
        }
    }

    // MARK: Figure

    private func bodyFigure(side: BodyMapSide) -> some View {
        if usesUnboundRegionOverlay {
            return AnyView(bodyFigureUnbound(side: side))
        }
        return AnyView(bodyFigureLegacy(side: side))
    }

    private func bodyFigureLegacy(side: BodyMapSide) -> some View {
        let parts = bodyPaths.parts(for: side)
        let viewBox = bodyPaths.viewBox(for: side)
        let transform = overlayProfile.overlayTransform(for: side)

        return ZStack {
            customBodyBase(side: side)
            figureAtmosphere(parts: parts, viewBox: viewBox)
                .scaleEffect(transform.scale)
                .offset(x: transform.x, y: transform.y)

            ForEach(parts.filter { !$0.isDecorative }) { part in
                if let group = part.heatGroup {
                    let rank = groupRanks[group] ?? .eMinus
                    let isPulsing = pulsingGroups.contains(group)
                    let isSelected = selectedGroup == group
                    let tint = rank.regionTint
                    let shape = muscleShape(part: part, viewBox: viewBox)

                    shape
                        .fill(muscleFill(for: rank, isSelected: isSelected, isPulsing: isPulsing))
                        .overlay(shape.fill(muscleTopLight(for: rank)))
                        .overlay(shape.fill(muscleCoreAura(for: rank, isSelected: isSelected || isPulsing)))
                        .overlay(
                            shape.stroke(Color.black.opacity(isSelected ? 0.74 : 0.30), lineWidth: isSelected ? 1.8 : 0.65)
                        )
                        .overlay(
                            shape.stroke(
                                tint.opacity(isSelected || isPulsing ? 1.0 : 0.48),
                                lineWidth: isSelected || isPulsing ? 1.35 : 0.55
                            )
                        )
                        .shadow(
                            color: tint.opacity(isSelected || isPulsing ? 0.82 : 0.30),
                            radius: isSelected || isPulsing ? 12 : rankGlowRadius(for: rank),
                            x: 0,
                            y: 0
                        )
                        .scaleEffect(isPulsing ? 1.025 : (isSelected ? 1.018 : 1.0))
                        .contentShape(shape)
                        .onTapGesture {
                            UnboundHaptics.medium()
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                                selectedGroup = group
                            }
                            onGroupTapped(group)
                        }
                        .animation(.easeInOut(duration: 0.4), value: isPulsing)
                        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: selectedGroup)
                }
            }
            .scaleEffect(transform.scale)
                .offset(x: transform.x, y: transform.y)
        }
    }

    private func bodyFigureUnbound(side: BodyMapSide) -> some View {
        let regions = BodyRegion.visible(on: side)
        let transform = overlayProfile.overlayTransform(for: side)

        return ZStack {
            customBodyBase(side: side)
            unboundFigureAtmosphere(regions: regions, side: side)
                .scaleEffect(transform.scale)
                .offset(x: transform.x, y: transform.y)

            ForEach(regions, id: \.self) { region in
                let group = region.heatGroup
                let rank = groupRanks[group] ?? .eMinus
                let isPulsing = pulsingGroups.contains(group)
                let isSelected = selectedGroup == group
                let tint = rank.regionTint
                let shape = MuscleRegionShape(region: region, side: side)

                shape
                    .fill(unboundPanelFill(for: rank, isSelected: isSelected, isPulsing: isPulsing))
                    .overlay(
                        shape.stroke(Color.black.opacity(isSelected ? 0.58 : 0.20), lineWidth: isSelected ? 1.2 : 0.45)
                    )
                    .overlay(
                        shape.stroke(
                            tint.opacity(isSelected || isPulsing ? 0.95 : unboundPanelStrokeOpacity(for: rank)),
                            lineWidth: isSelected || isPulsing ? 1.25 : 0.55
                        )
                    )
                    .shadow(
                        color: tint.opacity(isSelected || isPulsing ? 0.72 : unboundPanelGlowOpacity(for: rank)),
                        radius: isSelected || isPulsing ? 10 : unboundPanelGlowRadius(for: rank),
                        x: 0,
                        y: 0
                    )
                    .scaleEffect(isPulsing ? 1.025 : (isSelected ? 1.018 : 1.0))
                    .contentShape(shape)
                    .onTapGesture {
                        UnboundHaptics.medium()
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                            selectedGroup = group
                        }
                        onGroupTapped(group)
                    }
                    .animation(.easeInOut(duration: 0.4), value: isPulsing)
                    .animation(.spring(response: 0.28, dampingFraction: 0.78), value: selectedGroup)
            }
            .scaleEffect(transform.scale)
            .offset(x: transform.x, y: transform.y)
        }
    }

    private func customBodyBase(side: BodyMapSide) -> some View {
        let image = overlayProfile
            .baseImageCandidates(for: side)
            .compactMap { UIImage(named: $0) }
            .first

        return Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "figure.strengthtraining.traditional")
                    .resizable()
                    .scaledToFit()
                    .padding(22)
                    .foregroundStyle(Color.unbound.accent.opacity(0.6))
            }
        }
        .saturation(0.92)
        .contrast(1.04)
        .shadow(color: Color.unbound.accent.opacity(0.18), radius: 18, x: 0, y: 0)
        .allowsHitTesting(false)
    }

    private func figureAtmosphere(
        parts: [BodyPaths.Part],
        viewBox: CGRect
    ) -> some View {
        ZStack {
            ForEach(parts) { part in
                let shape = muscleShape(part: part, viewBox: viewBox)
                shape
                    .fill(Color.unbound.accent.opacity(0.045))
                    .shadow(color: Color.unbound.accent.opacity(0.24), radius: 18)
            }

            ForEach(parts.filter { !$0.isDecorative }) { part in
                if let group = part.heatGroup {
                    let rank = groupRanks[group] ?? .eMinus
                    let shape = muscleShape(part: part, viewBox: viewBox)
                    shape
                        .fill(rank.regionTint.opacity(rankAuraOpacity(for: rank)))
                        .blur(radius: rank.letter == "A" || rank.letter == "S" ? 12 : 7)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func unboundFigureAtmosphere(
        regions: [BodyRegion],
        side: BodyMapSide
    ) -> some View {
        ZStack {
            ForEach(regions, id: \.self) { region in
                let rank = groupRanks[region.heatGroup] ?? .eMinus
                let isActive = selectedGroup == region.heatGroup || pulsingGroups.contains(region.heatGroup)
                let shouldGlow = isActive || rank.letter == "A" || rank.letter == "S"
                let shape = MuscleRegionShape(region: region, side: side)
                if shouldGlow {
                    shape
                        .fill(rank.regionTint.opacity(isActive ? 0.22 : 0.08))
                        .blur(radius: isActive ? 8 : 5)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func unboundPanelFill(
        for rank: SubRank,
        isSelected: Bool,
        isPulsing: Bool
    ) -> LinearGradient {
        let tint = rank.regionTint
        let energy = isSelected || isPulsing
        let baseOpacity: Double = {
            switch rank.letter {
            case "S": return 0.26
            case "A": return 0.22
            case "B": return 0.18
            case "C": return 0.15
            default: return 0.11
            }
        }()
        return LinearGradient(
            colors: [
                tint.opacity(energy ? 0.40 : baseOpacity),
                tint.opacity(energy ? 0.20 : baseOpacity * 0.45),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func unboundPanelStrokeOpacity(for rank: SubRank) -> Double {
        switch rank.letter {
        case "S": return 0.62
        case "A": return 0.54
        case "B": return 0.44
        case "C": return 0.36
        default: return 0.26
        }
    }

    private func unboundPanelGlowOpacity(for rank: SubRank) -> Double {
        switch rank.letter {
        case "S": return 0.28
        case "A": return 0.22
        case "B": return 0.14
        default: return 0.06
        }
    }

    private func unboundPanelGlowRadius(for rank: SubRank) -> CGFloat {
        switch rank.letter {
        case "S": return 6
        case "A": return 5
        case "B": return 3
        default: return 1.5
        }
    }

    private func muscleFill(
        for rank: SubRank,
        isSelected: Bool,
        isPulsing: Bool
    ) -> LinearGradient {
        let tint = rank.regionTint
        let energy = isSelected || isPulsing
        return LinearGradient(
            colors: [
                tint.opacity(energy ? 0.70 : 0.38),
                tint.opacity(energy ? 0.42 : 0.18),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func muscleTopLight(for rank: SubRank) -> LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(rank.letter == "S" ? 0.22 : 0.12),
                Color.white.opacity(0.035),
                Color.clear
            ],
            startPoint: .top,
            endPoint: .center
        )
    }

    private func muscleCoreAura(
        for rank: SubRank,
        isSelected: Bool
    ) -> RadialGradient {
        let tint = rank.regionTint
        return RadialGradient(
            colors: [
                tint.opacity(isSelected ? 0.44 : 0.18),
                tint.opacity(isSelected ? 0.16 : 0.05),
                Color.clear
            ],
            center: .center,
            startRadius: 0,
            endRadius: 84
        )
    }

    private func rankAuraOpacity(for rank: SubRank) -> Double {
        switch rank.letter {
        case "A": return 0.16
        case "S": return 0.20
        case "B": return 0.11
        case "C": return 0.08
        default: return 0.055
        }
    }

    private func rankGlowRadius(for rank: SubRank) -> CGFloat {
        switch rank.letter {
        case "A": return 7
        case "S": return 9
        case "B": return 5
        default: return 3
        }
    }

    /// Combine every path string in the part into a single Shape so both
    /// the fill and tap hit-target cover the whole muscle (left + right +
    /// common sub-paths).
    private func muscleShape(
        part: BodyPaths.Part,
        viewBox: CGRect
    ) -> MusclePathShape {
        MusclePathShape(pathStrings: part.allPathStrings, viewBox: viewBox)
    }

    // MARK: Side selector

    private var sideSelector: some View {
        HStack(spacing: 4) {
            sideButton(title: "FRONT", side: .front)
            sideButton(title: "BACK", side: .back)
        }
        .padding(3)
        .fixedSize(horizontal: true, vertical: false)
        .background(Capsule().fill(Color.unbound.surface))
        .overlay(Capsule().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
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
                .foregroundStyle(
                    selectedSide == side ? Color.unbound.textPrimary : Color.unbound.textTertiary
                )
                .fixedSize(horizontal: true, vertical: false)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(
                        selectedSide == side ? Color.unbound.accent.opacity(0.25) : Color.clear
                    )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: Pulse trigger

    private func triggerPulse(forExerciseKey key: String) {
        let affected: Set<MuscleHeatGroup> = Set(
            BodyRegion.allCases
                .filter { region in
                    region.contributingLifts.contains { canonical in
                        key.contains(canonical) || canonical.contains(key)
                    }
                }
                .map(\.heatGroup)
        )
        guard !affected.isEmpty else { return }

        withAnimation(.easeOut(duration: 0.3)) {
            pulsingGroups.formUnion(affected)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeIn(duration: 0.45)) {
                pulsingGroups.subtract(affected)
            }
        }
    }
}

// MARK: - MusclePathShape
//
// Parses SVG path strings once per frame into SwiftUI Paths, then scales
// them from the source viewBox into the rendered rect.

struct MusclePathShape: Shape {
    let pathStrings: [String]
    let viewBox: CGRect

    func path(in rect: CGRect) -> Path {
        var combined = Path()
        guard viewBox.width > 0, viewBox.height > 0 else { return combined }

        // Fit viewBox into rect preserving aspect so left/right body halves
        // aren't squashed when the rect ratio differs from the source.
        let scale = min(rect.width / viewBox.width, rect.height / viewBox.height)
        let scaledW = viewBox.width * scale
        let scaledH = viewBox.height * scale
        let dx = rect.minX + (rect.width - scaledW) / 2 - viewBox.minX * scale
        let dy = rect.minY + (rect.height - scaledH) / 2 - viewBox.minY * scale

        let transform = CGAffineTransform(translationX: dx, y: dy)
            .scaledBy(x: scale, y: scale)

        for str in pathStrings {
            combined.addPath(SVGPathParser.path(from: str).applying(transform))
        }
        return combined
    }
}

private extension Path {
    func offsetBy(dx: CGFloat, dy: CGFloat) -> Path {
        applying(CGAffineTransform(translationX: dx, y: dy))
    }
}

// MARK: - Preview

#Preview {
    let sample: [MuscleHeatGroup: SubRank] = [
        .chest: .bPlus,
        .shoulders: .aMinus,
        .biceps: .cPlus,
        .core: .sMinus,
        .legs: .dPlus,
        .calves: .eMinus,
        .back: .b,
        .hamstrings: .cMinus,
        .glutes: .b
    ]
    return MuscleHeatmapView(groupRanks: sample, onGroupTapped: { _ in })
        .padding()
        .background(Color.black)
}
