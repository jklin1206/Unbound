import SwiftUI

// MARK: - SkinPickerView
//
// Settings sub-screen. Lists every SkillTreeSkin with lock states + a
// live tree-map swatch. Tapping an unlocked skin switches SkinService.

struct SkinPickerView: View {
    @StateObject private var skinService = SkinService.shared
    @State private var pulse: Bool = false
    @State private var lockAlert: String?

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    header
                    ForEach(SkillTreeSkin.allCases) { skin in
                        skinRow(skin)
                    }
                    footer
                    Spacer().frame(height: 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
        }
        .navigationTitle("Skill tree cosmetics")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .alert("Locked", isPresented: Binding(
            get: { lockAlert != nil },
            set: { if !$0 { lockAlert = nil } }
        )) {
            Button("OK", role: .cancel) { lockAlert = nil }
        } message: {
            Text(lockAlert ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SKILL TREE COSMETICS")
                .font(Font.unbound.monoS)
                .tracking(1.8)
                .foregroundStyle(Color.unbound.textTertiary)
            Text("Cosmetics change the tree background, rank bands, hex glow, rails, chips, and share cards. They unlock as your named rank climbs.")
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func skinRow(_ skin: SkillTreeSkin) -> some View {
        let unlocked = skinService.unlockedSkins.contains(skin)
        let selected = skinService.currentSkin == skin
        return Button {
            UnboundHaptics.medium()
            if unlocked {
                try? skinService.setCurrent(skin)
            } else {
                lockAlert = skin.unlockHintCopy
            }
        } label: {
            HStack(alignment: .center, spacing: 16) {
                swatch(for: skin)
                    .frame(width: 68, height: 68)
                    .saturation(unlocked ? 1.0 : 0.15)
                    .overlay(
                        lockOverlay(visible: !unlocked)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(skin.displayName.uppercased())
                            .font(Font.unbound.titleS)
                            .tracking(1.4)
                            .foregroundStyle(unlocked ? Color.unbound.textPrimary : Color.unbound.textSecondary)
                        if selected {
                            Text("ACTIVE")
                                .font(Font.unbound.monoS)
                                .tracking(1.6)
                                .foregroundStyle(skin.primaryColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().stroke(skin.primaryColor, lineWidth: 1))
                        }
                    }
                    Text(unlocked ? skin.description : skin.unlockHintCopy)
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(unlocked ? Color.unbound.textSecondary : Color.unbound.textTertiary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        selected ? skin.primaryColor : Color.unbound.border,
                        lineWidth: selected ? 2 : 1
                    )
            )
            .shadow(color: selected ? skin.impactColor.opacity(0.35) : .clear, radius: 18)
        }
        .buttonStyle(.plain)
    }

    private func swatch(for skin: SkillTreeSkin) -> some View {
        ZStack {
            if UIImage(named: skin.backgroundAssetName) != nil {
                Image(skin.backgroundAssetName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .contrast(skin.backgroundAssetContrast)
                    .opacity(skin.backgroundAssetOpacity)
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(skin.nodeGradient)
            }
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(skin.mapBackground)
                .blendMode(.screen)
            VStack(spacing: 6) {
                ForEach(SkillRank.allCases, id: \.self) { rank in
                    Capsule()
                        .fill((rank.isAscendedTier ? skin.impactColor : skin.primaryColor).opacity(0.18 + Double(rank.difficultyOrder) * 0.05))
                        .frame(height: 3)
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 10)
            HStack(spacing: 8) {
                Circle()
                    .fill(skin.nodeFill(state: .achieved, faded: false))
                    .frame(width: 12, height: 12)
                    .overlay(Circle().strokeBorder(skin.primaryColor, lineWidth: 1))
                Capsule()
                    .fill(skin.primaryColor.opacity(0.75))
                    .frame(width: 16, height: 2)
                Circle()
                    .fill(skin.nodeFill(state: .mastered, faded: false))
                    .frame(width: 12, height: 12)
                    .overlay(Circle().strokeBorder(skin.impactColor, lineWidth: 1))
            }
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(skin.primaryColor.opacity(pulse && skin == .holographic ? 0.8 : 0.45), lineWidth: 1.5)
            Image(systemName: "hexagon.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(skin.primaryColor)
                .shadow(color: skin.impactColor.opacity(0.6), radius: 8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func lockOverlay(visible: Bool) -> some View {
        if visible {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.unbound.bg.opacity(0.55))
                Image(systemName: "lock.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.unbound.textSecondary)
            }
        }
    }

    private var footer: some View {
        Text("Unlocked cosmetics stay in your collection. Graphite is included as a lower-purple default for quieter maps.")
            .font(Font.unbound.captionS)
            .foregroundStyle(Color.unbound.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
    }
}

#Preview {
    NavigationStack { SkinPickerView() }
}
