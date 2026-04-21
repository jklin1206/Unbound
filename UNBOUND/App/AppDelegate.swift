import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Firebase removed for V1 — everything persists locally. See
        // Services/{Auth,Database,Storage,Analytics,Logging} for the
        // FileManager / UserDefaults / os.Logger backed replacements.
        AuthService.shared.autoProvisionIfNeeded()
        SubscriptionService.shared.configure()
        PaywallService.shared.configure()
        return true
    }
}
