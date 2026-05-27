import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Firebase removed for V1 — everything persists locally. See
        // Services/{Auth,Database,Storage,Analytics,Logging} for the
        // FileManager / UserDefaults / os.Logger backed replacements.
        AnalyticsService.shared.configure()
        if UserDefaults.standard.bool(forKey: AppConstants.Analytics.usageOptOutKey) {
            AnalyticsService.shared.optOut()
        } else {
            AnalyticsService.shared.optIn()
        }
        AuthService.shared.autoProvisionIfNeeded()
        SubscriptionService.shared.configure()
        NotificationService.startMilestoneNotifier()
        Task { await NotificationService.applyStoredPreferences() }
        return true
    }
}
