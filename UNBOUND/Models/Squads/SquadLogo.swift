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
    static let defaultId = "forge"

    static let presets: [SquadLogoPreset] = [
        SquadLogoPreset(id: "forge", title: "Strawhat Blades", assetName: "squad_logo_forge", palette: .forge),
        SquadLogoPreset(id: "ember", title: "Golden Charge", assetName: "squad_logo_ember", palette: .ember),
        SquadLogoPreset(id: "volt", title: "Bald Cape", assetName: "squad_logo_volt", palette: .volt),
        SquadLogoPreset(id: "crown", title: "Shadow Monarchs", assetName: "squad_logo_crown", palette: .nova),
        SquadLogoPreset(id: "pulse", title: "Cursed Blade", assetName: "squad_logo_pulse", palette: .signal),
        SquadLogoPreset(id: "barbell", title: "Slayer Breath", assetName: "squad_logo_barbell", palette: .prism),
        SquadLogoPreset(id: "nova", title: "Hero Spark", assetName: "squad_logo_nova", palette: .neon),
        SquadLogoPreset(id: "glacier", title: "Stand Rush", assetName: "squad_logo_glacier", palette: .nova),
        SquadLogoPreset(id: "focus", title: "Soul Reaper", assetName: "squad_logo_focus", palette: .ember)
    ]

    private static let retiredIdAliases: [String: String] = [
        "prism": "crown",
        "eclipse": "ember",
        "signal": "focus"
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
