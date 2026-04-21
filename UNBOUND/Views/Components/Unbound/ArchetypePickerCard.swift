import SwiftUI

struct ArchetypePickerCard: View {
    let archetype: Archetype
    let index: Int
    let isSelected: Bool
    let action: () -> Void

    @State private var isPressed: Bool = false

    init(
        archetype: Archetype,
        index: Int = 0,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.archetype = archetype
        self.index = index
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: handleTap) {
            let shape = ChamferedRectangle(inset: 8)
            VStack(spacing: 10) {
                ZStack(alignment: .top) {
                    illustration
                        .frame(maxWidth: .infinity)
                        .frame(height: 140)

                    HStack {
                        Text(String(format: "%02d", max(index, 0) + 1))
                            .font(Font.unbound.monoS)
                            .tracking(1.4)
                            .foregroundStyle(
                                isSelected ? Color.unbound.accent : Color.unbound.textTertiary
                            )
                        Spacer(minLength: 0)
                        hexagonIndicator
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                }

                VStack(spacing: 4) {
                    Text(archetype.shortName)
                        .font(Font.unbound.titleS)
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(archetype.characterTagline)
                        .font(Font.unbound.monoS)
                        .tracking(1.0)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 14)
            }
            .frame(maxWidth: .infinity)
            .background(shape.fill(Color.unbound.surface))
            .overlay(
                shape.stroke(
                    isSelected ? Color.unbound.accent : Color.unbound.borderSubtle,
                    lineWidth: isSelected ? 2 : 1
                )
            )
            .overlay(alignment: .top) {
                if isSelected {
                    Rectangle()
                        .fill(Color.unbound.accent.opacity(0.35))
                        .frame(height: 1)
                        .padding(.horizontal, 8)
                }
            }
            .clipShape(shape)
            .animeGlow(
                color: Color.unbound.accent,
                radius: isSelected ? 18 : 0,
                intensity: isSelected ? 0.7 : 0
            )
            .scaleEffect(isPressed ? 0.98 : (isSelected ? 1.02 : 1.0))
            .animation(.spring(response: 0.28, dampingFraction: 0.75), value: isSelected)
            .animation(.spring(response: 0.22, dampingFraction: 0.75), value: isPressed)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
    }

    private var hexagonIndicator: some View {
        ZStack {
            if isSelected {
                HUDHexagon()
                    .fill(Color.unbound.accent)
                    .frame(width: 22, height: 20)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.unbound.textPrimary)
                    )
                    .animeGlow(color: Color.unbound.accent, radius: 8, intensity: 0.8)
            } else {
                HUDHexagon()
                    .stroke(Color.unbound.border, lineWidth: 1.25)
                    .frame(width: 22, height: 20)
            }
        }
        .frame(width: 22, height: 22)
    }

    @ViewBuilder
    private var illustration: some View {
        if UIImage(named: assetName) != nil {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.unbound.textPrimary)
                .opacity(isSelected ? 1.0 : 0.88)
                .padding(.top, 26)
        } else {
            fallbackSilhouette
                .padding(.top, 26)
        }
    }

    private var assetName: String {
        archetype.silhouetteAssetName
    }

    private var fallbackSilhouette: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.unbound.accent.opacity(isSelected ? 0.24 : 0), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 72
                    )
                )
            Image(systemName: fallbackSymbol)
                .font(.system(size: 72, weight: .ultraLight))
                .foregroundStyle(
                    isSelected ? Color.unbound.textPrimary : Color.unbound.textSecondary
                )
        }
    }

    private var fallbackSymbol: String {
        switch archetype {
        case .heavyDuty: return "figure.american.football"
        case .leanCut:   return "figure.run"
        case .shredded:  return "figure.core.training"
        case .vTaper:    return "figure.stand"
        }
    }

    private func handleTap() {
        UnboundHaptics.medium()
        withAnimation(.easeOut(duration: 0.12)) {
            isPressed = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.26, dampingFraction: 0.7)) {
                isPressed = false
            }
        }
        action()
    }
}

#Preview("ArchetypeGrid") {
    StatefulArchetypePreview()
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.unbound.bg)
}

private struct StatefulArchetypePreview: View {
    @State private var selected: Archetype? = .vTaper
    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 12
        ) {
            ForEach(Array(Archetype.allCases.enumerated()), id: \.element) { idx, arch in
                ArchetypePickerCard(
                    archetype: arch,
                    index: idx,
                    isSelected: selected == arch
                ) {
                    selected = arch
                }
            }
        }
    }
}
