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
        case .archiveWall: return "Archive Wall"
        case .lockerWall: return "Locker Wall"
        case .dojoScroll: return "Dojo Scroll"
        case .overgrownGate: return "Overgrown Gate"
        case .neonAtrium: return "Neon Atrium"
        case .solarForge: return "Solar Forge"
        case .holoForge: return "Holo Forge"
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
        case .archiveWall: return "Archive Wall"
        case .lockerWall: return "Locker Wall"
        case .dojoScroll: return "Dojo Scroll"
        case .overgrownGate: return "Overgrown Gate"
        case .neonAtrium: return "Neon Atrium"
        case .solarForge: return "Solar Forge"
        case .holoForge: return "Holo Forge"
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
    let subtitle: String
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
            subtitle: "The original UNBOUND home screen, now kept as a shop unlock.",
            price: 650,
            rarity: "Rare",
            reward: .homeBackground(.chamber),
            colors: [Color.skinHex("8B5CF6"), Color.skinHex("22D3EE")]
        ),
        .init(
            id: "homeBackground.streetNeon",
            category: .backdrop,
            name: "Street Neon",
            subtitle: "A rainy neon home screen with saturated alley color.",
            price: 900,
            rarity: "Rare",
            reward: .homeBackground(.streetNeon),
            colors: [Color.skinHex("22D3EE"), Color.skinHex("FF4FD8")]
        ),
        .init(
            id: "homeBackground.inkDojo",
            category: .backdrop,
            name: "Ink Dojo",
            subtitle: "A moonlit rooftop dojo with ink banners, teal lamps, and quiet city glow.",
            price: 1_100,
            rarity: "Rare",
            reward: .homeBackground(.inkDojo),
            colors: [Color.skinHex("EDE6D6"), Color.skinHex("2DD4BF"), Color.skinHex("D84B3D")]
        ),
        .init(
            id: "homeBackground.emeraldShrine",
            category: .backdrop,
            name: "Emerald Shrine",
            subtitle: "A sunlit jungle training court with emerald lanterns and gold floor sigils.",
            price: 1_450,
            rarity: "Epic",
            reward: .homeBackground(.emeraldShrine),
            colors: [Color.skinHex("55D487"), Color.skinHex("F6C95B"), Color.skinHex("5EEAD4")]
        ),
        .init(
            id: "homeBackground.solarCourt",
            category: .backdrop,
            name: "Solar Court",
            subtitle: "A rooftop training court with warm solar trim and teal glass rails.",
            price: 1_650,
            rarity: "Epic",
            reward: .homeBackground(.solarCourt),
            colors: [Color.skinHex("F6C95B"), Color.skinHex("5EEAD4"), Color.skinHex("FF4FD8")]
        ),
        .init(
            id: "homeBackground.glassCircuit",
            category: .backdrop,
            name: "Glass Circuit",
            subtitle: "A premium glass-and-gold home screen background.",
            price: 2_350,
            rarity: "Epic",
            reward: .homeBackground(.glassCircuit),
            colors: [Color.skinHex("5EEAD4"), Color.skinHex("F6C95B")]
        ),
        .init(
            id: "homeBackground.archiveWall",
            category: .backdrop,
            name: "Archive Wall",
            subtitle: "The former profile archive environment, now used as an immersive Home poster.",
            price: 480,
            rarity: "Common",
            reward: .homeBackground(.archiveWall),
            colors: [Color.skinHex("38BDF8"), Color.skinHex("94A3B8")]
        ),
        .init(
            id: "homeBackground.lockerWall",
            category: .backdrop,
            name: "Locker Wall",
            subtitle: "The former profile locker-room environment, now used as a Home poster.",
            price: 550,
            rarity: "Common",
            reward: .homeBackground(.lockerWall),
            colors: [Color.skinHex("38BDF8"), Color.skinHex("F97316")]
        ),
        .init(
            id: "homeBackground.dojoScroll",
            category: .backdrop,
            name: "Dojo Scroll",
            subtitle: "The former profile scroll environment, now used as an immersive Home poster.",
            price: 880,
            rarity: "Rare",
            reward: .homeBackground(.dojoScroll),
            colors: [Color.skinHex("EDE6D6"), Color.skinHex("2DD4BF"), Color.skinHex("D84B3D")]
        ),
        .init(
            id: "homeBackground.overgrownGate",
            category: .backdrop,
            name: "Overgrown Gate",
            subtitle: "The former profile stone-gate environment, now used as a Home poster.",
            price: 1_250,
            rarity: "Epic",
            reward: .homeBackground(.overgrownGate),
            colors: [Color.skinHex("55D487"), Color.skinHex("F6C95B"), Color.skinHex("5EEAD4")]
        ),
        .init(
            id: "homeBackground.neonAtrium",
            category: .backdrop,
            name: "Neon Atrium",
            subtitle: "The former profile atrium environment, now used as a Home poster.",
            price: 620,
            rarity: "Common",
            reward: .homeBackground(.neonAtrium),
            colors: [Color.skinHex("5EEAD4"), Color.skinHex("FF4FD8"), Color.skinHex("F6C95B")]
        ),
        .init(
            id: "homeBackground.solarForge",
            category: .backdrop,
            name: "Solar Forge",
            subtitle: "The former profile solar-forge environment, now used as a Home poster.",
            price: 640,
            rarity: "Common",
            reward: .homeBackground(.solarForge),
            colors: [Color.skinHex("F6C95B"), Color.skinHex("5EEAD4")]
        ),
        .init(
            id: "homeBackground.holoForge",
            category: .backdrop,
            name: "Holo Forge",
            subtitle: "The former profile holo sanctum, now used as a legendary Home poster.",
            price: 3_600,
            rarity: "Legendary",
            reward: .homeBackground(.holoForge),
            colors: [Color.skinHex("F6C95B"), Color.skinHex("67E8F9"), Color.skinHex("A78BFA"), Color.skinHex("FF4FD8")]
        ),
        .init(
            id: "skillTreeSkin.chalk",
            category: .skillTree,
            name: "Chalk Rails",
            subtitle: "A stripped-down map skin with chalky rails and quiet node glow.",
            price: 250,
            rarity: "Common",
            reward: .skillTreeSkin(.chalk),
            colors: [Color.skinHex("CBD5E1"), Color.skinHex("2DD4BF")]
        ),
        .init(
            id: "skillTreeSkin.blueprint",
            category: .skillTree,
            name: "Blueprint Rails",
            subtitle: "A crisp shop tree skin with cool drafting lines and icy nodes.",
            price: 520,
            rarity: "Common",
            reward: .skillTreeSkin(.blueprint),
            colors: [Color.skinHex("38BDF8"), Color.skinHex("E0F2FE")]
        ),
        .init(
            id: "skillTreeSkin.streetNeon",
            category: .skillTree,
            name: "Street Neon",
            subtitle: "A real tree-map skin with cyan rails and magenta proven nodes.",
            price: 850,
            rarity: "Rare",
            reward: .skillTreeSkin(.streetNeon),
            colors: [Color.skinHex("22D3EE"), Color.skinHex("FF4FD8")]
        ),
        .init(
            id: "skillTreeSkin.inkDojo",
            category: .skillTree,
            name: "Ink Dojo",
            subtitle: "An ink-wash tree skin with parchment bands and restrained teal node light.",
            price: 1_050,
            rarity: "Rare",
            reward: .skillTreeSkin(.inkDojo),
            colors: [Color.skinHex("EDE6D6"), Color.skinHex("2DD4BF"), Color.skinHex("D84B3D")]
        ),
        .init(
            id: "skillTreeSkin.solarCircuit",
            category: .skillTree,
            name: "Solar Circuit",
            subtitle: "A high-price tree skin with amber active paths and teal glass nodes.",
            price: 1_550,
            rarity: "Epic",
            reward: .skillTreeSkin(.solarCircuit),
            colors: [Color.skinHex("F97316"), Color.skinHex("F6C95B"), Color.skinHex("5EEAD4")]
        ),
        .init(
            id: "skillTreeSkin.glassCircuit",
            category: .skillTree,
            name: "Glass Circuit",
            subtitle: "A premium map skin with teal glass nodes and gold active paths.",
            price: 1_850,
            rarity: "Epic",
            reward: .skillTreeSkin(.glassCircuit),
            colors: [Color.skinHex("5EEAD4"), Color.skinHex("F6C95B")]
        ),
        .init(
            id: "skillTreeSkin.crystalCavern",
            category: .skillTree,
            name: "Crystal Cavern",
            subtitle: "A saturated crystal training hall with violet rails and cyan shard glow.",
            price: 2_050,
            rarity: "Epic",
            reward: .skillTreeSkin(.crystalCavern),
            colors: [Color.skinHex("A78BFA"), Color.skinHex("67E8F9"), Color.skinHex("F6C95B")]
        ),
        .init(
            id: "profileBorder.bronzeRivets",
            category: .profileBorder,
            name: "Bronze Rivets",
            subtitle: "A budget frame with stitched tape, rivets, and rough gym scuffs.",
            price: 220,
            rarity: "Common",
            reward: .profileBorder(.bronzeRivets),
            colors: [Color.skinHex("CBD5E1"), Color.skinHex("F97316"), Color.skinHex("2DD4BF")]
        ),
        .init(
            id: "profileBorder.tapeWrap",
            category: .profileBorder,
            name: "Tape Wrap",
            subtitle: "Cheap gym-tape trim with chalk marks and teal stitch lines.",
            price: 350,
            rarity: "Common",
            reward: .profileBorder(.tapeWrap),
            colors: [Color.skinHex("CBD5E1"), Color.skinHex("2DD4BF")]
        ),
        .init(
            id: "profileBorder.paperSeal",
            category: .profileBorder,
            name: "Paper Seal",
            subtitle: "A low-cost paper charm frame with ink strokes, red seals, and teal thread.",
            price: 420,
            rarity: "Common",
            reward: .profileBorder(.paperSeal),
            colors: [Color.skinHex("EDE6D6"), Color.skinHex("D84B3D"), Color.skinHex("2DD4BF")]
        ),
        .init(
            id: "profileBorder.prismCircuit",
            category: .profileBorder,
            name: "Prism Circuit",
            subtitle: "A premium neon-glass profile frame with gold edge charge.",
            price: 1_900,
            rarity: "Epic",
            reward: .profileBorder(.prismCircuit),
            colors: [Color.skinHex("FF4FD8"), Color.skinHex("F6C95B")]
        ),
        .init(
            id: "profileBorder.crystalHalo",
            category: .profileBorder,
            name: "Crystal Halo",
            subtitle: "A premium avatar halo with violet crystals, cyan shards, and gold mounts.",
            price: 2_350,
            rarity: "Legendary",
            reward: .profileBorder(.crystalHalo),
            colors: [Color.skinHex("A78BFA"), Color.skinHex("67E8F9"), Color.skinHex("F6C95B")]
        ),
        .init(
            id: "profileBorder.solarCrest",
            category: .profileBorder,
            name: "Solar Crest",
            subtitle: "A top-shelf avatar frame with teal glass, gold trim, and magenta charge.",
            price: 2_750,
            rarity: "Legendary",
            reward: .profileBorder(.solarCrest),
            colors: [Color.skinHex("F6C95B"), Color.skinHex("5EEAD4"), Color.skinHex("FF4FD8")]
        ),
        .init(
            id: "profileBackground.archiveWall",
            category: .profileWallpaper,
            name: "Archive Wall",
            subtitle: "A wide profile banner with archive panels, tape, and cool blue light.",
            price: 480,
            rarity: "Common",
            reward: .profileBackground(.archiveWall),
            colors: [Color.skinHex("38BDF8"), Color.skinHex("94A3B8")]
        ),
        .init(
            id: "profileBackground.lockerWall",
            category: .profileWallpaper,
            name: "Locker Wall",
            subtitle: "A wide profile banner with worn lockers, tape, and cool gym light.",
            price: 550,
            rarity: "Common",
            reward: .profileBackground(.lockerWall),
            colors: [Color.skinHex("38BDF8"), Color.skinHex("F97316")]
        ),
        .init(
            id: "profileBackground.dojoScroll",
            category: .profileWallpaper,
            name: "Dojo Scroll",
            subtitle: "A wide profile banner with ink arcs, moon wash, and teal lanterns.",
            price: 880,
            rarity: "Rare",
            reward: .profileBackground(.dojoScroll),
            colors: [Color.skinHex("EDE6D6"), Color.skinHex("2DD4BF"), Color.skinHex("D84B3D")]
        ),
        .init(
            id: "profileBackground.overgrownGate",
            category: .profileWallpaper,
            name: "Overgrown Gate",
            subtitle: "A wide profile banner with stone, vines, emerald lanterns, and gold trim.",
            price: 1_250,
            rarity: "Epic",
            reward: .profileBackground(.overgrownGate),
            colors: [Color.skinHex("55D487"), Color.skinHex("F6C95B"), Color.skinHex("5EEAD4")]
        ),
        .init(
            id: "profileBackground.neonAtrium",
            category: .profileWallpaper,
            name: "Neon Atrium",
            subtitle: "A wide profile banner with dark glass rails and restrained neon.",
            price: 620,
            rarity: "Common",
            reward: .profileBackground(.neonAtrium),
            colors: [Color.skinHex("5EEAD4"), Color.skinHex("FF4FD8"), Color.skinHex("F6C95B")]
        ),
        .init(
            id: "profileBackground.solarForge",
            category: .profileWallpaper,
            name: "Solar Forge",
            subtitle: "A wide profile banner with warm arcs, dark glass, and solar trim.",
            price: 640,
            rarity: "Common",
            reward: .profileBackground(.solarForge),
            colors: [Color.skinHex("F6C95B"), Color.skinHex("5EEAD4")]
        ),
        .init(
            id: "profileBackground.holoForge",
            category: .profileWallpaper,
            name: "Holo Forge",
            subtitle: "A wide profile banner with prism glass, gold rails, and a radiant core.",
            price: 3_600,
            rarity: "Legendary",
            reward: .profileBackground(.holoForge),
            colors: [Color.skinHex("F6C95B"), Color.skinHex("67E8F9"), Color.skinHex("A78BFA"), Color.skinHex("FF4FD8")]
        ),
        .init(
            id: "profileTitle.chalkGhost",
            category: .title,
            name: "Chalked Up",
            subtitle: "For the set that starts after three very serious hand claps.",
            price: 260,
            rarity: "Common",
            reward: .profileTitle(.shop("chalkGhost")),
            colors: [Color.skinHex("CBD5E1"), Color.skinHex("2DD4BF")]
        ),
        .init(
            id: "profileTitle.nightShift",
            category: .title,
            name: "Sleep Debt CEO",
            subtitle: "For training late and calling it discipline with a straight face.",
            price: 300,
            rarity: "Common",
            reward: .profileTitle(.shop("nightShift")),
            colors: [Color.skinHex("64748B"), Color.skinHex("A78BFA")]
        ),
        .init(
            id: "profileTitle.ironStatic",
            category: .title,
            name: "PR Pending",
            subtitle: "For the lift that is definitely happening next attempt.",
            price: 750,
            rarity: "Rare",
            reward: .profileTitle(.shop("ironStatic")),
            colors: [Color.skinHex("38BDF8"), Color.skinHex("F472B6")]
        ),
        .init(
            id: "profileTitle.goldSignal",
            category: .title,
            name: "Aura Farmer",
            subtitle: "A premium title for collecting immaculate gym-side presence.",
            price: 1_450,
            rarity: "Epic",
            reward: .profileTitle(.shop("goldSignal")),
            colors: [Color.skinHex("F6C95B"), Color.skinHex("5EEAD4")]
        ),
        .init(
            id: "profileTitle.solarBreaker",
            category: .title,
            name: "Main Character Arc",
            subtitle: "For players whose warm-up already has season-finale energy.",
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
