// UNBOUND/App/AniBodyApp.swift
//
// Universal Links — /squad/<code>
// AASA (apple-app-site-association) must be deployed at:
//   https://unboundapp.com/.well-known/apple-app-site-association
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
                        components.host == "unboundapp.com"
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
                        if let uid = services.auth.currentUserId {
                            Task {
                                await RolloverCoordinator.shared
                                    .evaluateOnForeground(userId: uid, services: services)
                            }
                        }
                        // Friend challenges have no server cron (unlike squad
                        // missions, which the evaluate_squad_mission cron closes).
                        // Their winner-selection lives in Swift, so we settle any
                        // past-deadline challenges on foreground — matching the
                        // existing RolloverCoordinator.evaluateOnForeground pattern.
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

struct RootView: View {
    @EnvironmentObject var services: ServiceContainer
    @State private var isAuthenticated = false
    @State private var isCheckingAuth = true

    // Reacts to UserDefaults changes — flipping this key from Settings
    // immediately re-routes the app back into onboarding.
    @AppStorage("onboardingCompleted") private var hasCompletedOnboarding: Bool = false

    init() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-OnboardingStep") || args.contains("--onboarding-step") {
            UserDefaults.standard.set(false, forKey: "onboardingCompleted")
        }
        #endif
    }

    var body: some View {
        Group {
            if isCheckingAuth {
                AppLaunchLoadingView()
            } else if !hasCompletedOnboarding {
                OnboardingContainerView(onComplete: {
                    hasCompletedOnboarding = true
                })
            } else if !isAuthenticated {
                AuthContainerView()
            } else {
                HomeTabView()
                    .subscriptionGate()
            }
        }
        .task {
            #if DEBUG
            await DevBuildBootstrapper.ensureReady()
            #endif

            for await userId in services.auth.authStatePublisher.values {
                isAuthenticated = userId != nil
                isCheckingAuth = false
                if let userId {
                    services.analytics.identify(
                        userId: userId,
                        traits: ["authState": "signedIn"]
                    )
                    #if DEBUG
                    DevFlags.shared.unlockAllFeatures = true
                    #endif
                    Task {
                        #if DEBUG
                        if userId != DevBuildBootstrapper.userId {
                            try? await services.subscription.login(userId: userId)
                        }
                        #else
                        try? await services.subscription.login(userId: userId)
                        #endif

                        // Backfill the 6-axis hex from existing logs on first launch
                        // (no-op if the profile already exists in the store).
                        await services.attribute.backfillFromExistingLogs(userId: userId)
                        // Trials: roll week on Monday or first launch. Marks prior
                        // uncompleted trial as .missed and generates 3 fresh cards.
                        await services.trials.ensureCurrentWeek(userId: userId)
                        // Restore-on-sign-in: if this device has no local program
                        // cache for the user, pull their data down once and
                        // rehydrate the active program. Gated on "no local cache"
                        // so it does NOT run on every launch.
                        if ProgramStore.shared.loadLocal(userId: userId) == nil {
                            try? await SyncEngine.shared.restore(userId: userId)
                            if let profile: UserProfile = try? await DatabaseService.shared
                                .read(collection: "users", documentId: userId),
                               let pid = profile.currentProgramId,
                               let prog: TrainingProgram = try? await DatabaseService.shared
                                .read(collection: "programs", documentId: pid) {
                                ProgramStore.shared.adopt(prog, userId: userId)
                            }
                        }
                        // One-time skill-tier migration: replay full log history
                        // to seed UserSkillTierState. Idempotent — guarded by
                        // a UserDefaults flag so it only runs once per user.
                        let profile = try? await services.user.fetchProfile(userId: userId)
                        let bodyweightKg = profile?.weightKg ?? 70.0
                        let logs = (try? await services.workoutLog.fetchLogs(userId: userId, programId: nil)) ?? []
                        let history = logs.flatMap { $0.exerciseEntries }
                        SkillTierMigration.migrateIfNeeded(
                            userId: userId,
                            history: history,
                            bodyweightKg: bodyweightKg
                        )
                    }
                } else {
                    services.analytics.reset()
                }
            }
        }
    }
}

private struct AppLaunchLoadingView: View {
    @State private var glow = false

    var body: some View {
        ZStack {
            launchBackground

            VStack(spacing: 20) {
                Spacer(minLength: 0)
                    .frame(maxHeight: .infinity)

                logoMark

                Text("UNBOUND")
                    .font(Font.unbound.displayXL)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .tracking(4)
                    .shadow(color: Color.unbound.accent.opacity(glow ? 0.65 : 0.25), radius: glow ? 28 : 14)

                Spacer(minLength: 0)
                    .frame(maxHeight: 220)
            }
            .padding(.horizontal, 34)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.45).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }

    private var launchBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.025, green: 0.024, blue: 0.034),
                    Color(red: 0.055, green: 0.043, blue: 0.083),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color.unbound.accent.opacity(glow ? 0.28 : 0.16),
                    Color.unbound.accent.opacity(0.05),
                    Color.clear
                ],
                center: .center,
                startRadius: 24,
                endRadius: 360
            )

            RadialGradient(
                colors: [
                    Color.unbound.ember.opacity(glow ? 0.16 : 0.08),
                    Color.clear
                ],
                center: UnitPoint(x: 0.22, y: 0.72),
                startRadius: 10,
                endRadius: 280
            )

            launchSigil
                .opacity(glow ? 0.72 : 0.46)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.62),
                    Color.clear,
                    Color.black.opacity(0.72)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    private var launchSigil: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .stroke(Color.unbound.accent.opacity(0.22), lineWidth: 1)
                .frame(width: 250, height: 250)
                .rotationEffect(.degrees(45))
                .blur(radius: 0.2)

            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                .frame(width: 176, height: 176)
                .rotationEffect(.degrees(45))

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.unbound.accent.opacity(0.45),
                            Color.unbound.ember.opacity(0.2),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 2, height: 430)
                .rotationEffect(.degrees(-34))
                .blur(radius: 0.4)
        }
        .offset(y: -10)
        .shadow(color: Color.unbound.accent.opacity(glow ? 0.24 : 0.12), radius: 40)
    }

    private var logoMark: some View {
        Group {
            if let image = Self.logoImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "link")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.unbound.textPrimary)
            }
        }
        .frame(width: 146, height: 146)
        .shadow(color: Color.unbound.accent.opacity(glow ? 0.55 : 0.28), radius: glow ? 30 : 16)
        .shadow(color: Color.unbound.ember.opacity(glow ? 0.22 : 0.08), radius: glow ? 46 : 22)
    }

    private static let logoImage: UIImage? = {
        guard let url = Bundle.main.url(forResource: "logo", withExtension: "png") else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }()
}
