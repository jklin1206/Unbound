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
        SquadLogoPreset(id: "forge", title: "Alchemy", assetName: "squad_logo_forge", palette: .forge),
        SquadLogoPreset(id: "ember", title: "Slayer", assetName: "squad_logo_ember", palette: .ember),
        SquadLogoPreset(id: "volt", title: "Hero Bolt", assetName: "squad_logo_volt", palette: .volt),
        SquadLogoPreset(id: "crown", title: "Straw Hat", assetName: "squad_logo_crown", palette: .crown),
        SquadLogoPreset(id: "barbell", title: "Scouts", assetName: "squad_logo_barbell", palette: .steel),
        SquadLogoPreset(id: "pulse", title: "Domain", assetName: "squad_logo_pulse", palette: .pulse),
        SquadLogoPreset(id: "nova", title: "Spiral", assetName: "squad_logo_nova", palette: .nova),
        SquadLogoPreset(id: "glacier", title: "Soul Moon", assetName: "squad_logo_glacier", palette: .glacier),
        SquadLogoPreset(id: "focus", title: "Limitless", assetName: "squad_logo_focus", palette: .neon),
        SquadLogoPreset(id: "prism", title: "Stand", assetName: "squad_logo_prism", palette: .prism),
        SquadLogoPreset(id: "eclipse", title: "Saiyan", assetName: "squad_logo_eclipse", palette: .dusk),
        SquadLogoPreset(id: "signal", title: "Sync", assetName: "squad_logo_signal", palette: .signal)
    ]

    static func preset(for id: String?) -> SquadLogoPreset {
        presets.first { $0.id == resolvedId(id) } ?? presets[0]
    }

    static func resolvedId(_ id: String?) -> String {
        guard let id,
              presets.contains(where: { $0.id == id })
        else {
            return defaultId
        }
        return id
    }
}
