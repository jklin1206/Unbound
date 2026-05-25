import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var services: ServiceContainer
    @StateObject private var viewModel: SettingsViewModel
    @State private var showDeleteAccount = false
    @AppStorage(WeightPlatePolicy.unitDefaultsKey) private var trainingWeightUnitRaw = TrainingWeightUnit.localeDefault.rawValue
    @AppStorage(WeightPlatePolicy.microloadingDefaultsKey) private var microloadingEnabled = false

    init(services: ServiceContainer) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(services: services))
    }

    var body: some View {
        List {
            // MARK: Account
            Section {
                HStack {
                    Label("Email", systemImage: "envelope")
                        .foregroundColor(.theme.textPrimary)
                    Spacer()
                    Text(viewModel.userProfile?.email ?? "—")
                        .font(.bodyText(14))
                        .foregroundColor(.theme.textMuted)
                }

                Button(role: .destructive) {
                    viewModel.signOut()
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.theme.danger)
                }
            } header: {
                Text("Account")
                    .foregroundColor(.theme.textSecondary)
            }

            // MARK: Subscription
            Section {
                HStack {
                    Label("Plan", systemImage: "crown")
                        .foregroundColor(.theme.textPrimary)
                    Spacer()
                    Text(viewModel.hasActiveSubscription ? "Pro" : "Free")
                        .font(.bodyMedium(14))
                        .foregroundColor(viewModel.hasActiveSubscription ? .theme.primary : .theme.textMuted)
                }

                if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
                    Link(destination: url) {
                        Label("Manage Subscription", systemImage: "arrow.up.circle")
                            .foregroundColor(.theme.textPrimary)
                    }
                }

                Button {
                    Task { await viewModel.restorePurchases() }
                } label: {
                    if viewModel.isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(.theme.primary)
                            Text("Restoring…")
                                .foregroundColor(.theme.textSecondary)
                        }
                    } else {
                        Label("Restore Purchases", systemImage: "arrow.counterclockwise")
                            .foregroundColor(.theme.textPrimary)
                    }
                }
                .disabled(viewModel.isLoading)
            } header: {
                Text("Subscription")
                    .foregroundColor(.theme.textSecondary)
            }

            // MARK: Training preferences
            Section {
                Picker(selection: $trainingWeightUnitRaw) {
                    ForEach(TrainingWeightUnit.allCases) { unit in
                        Text(unit.displayName).tag(unit.rawValue)
                    }
                } label: {
                    Label("Weight Unit", systemImage: "scalemass")
                        .foregroundColor(.theme.textPrimary)
                }

                Toggle(isOn: $microloadingEnabled) {
                    Label("Micro plates", systemImage: "plus.forwardslash.minus")
                        .foregroundColor(.theme.textPrimary)
                }
                .tint(.theme.primary)

                NavigationLink {
                    ExercisePreferencesView()
                        .environmentObject(services)
                } label: {
                    Label("Exercise Library", systemImage: "list.bullet.rectangle.portrait")
                        .foregroundColor(.theme.textPrimary)
                }
                NavigationLink {
                    EquipmentSettingsView()
                } label: {
                    Label("Equipment", systemImage: "dumbbell.fill")
                        .foregroundColor(.theme.textPrimary)
                }
                NavigationLink {
                    CoachActionHistoryView()
                        .environmentObject(services)
                } label: {
                    Label("Plan changes", systemImage: "arrow.triangle.2.circlepath")
                        .foregroundColor(.theme.textPrimary)
                }
                NavigationLink {
                    BadgeGalleryView()
                        .environmentObject(services)
                } label: {
                    Label("Badges", systemImage: "rosette")
                        .foregroundColor(.theme.textPrimary)
                }
            } header: {
                Text("Training")
                    .foregroundColor(.theme.textSecondary)
            } footer: {
                Text("Your exact logged weights are preserved. UNBOUND rounds suggestions and progression jumps to the selected plate system.")
                    .font(.caption(11))
                    .foregroundColor(.theme.textMuted)
            }

            // MARK: Appearance
            Section {
                NavigationLink {
                    ProfileCosmeticsView()
                        .environmentObject(services)
                } label: {
                    Label("Profile cosmetics", systemImage: "person.crop.circle.badge.sparkles")
                        .foregroundColor(.theme.textPrimary)
                }
                NavigationLink {
                    SkinPickerView()
                        .environmentObject(services)
                } label: {
                    Label("Skill tree cosmetics", systemImage: "paintpalette")
                        .foregroundColor(.theme.textPrimary)
                }
            } header: {
                Text("Appearance")
                    .foregroundColor(.theme.textSecondary)
            } footer: {
                Text("Equip unlocked profile frames, backdrops, and skill-tree cosmetics.")
                    .font(.caption(11))
                    .foregroundColor(.theme.textMuted)
            }

            // MARK: Support
            Section {
                if let mailURL = URL(string: "mailto:support@unboundapp.com") {
                    Link(destination: mailURL) {
                        Label("Contact Us", systemImage: "envelope.badge")
                            .foregroundColor(.theme.textPrimary)
                    }
                }

                NavigationLink {
                    FAQPlaceholderView()
                } label: {
                    Label("FAQ", systemImage: "questionmark.circle")
                        .foregroundColor(.theme.textPrimary)
                }
            } header: {
                Text("Support")
                    .foregroundColor(.theme.textSecondary)
            }

            // MARK: Legal
            Section {
                if let tosURL = URL(string: "https://unboundapp.com/terms") {
                    Link(destination: tosURL) {
                        Label("Terms of Service", systemImage: "doc.text")
                            .foregroundColor(.theme.textPrimary)
                    }
                }

                if let privacyURL = URL(string: "https://unboundapp.com/privacy") {
                    Link(destination: privacyURL) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                            .foregroundColor(.theme.textPrimary)
                    }
                }
            } header: {
                Text("Legal")
                    .foregroundColor(.theme.textSecondary)
            }

            // MARK: Danger Zone
            Section {
                Button(role: .destructive) {
                    showDeleteAccount = true
                } label: {
                    Label("Delete Account", systemImage: "trash")
                        .foregroundColor(.theme.danger)
                }
            } header: {
                Text("Danger Zone")
                    .foregroundColor(.theme.textSecondary)
            }

            // MARK: Dev (DEBUG only)
            #if DEBUG
            Section {
                NavigationLink {
                    DevPlayerToolsView()
                        .environmentObject(services)
                } label: {
                    Label("Dev Player Tools", systemImage: "gamecontroller")
                        .foregroundColor(.theme.textPrimary)
                }

                Toggle(isOn: Binding(
                    get: { DevFlags.shared.unlockAllFeatures },
                    set: { DevFlags.shared.unlockAllFeatures = $0 }
                )) {
                    Label("Unlock all features", systemImage: "lock.open")
                        .foregroundColor(.theme.textPrimary)
                }
                .tint(.theme.primary)

                Button {
                    resetOnboarding()
                } label: {
                    Label("Reset Onboarding", systemImage: "arrow.counterclockwise.circle")
                        .foregroundColor(.theme.primary)
                }

                Button {
                    resetEverything()
                } label: {
                    Label("Reset Everything (wipe)", systemImage: "arrow.triangle.2.circlepath")
                        .foregroundColor(.theme.danger)
                }
            } header: {
                Text("Dev")
                    .foregroundColor(.theme.textSecondary)
            } footer: {
                Text("Debug-only controls. Hidden in release builds. Unlock bypasses the paywall without charging.")
                    .font(.caption(11))
                    .foregroundColor(.theme.textMuted)
            }
            #endif
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.theme.background)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(isPresented: $showDeleteAccount) {
            AccountDeletionView(viewModel: viewModel)
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onAppear {
            Task { await viewModel.loadProfile() }
        }
    }

    // MARK: - Dev resets

    #if DEBUG
    private func resetOnboarding() {
        // Flip the flag — RootView observes via @AppStorage and re-routes.
        UserDefaults.standard.set(false, forKey: "onboardingCompleted")
        // Optional haptic so it feels intentional
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.impactOccurred()
    }

    private func resetEverything() {
        // Wipe everything local — user id, onboarding flag, answer data.
        // Forces the app into a truly fresh state.
        UserDefaults.standard.removeObject(forKey: "onboardingCompleted")
        UserDefaults.standard.removeObject(forKey: "unbound.localUserId")
        UserDefaults.standard.removeObject(forKey: "unbound.localUserEmail")

        // Clear local database + scan photos
        let fm = FileManager.default
        if let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
            try? fm.removeItem(at: docs.appendingPathComponent("Database"))
            try? fm.removeItem(at: docs.appendingPathComponent("ScanPhotos"))
        }

        // Re-provision so auth state publisher fires with a fresh UUID
        AuthService.shared.autoProvisionIfNeeded()

        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.warning)
    }
#endif
}

#if DEBUG
private struct DevPlayerToolsView: View {
    @EnvironmentObject private var services: ServiceContainer

    @State private var selectedLevel: Int = 25
    @State private var selectedRank: SkillTier = .ascendant
    @State private var devTotalSessions: Int = 96
    @State private var devCurrentStreak: Int = 21
    @State private var devLongestStreak: Int = 45
    @State private var devWeeklySessions: Int = 5
    @State private var devAttributes: [AttributeKey: Double] = Dictionary(uniqueKeysWithValues: AttributeKey.allCases.map { ($0, 70) })
    @State private var selectedBestLift: String = "deadlift"
    @State private var selectedBestLiftWeight: Double = 225
    @State private var selectedBestLiftReps: Int = 1
    @State private var isApplying = false
    @State private var status = "Dev account is local-only and hidden in release builds."

    private var currentUserId: String {
        AuthService.shared.currentUserId ?? DevBuildBootstrapper.userId
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center, spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.theme.primary.opacity(0.16))
                                .frame(width: 54, height: 54)
                            Image(systemName: "gamecontroller.fill")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.theme.primary)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Dev Player")
                                .font(.subheadline(18))
                                .foregroundColor(.theme.textPrimary)
                            Text(currentUserId)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(.theme.textMuted)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        Spacer()
                    }

                    Text(status)
                        .font(.caption(12))
                        .foregroundColor(.theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        run { await DevBuildBootstrapper.activate(services: services) }
                    } label: {
                        Label("Activate Dev Player", systemImage: "person.crop.circle.badge.checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isApplying)
                }
                .padding(.vertical, 6)
            } footer: {
                Text("This switches auth to a stable local user, completes onboarding, enables the paywall bypass, and seeds a usable profile.")
                    .font(.caption(11))
                    .foregroundColor(.theme.textMuted)
            }

            Section {
                Stepper(value: $selectedLevel, in: 1...80) {
                    HStack {
                        Label("Level", systemImage: "bolt.fill")
                            .foregroundColor(.theme.textPrimary)
                        Spacer()
                        Text("\(selectedLevel)")
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            .foregroundColor(.theme.primary)
                    }
                }

                Button {
                    run { await DevBuildBootstrapper.applyLevel(selectedLevel) }
                } label: {
                    Label("Apply Level", systemImage: "bolt.badge.checkmark")
                        .foregroundColor(.theme.primary)
                }

                Picker("Rank", selection: $selectedRank) {
                    ForEach(SkillTier.allCases, id: \.self) { tier in
                        Text(tier.displayName).tag(tier)
                    }
                }

                Button {
                    run { await DevBuildBootstrapper.applyRank(selectedRank) }
                } label: {
                    Label("Apply Rank", systemImage: "seal.fill")
                        .foregroundColor(.theme.primary)
                }

            } header: {
                Text("Fast Tuning")
                    .foregroundColor(.theme.textSecondary)
            } footer: {
                Text("Rank updates the profile tier, badge frame, lift proof tiers, and skill-tier state for the dev player.")
                    .font(.caption(11))
                    .foregroundColor(.theme.textMuted)
            }

            Section {
                devStepper(label: "Total Sessions", systemName: "bolt.fill", value: $devTotalSessions, range: 0...500)
                devStepper(label: "Current Streak", systemName: "flame.fill", value: $devCurrentStreak, range: 0...365)
                devStepper(label: "Longest Streak", systemName: "crown.fill", value: $devLongestStreak, range: 0...365)
                devStepper(label: "This Week", systemName: "calendar", value: $devWeeklySessions, range: 0...14)

                Button {
                    run {
                        await DevBuildBootstrapper.applySessionStats(
                            totalSessions: devTotalSessions,
                            currentStreak: devCurrentStreak,
                            longestStreak: devLongestStreak,
                            weeklyCount: devWeeklySessions
                        )
                    }
                } label: {
                    Label("Apply Session Stats", systemImage: "checkmark.seal")
                        .foregroundColor(.theme.primary)
                }
            } header: {
                Text("Profile Stats")
                    .foregroundColor(.theme.textSecondary)
            } footer: {
                Text("Controls the profile Sessions, Streak, weekly count, and related session XP record.")
                    .font(.caption(11))
                    .foregroundColor(.theme.textMuted)
            }

            Section {
                ForEach(AttributeKey.allCases, id: \.self) { key in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label(key.displayName, systemImage: attributeIcon(for: key))
                                .foregroundColor(.theme.textPrimary)
                            Spacer()
                            Text("\(Int(devAttributes[key, default: 0].rounded()))")
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .foregroundColor(.theme.primary)
                        }
                        Slider(
                            value: Binding(
                                get: { devAttributes[key, default: 0] },
                                set: { devAttributes[key] = $0 }
                            ),
                            in: 0...100,
                            step: 1
                        )
                        .tint(Color.unbound.accent)
                    }
                    .padding(.vertical, 4)
                }

                Button {
                    run { DevBuildBootstrapper.applyAttributes(devAttributes) }
                } label: {
                    Label("Apply Hex Stats", systemImage: "hexagon.fill")
                        .foregroundColor(.theme.primary)
                }
            } header: {
                Text("Attribute Hex")
                    .foregroundColor(.theme.textSecondary)
            } footer: {
                Text("Writes directly to AttributeProfileStore, so the profile radar and build identity use these values.")
                    .font(.caption(11))
                    .foregroundColor(.theme.textMuted)
            }

            Section {
                Picker("Best Lift", selection: $selectedBestLift) {
                    ForEach(DevBuildBootstrapper.devLiftNames, id: \.self) { lift in
                        Text(lift.capitalized).tag(lift)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Weight", systemImage: "dumbbell.fill")
                            .foregroundColor(.theme.textPrimary)
                        Spacer()
                        Text("\(Int(selectedBestLiftWeight.rounded())) kg")
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .foregroundColor(.theme.primary)
                    }
                    Slider(value: $selectedBestLiftWeight, in: 20...360, step: 2.5)
                        .tint(Color.unbound.accent)
                }

                devStepper(label: "Reps", systemName: "number", value: $selectedBestLiftReps, range: 1...20)

                Button {
                    run {
                        await DevBuildBootstrapper.applyBestLift(
                            lift: selectedBestLift,
                            weightKg: selectedBestLiftWeight,
                            reps: selectedBestLiftReps
                        )
                    }
                } label: {
                    Label("Apply Best Lift", systemImage: "dumbbell.fill")
                        .foregroundColor(.theme.primary)
                }
            } header: {
                Text("Best Lift")
                    .foregroundColor(.theme.textSecondary)
            } footer: {
                Text("Seeds the profile PR workout log so Best Lift shows this lift and its rank badge.")
                    .font(.caption(11))
                    .foregroundColor(.theme.textMuted)
            }

            Section {
                Button {
                    run { await DevBuildBootstrapper.unlockAllBadges() }
                } label: {
                    Label("Unlock All Badges", systemImage: "rosette")
                        .foregroundColor(.theme.primary)
                }

                Button {
                    run { await DevBuildBootstrapper.masterSkillTree() }
                } label: {
                    Label("Master Skill Tree", systemImage: "circle.hexagongrid.fill")
                        .foregroundColor(.theme.primary)
                }

                Button {
                    run { await DevBuildBootstrapper.seedSessionStats() }
                } label: {
                    Label("Seed Streak + Session Stats", systemImage: "flame.fill")
                        .foregroundColor(.theme.primary)
                }

                Button {
                    run {
                        await DevBuildBootstrapper.maxEverything(
                            level: selectedLevel,
                            services: services
                        )
                    }
                } label: {
                    Label("Max Everything", systemImage: "sparkles")
                        .foregroundColor(.theme.primary)
                }
                .disabled(isApplying)
            } header: {
                Text("Feature Unlocks")
                    .foregroundColor(.theme.textSecondary)
            }

            Section {
                Button(role: .destructive) {
                    DevBuildBootstrapper.clearDevProgress()
                    status = "Dev progress cleared. Activate again when you want a fresh sandbox."
                } label: {
                    Label("Clear Dev Progress", systemImage: "trash")
                        .foregroundColor(.theme.danger)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.theme.background)
        .navigationTitle("Dev Player")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadDevControlValues() }
    }

    private func devStepper(label: String, systemName: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        Stepper(value: value, in: range) {
            HStack {
                Label(label, systemImage: systemName)
                    .foregroundColor(.theme.textPrimary)
                Spacer()
                Text("\(value.wrappedValue)")
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundColor(.theme.primary)
            }
        }
    }

    private func attributeIcon(for key: AttributeKey) -> String {
        switch key {
        case .power: return "bolt.fill"
        case .explosiveness: return "hare.fill"
        case .control: return "scope"
        case .agility: return "heart.fill"
        case .mobility: return "figure.flexibility"
        case .endurance: return "infinity"
        }
    }

    private func loadDevControlValues() {
        let record = SessionXPService.shared.record(userId: currentUserId)
        devTotalSessions = record.totalSessions
        devCurrentStreak = record.currentStreak
        devLongestStreak = record.longestStreak
        devWeeklySessions = record.weeklyCount

        let profile = AttributeProfileStore.shared.load(userId: currentUserId) ?? .empty(userId: currentUserId, at: .now)
        devAttributes = Dictionary(uniqueKeysWithValues: AttributeKey.allCases.map { key in
            (key, profile.value(for: key).current)
        })
    }

    private func run(_ action: @escaping () async -> Void) {
        isApplying = true
        status = "Applying..."
        Task {
            await action()
            await MainActor.run {
                isApplying = false
                status = "Applied. Pull to refresh or switch tabs if a visible screen was already loaded."
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }
}

@MainActor
enum DevBuildBootstrapper {
    static let userId = "dev-player"
    static let devLiftNames = ["bench press", "back squat", "deadlift", "overhead press"]

    private static let gainsKey = "unbound.gains"
    private static let badgeKey = "unbound.badges.\(userId)"
    private static let sessionXPKey = "unbound.sessionxp.\(userId)"
    private static let didBootstrapKey = "unbound.dev.didBootstrapEverything"
    private static let resetOpenedSkillForProofArg = "--unbound-reset-opened-skill-for-proof"
    private static let resetActiveGoalsForProofArg = "--unbound-reset-active-goals-for-proof"
    private static let scheduledSkillProofArg = "--unbound-proof-scheduled-skill"
    private static let rankTrialReadyProofArg = "--unbound-proof-rank-trial-ready"
    private static let programStateProofArg = "--unbound-proof-program-state"
    private static let programSurfaceProofArg = "--unbound-proof-program-surface"

    static func ensureReady() async {
        AuthService.shared.activateDevUser(id: userId)
        DevFlags.shared.unlockAllFeatures = true

        await maxEverything(
            level: 42,
            services: ServiceContainer(),
            completeOnboarding: shouldCompleteOnboardingForLaunchRoute
        )
        if ProcessInfo.processInfo.arguments.contains(resetOpenedSkillForProofArg),
           let skillId = launchArgumentValue(for: "--unbound-open-skill") {
            await resetSkillForProof(skillId: skillId)
        }
        if ProcessInfo.processInfo.arguments.contains(resetActiveGoalsForProofArg) {
            await resetActiveGoalsForProof()
        }
        if let skillId = launchArgumentValue(for: scheduledSkillProofArg) {
            await seedScheduledSkillProof(skillId: skillId)
        }
        if let targetRank = rankTrialProofTargetArgument {
            await seedOverallRankTrialReadyProof(targetRankRawValue: targetRank)
        }
        if let rawProgramState = launchArgumentValue(for: programStateProofArg) {
            await seedProgramProofState(rawValue: rawProgramState)
        }
        if shouldSeedBindingVowForProof {
            await seedBindingVowForProof()
        }
        UserDefaults.standard.set(true, forKey: didBootstrapKey)
    }

    private static var shouldCompleteOnboardingForLaunchRoute: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("--unbound-open-program")
            || arguments.contains("--unbound-open-routine")
            || arguments.contains("--unbound-open-cardio-log")
            || arguments.contains("--unbound-open-skills")
            || arguments.contains("--unbound-open-squad")
            || arguments.contains("--unbound-open-profile")
            || rankTrialProofTargetArgument != nil
            || arguments.contains(where: { $0 == "--unbound-open-skill" || $0.hasPrefix("--unbound-open-skill=") })
            || arguments.contains(resetActiveGoalsForProofArg)
            || arguments.contains(where: { $0 == scheduledSkillProofArg || $0.hasPrefix("\(scheduledSkillProofArg)=") })
            || arguments.contains(where: { $0 == programStateProofArg || $0.hasPrefix("\(programStateProofArg)=") })
            || arguments.contains(where: { $0 == programSurfaceProofArg || $0.hasPrefix("\(programSurfaceProofArg)=") })
    }

    private static var rankTrialProofTargetArgument: String? {
        if let targetRank = launchArgumentValue(for: rankTrialReadyProofArg) {
            return targetRank
        }
        return ProcessInfo.processInfo.arguments.contains(rankTrialReadyProofArg)
            ? RankTitle.novice.rawValue
            : nil
    }

    private static var shouldSeedBindingVowForProof: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("--unbound-open-program")
            || arguments.contains(where: { $0 == programStateProofArg || $0.hasPrefix("\(programStateProofArg)=") })
            || arguments.contains(where: { $0 == programSurfaceProofArg || $0.hasPrefix("\(programSurfaceProofArg)=") })
    }

    static func activate(services: ServiceContainer, completeOnboarding: Bool = true) async {
        AuthService.shared.activateDevUser(id: userId)
        DevFlags.shared.unlockAllFeatures = true
        UserDefaults.standard.set(completeOnboarding, forKey: "onboardingCompleted")
        UserDefaults.standard.set(completeOnboarding, forKey: "unbound.calibration.completed")

        var profile = UserProfile(
            id: userId,
            email: "dev@unbound.local",
            displayName: "Dev Player",
            createdAt: Date(),
            onboardingCompleted: completeOnboarding,
            totalScans: 12,
            currentProgramId: "dev-program",
            heightCm: 180,
            weightKg: 82,
            age: 28,
            biologicalSex: .male
        )
        profile.displayHandle = "devplayer"
        profile.experience = .current
        profile.currentFrequency = .fivePlus
        profile.targetFrequency = .five
        profile.equipment = [.fullGym, .barbell, .dumbbells, .bench, .pullupBar, .bodyweight]
        profile.goals = [.buildMuscle, .getDefined, .getStronger, .athletic]
        profile.trainingStyleOverride = .freeWeights
        profile.trainingFeedbackMode = .detailed
        profile.trainingDays = [.monday, .tuesday, .wednesday, .thursday, .friday]

        try? await DatabaseService.shared.create(profile, collection: "users", documentId: userId)
        BadgeService.shared.bind(userId: userId)
        await SkillProgressService.shared.load(userId: userId)
        seedAttributes()
        await seedProgressionFamilies()
        seedLiftTiers()
        await seedProgram()
        await seedWorkoutLogs()
        await seedProgressPhotos()
        SkinService.shared.debugUnlockAllSkins()
        await seedSessionStats()
        await applyLevel(25)
        await TrialsService.shared.ensureCurrentWeek(userId: userId)
    }

    static func maxEverything(level: Int, services: ServiceContainer, completeOnboarding: Bool = true) async {
        await activate(services: services, completeOnboarding: completeOnboarding)
        await applyLevel(level)
        await unlockAllBadges()
        await masterSkillTree()
        await seedSessionStats()
        seedAttributes()
        await seedProgressionFamilies()
        seedLiftTiers()
        await seedProgram()
        await seedWorkoutLogs()
        await seedProgressPhotos()
        SkinService.shared.debugUnlockAllSkins()
        await TrialsService.shared.ensureCurrentWeek(userId: userId)
    }

    static func applyLevel(_ level: Int) async {
        let clamped = max(1, min(80, level))
        UserDefaults.standard.set((clamped - 1) * 250, forKey: gainsKey)
    }

    static func unlockAllBadges() async {
        AuthService.shared.activateDevUser(id: userId)
        let now = Date()
        let unlocked = BadgeCatalog.all.enumerated().reduce(into: [String: Date]()) { result, pair in
            result[pair.element.id] = Calendar.current.date(byAdding: .minute, value: -pair.offset, to: now) ?? now
        }
        if let data = try? JSONEncoder.unbound.encode(unlocked) {
            UserDefaults.standard.set(data, forKey: badgeKey)
        }
        BadgeService.shared.bind(userId: userId)
    }

    static func seedSessionStats() async {
        await applySessionStats(totalSessions: 96, currentStreak: 21, longestStreak: 45, weeklyCount: 5)
    }

    static func applySessionStats(
        totalSessions: Int,
        currentStreak: Int,
        longestStreak: Int,
        weeklyCount: Int
    ) async {
        AuthService.shared.activateDevUser(id: userId)
        var cal = Calendar.current
        cal.firstWeekday = 2
        let weekComponents = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        let weekStart = cal.date(from: weekComponents) ?? cal.startOfDay(for: Date())
        let streak = max(0, currentStreak)
        let record = SessionXPRecord(
            userId: userId,
            totalSessions: max(0, totalSessions),
            currentStreak: streak,
            longestStreak: max(streak, longestStreak),
            lastSessionDate: Date(),
            weeklyCount: max(0, weeklyCount),
            weekStartDate: weekStart
        )
        if let data = try? JSONEncoder.unbound.encode(record) {
            UserDefaults.standard.set(data, forKey: sessionXPKey)
        }
        UserDefaults.standard.set(record.currentStreak, forKey: "unbound.streakDays")
        let delta = SessionXPDelta(previous: record, updated: record, streakExtended: false, streakBroken: false)
        NotificationCenter.default.post(name: .sessionXPUpdated, object: nil, userInfo: ["delta": delta])
    }

    static func masterSkillTree(tier: SkillTier = .ascendant) async {
        AuthService.shared.activateDevUser(id: userId)
        let now = Date()
        let graph = SkillGraph.shared
        let states = graph.nodes.reduce(into: [String: NodeState]()) { result, node in
            result[node.id] = .mastered
        }
        let dates = graph.nodes.reduce(into: [String: Date]()) { result, node in
            result[node.id] = now
        }
        let progress = graph.nodes.reduce(into: [String: SkillProgress]()) { result, node in
            result[node.id] = SkillProgress(currentLevel: 5, xpInLevel: 0, xpToNextLevel: 0)
        }
        let activeGoals = Set(graph.nodes.filter { !$0.isMythic }.prefix(6).map(\.id))
        let schedule: [DayCategory?] = [.push, .pull, .legs, .core, .skills, .conditioning, .rest]

        let payload = UserSkillProgress(
            userId: userId,
            nodeStates: states,
            achievedAt: dates,
            masteredAt: dates,
            updatedAt: now,
            skillProgress: progress,
            lastTrainedAt: [:],
            bookmarkedNodeIds: activeGoals,
            activeGoalIds: activeGoals,
            weeklySchedule: schedule,
            currentWeekPhase: .heavy
        )
        try? await DatabaseService.shared.create(payload, collection: "skillProgress", documentId: userId)
        await SkillProgressService.shared.load(userId: userId)

        let tierState = UserSkillTierState(
            perSkill: graph.nodes.reduce(into: [String: SkillTier]()) { result, node in
                result[node.id] = tier
            },
            rankUpsEarned: graph.nodes.count * max(tier.rawValue, 1),
            ascendantSkills: tier == .ascendant ? graph.nodes.map(\.id) : []
        )
        UserSkillTierStore.shared.save(tierState, userId: userId)
    }

    static func applyRank(_ tier: SkillTier) async {
        AuthService.shared.activateDevUser(id: userId)
        await masterSkillTree(tier: tier)
        seedLiftTiers(tier: tier)
        await seedProgressionFamilies(tier: tier)
        SkinService.shared.debugUnlockAllSkins(select: tier.rawValue >= SkillTier.unbound.rawValue ? .holographic : .violet)
        NotificationCenter.default.post(name: .skillTierAdvanced, object: SkillTierAdvance(
            skillId: "dev-profile-rank",
            from: .initiate,
            to: tier
        ))
    }

    static func seedAttributes() {
        applyAttributes([
            .power: 88,
            .explosiveness: 78,
            .control: 82,
            .agility: 66,
            .mobility: 60,
            .endurance: 74
        ])
    }

    static func applyAttributes(_ values: [AttributeKey: Double]) {
        let now = Date()
        var profile = AttributeProfile.empty(userId: userId, at: now)
        for key in AttributeKey.allCases {
            let score = min(100, max(0, values[key] ?? 0))
            profile.set(
                key,
                AttributeValue(peak: score, current: score, lastContributionAt: now)
            )
        }
        profile.computedAt = now
        AttributeProfileStore.shared.save(profile)
        NotificationCenter.default.post(name: .attributeRankUp, object: nil)
    }

    static func seedLiftTiers(tier: SkillTier = .ascendant) {
        for lift in devLiftNames {
            LiftTierService.shared.save(tier: tier, lift: lift, userId: userId)
        }
    }

    static func applyBestLift(lift: String, weightKg: Double, reps: Int) async {
        AuthService.shared.activateDevUser(id: userId)
        let normalized = devLiftNames.contains(lift) ? lift : "deadlift"
        let safeWeight = max(1, weightKg)
        let safeReps = max(1, reps)
        let tier = liftTier(for: normalized, weightKg: safeWeight)

        for name in devLiftNames {
            LiftTierService.shared.save(tier: name == normalized ? tier : .initiate, lift: name, userId: userId)
        }

        let entries = devLiftNames.enumerated().map { offset, name in
            let isSelected = name == normalized
            return ExerciseLogEntry(
                id: "dev-\(name.replacingOccurrences(of: " ", with: "-"))",
                exerciseName: name,
                plannedSets: 1,
                plannedReps: "\(isSelected ? safeReps : 1)",
                sets: [
                    SetLog(
                        id: "dev-\(offset)-top",
                        setNumber: 1,
                        weightKg: isSelected ? safeWeight : 1,
                        reps: isSelected ? safeReps : 1,
                        rpe: isSelected ? 9 : 6,
                        isWarmup: false
                    )
                ],
                skipped: false,
                notes: nil
            )
        }
        let now = Date()
        let log = WorkoutLog(
            id: "dev-profile-prs",
            userId: userId,
            programId: "dev-program",
            dayNumber: 1,
            plannedWorkoutName: "Dev Showcase",
            startedAt: now.addingTimeInterval(-86_400),
            completedAt: now.addingTimeInterval(-86_400 + 3_600),
            exerciseEntries: entries,
            overallNotes: "Seeded debug profile lift proofs.",
            overallRPE: 9,
            durationMinutes: 60
        )
        try? await DatabaseService.shared.create(log, collection: "workoutLogs", documentId: log.id)
    }

    private static func liftTier(for lift: String, weightKg: Double) -> SkillTier {
        guard let criteria = LiftTierCriteria.table[lift] else { return .initiate }
        return SkillTier.allCases.reversed().first { tier in
            guard case .weightKg(let target)? = criteria[tier] else { return false }
            return weightKg >= target
        } ?? .initiate
    }

    static func seedProgressionFamilies(tier: SkillTier = .ascendant) async {
        let now = Date()
        let requestedTier = progressionFamilyTier(for: tier)
        let grouped = Dictionary(grouping: MovementCatalog.legacyExercises.compactMap { exercise -> (String, Int)? in
            guard let family = exercise.progressionFamily, let tier = exercise.progressionTier else { return nil }
            return (family, tier)
        }, by: { $0.0 })

        for (family, entries) in grouped {
            let maxTier = entries.map(\.1).max() ?? 0
            let unlockedTier = min(maxTier, requestedTier)
            let state = ProgressionFamilyState(
                userId: userId,
                family: family,
                unlockedTier: unlockedTier,
                currentTier: unlockedTier,
                updatedAt: now
            )
            await ProgressionStateStore.shared.saveFamilyState(state)
        }
    }

    static func seedOverallRankTrialReadyProof(targetRankRawValue: String = RankTitle.novice.rawValue) async {
        AuthService.shared.activateDevUser(id: userId)
        let now = Date()
        let targetRank = RankTitle(rawValue: targetRankRawValue) ?? .novice
        let definition = OverallRankTrialDefinitions.all.first { $0.targetRank == targetRank }
            ?? OverallRankTrialDefinitions.foundationProof
        OverallRankTrialStore.shared.save(
            OverallRankTrialProgress(highestPassedRank: sourceRank(before: definition.targetRank), attempts: []),
            userId: userId
        )

        let overall = OverallLevelProgress(
            userId: userId,
            totalXP: OverallLevelCurve.xpRequired(forLevel: definition.minOverallLevel),
            lastGainedXP: 0,
            processedSourceLogIds: [],
            updatedAt: now
        )
        try? await DatabaseService.shared.create(
            overall,
            collection: "overall_level_progress",
            documentId: userId
        )

        for standard in definition.movementStandards {
            let state = MovementProgressState(
                userId: userId,
                rankStandardMovementId: standard.rankStandardMovementId,
                displayName: standard.displayName,
                rankTemplate: MovementCatalog.definition(for: standard.rankStandardMovementId)?.rankTemplate ?? .bodyweightReps,
                totalAP: standard.minimumAP + 25,
                lastGainedAP: 0,
                updatedAt: now
            )
            try? await DatabaseService.shared.create(
                state,
                collection: "movement_progress",
                documentId: state.id
            )
        }

        var tierState = UserSkillTierStore.shared.load(userId: userId)
        for standard in definition.skillStandards {
            tierState.perSkill[standard.skillId] = standard.minimumTier
        }
        UserSkillTierStore.shared.save(tierState, userId: userId)
        applyAttributes(
            Dictionary(uniqueKeysWithValues: AttributeKey.allCases.map { key in
                (key, max(25, definition.topAttributeFloor + 2))
            })
        )
    }

    private static func sourceRank(before targetRank: RankTitle) -> RankTitle {
        switch targetRank {
        case .novice: return .initiate
        case .apprentice: return .novice
        case .honed: return .apprentice
        case .forged: return .honed
        case .veteran: return .forged
        case .vessel: return .veteran
        case .unbound: return .vessel
        case .ascendant: return .unbound
        case .initiate: return .initiate
        }
    }

    private static func progressionFamilyTier(for tier: SkillTier) -> Int {
        switch tier {
        case .initiate: return 0
        case .novice: return 1
        case .apprentice: return 1
        case .forged: return 2
        case .veteran: return 3
        case .honed: return 4
        case .vessel: return 5
        case .unbound: return 6
        case .ascendant: return 7
        }
    }

    static func seedProgram() async {
        let now = Date()
        let workouts: [Workout] = [
            Workout(
                name: "Power Upper",
                targetMuscleGroups: [.chest, .shoulders, .arms],
                warmup: [],
                mainExercises: [
                    Exercise(id: "dev-bench", name: "Bench Press", muscleGroups: [.chest, .shoulders, .arms], sets: 4, reps: "4-6", restSeconds: 180, rpe: 8, notes: nil, substitution: nil),
                    Exercise(id: "dev-ohp", name: "Overhead Press", muscleGroups: [.shoulders, .arms], sets: 3, reps: "5", restSeconds: 150, rpe: 8, notes: nil, substitution: nil),
                    Exercise(id: "dev-pullup", name: "Pullup", muscleGroups: [.back, .arms], sets: 4, reps: "6-10", restSeconds: 120, rpe: 8, notes: nil, substitution: nil)
                ],
                cooldown: [],
                estimatedMinutes: 55,
                notes: "Debug seeded session.",
                blockType: .intensification
            ),
            Workout(
                name: "Lower Output",
                targetMuscleGroups: [.legs, .glutes, .core],
                warmup: [],
                mainExercises: [
                    Exercise(id: "dev-squat", name: "Back Squat", muscleGroups: [.legs, .glutes, .core], sets: 4, reps: "3-5", restSeconds: 180, rpe: 8, notes: nil, substitution: nil),
                    Exercise(id: "dev-rdl", name: "Romanian Deadlift", muscleGroups: [.legs, .glutes, .back], sets: 3, reps: "6-8", restSeconds: 150, rpe: 8, notes: nil, substitution: nil),
                    Exercise(id: "dev-calf", name: "Standing Calf Raise", muscleGroups: [.calves], sets: 4, reps: "10-15", restSeconds: 75, rpe: 8, notes: nil, substitution: nil)
                ],
                cooldown: [],
                estimatedMinutes: 60,
                notes: "Debug seeded session.",
                blockType: .intensification
            ),
            Workout(
                name: "Skill Control",
                targetMuscleGroups: [.core, .shoulders],
                warmup: [],
                mainExercises: [
                    Exercise(id: "dev-handstand", name: "Wall Handstand", muscleGroups: [.shoulders, .core], sets: 5, reps: "30s", restSeconds: 90, rpe: 7, notes: nil, substitution: nil),
                    Exercise(id: "dev-lsit", name: "L-Sit", muscleGroups: [.core], sets: 5, reps: "15s", restSeconds: 90, rpe: 7, notes: nil, substitution: nil),
                    Exercise(id: "dev-mobility", name: "Deep Squat Hold", muscleGroups: [.legs, .core], sets: 3, reps: "60s", restSeconds: 60, rpe: 6, notes: nil, substitution: nil)
                ],
                cooldown: [],
                estimatedMinutes: 45,
                notes: "Debug seeded session.",
                blockType: .accumulation
            )
        ]

        let days = (1...14).map { day in
            let isRest = day == 4 || day == 7 || day == 11 || day == 14
            return ProgramDay(
                id: "dev-day-\(day)",
                dayNumber: day,
                label: isRest ? "Recovery" : "Day \(day)",
                isRestDay: isRest,
                workout: isRest ? nil : workouts[(day - 1) % workouts.count],
                nutritionOverride: nil,
                recoveryActivities: isRest ? [
                    RecoveryActivity(id: "dev-recovery-\(day)", name: "Walk + Mobility", description: "Zone 2 walk with hip and shoulder range work.", durationMinutes: 30, frequency: "Today")
                ] : []
            )
        }

        let program = TrainingProgram(
            id: "dev-program",
            scanId: "dev-scan",
            analysisId: "dev-analysis",
            userId: userId,
            createdAt: now,
            name: "Dev Ascension Block",
            description: "Seeded debug block with strength, skill, recovery, and nutrition surfaces populated.",
            days: days,
            nutritionPlan: NutritionPlan(
                dailyCalories: 2850,
                proteinGrams: 180,
                carbsGrams: 330,
                fatGrams: 80,
                mealCount: 4,
                meals: [],
                hydrationLiters: 3.2,
                supplements: ["Creatine", "Electrolytes"],
                notes: "Debug nutrition target.",
                restDayCalories: 2550,
                restDayProteinGrams: 180,
                restDayCarbsGrams: 260,
                restDayFatGrams: 85
            ),
            recoveryPlan: RecoveryPlan(
                sleepHoursTarget: 8,
                restDaysPerWeek: 2,
                activities: [
                    RecoveryActivity(id: "dev-sleep", name: "Sleep Window", description: "Eight hour target with a consistent shutdown ritual.", durationMinutes: 480, frequency: "Daily")
                ],
                notes: "Debug recovery target."
            ),
            difficultyLevel: .advanced,
            requiredEquipment: ["Barbell", "Dumbbells", "Pullup Bar"],
            estimatedDailyMinutes: 55,
            rationale: nil
        )

        try? await DatabaseService.shared.create(program, collection: "programs", documentId: program.id)
        await ProgramStore.shared.save(program, userId: userId)
        try? await DatabaseService.shared.update(["currentProgramId": program.id], collection: "users", documentId: userId)
    }

    static func seedProgramProofState(rawValue: String) async {
        guard let state = ProgramProofState.parse(rawValue) else { return }
        AuthService.shared.activateDevUser(id: userId)
        let program = ProgramProofProgramFactory.make(state: state, userId: userId)
        try? await DatabaseService.shared.create(program, collection: "programs", documentId: program.id)
        await ProgramStore.shared.save(program, userId: userId)
        try? await DatabaseService.shared.update(["currentProgramId": program.id], collection: "users", documentId: userId)
    }

    static func seedBindingVowForProof() async {
        AuthService.shared.activateDevUser(id: userId)
        WeeklyVowsStore.shared.save(.empty, userId: userId)
        await TrialsService.shared.ensureCurrentWeek(userId: userId)
        let cards = TrialsService.shared.state(userId: userId).currentWeekCards
        if let card = cards.first(where: { $0.kind == .overdrive }) ?? cards.first {
            TrialsService.shared.pickVowCard(card, userId: userId)
        }
    }

    static func seedWorkoutLogs() async {
        let now = Date()
        let lifts: [(String, Double, Int)] = [
            ("bench press", 142.5, 3),
            ("back squat", 190, 2),
            ("deadlift", 225, 1),
            ("overhead press", 92.5, 2)
        ]
        let entries = lifts.enumerated().map { offset, lift in
            ExerciseLogEntry(
                id: "dev-\(lift.0.replacingOccurrences(of: " ", with: "-"))",
                exerciseName: lift.0,
                plannedSets: 3,
                plannedReps: "\(lift.2)",
                sets: [
                    SetLog(
                        id: "dev-\(offset)-top",
                        setNumber: 1,
                        weightKg: lift.1,
                        reps: lift.2,
                        rpe: 9,
                        isWarmup: false
                    )
                ],
                skipped: false,
                notes: nil
            )
        }
        let log = WorkoutLog(
            id: "dev-profile-prs",
            userId: userId,
            programId: "dev-program",
            dayNumber: 1,
            plannedWorkoutName: "Dev Showcase",
            startedAt: now.addingTimeInterval(-86_400),
            completedAt: now.addingTimeInterval(-86_400 + 3_600),
            exerciseEntries: entries,
            overallNotes: "Seeded debug profile lift proofs.",
            overallRPE: 9,
            durationMinutes: 60
        )
        try? await DatabaseService.shared.create(log, collection: "workoutLogs", documentId: log.id)
    }

    static func seedProgressPhotos() async {
        guard
            let before = UIImage(named: "DevProgressBefore"),
            let after = UIImage(named: "DevProgressAfter")
        else { return }

        ProfilePhotoStore.shared.set(after, userId: userId)

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        guard let docs else { return }

        let beforePath = docs.appendingPathComponent("dev_progress_before.jpg")
        let afterPath = docs.appendingPathComponent("dev_progress_after.jpg")
        try? before.jpegData(compressionQuality: 0.9)?.write(to: beforePath, options: [.atomic])
        try? after.jpegData(compressionQuality: 0.9)?.write(to: afterPath, options: [.atomic])

        let calendar = Calendar.current
        let beforeDate = calendar.date(byAdding: .month, value: -5, to: Date()) ?? Date().addingTimeInterval(-150 * 86_400)
        let afterDate = Date()

        let beforePhoto = ProgressPhoto(
            id: "dev-progress-before",
            userId: userId,
            storageUrl: beforePath.path,
            capturedAt: beforeDate,
            note: "Before",
            angle: .front,
            blockNumber: 1,
            source: .manual
        )
        let afterPhoto = ProgressPhoto(
            id: "dev-progress-after",
            userId: userId,
            storageUrl: afterPath.path,
            capturedAt: afterDate,
            note: "After",
            angle: .front,
            blockNumber: 4,
            source: .manual
        )

        try? await DatabaseService.shared.create(beforePhoto, collection: "progressPhotos", documentId: beforePhoto.id)
        try? await DatabaseService.shared.create(afterPhoto, collection: "progressPhotos", documentId: afterPhoto.id)
    }

    static func clearDevProgress() {
        UserDefaults.standard.removeObject(forKey: gainsKey)
        UserDefaults.standard.removeObject(forKey: badgeKey)
        UserDefaults.standard.removeObject(forKey: sessionXPKey)
        UserDefaults.standard.removeObject(forKey: didBootstrapKey)
        UserDefaults.standard.removeObject(forKey: "unbound.streakDays")
        DevFlags.shared.unlockAllFeatures = false
    }

    private static func resetSkillForProof(skillId: String) async {
        var payload: UserSkillProgress = (try? await DatabaseService.shared.read(
            collection: "skillProgress",
            documentId: userId
        )) ?? .empty(userId: userId)

        payload.skillProgress[skillId] = .starter
        payload.nodeStates[skillId] = .attempting
        payload.lastTrainedAt.removeValue(forKey: skillId)
        payload.masteredAt.removeValue(forKey: skillId)
        payload.updatedAt = Date()

        try? await DatabaseService.shared.create(payload, collection: "skillProgress", documentId: userId)
        await SkillProgressService.shared.load(userId: userId)
    }

    private static func resetActiveGoalsForProof() async {
        var payload: UserSkillProgress = (try? await DatabaseService.shared.read(
            collection: "skillProgress",
            documentId: userId
        )) ?? .empty(userId: userId)

        payload.activeGoalIds = []
        payload.updatedAt = Date()

        try? await DatabaseService.shared.create(payload, collection: "skillProgress", documentId: userId)
        await SkillProgressService.shared.load(userId: userId)
    }

    private static func seedScheduledSkillProof(skillId: String) async {
        guard let node = SkillGraph.shared.node(id: skillId) else { return }

        var payload: UserSkillProgress = (try? await DatabaseService.shared.read(
            collection: "skillProgress",
            documentId: userId
        )) ?? .empty(userId: userId)

        var schedule = payload.weeklySchedule.count == 7
            ? payload.weeklySchedule
            : Array(repeating: nil, count: 7)
        schedule[mondayZeroIndex(for: Date())] = category(for: node.cluster)

        payload.activeGoalIds = [skillId]
        payload.bookmarkedNodeIds.insert(skillId)
        payload.weeklySchedule = schedule
        payload.lastTrainedAt.removeValue(forKey: skillId)
        payload.updatedAt = Date()

        try? await DatabaseService.shared.create(payload, collection: "skillProgress", documentId: userId)
        await resetSkillForProof(skillId: skillId)
    }

    private static func mondayZeroIndex(for date: Date) -> Int {
        let weekday = Calendar(identifier: .iso8601).component(.weekday, from: date)
        switch weekday {
        case 2: return 0
        case 3: return 1
        case 4: return 2
        case 5: return 3
        case 6: return 4
        case 7: return 5
        case 1: return 6
        default: return 0
        }
    }

    private static func category(for cluster: SkillCluster) -> DayCategory {
        switch cluster {
        case .calisthenicControl: return .push
        case .pullingPower: return .pull
        case .legDominance: return .legs
        case .coreLever: return .core
        case .handstand: return .skills
        case .handstandPushup: return .push
        case .oneArmHandstand: return .skills
        case .planche: return .skills
        case .conditioning: return .conditioning
        }
    }

    private static func launchArgumentValue(for key: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        for (index, argument) in arguments.enumerated() {
            if argument == key, arguments.indices.contains(index + 1) {
                return arguments[index + 1]
            }
            if argument.hasPrefix("\(key)=") {
                return String(argument.dropFirst(key.count + 1))
            }
        }
        return nil
    }

}
#endif

// MARK: - FAQ Placeholder

private struct FAQPlaceholderView: View {
    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()
            Text("FAQ coming soon")
                .font(.bodyText(16))
                .foregroundColor(.theme.textSecondary)
        }
        .navigationTitle("FAQ")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SettingsView(services: .mock)
            .environmentObject(ServiceContainer.mock)
    }
}
