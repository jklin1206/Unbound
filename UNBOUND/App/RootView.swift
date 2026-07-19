// UNBOUND/App/RootView.swift
import SwiftUI
import UIKit

struct RootView: View {
    @EnvironmentObject var services: ServiceContainer
    // Routing gates on a real CLOUD session, not merely "has a user id": every
    // launch auto-provisions an anonymous local UUID (so data has a key during
    // onboarding), which would otherwise read as authenticated and skip the
    // forced "protect your progress" screen.
    @State private var isCloudLinked = false
    @State private var isCheckingAuth = true

    // Reacts to UserDefaults changes — flipping this key from Settings
    // immediately re-routes the app back into onboarding.
    @AppStorage("onboardingCompleted") private var hasCompletedOnboarding: Bool = false

    // Observes the offline auth-deferral timestamp so that tapping "continue for
    // now" on the forced-auth screen re-routes past the wall immediately (same
    // mechanism the onboardingCompleted key uses). Read in `route` so the
    // dependency is tracked; the TTL interpretation lives in AuthDeferralStore.
    @AppStorage(AuthDeferralStore.deferredAtKey) private var authDeferredAt: Double = 0

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
            || ProcessInfo.processInfo.arguments.contains("-rewardDemoManual")
            || ProcessInfo.processInfo.environment["REWARD_DEMO"] == "1" {
            RewardDemoView()
        } else if ProcessInfo.processInfo.arguments.contains("-rankTrialDemos")
            || ProcessInfo.processInfo.environment["RANK_TRIAL_DEMOS"] == "1"
            || ProcessInfo.processInfo.environment["RANK_TRIAL_DEMO"] != nil {
            RankTrialDemoRecorderView()
        } else if ProcessInfo.processInfo.arguments.contains("-activeWorkoutDemo") {
            ActiveWorkoutDemoHarness()
        } else if ProcessInfo.processInfo.arguments.contains("-sessionEditorDemo") {
            SessionEditorDemoHarness()
        } else if ProcessInfo.processInfo.arguments.contains("-myWorkoutsDemo") {
            MyWorkoutsDemoHarness()
        } else if ProcessInfo.processInfo.arguments.contains("-vowDemo") {
            VowDemoHarness()
        } else if ProcessInfo.processInfo.arguments.contains("-homeTrialsDemo") {
            HomeTrialsDemoHarness()
        } else if ProcessInfo.processInfo.arguments.contains("-gateDemo") {
            // Gate journey stage harness — pick the screen with
            // UNBOUND_GATE_STAGE=<sealed|open|hall|active|beat|verdictPass|card|verdictFail|records|crossing|flow>.
            GateExperienceDemoView()
        } else if ProcessInfo.processInfo.arguments.contains("-authScreenDemo") {
            // Renders the forced "protect your progress" auth screen directly
            // (Apple + Google + email), bypassing the onboarding/cloud-link gate
            // so it can be reviewed without walking the full first-run flow.
            AuthContainerView()
        } else if ProcessInfo.processInfo.arguments.contains("-treeUnlockDemo") {
            TreeUnlockRevealDemoHarness()
        } else if ProcessInfo.processInfo.arguments.contains("-rankDetailDemo") {
            RankDetailDemoHarness()
        } else if ProcessInfo.processInfo.arguments.contains("-exerciseDetailDemo") {
            ExerciseDetailDemoHarness()
        } else {
            mainContent
        }
        #else
        mainContent
        #endif
    }

    // Pure top-level routing decision. The offline deferral is interpreted from
    // the `@AppStorage`-observed raw timestamp so a fresh "continue for now" tap
    // invalidates the body and re-routes without any extra plumbing.
    private var route: RootRoute {
        RootRouter.route(
            isCheckingAuth: isCheckingAuth,
            onboardingCompleted: hasCompletedOnboarding,
            isCloudLinked: isCloudLinked,
            deferralActive: AuthDeferralStore.isActive(deferredAt: authDeferredAt),
            forceAuthScreen: Self.forceAuthScreen
        )
    }

    // DEBUG review hook: `--unbound-force-auth` forces the forced-auth screen
    // through the real routing path (even if a lingering deferral would skip it)
    // so the orchestrator can screenshot it on-sim. Mirrors the `--unbound-open-*`
    // launch-argument convention and is compiled out of release builds.
    private static var forceAuthScreen: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("--unbound-force-auth")
        #else
        return false
        #endif
    }

    private var mainContent: some View {
        Group {
            switch route {
            case .loading:
                AppLaunchLoadingView()
            case .onboarding:
                OnboardingContainerView(onComplete: {
                    hasCompletedOnboarding = true
                })
            case .auth:
                // Sign-in stays the default, encouraged path; the quiet escape
                // hatch records a deferral (routing above re-reads it and moves
                // the user into the main app as the anonymous local user).
                AuthContainerView(onContinueWithoutAccount: {
                    AuthDeferralStore.shared.markDeferred()
                })
            case .main:
                HomeTabView()
                    .subscriptionGate()
            }
        }
        .task {
            #if DEBUG
            await DevBuildBootstrapper.ensureReady()
            #endif

            for await userId in services.auth.authStatePublisher.values {
                // Anonymous users emit a userId too, so re-derive cloud-link on
                // every change: only a real Supabase session flips this true and
                // routes past the forced auth screen into Home.
                let cloudLinked = await services.auth.isCloudLinked
                isCloudLinked = cloudLinked
                isCheckingAuth = false
                if let userId, cloudLinked {
                    // The offline deferral is meaningless once linked (routing
                    // already resolves to the main app on a real session); clear
                    // it so no stale timestamp survives into a later signed-out
                    // state.
                    AuthDeferralStore.shared.clear()
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
                        // Clears the stash only on a successful write; a throw
                        // leaves it in place so a later launch retries.
                        try? await PendingOnboardingProfile.replay { fields in
                            try await services.user.updateProfile(userId: userId, fields: fields)
                        }
                        #if DEBUG
                        if userId != DevBuildBootstrapper.userId {
                            try? await services.subscription.login(userId: userId)
                        }
                        #else
                        try? await services.subscription.login(userId: userId)
                        #endif

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
                        // Backfill the 6-axis hex from existing logs. Runs AFTER
                        // restore-on-sign-in so a reinstall replays the restored
                        // log history instead of seeing an empty local DB; running
                        // it earlier risks a first post-reinstall workout creating
                        // a one-session profile that latches the backfill off and
                        // permanently undercounts attributes. No-op once a profile
                        // exists in the store.
                        await services.attribute.backfillFromExistingLogs(userId: userId)
                        // One-time skill-tier migration: replay full log history
                        // to seed UserSkillTierState. Idempotent — guarded by
                        // a UserDefaults flag so it only runs once per user.
                        let profile = try? await services.user.fetchProfile(userId: userId)
                        // Restore-on-launch: seed the trial-confirmed rank + per-lift
                        // tiers from the server profile when the local UserDefaults
                        // stores are empty (e.g. after a reinstall). Conservative and
                        // never-regressing, so it is safe to run every launch and can
                        // never lower a locally-earned rank or tier.
                        if let profile {
                            RankProgressCloudBackup.shared.seedLocalStores(from: profile, userId: userId)
                            // Same contract for every seed below: conservative,
                            // never-regressing merges that only raise or fill
                            // empty local state, so running on every launch is
                            // safe. The movement/load snapshot must land before
                            // MovementProgressConsolidationMigration below so
                            // consolidation merges restored rows, not a void.
                            await OverallLevelCloudBackup.shared.seedLocalStores(from: profile, userId: userId)
                            SessionXPCloudBackup.shared.seedLocalStores(from: profile, userId: userId)
                            RewardsCloudBackup.shared.seedLocalStores(from: profile, userId: userId)
                            AchievementsCloudBackup.shared.seedLocalStores(from: profile, userId: userId)
                            await ProgressSnapshotCloudBackup.shared.seedLocalStores(from: profile, userId: userId)
                            // Sweep up equips made outside shop flows (rank
                            // cosmetics, showcase, skin) — free when unchanged
                            // thanks to the redundant-patch cache.
                            RewardsCloudBackup.shared.backup(userId: userId)
                        }
                        let bodyweightKg = profile?.weightKg ?? 70.0
                        let logs = (try? await services.workoutLog.fetchLogs(userId: userId, programId: nil)) ?? []
                        let history = logs.flatMap { $0.exerciseEntries }
                        SkillTierMigration.migrateIfNeeded(
                            userId: userId,
                            history: history,
                            bodyweightKg: bodyweightKg
                        )
                        // One-time consolidation of split movement_progress rows
                        // for movements whose rank standards were unified (P3).
                        // Idempotent + local-only.
                        await MovementProgressConsolidationMigration.migrateIfNeeded(userId: userId)
                    }
                } else if userId == nil {
                    // Genuine sign-out. An anonymous user (userId set, not
                    // cloud-linked) is mid-forced-auth — leave analytics alone.
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
