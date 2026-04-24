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
    let onGroupTapped: (MuscleHeatGroup) -> Void

    @State private var selectedSide: BodyMapSide = .front
    @State private var pulsingGroups: Set<MuscleHeatGroup> = []
    @State private var breathingScale: CGFloat = 1.0

    private static let bodyPaths = BodyPaths.shared

    var body: some View {
        let aspect = max(Self.bodyPaths.frontViewBox.width, Self.bodyPaths.backViewBox.width) /
            max(Self.bodyPaths.frontViewBox.height, Self.bodyPaths.backViewBox.height)
        return VStack(spacing: 10) {
            ZStack {
                bodyFigure(side: .front).opacity(selectedSide == .front ? 1 : 0)
                bodyFigure(side: .back).opacity(selectedSide == .back ? 1 : 0)
            }
            .aspectRatio(aspect, contentMode: .fit)
            .scaleEffect(breathingScale)
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
        let parts = Self.bodyPaths.parts(for: side)
        let viewBox = Self.bodyPaths.viewBox(for: side)

        // Shared top-to-bottom depth composite used by every muscle + the
        // decorative silhouette. Top gets a soft white highlight, bottom
        // gets a shadow — gives the flat vector body a 3D-ish feel without
        // needing per-muscle texture assets.
        let highlight = LinearGradient(
            colors: [Color.white.opacity(0.45), Color.white.opacity(0.10), .clear],
            startPoint: .top,
            endPoint: .center
        )
        let shadow = LinearGradient(
            colors: [.clear, Color.black.opacity(0.25), Color.black.opacity(0.65)],
            startPoint: .center,
            endPoint: .bottom
        )

        return ZStack {
            // Decorative silhouette layer — head, hair, hands, feet, etc.
            // Shaded with the same depth gradients so the silhouette reads
            // dimensional instead of flat grey.
            ForEach(parts.filter { $0.isDecorative }) { part in
                let shape = muscleShape(part: part, viewBox: viewBox)
                shape
                    .fill(Color.unbound.textSecondary.opacity(0.5))
                    .overlay(shape.fill(highlight))
                    .overlay(shape.fill(shadow))
                    .overlay(
                        shape.stroke(Color.unbound.textSecondary.opacity(0.7), lineWidth: 1.0)
                    )
            }

            // Rank-tinted muscles on top. Each muscle gets a rank tint fill
            // + highlight + shadow + stroke + glow shadow for presence.
            ForEach(parts.filter { !$0.isDecorative }) { part in
                if let group = part.heatGroup {
                    let rank = groupRanks[group] ?? .eMinus
                    let isPulsing = pulsingGroups.contains(group)
                    let tint = rank.regionTint
                    let shape = muscleShape(part: part, viewBox: viewBox)

                    shape
                        .fill(tint.opacity(isPulsing ? 1.0 : 0.82))
                        .overlay(shape.fill(highlight))
                        .overlay(shape.fill(shadow))
                        .overlay(
                            shape.stroke(tint.opacity(0.95), lineWidth: isPulsing ? 1.6 : 1.0)
                        )
                        .shadow(color: tint.opacity(isPulsing ? 0.9 : 0.35),
                                radius: isPulsing ? 14 : 3)
                        .scaleEffect(isPulsing ? 1.03 : 1.0)
                        .contentShape(shape)
                        .onTapGesture {
                            UnboundHaptics.medium()
                            onGroupTapped(group)
                        }
                        .animation(.easeInOut(duration: 0.4), value: isPulsing)
                }
            }
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
