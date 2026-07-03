import XCTest

/// Holds the real app open under a live StoreKit Testing session so an external
/// driver (idb / simctl screenshots) can walk genuine onboarding and complete
/// the local in-app purchase, landing on Home.
///
/// A local `.storekit` test session is only activated when the app is launched
/// by Xcode / `xcodebuild test` — a plain `simctl launch` does NOT start one.
/// This UI test exists purely to provide that launch + keep the process alive;
/// it is not a behavioral assertion and is excluded from the normal test scheme.
///
/// Run it (Release config, so the DEBUG dev-account bootstrapper is compiled
/// out) via the dedicated `UNBOUND-StoreKitTesting` scheme:
///
///   xcodebuild test -scheme UNBOUND-StoreKitTesting \
///     -only-testing:UNBOUNDUITests/StoreKitHoldOpenUITests/testHoldAppOpenForManualDriving
final class StoreKitHoldOpenUITests: XCTestCase {
    func testHoldAppOpenForManualDriving() {
        let app = XCUIApplication()
        app.launch()
        // Keep the host process (and its StoreKit Testing session) alive for a
        // generous window while the purchase flow is driven externally.
        Thread.sleep(forTimeInterval: 1800)
    }
}
