import SwiftUI

struct LifestyleSignalAsset: View {
    enum Kind {
        case diet, sleep, stress

        var icon: String {
            switch self {
            case .diet: return "leaf.fill"
            case .sleep: return "moon.stars.fill"
            case .stress: return "waveform.path.ecg"
            }
        }

        var title: String {
            switch self {
            case .diet: return "FUEL"
            case .sleep: return "RECOVERY"
            case .stress: return "LOAD"
            }
        }

        var tint: Color {
            switch self {
            case .diet: return Color.unbound.impact
            case .sleep: return Color.unbound.accent
            case .stress: return Color.unbound.ember
            }
        }
    }

    let kind: Kind
    let value: Int

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(kind.tint.opacity(0.14))
                    .frame(width: 64, height: 64)
                Circle()
                    .stroke(kind.tint.opacity(0.42), lineWidth: 1)
                    .frame(width: 64, height: 64)
                Image(systemName: kind.icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(kind.tint)
                    .shadow(color: kind.tint.opacity(0.45), radius: 12)
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text(kind.title)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1.8)
                        .foregroundStyle(kind.tint)
                    Text("\(value)/10")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.unbound.textTertiary)
                        .monospacedDigit()
                }

                HStack(spacing: 5) {
                    ForEach(1...10, id: \.self) { index in
                        ChamferedRectangle(inset: 1)
                            .fill(index <= value ? kind.tint : Color.unbound.borderSubtle.opacity(0.75))
                            .frame(height: 8)
                            .opacity(index <= value ? 1 : 0.55)
                            .shadow(color: index == value ? kind.tint.opacity(0.45) : .clear, radius: 6)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.26))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(kind.tint.opacity(0.24), lineWidth: 1)
        )
    }
}
