import SwiftUI

// MARK: - Unbound Font Tokens
//
// Premium typography per UNBOUND_PROMPT.md spec.
//
// TODO(fonts): bundle actual type files in Resources/Fonts/ and add to Xcode target:
//   - Display:  PP Neue Montreal (Bold)   — fallback: Inter Tight ExtraBold, then system serif-less heavy
//   - Body:     Inter                     — fallback: system (SF Pro)
//   - Numbers:  Geist Mono                — fallback: IBM Plex Mono, then .monospaced
//
// Until the .ttf files are bundled, the `.system(...)` fallbacks below ship a
// good-enough premium feel. Swap the `.system` lines for `.custom(name:, size:)`
// once the files land.

extension Font {
    static let unbound = UnboundFonts()
}

struct UnboundFonts {
    // Display — hero screens, verdict, rank changes
    let displayXL = Font.system(size: 56, weight: .black, design: .default)
    let displayL  = Font.system(size: 40, weight: .heavy, design: .default)
    let displayM  = Font.system(size: 32, weight: .bold,  design: .default)

    // Titles — screen headlines
    let titleL = Font.system(size: 28, weight: .bold,      design: .default)
    let titleM = Font.system(size: 22, weight: .semibold,  design: .default)
    let titleS = Font.system(size: 18, weight: .semibold,  design: .default)

    // Body
    let bodyL = Font.system(size: 17, weight: .regular, design: .default)
    let bodyM = Font.system(size: 15, weight: .regular, design: .default)
    let bodyS = Font.system(size: 13, weight: .regular, design: .default)

    // Emphasized body (button labels, selected state)
    let bodyMStrong = Font.system(size: 15, weight: .semibold, design: .default)
    let bodyLStrong = Font.system(size: 17, weight: .semibold, design: .default)

    // Caption / meta
    let caption   = Font.system(size: 12, weight: .regular, design: .default)
    let captionS  = Font.system(size: 11, weight: .medium,  design: .default)

    // Mono — numbers, readouts, stats (Geist Mono fallback = .monospaced)
    let monoXL = Font.system(size: 48, weight: .bold,     design: .monospaced)
    let monoL  = Font.system(size: 28, weight: .semibold, design: .monospaced)
    let monoM  = Font.system(size: 18, weight: .medium,   design: .monospaced)
    let monoS  = Font.system(size: 13, weight: .regular,  design: .monospaced)
}
