import Foundation
import SwiftUI
import UIKit

struct HomeBackgroundContrastScrim: View {
    let size: CGSize

    var body: some View {
        let longestSide = max(size.width, size.height)

        ZStack {
            Color.unbound.bg.opacity(0.06)

            LinearGradient(
                colors: [
                    Color.unbound.bg.opacity(0.22),
                    Color.unbound.bg.opacity(0.10),
                    Color.unbound.bg.opacity(0.46)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [
                    Color.unbound.bg.opacity(0.22),
                    Color.unbound.bg.opacity(0.08),
                    Color.unbound.bg.opacity(0.02)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            RadialGradient(
                colors: [
                    Color.unbound.bg.opacity(0.00),
                    Color.unbound.bg.opacity(0.32)
                ],
                center: UnitPoint(x: 0.54, y: 0.16),
                startRadius: longestSide * 0.16,
                endRadius: longestSide * 0.78
            )
        }
    }
}

struct HomeLegibilityPlane: ViewModifier {
    let cornerRadius: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.unbound.bg.opacity(0.78))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.unbound.surface.opacity(0.12))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.24), radius: 18, x: 0, y: 10)
    }
}

extension View {
    func homeLegibilityPlane(
        cornerRadius: CGFloat,
        horizontalPadding: CGFloat,
        verticalPadding: CGFloat
    ) -> some View {
        modifier(
            HomeLegibilityPlane(
                cornerRadius: cornerRadius,
                horizontalPadding: horizontalPadding,
                verticalPadding: verticalPadding
            )
        )
    }
}

struct HomeIconCommand: View {
    let systemName: String
    let value: String
    let label: String
    let tint: Color
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemName)
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(tint)
                    .frame(height: 25)
                    .shadow(color: tint.opacity(0.26), radius: 6)

                Text(value.uppercased())
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                    .allowsTightening(true)
                    .fixedSize(horizontal: true, vertical: false)

                Text(label.uppercased())
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .tracking(0.9)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .allowsTightening(true)
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 4)
            .frame(minWidth: 64, maxWidth: .infinity)
            .frame(minHeight: 70)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
