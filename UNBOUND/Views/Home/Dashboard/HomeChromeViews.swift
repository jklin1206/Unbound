import Foundation
import SwiftUI
import UIKit

struct HomeBackgroundContrastScrim: View {
    let size: CGSize

    var body: some View {
        let longestSide = max(size.width, size.height)

        ZStack {
            Color.unbound.bg.opacity(0.18)

            LinearGradient(
                colors: [
                    Color.unbound.bg.opacity(0.46),
                    Color.unbound.bg.opacity(0.24),
                    Color.unbound.bg.opacity(0.72)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [
                    Color.unbound.bg.opacity(0.42),
                    Color.unbound.bg.opacity(0.18),
                    Color.unbound.bg.opacity(0.06)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            RadialGradient(
                colors: [
                    Color.unbound.bg.opacity(0.00),
                    Color.unbound.bg.opacity(0.46)
                ],
                center: UnitPoint(x: 0.54, y: 0.16),
                startRadius: longestSide * 0.16,
                endRadius: longestSide * 0.78
            )
        }
    }
}

enum HomeCommandArtworkKind {
    case rankTrial
    case vow
    case shop
    case backdrops
    case rankLibrary
    case weight
}

/// Visual identity for a command family — semantic grouping so the six entries
/// read as two tuned sets, not a rainbow. Token-only per the palette rule:
/// Progression is warm (ember -> gold), Cosmetics is cool (violet -> teal).
struct HomeCommandPalette {
    let glyph: Color
    let chipTop: Color
    let chipBottom: Color

    static let progression = HomeCommandPalette(
        glyph: Color.unbound.emberGlow,
        chipTop: Color.unbound.ember.opacity(0.26),
        chipBottom: Color.unbound.rankGold.opacity(0.12)
    )

    static let cosmetics = HomeCommandPalette(
        glyph: Color.unbound.coachCyan,
        chipTop: Color.unbound.accent.opacity(0.26),
        chipBottom: Color.unbound.coachCyan.opacity(0.12)
    )
}

/// One command entry. Each opens another screen, so it presents as a row that
/// obviously navigates — icon chip · title · live status · chevron.
struct HomeCommand {
    let artwork: HomeCommandArtworkKind
    let title: String
    let detail: String
    let accessibilityLabel: String
    let action: () -> Void
}

/// A grouped, inset section of command rows (Settings-style) on one elevated
/// surface, so the cluster reads as a discrete component, not one long sheet.
struct HomeCommandSection: View {
    let title: String
    let palette: HomeCommandPalette
    let commands: [HomeCommand]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(1.8)
                .foregroundStyle(Color.unbound.textTertiary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(Array(commands.enumerated()), id: \.offset) { index, command in
                    if index > 0 {
                        Rectangle()
                            .fill(Color.unbound.borderSubtle)
                            .frame(height: 0.5)
                            .padding(.leading, 61)
                    }
                    HomeCommandRow(command: command, palette: palette)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.unbound.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

struct HomeCommandRow: View {
    let command: HomeCommand
    let palette: HomeCommandPalette

    var body: some View {
        Button(action: command.action) {
            HStack(spacing: 13) {
                iconChip

                Text(command.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: 8)

                if !command.detail.isEmpty {
                    Text(command.detail)
                        .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .layoutPriority(1)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(HomeCommandButtonStyle())
        .accessibilityLabel(command.accessibilityLabel)
    }

    private var iconChip: some View {
        RoundedRectangle(cornerRadius: 11, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [palette.chipTop, palette.chipBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(palette.glyph.opacity(0.22), lineWidth: 1)
            )
            .frame(width: 34, height: 34)
            .overlay(HomeCommandMiniGlyph(kind: command.artwork, tint: palette.glyph))
    }
}

/// Makes a command row feel pressed, not just tapped: a small scale-in +
/// brighten with a soft haptic on touch-down (reduced-motion drops the scale).
struct HomeCommandButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1.0)
            .brightness(configuration.isPressed ? 0.05 : 0)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { UnboundHaptics.soft() }
            }
    }
}

private struct HomeCommandMiniGlyph: View {
    let kind: HomeCommandArtworkKind
    let tint: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: fontSize, weight: .black))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(tint)
    }

    private var systemName: String {
        switch kind {
        case .rankTrial: return "key.fill"
        case .vow: return "link"
        case .shop: return "bag.fill"
        case .backdrops: return "photo.on.rectangle.angled"
        case .rankLibrary: return "list.bullet.rectangle.portrait.fill"
        case .weight: return "scalemass.fill"
        }
    }

    private var fontSize: CGFloat {
        switch kind {
        case .vow: return 17
        case .backdrops: return 15
        default: return 16
        }
    }
}
