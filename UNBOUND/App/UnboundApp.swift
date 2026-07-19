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
import GoogleSignIn

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
                .onOpenURL { url in
                    // Google Sign-In callback (reversed-client-id scheme). Harmless
                    // for any other URL — returns false when it isn't Google's.
                    _ = GIDSignIn.sharedInstance.handle(url)
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    // Match /squad/<invite-code> (host/segment casing + optional
                    // www. tolerant; see SquadInviteLink). PERSIST first so the
                    // invite survives a cold-launch through onboarding/paywall/
                    // auth, then post so a warm, already-routed app consumes it
                    // immediately. The persisted store is the source of truth;
                    // HomeTabView is the single consumption seam.
                    guard
                        let url = activity.webpageURL,
                        let code = SquadInviteLink.inviteCode(from: url)
                    else { return }

                    PendingSquadInvite.shared.save(code: code)
                    NotificationCenter.default.post(
                        name: .squadInviteCodeReceived,
                        object: code
                    )
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
