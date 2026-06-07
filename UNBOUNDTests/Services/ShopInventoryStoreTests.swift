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

    func testBackdropsCategoryCombinesHomeAndProfileBackdropItems() {
        let backdrops = ShopCatalog.items(for: .backdrop)

        XCTAssertTrue(backdrops.contains { $0.id == "homeBackground.chamber" })
        XCTAssertTrue(backdrops.contains { $0.id == "profileBackground.archiveWall" })
    }

    func testBackdropsSortByRarityThenPrice() {
        let backdrops = ShopCatalog.items(for: .backdrop)
        let expected = backdrops.sorted {
            if $0.raritySortRank != $1.raritySortRank {
                return $0.raritySortRank < $1.raritySortRank
            }
            if $0.price != $1.price {
                return $0.price < $1.price
            }
            return $0.name < $1.name
        }

        XCTAssertEqual(backdrops.map(\.id), expected.map(\.id))
        XCTAssertEqual(backdrops.first?.id, "profileBackground.archiveWall")
        XCTAssertEqual(backdrops.last?.id, "profileBackground.holoForge")
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

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "ShopInventoryStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
