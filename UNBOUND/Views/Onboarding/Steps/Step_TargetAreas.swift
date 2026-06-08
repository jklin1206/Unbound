import SwiftUI

struct Step_TargetAreas: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            title: "Where do you want to focus?",
            subtitle: "Pick a few. We'll prioritize these in every session.",
            progress: progress,
            primaryTitle: "Continue",
            primaryEnabled: !flow.targetAreas.isEmpty,
            hudStep: .targetAreas,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            VStack(spacing: 14) {
                OnboardingTargetAreaHeatmap(selection: $flow.targetAreas)

                OnboardingTargetAreaChipGrid(selection: $flow.targetAreas)
            }
            .padding(.top, 4)
        }
    }
}

private struct OnboardingTargetAreaHeatmap: View {
    @Binding var selection: Set<TargetArea>

    private var activeAreas: Set<TargetArea> {
        if selection.contains(.fullBody) {
            return Set(TargetArea.bodyPartCases)
        }
        return Set(selection.filter { $0 != .fullBody })
    }

    private var selectedRegions: Set<BodyRegion> {
        Set(activeAreas.flatMap { $0.bodyRegions })
    }

    private var summary: String {
        if selection.contains(.fullBody) {
            return "FULL BODY"
        }

        let selectedNames = TargetArea.bodyPartCases
            .filter { selection.contains($0) }
            .map { $0.displayName.uppercased() }

        guard !selectedNames.isEmpty else {
            return "TAP REGIONS OR PICKS"
        }

        if selectedNames.count > 3 {
            return selectedNames.prefix(3).joined(separator: " + ") + " +\(selectedNames.count - 3)"
        }
        return selectedNames.joined(separator: " + ")
    }

    var body: some View {
        HUDPanel(isActive: !selection.isEmpty, pulse: false) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TARGET MAP")
                            .font(Font.unbound.captionS.weight(.black))
                            .tracking(1.8)
                            .foregroundStyle(Color.unbound.textTertiary)
                        Text(summary)
                            .font(.system(size: 17, weight: .black, design: .monospaced))
                            .tracking(0.6)
                            .foregroundStyle(selection.isEmpty ? Color.unbound.textSecondary : Color.unbound.accent)
                            .lineLimit(2)
                            .minimumScaleFactor(0.72)
                    }

                    Spacer(minLength: 8)

                    Text("\(selectionCount)")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .frame(width: 30, height: 28)
                        .background(
                            HUDHexagon()
                                .fill(selection.isEmpty ? Color.unbound.surfaceElevated : Color.unbound.accent.opacity(0.86))
                        )
                        .overlay(
                            HUDHexagon()
                                .stroke(Color.unbound.accent.opacity(selection.isEmpty ? 0.22 : 0.7), lineWidth: 1)
                        )
                }

                HStack(alignment: .top, spacing: 10) {
                    OnboardingTargetBodyFigure(
                        side: .front,
                        selectedRegions: selectedRegions,
                        onRegionTap: toggleArea(for:)
                    )
                    OnboardingTargetBodyFigure(
                        side: .back,
                        selectedRegions: selectedRegions,
                        onRegionTap: toggleArea(for:)
                    )
                }

                HStack(spacing: 6) {
                    ForEach(OnboardingTargetHeatLegendItem.allCases) { item in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(item.color)
                            .frame(width: 16, height: 6)
                    }
                    Text("SELECTED MUSCLE REGIONS")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(0.6)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
            }
            .padding(14)
        }
    }

    private var selectionCount: Int {
        if selection.contains(.fullBody) {
            return TargetArea.bodyPartCases.count
        }
        return selection.filter { $0 != .fullBody }.count
    }

    private func toggleArea(for region: BodyRegion) {
        guard let area = TargetArea.targetArea(for: region) else { return }
        toggle(area)
    }

    private func toggle(_ area: TargetArea) {
        withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
            if selection.contains(.fullBody) {
                selection.remove(.fullBody)
            }

            if selection.contains(area) {
                selection.remove(area)
            } else {
                selection.insert(area)
            }
        }
        UnboundHaptics.medium()
    }
}

private struct OnboardingTargetBodyFigure: View {
    let side: BodyMapSide
    let selectedRegions: Set<BodyRegion>
    let onRegionTap: (BodyRegion) -> Void

    var body: some View {
        OnboardingTargetBodyCanvas(
            side: side,
            selectedRegions: selectedRegions,
            onRegionTap: onRegionTap
        )
        .overlay(alignment: .topTrailing) {
            Text(side.shortTitle)
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(Color.unbound.textTertiary)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.unbound.bg.opacity(0.62))
                )
                .padding(5)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct OnboardingTargetBodyCanvas: View {
    let side: BodyMapSide
    let selectedRegions: Set<BodyRegion>
    let onRegionTap: (BodyRegion) -> Void

    var body: some View {
        GeometryReader { proxy in
            let viewBox = BodyLoadSVGRegionAsset.viewBox(for: side)
            let drawRect = Self.drawRect(in: proxy.size, viewBox: viewBox)
            let separatorWidth = max(0.75, min(1.6, drawRect.width / 260))

            ZStack {
                if let baseImage = BodyLoadImageAsset.image(for: side) {
                    Image(uiImage: baseImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: drawRect.width, height: drawRect.height)
                        .position(x: drawRect.midX, y: drawRect.midY)
                        .opacity(0.82)
                }

                ForEach(BodyLoadSVGRegionAsset.paths(for: side)) { spec in
                    let isSelected = selectedRegions.contains(spec.region)

                    spec.path(in: drawRect, viewBox: viewBox)
                        .fill(
                            OnboardingTargetHeatmapColor.fill(
                                isSelected: isSelected,
                                kind: spec.kind
                            ),
                            style: FillStyle(eoFill: spec.usesEvenOdd)
                        )

                    spec.path(in: drawRect, viewBox: viewBox)
                        .stroke(
                            OnboardingTargetHeatmapColor.separator(isSelected: isSelected),
                            style: StrokeStyle(
                                lineWidth: isSelected ? separatorWidth + 0.65 : separatorWidth,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                        .shadow(
                            color: isSelected ? Color.unbound.accent.opacity(0.34) : .clear,
                            radius: isSelected ? 5 : 0
                        )

                    spec.path(in: drawRect, viewBox: viewBox)
                        .fill(Color.white.opacity(0.001), style: FillStyle(eoFill: spec.usesEvenOdd))
                        .onTapGesture {
                            onRegionTap(spec.region)
                        }
                        .accessibilityLabel("\(spec.region.displayName) target area")
                        .accessibilityAddTraits(.isButton)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(BodyLoadSVGRegionAsset.viewBox(for: side).width / BodyLoadSVGRegionAsset.viewBox(for: side).height, contentMode: .fit)
        .background(
            ChamferedRectangle(inset: 10)
                .fill(Color.unbound.bg.opacity(0.30))
        )
        .overlay(
            ChamferedRectangle(inset: 10)
                .stroke(Color.unbound.borderSubtle.opacity(0.78), lineWidth: 1)
        )
        .clipShape(ChamferedRectangle(inset: 10))
    }

    private static func drawRect(in size: CGSize, viewBox: CGSize) -> CGRect {
        let scale = min(size.width / viewBox.width, size.height / viewBox.height)
        let width = viewBox.width * scale
        let height = viewBox.height * scale
        return CGRect(
            x: (size.width - width) / 2,
            y: (size.height - height) / 2,
            width: width,
            height: height
        )
    }
}

private struct OnboardingTargetAreaChipGrid: View {
    @Binding var selection: Set<TargetArea>

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            TargetAreaChip(
                title: TargetArea.fullBody.displayName,
                subtitle: "Full arc",
                isActive: selection.contains(.fullBody),
                isWide: true
            ) {
                toggleFullBody()
            }
            .gridCellColumns(2)

            ForEach(TargetArea.bodyPartCases) { area in
                TargetAreaChip(
                    title: area.displayName,
                    subtitle: area.shortRegionLabel,
                    isActive: selection.contains(.fullBody) || selection.contains(area)
                ) {
                    toggle(area)
                }
            }
        }
    }

    private func toggleFullBody() {
        withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
            if selection.contains(.fullBody) {
                selection.removeAll()
            } else {
                selection = Set(TargetArea.allCases)
            }
        }
        UnboundHaptics.medium()
    }

    private func toggle(_ area: TargetArea) {
        withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
            if selection.contains(.fullBody) {
                selection.remove(.fullBody)
            }

            if selection.contains(area) {
                selection.remove(area)
            } else {
                selection.insert(area)
            }
        }
        UnboundHaptics.medium()
    }
}

private struct TargetAreaChip: View {
    let title: String
    let subtitle: String
    let isActive: Bool
    var isWide = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                HUDHexagon()
                    .fill(isActive ? Color.unbound.accent : Color.unbound.surfaceElevated)
                    .frame(width: 18, height: 16)
                    .overlay(
                        HUDHexagon()
                            .stroke(isActive ? Color.unbound.accent.opacity(0.8) : Color.unbound.borderSubtle, lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title.uppercased())
                        .font(.system(size: isWide ? 13 : 12, weight: .black, design: .monospaced))
                        .tracking(0.6)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(subtitle.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(0.5)
                        .foregroundStyle(isActive ? Color.unbound.accent.opacity(0.82) : Color.unbound.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ChamferedRectangle(inset: 7)
                    .fill(isActive ? Color.unbound.accent.opacity(0.11) : Color.unbound.surface.opacity(0.88))
            )
            .overlay(
                ChamferedRectangle(inset: 7)
                    .stroke(isActive ? Color.unbound.accent.opacity(0.72) : Color.unbound.borderSubtle, lineWidth: isActive ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private enum OnboardingTargetHeatLegendItem: CaseIterable, Identifiable {
    case idle
    case selected
    case active

    var id: Self { self }

    var color: Color {
        switch self {
        case .idle:
            return Color.white.opacity(0.12)
        case .selected:
            return Color.unbound.accent.opacity(0.52)
        case .active:
            return Color.unbound.accent
        }
    }
}

private enum OnboardingTargetHeatmapColor {
    static func fill(isSelected: Bool, kind: BodyLoadPathKind) -> Color {
        guard isSelected else {
            return kind == .stroke ? Color.white.opacity(0.03) : Color.clear
        }

        switch kind {
        case .fill:
            return Color.unbound.accent.opacity(0.52)
        case .stroke:
            return Color.unbound.accent.opacity(0.86)
        }
    }

    static func separator(isSelected: Bool) -> Color {
        isSelected
            ? Color.unbound.accent.opacity(0.88)
            : Color.black.opacity(0.36)
    }
}

private extension TargetArea {
    static var bodyPartCases: [TargetArea] {
        allCases.filter { $0 != .fullBody }
    }

    var bodyRegions: [BodyRegion] {
        switch self {
        case .chest:
            return [.chest, .upperChest, .midLowerChest]
        case .back:
            return [.lats, .rhomboids, .traps, .lowerBack]
        case .shoulders:
            return [.shoulders, .frontSideDelts, .rearDelts]
        case .arms:
            return [.biceps, .triceps, .forearms]
        case .core:
            return [.abs, .obliques]
        case .legs:
            return [.quads, .adductors, .hamstrings, .calves]
        case .glutes:
            return [.glutes, .abductors]
        case .fullBody:
            return TargetArea.bodyPartCases.flatMap { $0.bodyRegions }
        }
    }

    var shortRegionLabel: String {
        switch self {
        case .chest:
            return "Pecs"
        case .back:
            return "Lats + traps"
        case .shoulders:
            return "Delts"
        case .arms:
            return "Bi + tri"
        case .core:
            return "Abs + brace"
        case .legs:
            return "Quads + hams"
        case .glutes:
            return "Posterior"
        case .fullBody:
            return "Full arc"
        }
    }

    static func targetArea(for region: BodyRegion) -> TargetArea? {
        switch region {
        case .chest, .upperChest, .midLowerChest:
            return .chest
        case .lats, .rhomboids, .traps, .lowerBack:
            return .back
        case .shoulders, .frontSideDelts, .rearDelts:
            return .shoulders
        case .biceps, .triceps, .forearms:
            return .arms
        case .abs, .obliques:
            return .core
        case .quads, .adductors, .hamstrings, .calves:
            return .legs
        case .glutes, .abductors:
            return .glutes
        }
    }
}
