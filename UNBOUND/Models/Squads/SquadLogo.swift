import Foundation

struct SquadLogoPreset: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let assetName: String
    let palette: Palette

    enum Palette: String, CaseIterable, Sendable {
        case forge
        case ember
        case volt
        case crown
        case steel
        case pulse
        case nova
        case glacier
        case neon
        case prism
        case dusk
        case signal
    }
}

enum SquadLogoCatalog {
    static let defaultId = "monk"

    // Titles are VoiceOver descriptions only; the UI shows just the mark.
    static let presets: [SquadLogoPreset] = [
        SquadLogoPreset(id: "monk", title: "Meditating monk", assetName: "squad_logo_monk", palette: .nova),
        SquadLogoPreset(id: "fighter", title: "Scarred fighter", assetName: "squad_logo_fighter", palette: .signal),
        SquadLogoPreset(id: "fist", title: "Wrapped fist and rising sun", assetName: "squad_logo_fist", palette: .ember),
        SquadLogoPreset(id: "surge", title: "Energy surge", assetName: "squad_logo_surge", palette: .forge),
        SquadLogoPreset(id: "spotlight", title: "Spotlit hero", assetName: "squad_logo_spotlight", palette: .crown),
        SquadLogoPreset(id: "awakening", title: "Awakening statue", assetName: "squad_logo_awakening", palette: .steel),
        SquadLogoPreset(id: "wingfoot", title: "Crossed-out winged shoe", assetName: "squad_logo_wingfoot", palette: .prism),
        SquadLogoPreset(id: "drumstick", title: "Torso on chicken legs", assetName: "squad_logo_drumstick", palette: .crown),
        SquadLogoPreset(id: "crownbar", title: "Crowned barbell", assetName: "squad_logo_crownbar", palette: .pulse),
        SquadLogoPreset(id: "rat", title: "Gym rat", assetName: "squad_logo_rat", palette: .prism),
        SquadLogoPreset(id: "shadow", title: "Shadowed villain", assetName: "squad_logo_shadow", palette: .dusk),
        SquadLogoPreset(id: "goblin", title: "Shaker goblin", assetName: "squad_logo_goblin", palette: .neon),
        SquadLogoPreset(id: "moai", title: "Moai with barbell", assetName: "squad_logo_moai", palette: .glacier)
    ]

    private static let retiredIdAliases: [String: String] = [
        "forge": "monk",
        "ember": "fist",
        "volt": "spotlight",
        "crown": "shadow",
        "pulse": "rat",
        "barbell": "crownbar",
        "nova": "surge",
        "glacier": "wingfoot",
        "focus": "fighter",
        "prism": "shadow",
        "eclipse": "fist",
        "signal": "fighter"
    ]

    static func preset(for id: String?) -> SquadLogoPreset {
        presets.first { $0.id == resolvedId(id) } ?? presets[0]
    }

    static func resolvedId(_ id: String?) -> String {
        guard let id
        else {
            return defaultId
        }
        let resolvedId = retiredIdAliases[id] ?? id
        guard presets.contains(where: { $0.id == resolvedId }) else {
            return defaultId
        }
        return resolvedId
    }
}
