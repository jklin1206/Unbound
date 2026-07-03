// UNBOUND/App/UnboundApp.swift
//
// Universal Links — /squad/<code>
// AASA (apple-app-site-association) must be deployed at:
//   https://unboundbtr.com/.well-known/apple-app-site-association
//
// Required AASA content:
// {
//   "applinks": {
//     "details": [
//       {
//         "appIDs": ["TEAMID.com.unboundapp.ios"],
//         "components": [{ "/": "/squad/*" }]
//       }
//     ]
//   }
// }
//
// AASA deployment is a marketing-site concern (not in this PR).
// The app side: entitlement + onContinueUserActivity handler below.
import SwiftUI
import UIKit

#if DEBUG && targetEnvironment(simulator)
// Hot-reload for SwiftUI iteration. Save any .swift file and the
// simulator re-renders affected views without a rebuild. Requires
// InjectionIII.app installed and pointed at this project.
// See: https://github.com/johnno1962/HotReloading
//
// Guard MUST stay `DEBUG && targetEnvironment(simulator)`. On a real device
// dyld can't load HotReloading.framework (it's not embedded for device) and
// the app SIGABRTs on launch — see project.pbxproj where the SPM product
// is also marked Weak-linked for the same reason.
import HotReloading
#endif

@main
struct UnboundApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var services = ServiceContainer()
    @Environment(\.scenePhase) private var scenePhase
    @State private var lastAppOpenedAt: Date?

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(services)
                .preferredColorScheme(.dark)
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    guard
                        let url = activity.webpageURL,
                        let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                        components.host == "unboundbtr.com"
                    else { return }

                    let pathComponents = components.path
                        .split(separator: "/")
                        .map(String.init)

                    // Match /squad/<invite-code>
                    if pathComponents.count == 2,
                       pathComponents[0] == "squad" {
                        let code = pathComponents[1]
                        NotificationCenter.default.post(
                            name: .squadInviteCodeReceived,
                            object: code
                        )
                    }
                }
                .task { SyncTriggers.shared.start() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        trackAppOpenedIfNeeded()
                        Task { await SyncEngine.shared.flush() }
                        Task { await NotificationService.applyStoredPreferences() }
                        // Friend challenges have no server cron (unlike squad
                        // missions, which the evaluate_squad_mission cron closes).
                        // Their winner-selection lives in Swift, so we settle any
                        // past-deadline challenges on foreground.
                        Task { await services.friendChallenge.evaluateExpired() }
                    }
                }
        }
    }

    private func trackAppOpenedIfNeeded(now: Date = Date()) {
        let shouldTrack = lastAppOpenedAt
            .map { now.timeIntervalSince($0) >= 5 * 60 }
            ?? true
        guard shouldTrack else { return }
        lastAppOpenedAt = now
        services.analytics.track(.appOpened)
    }
}
