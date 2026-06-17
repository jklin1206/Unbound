import SwiftUI

enum ShopCategory: String, CaseIterable, Identifiable {
    case backdrop
    case profileBorder
    case profileWallpaper
    case skillTree
    case title

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .backdrop: return "Backdrops"
        case .profileWallpaper: return "Profile Banners"
        case .skillTree: return "Tree Skins"
        case .profileBorder: return "Borders"
        case .title: return "Titles"
        }
    }

    var systemImage: String {
        switch self {
        case .backdrop: return "house.fill"
        case .profileWallpaper: return "person.crop.rectangle.stack.fill"
        case .skillTree: return "point.3.connected.trianglepath.dotted"
        case .profileBorder: return "person.crop.circle.badge.sparkles"
        case .title: return "textformat.alt"
        }
    }
}

enum ShopItemReward: Hashable {
    case homeBackground(ShopHomeBackgroundID)
    case skillTreeSkin(SkillTreeSkin)
    case profileBorder(ShopProfileBorderID)
    case profileBackground(ShopProfileBackgroundID)
    case profileTitle(TitleID)
}

enum ShopBackdropSurface: String, CaseIterable, Identifiable, Hashable {
    case home
    case profile

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .home: return "Home"
        case .profile: return "Profile"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .profile: return "person.crop.rectangle.stack.fill"
        }
    }
}

enum ShopHomeBackgroundID: String, Codable, CaseIterable, Hashable, Identifiable {
    case chalk
    case chamber
    case streetNeon = "street_neon"
    case inkDojo = "ink_dojo"
    case emeraldShrine = "emerald_shrine"
    case solarCourt = "solar_court"
    case glassCircuit = "glass_circuit"
    case archiveWall = "archive_wall"
    case lockerWall = "locker_wall"
    case dojoScroll = "dojo_scroll"
    case overgrownGate = "overgrown_gate"
    case neonAtrium = "neon_atrium"
    case solarForge = "solar_forge"
    case holoForge = "holo_forge"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chalk: return "Chalk Chamber"
        case .chamber: return "Core Chamber"
        case .streetNeon: return "Street Neon"
        case .inkDojo: return "Ink Dojo"
        case .emeraldShrine: return "Emerald Shrine"
        case .solarCourt: return "Solar Court"
        case .glassCircuit: return "Glass Circuit"
        case .archiveWall: return "The Archive"
        case .lockerWall: return "The Locker Room"
        case .dojoScroll: return "The Dojo Scroll"
        case .overgrownGate: return "The Overgrown Gate"
        case .neonAtrium: return "The Neon Atrium"
        case .solarForge: return "The Solar Forge"
        case .holoForge: return "The Prism Sanctum"
        }
    }

    var assetName: String {
        switch self {
        case .chalk, .chamber, .streetNeon, .inkDojo, .emeraldShrine, .solarCourt, .glassCircuit:
            return "home_background_\(rawValue)"
        case .archiveWall, .lockerWall, .dojoScroll, .overgrownGate, .neonAtrium, .solarForge, .holoForge:
            return "shop_profile_bg_\(rawValue)"
        }
    }

    var accent: Color {
        switch self {
        case .chalk: return Color.skinHex("2DD4BF")
        case .chamber: return Color.skinHex("8B5CF6")
        case .streetNeon: return Color.skinHex("FF4FD8")
        case .inkDojo: return Color.skinHex("2DD4BF")
        case .emeraldShrine: return Color.skinHex("55D487")
        case .solarCourt: return Color.skinHex("F6C95B")
        case .glassCircuit: return Color.skinHex("F6C95B")
        case .archiveWall: return Color.skinHex("38BDF8")
        case .lockerWall: return Color.skinHex("38BDF8")
        case .dojoScroll: return Color.skinHex("EDE6D6")
        case .overgrownGate: return Color.skinHex("55D487")
        case .neonAtrium: return Color.skinHex("FF4FD8")
        case .solarForge: return Color.skinHex("F6C95B")
        case .holoForge: return Color.skinHex("67E8F9")
        }
    }
}

enum ShopProfileBorderID: String, Codable, CaseIterable, Hashable, Identifiable {
    case bronzeRivets = "bronze_rivets"
    case tapeWrap = "tape_wrap"
    case paperSeal = "paper_seal"
    case prismCircuit = "prism_circuit"
    case crystalHalo = "crystal_halo"
    case solarCrest = "solar_crest"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bronzeRivets: return "Bronze Rivets"
        case .tapeWrap: return "Tape Wrap"
        case .paperSeal: return "Paper Seal"
        case .prismCircuit: return "Prism Circuit"
        case .crystalHalo: return "Crystal Halo"
        case .solarCrest: return "Solar Crest"
        }
    }

    var assetName: String {
        "shop_profile_border_\(rawValue)"
    }

    var accent: Color {
        switch self {
        case .bronzeRivets: return Color.skinHex("F97316")
        case .tapeWrap: return Color.skinHex("2DD4BF")
        case .paperSeal: return Color.skinHex("EDE6D6")
        case .prismCircuit: return Color.skinHex("F6C95B")
        case .crystalHalo: return Color.skinHex("A78BFA")
        case .solarCrest: return Color.skinHex("F6C95B")
        }
    }
}

enum ShopProfileBackgroundID: String, Codable, CaseIterable, Hashable, Identifiable {
    case archiveWall = "archive_wall"
    case lockerWall = "locker_wall"
    case dojoScroll = "dojo_scroll"
    case overgrownGate = "overgrown_gate"
    case neonAtrium = "neon_atrium"
    case solarForge = "solar_forge"
    case holoForge = "holo_forge"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .archiveWall: return "The Archive"
        case .lockerWall: return "The Locker Room"
        case .dojoScroll: return "The Dojo Scroll"
        case .overgrownGate: return "The Overgrown Gate"
        case .neonAtrium: return "The Neon Atrium"
        case .solarForge: return "The Solar Forge"
        case .holoForge: return "The Prism Sanctum"
        }
    }

    var assetName: String {
        "profile_banner_\(rawValue)"
    }

    var accent: Color {
        switch self {
        case .archiveWall: return Color.skinHex("22D3EE")
        case .lockerWall: return Color.skinHex("22D3EE")
        case .dojoScroll: return Color.skinHex("EDE6D6")
        case .overgrownGate: return Color.skinHex("55D487")
        case .neonAtrium: return Color.skinHex("FF4FD8")
        case .solarForge: return Color.skinHex("F6C95B")
        case .holoForge: return Color.skinHex("F6C95B")
        }
    }
}

struct ShopItem: Identifiable, Hashable {
    let id: String
    let category: ShopCategory
    let name: String
    let price: Int
    let rarity: String
    let reward: ShopItemReward
    let colors: [Color]

    var accent: Color {
        colors.first ?? Color.unbound.accent
    }

    private var normalizedRarity: String {
        rarity.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var rarityTint: Color {
        switch normalizedRarity {
        case "common":
            return Color.white
        case "rare":
            return Color.skinHex("38BDF8")
        case "epic":
            return Color.skinHex("A78BFA")
        case "legendary":
            return Color.skinHex("F6C95B")
        default:
            return accent
        }
    }

    var raritySortRank: Int {
        switch normalizedRarity {
        case "common": return 0
        case "rare": return 1
        case "epic": return 2
        case "legendary": return 3
        default: return 99
        }
    }

    var isBackdrop: Bool {
        backdropAssetName != nil
    }

    var backdropAssetName: String? {
        switch reward {
        case .homeBackground(let background):
            return background.assetName
        case .profileBackground(let background):
            return background.assetName
        default:
            return nil
        }
    }
}

enum ShopCatalog {
    static let items: [ShopItem] = [
        .init(
            id: "homeBackground.chamber",
            category: .backdrop,
            name: "Core Chamber",
            price: 650,
            rarity: "Rare",
            reward: .homeBackground(.chamber),
            colors: [Color.skinHex("8B5CF6"), Color.skinHex("22D3EE")]
        ),
        .init(
            id: "homeBackground.streetNeon",
            category: .backdrop,
            name: "Street Neon",
            price: 900,
            rarity: "Rare",
            reward: .homeBackground(.streetNeon),
            colors: [Color.skinHex("22D3EE"), Color.skinHex("FF4FD8")]
        ),
        .init(
            id: "homeBackground.inkDojo",
            category: .backdrop,
            name: "Ink Dojo",
            price: 1_100,
            rarity: "Rare",
            reward: .homeBackground(.inkDojo),
            colors: [Color.skinHex("EDE6D6"), Color.skinHex("2DD4BF"), Color.skinHex("D84B3D")]
        ),
        .init(
            id: "homeBackground.emeraldShrine",
            category: .backdrop,
            name: "Emerald Shrine",
            price: 1_450,
            rarity: "Epic",
            reward: .homeBackground(.emeraldShrine),
            colors: [Color.skinHex("55D487"), Color.skinHex("F6C95B"), Color.skinHex("5EEAD4")]
        ),
        .init(
            id: "homeBackground.solarCourt",
            category: .backdrop,
            name: "Solar Court",
            price: 1_650,
            rarity: "Epic",
            reward: .homeBackground(.solarCourt),
            colors: [Color.skinHex("F6C95B"), Color.skinHex("5EEAD4"), Color.skinHex("FF4FD8")]
        ),
        .init(
            id: "homeBackground.glassCircuit",
            category: .backdrop,
            name: "Glass Circuit",
            price: 2_350,
            rarity: "Epic",
            reward: .homeBackground(.glassCircuit),
            colors: [Color.skinHex("5EEAD4"), Color.skinHex("F6C95B")]
        ),
        .init(
            id: "homeBackground.archiveWall",
            category: .backdrop,
            name: "The Archive",
            price: 480,
            rarity: "Common",
            reward: .homeBackground(.archiveWall),
            colors: [Color.skinHex("38BDF8"), Color.skinHex("94A3B8")]
        ),
        .init(
            id: "homeBackground.lockerWall",
            category: .backdrop,
            name: "The Locker Room",
            price: 550,
            rarity: "Common",
            reward: .homeBackground(.lockerWall),
            colors: [Color.skinHex("38BDF8"), Color.skinHex("F97316")]
        ),
        .init(
            id: "homeBackground.dojoScroll",
            category: .backdrop,
            name: "The Dojo Scroll",
            price: 880,
            rarity: "Rare",
            reward: .homeBackground(.dojoScroll),
            colors: [Color.skinHex("EDE6D6"), Color.skinHex("2DD4BF"), Color.skinHex("D84B3D")]
        ),
        .init(
            id: "homeBackground.overgrownGate",
            category: .backdrop,
            name: "The Overgrown Gate",
            price: 1_250,
            rarity: "Epic",
            reward: .homeBackground(.overgrownGate),
            colors: [Color.skinHex("55D487"), Color.skinHex("F6C95B"), Color.skinHex("5EEAD4")]
        ),
        .init(
            id: "homeBackground.neonAtrium",
            category: .backdrop,
            name: "The Neon Atrium",
            price: 620,
            rarity: "Common",
            reward: .homeBackground(.neonAtrium),
            colors: [Color.skinHex("5EEAD4"), Color.skinHex("FF4FD8"), Color.skinHex("F6C95B")]
        ),
        .init(
            id: "homeBackground.solarForge",
            category: .backdrop,
            name: "The Solar Forge",
            price: 640,
            rarity: "Common",
            reward: .homeBackground(.solarForge),
            colors: [Color.skinHex("F6C95B"), Color.skinHex("5EEAD4")]
        ),
        .init(
            id: "homeBackground.holoForge",
            category: .backdrop,
            name: "The Prism Sanctum",
            price: 3_600,
            rarity: "Legendary",
            reward: .homeBackground(.holoForge),
            colors: [Color.skinHex("F6C95B"), Color.skinHex("67E8F9"), Color.skinHex("A78BFA"), Color.skinHex("FF4FD8")]
        ),
        .init(
            id: "skillTreeSkin.chalk",
            category: .skillTree,
            name: "Chalk Rails",
            price: 250,
            rarity: "Common",
            reward: .skillTreeSkin(.chalk),
            colors: [Color.skinHex("CBD5E1"), Color.skinHex("2DD4BF")]
        ),
        .init(
            id: "skillTreeSkin.blueprint",
            category: .skillTree,
            name: "Blueprint Rails",
            price: 520,
            rarity: "Common",
            reward: .skillTreeSkin(.blueprint),
            colors: [Color.skinHex("38BDF8"), Color.skinHex("E0F2FE")]
        ),
        .init(
            id: "skillTreeSkin.streetNeon",
            category: .skillTree,
            name: "Street Neon",
            price: 850,
            rarity: "Rare",
            reward: .skillTreeSkin(.streetNeon),
            colors: [Color.skinHex("22D3EE"), Color.skinHex("FF4FD8")]
        ),
        .init(
            id: "skillTreeSkin.inkDojo",
            category: .skillTree,
            name: "Ink Dojo",
            price: 1_050,
            rarity: "Rare",
            reward: .skillTreeSkin(.inkDojo),
            colors: [Color.skinHex("EDE6D6"), Color.skinHex("2DD4BF"), Color.skinHex("D84B3D")]
        ),
        .init(
            id: "skillTreeSkin.solarCircuit",
            category: .skillTree,
            name: "Solar Circuit",
            price: 1_550,
            rarity: "Epic",
            reward: .skillTreeSkin(.solarCircuit),
            colors: [Color.skinHex("F97316"), Color.skinHex("F6C95B"), Color.skinHex("5EEAD4")]
        ),
        .init(
            id: "skillTreeSkin.glassCircuit",
            category: .skillTree,
            name: "Glass Circuit",
            price: 1_850,
            rarity: "Epic",
            reward: .skillTreeSkin(.glassCircuit),
            colors: [Color.skinHex("5EEAD4"), Color.skinHex("F6C95B")]
        ),
        .init(
            id: "skillTreeSkin.crystalCavern",
            category: .skillTree,
            name: "Crystal Cavern",
            price: 2_050,
            rarity: "Epic",
            reward: .skillTreeSkin(.crystalCavern),
            colors: [Color.skinHex("A78BFA"), Color.skinHex("67E8F9"), Color.skinHex("F6C95B")]
        ),
        .init(
            id: "profileBorder.bronzeRivets",
            category: .profileBorder,
            name: "Bronze Rivets",
            price: 220,
            rarity: "Common",
            reward: .profileBorder(.bronzeRivets),
            colors: [Color.skinHex("CBD5E1"), Color.skinHex("F97316"), Color.skinHex("2DD4BF")]
        ),
        .init(
            id: "profileBorder.tapeWrap",
            category: .profileBorder,
            name: "Tape Wrap",
            price: 350,
            rarity: "Common",
            reward: .profileBorder(.tapeWrap),
            colors: [Color.skinHex("CBD5E1"), Color.skinHex("2DD4BF")]
        ),
        .init(
            id: "profileBorder.paperSeal",
            category: .profileBorder,
            name: "Paper Seal",
            price: 420,
            rarity: "Common",
            reward: .profileBorder(.paperSeal),
            colors: [Color.skinHex("EDE6D6"), Color.skinHex("D84B3D"), Color.skinHex("2DD4BF")]
        ),
        .init(
            id: "profileBorder.prismCircuit",
            category: .profileBorder,
            name: "Prism Circuit",
            price: 1_900,
            rarity: "Epic",
            reward: .profileBorder(.prismCircuit),
            colors: [Color.skinHex("FF4FD8"), Color.skinHex("F6C95B")]
        ),
        .init(
            id: "profileBorder.crystalHalo",
            category: .profileBorder,
            name: "Crystal Halo",
            price: 2_350,
            rarity: "Legendary",
            reward: .profileBorder(.crystalHalo),
            colors: [Color.skinHex("A78BFA"), Color.skinHex("67E8F9"), Color.skinHex("F6C95B")]
        ),
        .init(
            id: "profileBorder.solarCrest",
            category: .profileBorder,
            name: "Solar Crest",
            price: 2_750,
            rarity: "Legendary",
            reward: .profileBorder(.solarCrest),
            colors: [Color.skinHex("F6C95B"), Color.skinHex("5EEAD4"), Color.skinHex("FF4FD8")]
        ),
        .init(
            id: "profileBackground.archiveWall",
            category: .profileWallpaper,
            name: "The Archive",
            price: 480,
            rarity: "Common",
            reward: .profileBackground(.archiveWall),
            colors: [Color.skinHex("38BDF8"), Color.skinHex("94A3B8")]
        ),
        .init(
            id: "profileBackground.lockerWall",
            category: .profileWallpaper,
            name: "The Locker Room",
            price: 550,
            rarity: "Common",
            reward: .profileBackground(.lockerWall),
            colors: [Color.skinHex("38BDF8"), Color.skinHex("F97316")]
        ),
        .init(
            id: "profileBackground.dojoScroll",
            category: .profileWallpaper,
            name: "The Dojo Scroll",
            price: 880,
            rarity: "Rare",
            reward: .profileBackground(.dojoScroll),
            colors: [Color.skinHex("EDE6D6"), Color.skinHex("2DD4BF"), Color.skinHex("D84B3D")]
        ),
        .init(
            id: "profileBackground.overgrownGate",
            category: .profileWallpaper,
            name: "The Overgrown Gate",
            price: 1_250,
            rarity: "Epic",
            reward: .profileBackground(.overgrownGate),
            colors: [Color.skinHex("55D487"), Color.skinHex("F6C95B"), Color.skinHex("5EEAD4")]
        ),
        .init(
            id: "profileBackground.neonAtrium",
            category: .profileWallpaper,
            name: "The Neon Atrium",
            price: 620,
            rarity: "Common",
            reward: .profileBackground(.neonAtrium),
            colors: [Color.skinHex("5EEAD4"), Color.skinHex("FF4FD8"), Color.skinHex("F6C95B")]
        ),
        .init(
            id: "profileBackground.solarForge",
            category: .profileWallpaper,
            name: "The Solar Forge",
            price: 640,
            rarity: "Common",
            reward: .profileBackground(.solarForge),
            colors: [Color.skinHex("F6C95B"), Color.skinHex("5EEAD4")]
        ),
        .init(
            id: "profileBackground.holoForge",
            category: .profileWallpaper,
            name: "The Prism Sanctum",
            price: 3_600,
            rarity: "Legendary",
            reward: .profileBackground(.holoForge),
            colors: [Color.skinHex("F6C95B"), Color.skinHex("67E8F9"), Color.skinHex("A78BFA"), Color.skinHex("FF4FD8")]
        ),
        .init(
            id: "profileTitle.chalkGhost",
            category: .title,
            name: "Chalked Up",
            price: 260,
            rarity: "Common",
            reward: .profileTitle(.shop("chalkGhost")),
            colors: [Color.skinHex("CBD5E1"), Color.skinHex("2DD4BF")]
        ),
        .init(
            id: "profileTitle.nightShift",
            category: .title,
            name: "Sleep Debt CEO",
            price: 300,
            rarity: "Common",
            reward: .profileTitle(.shop("nightShift")),
            colors: [Color.skinHex("64748B"), Color.skinHex("A78BFA")]
        ),
        .init(
            id: "profileTitle.ironStatic",
            category: .title,
            name: "PR Pending",
            price: 750,
            rarity: "Rare",
            reward: .profileTitle(.shop("ironStatic")),
            colors: [Color.skinHex("38BDF8"), Color.skinHex("F472B6")]
        ),
        .init(
            id: "profileTitle.goldSignal",
            category: .title,
            name: "Aura Farmer",
            price: 1_450,
            rarity: "Epic",
            reward: .profileTitle(.shop("goldSignal")),
            colors: [Color.skinHex("F6C95B"), Color.skinHex("5EEAD4")]
        ),
        .init(
            id: "profileTitle.solarBreaker",
            category: .title,
            name: "Main Character Arc",
            price: 2_050,
            rarity: "Legendary",
            reward: .profileTitle(.shop("solarBreaker")),
            colors: [Color.skinHex("F6C95B"), Color.skinHex("FF4FD8"), Color.skinHex("5EEAD4")]
        )
    ]

    static func item(id: String) -> ShopItem? {
        items.first { $0.id == id }
    }

    static func item(for reward: ShopItemReward) -> ShopItem? {
        items.first { $0.reward == reward }
    }

    static func items(for category: ShopCategory) -> [ShopItem] {
        let categoryItems = items.filter { $0.category == category }
        guard category == .backdrop || category == .profileWallpaper else { return categoryItems }
        return categoryItems.sorted(by: backdropDisplaySort)
    }

    private static func backdropDisplaySort(_ lhs: ShopItem, _ rhs: ShopItem) -> Bool {
        if lhs.raritySortRank != rhs.raritySortRank {
            return lhs.raritySortRank < rhs.raritySortRank
        }
        if lhs.price != rhs.price {
            return lhs.price < rhs.price
        }
        let leftName = lhs.name.lowercased()
        let rightName = rhs.name.lowercased()
        if leftName != rightName {
            return leftName < rightName
        }
        return lhs.id < rhs.id
    }
}
