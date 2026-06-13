import SwiftUI

/// The minted gate card / share card (spec §6.6/§6.8): banner + numeral + trial
/// name + date + defining number + destination crest stamp. Stamped (passed) vs
/// unstamped (failed/in-progress, with attempt count).
struct GateCardView: View {
    let world: GateWorld
    let dateText: String?
    let definingNumber: String?
    let stamped: Bool
    var attemptCount: Int? = nil

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(world.bannerAssetName).resizable().scaledToFill()
                .frame(height: 220).clipped()
                .saturation(stamped ? 1 : 0.4)
                .overlay(LinearGradient(colors: [.clear, Color.black.opacity(0.7)],
                    startPoint: .center, endPoint: .bottom))

            if stamped {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 30, weight: .black))
                    .foregroundStyle(world.fillTint)
                    .padding(12).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("RANK GATE \(world.numeral)").font(Font.unbound.captionS.weight(.heavy)).tracking(2)
                    .foregroundStyle(world.tint)
                Text(world.trialName.uppercased()).font(Font.unbound.titleM.weight(.black))
                    .foregroundStyle(Color.unbound.textPrimary)
                HStack(spacing: 10) {
                    if let definingNumber {
                        Text(definingNumber).font(Font.unbound.monoS.weight(.heavy)).foregroundStyle(world.tint)
                    }
                    if let dateText {
                        Text(dateText).font(Font.unbound.captionS).foregroundStyle(Color.unbound.textTertiary)
                    }
                    if !stamped, let attemptCount {
                        Text("ATTEMPT \(attemptCount)").font(Font.unbound.captionS.weight(.bold))
                            .foregroundStyle(Color.unbound.warnOrange)
                    }
                }
            }
            .padding(16)
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(world.tint.opacity(stamped ? 0.6 : 0.25), lineWidth: 1))
        .accessibilityIdentifier("gate-card")
    }
}
