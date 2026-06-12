// UNBOUND/App/RootView.swift
//
// Root router: gates the app into loading / onboarding / auth / home,
// and (in DEBUG) into the launch-arg demo harnesses. Extracted from
// UnboundApp.swift; logic and ordering are byte-identical to the original.
import Foundation
import SwiftUI

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

    @ViewBuilder
    var body: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-rewardDemo")
            || ProcessInfo.processInfo.environment["REWARD_DEMO"] == "1" {
            RewardDemoView()
        } else if ProcessInfo.processInfo.arguments.contains("-rankTrialDemos")
            || ProcessInfo.processInfo.environment["RANK_TRIAL_DEMOS"] == "1"
            || ProcessInfo.processInfo.environment["RANK_TRIAL_DEMO"] != nil {
            RankTrialDemoRecorderView()
        } else if ProcessInfo.processInfo.arguments.contains("-rankTrialReadyReview")
            || ProcessInfo.processInfo.environment["RANK_TRIAL_READY_REVIEW"] == "1" {
            RankTrialReadyReviewView()
        } else if ProcessInfo.processInfo.arguments.contains("-towerTrialDemo")
            || ProcessInfo.processInfo.environment["TOWER_TRIAL_DEMO"] == "1" {
            TowerTrialDemoView()
        } else if ProcessInfo.processInfo.arguments.contains("-activeWorkoutDemo") {
            ActiveWorkoutDemoHarness()
        } else if ProcessInfo.processInfo.arguments.contains("-sessionEditorDemo") {
            SessionEditorDemoHarness()
        } else if ProcessInfo.processInfo.arguments.contains("-myWorkoutsDemo") {
            MyWorkoutsDemoHarness()
        } else {
            mainContent
        }
        #else
        mainContent
        #endif
    }

    private var mainContent: some View {
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
                        // New users finish onboarding BEFORE signing in, so their
                        // answers were stashed under the "anonymous" placeholder.
                        // Replay them onto the authenticated profile now (the stub
                        // was just created by createUserIfNeeded), then clear — so
                        // the real user isn't blank and program-gen sees the real
                        // goals/equipment/body inputs.
                        if let pending = PendingOnboardingProfile.take() {
                            do {
                                try await services.user.updateProfile(userId: userId, fields: pending)
                                PendingOnboardingProfile.clear()
                            } catch {
                                // Keep the stash; a later launch retries the replay.
                            }
                        }
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
                        services.trials.checkVowWindow(userId: userId, now: Date())
                        // Restore-on-sign-in: if this device has no local program
                        // cache for the user, pull their data down once and
                        // rehydrate the active program. Gated on "no local cache"
                        // so it does NOT run on every launch.
                        if ProgramStore.shared.loadLocal(userId: userId) == nil {
                            do {
                                try await SyncEngine.shared.restore(userId: userId)
                            } catch {
                                // Restore is retried implicitly (cache stays empty so
                                // this branch runs again next launch) — but a silent
                                // failure here looks like a wiped account, so log it.
                                LoggingService.shared.log(
                                    "Restore-on-sign-in failed: \(error)",
                                    level: .error
                                )
                            }
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
