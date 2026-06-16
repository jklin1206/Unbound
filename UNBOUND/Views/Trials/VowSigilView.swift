import SwiftUI

// MARK: - VowSigilView
//
// Functional vector render of the evolving profile oath-mark (spec §8). A radial
// ring of wedges: `sigil.sealedSegments` lit in `accent`, the rest a dim surface
// tone. The center `seal.fill` glyph softens (never cracks) while fractures are
// still active, so the mark reads as "healing", not "broken". Final illustrated
// art is deferred — this is the token-only interim.
//
// Reduced-motion safe: no required animation; the render is fully static.

struct VowSigilView: View {
    let sigil: VowSigil
    var accent: Color = Color.unbound.rankGold

    /// Fixed ring resolution. Lit wedges saturate when keeps exceed the ring.
    private let segmentCount = 12

    private var litCount: Int { min(segmentCount, sigil.sealedSegments) }
    private var isHealing: Bool { sigil.activeFractures > 0 }

    var body: some View {
        ZStack {
            ForEach(0..<segmentCount, id: \.self) { index in
                let isLit = index < litCount
                Capsule(style: .continuous)
                    .fill(isLit ? accent : Color.unbound.surfaceElevated)
                    .frame(width: 4, height: 13)
                    .opacity(isLit ? 1 : 0.7)
                    .offset(y: -28)
                    .rotationEffect(.degrees(Double(index) / Double(segmentCount) * 360))
            }

            Circle()
                .strokeBorder(accent.opacity(0.18), lineWidth: 1)
                .frame(width: 40, height: 40)

            Image(systemName: "seal.fill")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(accent)
                // Healing softens the seal rather than fracturing it — never negging.
                .opacity(isHealing ? 0.62 : 1)
        }
        .frame(width: 72, height: 72)
        .accessibilityElement()
        .accessibilityLabel(
            isHealing
                ? "Vow sigil. \(sigil.sealedSegments) vows sealed, mending."
                : "Vow sigil. \(sigil.sealedSegments) vows sealed."
        )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.unbound.bg.ignoresSafeArea()
        HStack(spacing: 28) {
            VowSigilView(sigil: VowSigil(keptVows: 7, brokenVows: 0))
            VowSigilView(sigil: VowSigil(keptVows: 2, brokenVows: 1))
            VowSigilView(sigil: VowSigil(keptVows: 0, brokenVows: 0), accent: Color.unbound.coachCyan)
        }
    }
}
