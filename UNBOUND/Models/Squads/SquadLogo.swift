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
        SquadLogoPreset(id: "forge", title: "Shadow Legion", assetName: "squad_logo_forge", palette: .forge),
        SquadLogoPreset(id: "ember", title: "Hunter Guild", assetName: "squad_logo_ember", palette: .ember),
        SquadLogoPreset(id: "volt", title: "White Tiger", assetName: "squad_logo_volt", palette: .volt),
        SquadLogoPreset(id: "crown", title: "Gatebreakers", assetName: "squad_logo_crown", palette: .crown),
        SquadLogoPreset(id: "barbell", title: "Iron Guard", assetName: "squad_logo_barbell", palette: .steel),
        SquadLogoPreset(id: "pulse", title: "Striker Unit", assetName: "squad_logo_pulse", palette: .pulse),
        SquadLogoPreset(id: "nova", title: "Scout Wing", assetName: "squad_logo_nova", palette: .nova),
        SquadLogoPreset(id: "glacier", title: "Arcane Tower", assetName: "squad_logo_glacier", palette: .glacier),
        SquadLogoPreset(id: "focus", title: "Assassin Cell", assetName: "squad_logo_focus", palette: .neon),
        SquadLogoPreset(id: "prism", title: "Reaper Order", assetName: "squad_logo_prism", palette: .prism),
        SquadLogoPreset(id: "eclipse", title: "Berserker Fang", assetName: "squad_logo_eclipse", palette: .dusk),
        SquadLogoPreset(id: "signal", title: "Raid Command", assetName: "squad_logo_signal", palette: .signal)
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
