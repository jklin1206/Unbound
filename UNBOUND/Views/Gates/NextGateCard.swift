import SwiftUI

/// Discovery card (spec §6.1). Sealed = darkened banner + gate sigil + quest log
/// + key fragments while accumulating; open = brightened banner + BEGIN; cleared
/// = the quiet answered state. Reachable via the demo harness in Plan 2; goes live
/// in Profile in Plan 4.
struct NextGateCard: View {
    let readiness: OverallRankTrialReadiness
    let world: GateWorld
    var onBegin: (() -> Void)? = nil

    private var model: NextGateCardModel { .init(readiness: readiness, world: world) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            banner
            content
        }
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.unbound.surface))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(world.tint.opacity(model.presentation == .open ? 0.55 : 0.22), lineWidth: 1))
        .accessibilityIdentifier("next-gate-card")
    }

    private var banner: some View {
        ZStack(alignment: .bottomLeading) {
            Image(world.bannerAssetName)
                .resizable().scaledToFill()
                .frame(height: 168).clipped()
                .saturation(model.presentation == .sealed ? 0.15 : 1)
                .overlay(Color.black.opacity(model.presentation == .sealed ? 0.62 : 0.12))
                .overlay(LinearGradient(colors: [.clear, Color.unbound.surface],
                    startPoint: .center, endPoint: .bottom))

            if model.presentation == .sealed {
                Image(systemName: "lock.fill")
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(world.tint.opacity(0.9))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Text("RANK GATE \(world.numeral)")
                .font(Font.unbound.captionS.weight(.heavy)).tracking(2)
                .foregroundStyle(world.tint)
                .padding(14)
        }
        .frame(height: 168)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.trialName.uppercased())
                .font(Font.unbound.titleS).foregroundStyle(Color.unbound.textPrimary)

            if model.presentation == .cleared {
                Label("ANSWERED", systemImage: "checkmark.seal.fill")
                    .font(Font.unbound.captionS.weight(.heavy)).tracking(1.4)
                    .foregroundStyle(world.tint)
            } else {
                Text(model.transitionLabel)
                    .font(Font.unbound.captionS.weight(.heavy)).tracking(1.4)
                    .foregroundStyle(world.tint)
            }

            Text(model.presentation == .cleared
                 ? "Every gate answered. You're \(world.destinationRank.displayName)."
                 : model.promise)
                .font(Font.unbound.bodyMStrong).foregroundStyle(Color.unbound.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if model.presentation == .sealed {
                questLog
                if !model.keyFragments.isEmpty { keyFragmentRow }
            }

            if let cta = model.ctaTitle {
                Button { onBegin?() } label: {
                    Text(cta).font(Font.unbound.captionS.weight(.heavy)).tracking(1.6)
                        .foregroundStyle(Color.unbound.bg)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(Capsule().fill(world.fillTint))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("next-gate-begin")
            }
        }
        .padding(16)
    }

    private var questLog: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(model.questItems) { item in
                Label {
                    Text(item.label).font(Font.unbound.captionS.weight(.semibold))
                        .foregroundStyle(Color.unbound.textPrimary)
                } icon: {
                    Image(systemName: item.isMet ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(item.isMet ? Color.unbound.success : world.tint.opacity(0.7))
                }
            }
        }
    }

    private var keyFragmentRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("GATE KEYS").font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(1.6).foregroundStyle(Color.unbound.textTertiary)
            ForEach(model.keyFragments) { frag in
                Label {
                    Text(frag.label).font(Font.unbound.captionS.weight(.semibold))
                        .foregroundStyle(frag.isLit ? Color.unbound.textPrimary : Color.unbound.textSecondary)
                } icon: {
                    Image(systemName: frag.isLit ? "key.fill" : "key")
                        .foregroundStyle(frag.isLit ? world.fillTint : world.tint.opacity(0.4))
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(world.tint.opacity(0.08)))
    }
}
