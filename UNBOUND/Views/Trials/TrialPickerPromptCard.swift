import SwiftUI

// MARK: - TrialPickerPromptCard
//
// Compact home banner shown before the weekly Binding Vow is chosen.

struct TrialPickerPromptCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            UnboundHaptics.soft()
            onTap()
        }) {
            HStack(spacing: 13) {
                WeeklyVowProofAsset(kind: .overdrive, tint: Color.unbound.accent, compact: true)
                    .frame(width: 42, height: 42)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Text("BINDING VOW")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .tracking(1.5)
                            .foregroundStyle(Color.unbound.accent)
                            .lineLimit(1)
                        Text("3 OPTIONS")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .tracking(1.0)
                            .foregroundStyle(Color.unbound.textTertiary)
                            .lineLimit(1)
                    }

                    Text("Pick this week's vow")
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)
                }
                .layoutPriority(1)

                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    Text("BIND")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(1.2)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .black))
                }
                .foregroundStyle(Color.unbound.bg)
                .padding(.horizontal, 11)
                .frame(height: 28)
                .background(Color.unbound.accent)
                .clipShape(Capsule())
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                ZStack(alignment: .trailing) {
                    Color.unbound.surface
                    TrialCutShape()
                        .fill(Color.unbound.accent.opacity(0.12))
                        .frame(width: 132)
                }
            )
            .overlay(
                Rectangle()
                    .fill(Color.unbound.accent.opacity(0.42))
                    .frame(width: 2),
                alignment: .leading
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.unbound.accent.opacity(0.22), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct TrialStrikeMark: View {
    let tint: Color

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                TrialCutShape()
                    .fill(tint.opacity(index == 1 ? 0.88 : 0.28))
                    .frame(width: 9, height: CGFloat(24 + index * 6))
                    .offset(x: CGFloat(index - 1) * 9)
            }
        }
    }
}

private struct TrialCutShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let lean = rect.width * 0.38
        path.move(to: CGPoint(x: rect.minX + lean, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - lean, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.unbound.bg.ignoresSafeArea()
        TrialPickerPromptCard(onTap: {})
            .padding(20)
    }
}
