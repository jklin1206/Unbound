import SwiftUI

// MARK: - Stateless helpers

extension ProgramFocusSwitchSheet {

    func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Font.unbound.captionS.weight(.heavy))
            .tracking(1.4)
            .foregroundStyle(Color.unbound.textTertiary)
    }

    func horizontalRail<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                content()
            }
            .padding(.horizontal, 20)
        }
        .padding(.horizontal, -20)
    }

    func artworkHeader<Accessory: View>(
        assetName: String?,
        fallbackIcon: String,
        selected: Bool,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.unbound.bg.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.unbound.coachCyan.opacity(selected ? 0.2 : 0.08),
                                    Color.unbound.surface.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay {
                    if let assetName {
                        Image(assetName)
                            .resizable()
                            .scaledToFit()
                            .padding(3)
                            .scaleEffect(1.12)
                            .accessibilityHidden(true)
                    } else {
                        Image(systemName: fallbackIcon)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(selected ? Color.unbound.textPrimary : Color.unbound.coachCyan)
                            .accessibilityHidden(true)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            accessory()
                .padding(6)
        }
        .frame(height: 58)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(selected ? Color.unbound.coachCyan.opacity(0.42) : Color.unbound.borderSubtle.opacity(0.7), lineWidth: 1)
        )
    }

    func contextControlCard(
        title: String,
        detail: String,
        icon: String,
        actionTitle: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            guard !isApplying else { return }
            UnboundHaptics.soft()
            action()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.unbound.coachCyan)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.unbound.coachCyan.opacity(0.14)))

                VStack(alignment: .leading, spacing: 1) {
                    Text(title.uppercased())
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.0)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                    Text(detail.uppercased())
                        .font(Font.unbound.monoS.weight(.bold))
                        .foregroundStyle(Color.unbound.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                }

                Spacer(minLength: 4)

                Text(actionTitle.uppercased())
                    .font(Font.unbound.captionS.weight(.black))
                    .tracking(1.0)
                    .foregroundStyle(Color.unbound.alert)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .padding(.horizontal, 12)
            .frame(width: 168, height: 58, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.unbound.alert.opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isApplying)
        .accessibilityIdentifier(identifier)
    }

    func errorRow(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .bold))
            Text(message)
                .font(Font.unbound.captionS)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Color.unbound.alert)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.alert.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.unbound.alert.opacity(0.25), lineWidth: 1)
        )
    }

    func equipmentLabel(_ equipment: [Equipment]) -> String {
        if equipment.contains(.fullGym) { return "Full gym" }
        if equipment == [.bodyweight] { return "Bodyweight only" }
        let ordered: [Equipment] = [.bodyweight, .pullupBar, .bands, .dipStation, .rings, .bench, .dumbbells, .barbell, .machines, .homeWeights]
        let labels = ordered
            .filter { equipment.contains($0) }
            .prefix(3)
            .map(\.displayName)
        return labels.isEmpty ? "Equipment open" : labels.joined(separator: " / ")
    }

    func contextModeLabel(_ override: ProgramTrainingContextOverride) -> String {
        let mode = override.selection.mode.displayName
        let equipment = equipmentLabel(ProgramTrainingContextResolver.sortedEquipment(override.selection.equipment))
        if override.selection.equipment.isEmpty {
            return mode
        }
        return "\(mode) / \(equipment)"
    }
}
