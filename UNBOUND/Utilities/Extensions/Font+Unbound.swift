import SwiftUI

// MARK: - Unbound Font Tokens
//
// Premium typography per UNBOUND_PROMPT.md spec.
//
// Every token below scales with the user's Dynamic Type setting while rendering
// IDENTICALLY to its former fixed point size at the default (Large) content size
// category. Two mechanisms are used, both of which SwiftUI resolves against the
// environment at render time (so the tokens stay dynamic even though they are
// stored `let`s):
//   - Tokens whose base size equals a `Font.TextStyle` default size use
//     `Font.system(_:design:weight:)`, anchored to the nearest semantic style.
//   - Off-size tokens (e.g. the 56 pt hero) use `unboundScaled(_:relativeTo:...)`,
//     which preserves the exact base size and borrows the anchor style's scale
//     curve. iOS 17 ships no `Font.system(size:relativeTo:)`, so this is the only
//     pure-SwiftUI way to scale an arbitrary-size system font.
//
// TODO(fonts): bundle actual type files in Resources/Fonts/ and add to Xcode target:
//   - Display:  PP Neue Montreal (Bold)   - fallback: Inter Tight ExtraBold, then system serif-less heavy
//   - Body:     Inter                     - fallback: system (SF Pro)
//   - Numbers:  Geist Mono                - fallback: IBM Plex Mono, then .monospaced
//
// Until the .ttf files are bundled, the system fallbacks below ship a good-enough
// premium feel. When the files land, feed their bundled names into `unboundScaled`
// / swap the `.system` lines - the Dynamic Type anchoring stays the same.

extension Font {
    static let unbound = UnboundFonts()
}

extension Font {
    // Arbitrary-size system font that scales with Dynamic Type.
    //
    // `Font.custom(_:size:relativeTo:)` is the only pure-SwiftUI initializer that
    // scales an arbitrary base `size` against a text style. The name passed here is
    // deliberately not a bundled face, so it resolves to the San Francisco system
    // font while keeping the size + relativeTo scaling and honouring the weight /
    // monospaced modifiers. At the default (Large) category the result is pixel
    // identical to `Font.system(size:weight:design:)`; above/below default it grows
    // and shrinks along `textStyle`'s Dynamic Type curve.
    static func unboundScaled(
        _ size: CGFloat,
        relativeTo textStyle: Font.TextStyle,
        weight: Font.Weight,
        monospaced: Bool = false
    ) -> Font {
        let scaled = Font.custom("UnboundSystemFallback", size: size, relativeTo: textStyle)
            .weight(weight)
        return monospaced ? scaled.monospaced() : scaled
    }
}

struct UnboundFonts {
    // Display - hero screens, verdict, rank changes (off-size, anchored to .largeTitle)
    let displayXL = Font.unboundScaled(56, relativeTo: .largeTitle, weight: .black)
    let displayL  = Font.unboundScaled(40, relativeTo: .largeTitle, weight: .heavy)
    let displayM  = Font.unboundScaled(32, relativeTo: .largeTitle, weight: .bold)

    // Titles - screen headlines
    let titleL = Font.system(.title,  weight: .bold)      // 28 pt
    let titleM = Font.system(.title2, weight: .semibold)  // 22 pt
    let titleS = Font.unboundScaled(18, relativeTo: .title3, weight: .semibold) // off-size

    // Body
    let bodyL = Font.system(.body,        weight: .regular) // 17 pt
    let bodyM = Font.system(.subheadline, weight: .regular) // 15 pt
    let bodyS = Font.system(.footnote,    weight: .regular) // 13 pt

    // Emphasized body (button labels, selected state)
    let bodyMStrong = Font.system(.subheadline, weight: .semibold) // 15 pt
    let bodyLStrong = Font.system(.body,        weight: .semibold) // 17 pt

    // Caption / meta
    let caption   = Font.system(.caption,  weight: .regular) // 12 pt
    let captionS  = Font.system(.caption2, weight: .medium)  // 11 pt

    // Mono - numbers, readouts, stats (Geist Mono fallback = .monospaced)
    let monoXL = Font.unboundScaled(48, relativeTo: .largeTitle, weight: .bold, monospaced: true) // off-size
    let monoL  = Font.system(.title,    design: .monospaced, weight: .semibold) // 28 pt
    let monoM  = Font.unboundScaled(18, relativeTo: .body, weight: .medium, monospaced: true) // off-size
    let monoS  = Font.system(.footnote, design: .monospaced, weight: .regular)  // 13 pt
}
