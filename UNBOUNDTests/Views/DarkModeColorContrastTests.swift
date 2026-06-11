import SwiftUI
import UIKit
import XCTest
@testable import UNBOUND

@MainActor
final class DarkModeColorContrastTests: XCTestCase {
    private let normalTextMinimum = 4.5
    private let statusTextMinimum = 3.0

    func testUnboundTextTokensMeetAAContrastOnDarkSurfaces() {
        let backgrounds = [
            ColorToken("bg", Color.unbound.bg),
            ColorToken("surface", Color.unbound.surface),
            ColorToken("surfaceElevated", Color.unbound.surfaceElevated)
        ]
        let textTokens = [
            ColorToken("textPrimary", Color.unbound.textPrimary),
            ColorToken("textSecondary", Color.unbound.textSecondary),
            ColorToken("textTertiary", Color.unbound.textTertiary)
        ]

        assertContrast(
            foregrounds: textTokens,
            backgrounds: backgrounds,
            minimum: normalTextMinimum,
            rule: "normal text"
        )
    }

    func testSemanticTintTokensStayReadableOnDarkSurfaces() {
        let backgrounds = [
            ColorToken("bg", Color.unbound.bg),
            ColorToken("surface", Color.unbound.surface),
            ColorToken("surfaceElevated", Color.unbound.surfaceElevated)
        ]
        let tintTokens = [
            ColorToken("accent", Color.unbound.accent),
            ColorToken("impact", Color.unbound.impact),
            ColorToken("ember", Color.unbound.ember),
            ColorToken("emberGlow", Color.unbound.emberGlow),
            ColorToken("alert", Color.unbound.alert),
            ColorToken("success", Color.unbound.success),
            ColorToken("coachCyan", Color.unbound.coachCyan),
            ColorToken("warnOrange", Color.unbound.warnOrange),
            ColorToken("rankRed", Color.unbound.rankRed),
            ColorToken("rankOrange", Color.unbound.rankOrange),
            ColorToken("rankAmber", Color.unbound.rankAmber),
            ColorToken("rankGreen", Color.unbound.rankGreen),
            ColorToken("rankGold", Color.unbound.rankGold)
        ]

        assertContrast(
            foregrounds: tintTokens,
            backgrounds: backgrounds,
            minimum: statusTextMinimum,
            rule: "status/accent text"
        )
    }

    private func assertContrast(
        foregrounds: [ColorToken],
        backgrounds: [ColorToken],
        minimum: Double,
        rule: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for foreground in foregrounds {
            for background in backgrounds {
                let ratio = contrastRatio(foreground.color, background.color, file: file, line: line)
                XCTAssertGreaterThanOrEqual(
                    ratio,
                    minimum,
                    "\(foreground.name) on \(background.name) is \(formatted(ratio)):1, below \(formatted(minimum)):1 for \(rule)",
                    file: file,
                    line: line
                )
            }
        }
    }

    private func contrastRatio(
        _ foreground: Color,
        _ background: Color,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Double {
        let foregroundLuminance = relativeLuminance(resolvedRGB(foreground, file: file, line: line))
        let backgroundLuminance = relativeLuminance(resolvedRGB(background, file: file, line: line))
        let lighter = max(foregroundLuminance, backgroundLuminance)
        let darker = min(foregroundLuminance, backgroundLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func relativeLuminance(_ rgb: RGB) -> Double {
        let red = linearized(rgb.red)
        let green = linearized(rgb.green)
        let blue = linearized(rgb.blue)
        return 0.2126 * red + 0.7152 * green + 0.0722 * blue
    }

    private func linearized(_ channel: Double) -> Double {
        channel <= 0.04045
            ? channel / 12.92
            : pow((channel + 0.055) / 1.055, 2.4)
    }

    private func resolvedRGB(
        _ color: Color,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> RGB {
        let darkTraits = UITraitCollection(userInterfaceStyle: .dark)
        let resolved = UIColor(color).resolvedColor(with: darkTraits)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            XCTFail("Could not resolve color into sRGB components", file: file, line: line)
            return RGB(red: 0, green: 0, blue: 0, alpha: 1)
        }

        return RGB(
            red: Double(red),
            green: Double(green),
            blue: Double(blue),
            alpha: Double(alpha)
        )
    }

    private func formatted(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}

private struct ColorToken {
    let name: String
    let color: Color

    init(_ name: String, _ color: Color) {
        self.name = name
        self.color = color
    }
}

private struct RGB {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
}
