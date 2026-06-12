import XCTest
@testable import UNBOUND

@MainActor
final class ShopInventoryStoreTests: XCTestCase {
    func testStarterGrantOnlyAppliesOncePerUser() {
        let defaults = isolatedDefaults()
        let wallet = CurrencyWalletStore(defaults: defaults)

        wallet.bind(userId: "shop-test-user")
        XCTAssertEqual(wallet.balance, 1_500)

        XCTAssertTrue(wallet.spend(200))
        wallet.bind(userId: "shop-test-user")
        XCTAssertEqual(wallet.balance, 1_300)
    }

    func testDevWalletHasUnlimitedCreditsAndDoesNotSpendDown() {
        let defaults = isolatedDefaults()
        let wallet = CurrencyWalletStore(defaults: defaults)

        wallet.bind(userId: "dev-player")
        let startingBalance = wallet.balance

        XCTAssertGreaterThanOrEqual(startingBalance, 9_000_000)
        XCTAssertTrue(wallet.canAfford(startingBalance + 1))
        XCTAssertTrue(wallet.spend(startingBalance + 1))
        XCTAssertEqual(wallet.balance, startingBalance)
        XCTAssertEqual(
            CurrencyWalletStore.storedBalance(userId: "dev-player", defaults: defaults),
            startingBalance
        )
    }

    func testPurchaseSpendsArcsAndPersistsProfileTitleEntitlement() {
        let defaults = isolatedDefaults()
        let wallet = CurrencyWalletStore(defaults: defaults)
        let inventory = ShopInventoryStore(defaults: defaults)
        let item = ShopCatalog.item(id: "profileTitle.nightShift")!

        wallet.bind(userId: "shop-test-user")
        inventory.bind(userId: "shop-test-user")

        XCTAssertEqual(inventory.purchase(item, wallet: wallet), .purchased)
        XCTAssertEqual(wallet.balance, 1_200)
        XCTAssertTrue(inventory.isPurchased(item))
        XCTAssertTrue(
            ShopInventoryStore
                .purchasedProfileTitles(userId: "shop-test-user", defaults: defaults)
                .contains(.shop("nightShift"))
        )
    }

    func testProfileBorderEquipRequiresPurchase() {
        let defaults = isolatedDefaults()
        let userId = "shop-test-user"
        let item = ShopCatalog.item(id: "profileBorder.tapeWrap")!

        ShopInventoryStore.setEquippedProfileBorder(.tapeWrap, userId: userId, defaults: defaults)
        XCTAssertNil(ShopInventoryStore.equippedProfileBorder(userId: userId, defaults: defaults))

        ShopInventoryStore.markPurchased(item, userId: userId, defaults: defaults)
        ShopInventoryStore.setEquippedProfileBorder(.tapeWrap, userId: userId, defaults: defaults)
        XCTAssertEqual(ShopInventoryStore.equippedProfileBorder(userId: userId, defaults: defaults), .tapeWrap)
    }

    func testHomeBackgroundEquipRequiresPurchase() {
        let defaults = isolatedDefaults()
        let userId = "shop-test-user"
        let item = ShopCatalog.item(id: "homeBackground.chamber")!

        ShopInventoryStore.setEquippedHomeBackground(.chamber, userId: userId, defaults: defaults)
        XCTAssertNil(ShopInventoryStore.equippedHomeBackground(userId: userId, defaults: defaults))

        ShopInventoryStore.markPurchased(item, userId: userId, defaults: defaults)
        ShopInventoryStore.setEquippedHomeBackground(.chamber, userId: userId, defaults: defaults)
        XCTAssertEqual(ShopInventoryStore.equippedHomeBackground(userId: userId, defaults: defaults), .chamber)
        XCTAssertEqual(ShopInventoryStore.equippedBackdrop(for: .home, userId: userId, defaults: defaults)?.id, item.id)
    }

    func testBackdropAndWallpaperCategoriesSplitHomeAndProfileItems() {
        let backdrops = ShopCatalog.items(for: .backdrop)
        let wallpapers = ShopCatalog.items(for: .profileWallpaper)

        XCTAssertTrue(backdrops.contains { $0.id == "homeBackground.chamber" })
        XCTAssertFalse(backdrops.contains { $0.id == "profileBackground.archiveWall" })
        XCTAssertTrue(wallpapers.contains { $0.id == "profileBackground.archiveWall" })
        XCTAssertFalse(wallpapers.contains { $0.id == "homeBackground.chamber" })
    }

    func testBackdropsSortByRarityThenPrice() {
        let backdrops = ShopCatalog.items(for: .backdrop)

        XCTAssertEqual(backdrops.map(\.id), sortedVisualItems(backdrops).map(\.id))
        XCTAssertEqual(backdrops.first?.id, "homeBackground.archiveWall")
        XCTAssertEqual(backdrops.last?.id, "homeBackground.holoForge")
    }

    func testWallpapersSortByRarityThenPrice() {
        let wallpapers = ShopCatalog.items(for: .profileWallpaper)

        XCTAssertEqual(wallpapers.map(\.id), sortedVisualItems(wallpapers).map(\.id))
        XCTAssertEqual(wallpapers.first?.id, "profileBackground.archiveWall")
        XCTAssertEqual(wallpapers.last?.id, "profileBackground.holoForge")
    }

    func testBackdropEquipCanReturnToDefaultSurfaces() {
        let defaults = isolatedDefaults()
        let userId = "shop-test-user"
        let homeItem = ShopCatalog.item(id: "homeBackground.chamber")!
        let profileItem = ShopCatalog.item(id: "profileBackground.archiveWall")!

        ShopInventoryStore.markPurchased(homeItem, userId: userId, defaults: defaults)
        ShopInventoryStore.markPurchased(profileItem, userId: userId, defaults: defaults)
        ShopInventoryStore.setEquippedBackdrop(profileItem, for: .home, userId: userId, defaults: defaults)
        ShopInventoryStore.setEquippedBackdrop(homeItem, for: .profile, userId: userId, defaults: defaults)

        XCTAssertEqual(ShopInventoryStore.equippedBackdrop(for: .home, userId: userId, defaults: defaults)?.id, profileItem.id)
        XCTAssertEqual(ShopInventoryStore.equippedBackdrop(for: .profile, userId: userId, defaults: defaults)?.id, homeItem.id)

        ShopInventoryStore.clearEquippedBackdrop(for: .home, userId: userId, defaults: defaults)
        ShopInventoryStore.clearEquippedBackdrop(for: .profile, userId: userId, defaults: defaults)

        XCTAssertNil(ShopInventoryStore.equippedBackdrop(for: .home, userId: userId, defaults: defaults))
        XCTAssertNil(ShopInventoryStore.equippedBackdrop(for: .profile, userId: userId, defaults: defaults))
    }

    func testInsufficientFundsDoesNotPersistPurchase() {
        let defaults = isolatedDefaults()
        let wallet = CurrencyWalletStore(defaults: defaults)
        let inventory = ShopInventoryStore(defaults: defaults)
        let item = ShopCatalog.item(id: "skillTreeSkin.glassCircuit")!

        wallet.bind(userId: "shop-test-user")
        inventory.bind(userId: "shop-test-user")

        XCTAssertEqual(inventory.purchase(item, wallet: wallet), .insufficientFunds(shortfall: 350))
        XCTAssertEqual(wallet.balance, 1_500)
        XCTAssertFalse(inventory.isPurchased(item))
    }

    // MARK: - CurrencyWalletStore.hasGranted tests

    func testHasGrantedReturnsTrueAfterGrant() {
        let defaults = isolatedDefaults()
        let wallet = CurrencyWalletStore(defaults: defaults)
        wallet.bind(userId: "wallet-test-user")
        let sourceId = "squad_mission:11111111-1111-1111-1111-111111111111"

        XCTAssertFalse(wallet.hasGranted(sourceId: sourceId))
        wallet.grant(300, sourceId: sourceId)
        XCTAssertTrue(wallet.hasGranted(sourceId: sourceId))
    }

    func testHasGrantedReturnsFalseForUnknownSourceId() {
        let defaults = isolatedDefaults()
        let wallet = CurrencyWalletStore(defaults: defaults)
        wallet.bind(userId: "wallet-test-user")

        XCTAssertFalse(wallet.hasGranted(sourceId: "squad_mission:99999999-9999-9999-9999-999999999999"))
    }

    func testGrantDedupSecondCallReturnsFalseAndBalanceUnchanged() {
        let defaults = isolatedDefaults()
        let wallet = CurrencyWalletStore(defaults: defaults)
        wallet.bind(userId: "wallet-test-user")
        let sourceId = "squad_mission:22222222-2222-2222-2222-222222222222"

        let firstGrant = wallet.grant(300, sourceId: sourceId)
        let balanceAfterFirst = wallet.balance
        let secondGrant = wallet.grant(300, sourceId: sourceId)

        XCTAssertTrue(firstGrant)
        XCTAssertFalse(secondGrant)
        XCTAssertEqual(wallet.balance, balanceAfterFirst, "Balance must not change on duplicate grant")
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "ShopInventoryStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func sortedVisualItems(_ items: [ShopItem]) -> [ShopItem] {
        items.sorted {
            if $0.raritySortRank != $1.raritySortRank {
                return $0.raritySortRank < $1.raritySortRank
            }
            if $0.price != $1.price {
                return $0.price < $1.price
            }
            let leftName = $0.name.lowercased()
            let rightName = $1.name.lowercased()
            if leftName != rightName {
                return leftName < rightName
            }
            return $0.id < $1.id
        }
    }
}
