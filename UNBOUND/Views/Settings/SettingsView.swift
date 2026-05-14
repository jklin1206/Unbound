import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var services: ServiceContainer
    @StateObject private var viewModel: SettingsViewModel
    @State private var showDeleteAccount = false

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
                    Label("Coach actions", systemImage: "sparkles")
                        .foregroundColor(.theme.textPrimary)
                }
                NavigationLink {
                    SkinPickerView()
                        .environmentObject(services)
                } label: {
                    Label("Skill tree skin", systemImage: "paintpalette")
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
                Text("Tell us which exercises you like, substitute, or avoid. We'll tune your program around it.")
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

    @State private var selectedRank: RankTitle = .unbound
    @State private var selectedLevel: Int = 25
    @State private var isApplying = false
    @State private var status = "Dev account is local-only and hidden in release builds."

    private var currentUserId: String {
        AuthService.shared.currentUserId ?? DevPlayerSeeder.userId
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
                        run { await DevPlayerSeeder.activate(services: services) }
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

                Picker("Rank Title", selection: $selectedRank) {
                    ForEach(RankTitle.allCases, id: \.rawValue) { title in
                        Text(title.displayName).tag(title)
                    }
                }

                Button {
                    run { await DevPlayerSeeder.applyLevel(selectedLevel) }
                } label: {
                    Label("Apply Level", systemImage: "bolt.badge.checkmark")
                        .foregroundColor(.theme.primary)
                }

                Button {
                    run { await DevPlayerSeeder.applyRank(selectedRank, services: services) }
                } label: {
                    Label("Apply Rank to All Core Lifts", systemImage: "shield.lefthalf.filled")
                        .foregroundColor(.theme.primary)
                }
            } header: {
                Text("Fast Tuning")
                    .foregroundColor(.theme.textSecondary)
            } footer: {
                Text("Rank applies to the core lifts used by the home/profile archetype rank calculations.")
                    .font(.caption(11))
                    .foregroundColor(.theme.textMuted)
            }

            Section {
                Button {
                    run { await DevPlayerSeeder.unlockAllBadges() }
                } label: {
                    Label("Unlock All Badges", systemImage: "rosette")
                        .foregroundColor(.theme.primary)
                }

                Button {
                    run { await DevPlayerSeeder.masterSkillTree() }
                } label: {
                    Label("Master Skill Tree", systemImage: "circle.hexagongrid.fill")
                        .foregroundColor(.theme.primary)
                }

                Button {
                    run { await DevPlayerSeeder.seedSessionStats() }
                } label: {
                    Label("Seed Streak + Session Stats", systemImage: "flame.fill")
                        .foregroundColor(.theme.primary)
                }

                Button {
                    run {
                        await DevPlayerSeeder.maxEverything(
                            rankTitle: selectedRank,
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
                    DevPlayerSeeder.clearDevProgress()
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
private enum DevPlayerSeeder {
    static let userId = "dev-player"

    private static let gainsKey = "unbound.gains"
    private static let badgeKey = "unbound.badges.\(userId)"
    private static let sessionXPKey = "unbound.sessionxp.\(userId)"

    static func activate(services: ServiceContainer) async {
        AuthService.shared.activateDevUser(id: userId)
        DevFlags.shared.unlockAllFeatures = true
        UserDefaults.standard.set(true, forKey: "onboardingCompleted")
        UserDefaults.standard.set(true, forKey: "unbound.calibration.completed")

        var profile = UserProfile(
            id: userId,
            email: "dev@unbound.local",
            displayName: "Dev Player",
            createdAt: Date(),
            onboardingCompleted: true,
            totalScans: 12,
            currentProgramId: nil,
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
        await seedSessionStats()
        await applyLevel(25)
    }

    static func maxEverything(rankTitle: RankTitle, level: Int, services: ServiceContainer) async {
        await activate(services: services)
        await applyLevel(level)
        await applyRank(rankTitle, services: services)
        await unlockAllBadges()
        await masterSkillTree()
        await seedSessionStats()
    }

    static func applyLevel(_ level: Int) async {
        let clamped = max(1, min(80, level))
        UserDefaults.standard.set((clamped - 1) * 250, forKey: gainsKey)
    }

    static func applyRank(_ title: RankTitle, services: ServiceContainer) async {
        AuthService.shared.activateDevUser(id: userId)
        let rank = representativeSubRank(for: title)
        for seed in canonicalLiftSeeds {
            await services.rank.save(
                LiftRank(
                    userId: userId,
                    exerciseKey: seed.key,
                    displayName: seed.name,
                    currentRank: rank,
                    peakRank: rank,
                    lastAdvanceAt: Date(),
                    lastActivityAt: Date()
                )
            )
        }
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
        AuthService.shared.activateDevUser(id: userId)
        var cal = Calendar.current
        cal.firstWeekday = 2
        let weekComponents = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        let weekStart = cal.date(from: weekComponents) ?? cal.startOfDay(for: Date())
        let record = SessionXPRecord(
            userId: userId,
            totalSessions: 96,
            currentStreak: 21,
            longestStreak: 45,
            lastSessionDate: Date(),
            weeklyCount: 5,
            weekStartDate: weekStart
        )
        if let data = try? JSONEncoder.unbound.encode(record) {
            UserDefaults.standard.set(data, forKey: sessionXPKey)
        }
        UserDefaults.standard.set(record.currentStreak, forKey: "unbound.streakDays")
    }

    static func masterSkillTree() async {
        AuthService.shared.activateDevUser(id: userId)
        let now = Date()
        let graph = SkillGraph.shared
        let states = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0.id, NodeState.mastered) })
        let dates = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0.id, now) })
        let progress = Dictionary(uniqueKeysWithValues: graph.nodes.map {
            ($0.id, SkillProgress(currentLevel: 5, xpInLevel: 0, xpToNextLevel: 0))
        })
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
    }

    static func clearDevProgress() {
        UserDefaults.standard.removeObject(forKey: gainsKey)
        UserDefaults.standard.removeObject(forKey: badgeKey)
        UserDefaults.standard.removeObject(forKey: sessionXPKey)
        UserDefaults.standard.removeObject(forKey: "unbound.streakDays")
        DevFlags.shared.unlockAllFeatures = false
    }

    private static func representativeSubRank(for title: RankTitle) -> SubRank {
        switch title {
        case .initiate: return .e
        case .novice: return .dMinus
        case .apprentice: return .dPlus
        case .forged: return .c
        case .veteran: return .bMinus
        case .honed: return .bPlus
        case .vessel: return .a
        case .unbound: return .sMinus
        case .ascendant: return .sPlus
        }
    }

    private static let canonicalLiftSeeds: [(key: String, name: String)] = [
        ("back squat", "Back Squat"),
        ("deadlift", "Deadlift"),
        ("bench press", "Bench Press"),
        ("overhead press", "Overhead Press"),
        ("pullup", "Pull-Up"),
        ("weighted pullup", "Weighted Pull-Up"),
        ("pushup", "Push-Up"),
        ("dip", "Dip"),
        ("l-sit", "L-Sit")
    ]
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
