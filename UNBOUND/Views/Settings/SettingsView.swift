import SwiftUI
import UserNotifications
import UIKit

struct SettingsView: View {
    @EnvironmentObject var services: ServiceContainer
    @StateObject private var viewModel: SettingsViewModel
    @State private var showDeleteAccount = false
    @AppStorage(WeightPlatePolicy.unitDefaultsKey) private var trainingWeightUnitRaw = TrainingWeightUnit.localeDefault.rawValue
    @AppStorage(WeightPlatePolicy.microloadingDefaultsKey) private var microloadingEnabled = false
    @AppStorage(AppConstants.Analytics.usageOptOutKey) private var analyticsOptOut = false

    init(services: ServiceContainer) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(services: services))
    }

    var body: some View {
        List {
            // MARK: Account
            Section {
                HStack {
                    Label(L10n.string(.settingsEmail, defaultValue: "Email"), systemImage: "envelope")
                        .foregroundColor(.theme.textPrimary)
                    Spacer()
                    Text(viewModel.userProfile?.email ?? "—")
                        .font(.bodyText(14))
                        .foregroundColor(.theme.textMuted)
                }

                Button(role: .destructive) {
                    viewModel.signOut()
                } label: {
                    Label(L10n.string(.settingsSignOut, defaultValue: "Sign Out"), systemImage: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.theme.danger)
                }
            } header: {
                Text(L10n.string(.settingsSectionAccount, defaultValue: "Account"))
                    .foregroundColor(.theme.textSecondary)
            }

            // MARK: Subscription
            Section {
                HStack {
                    Label(L10n.string(.settingsPlan, defaultValue: "Plan"), systemImage: "crown")
                        .foregroundColor(.theme.textPrimary)
                    Spacer()
                    Text(viewModel.hasActiveSubscription ? settingsPlanPro : settingsPlanFree)
                        .font(.bodyMedium(14))
                        .foregroundColor(viewModel.hasActiveSubscription ? .theme.primary : .theme.textMuted)
                }

                if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
                    Link(destination: url) {
                        Label(L10n.string(.settingsManageSubscription, defaultValue: "Manage Subscription"), systemImage: "arrow.up.circle")
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
                            Text(L10n.string(.subscriptionRestoreRestoring, defaultValue: "Restoring..."))
                                .foregroundColor(.theme.textSecondary)
                        }
                    } else {
                        Label(L10n.string(.subscriptionRestoreIdle, defaultValue: "Restore Purchases"), systemImage: "arrow.counterclockwise")
                            .foregroundColor(.theme.textPrimary)
                    }
                }
                .disabled(viewModel.isLoading)
            } header: {
                Text(L10n.string(.settingsSectionSubscription, defaultValue: "Subscription"))
                    .foregroundColor(.theme.textSecondary)
            }

            // MARK: Privacy
            Section {
                Toggle(isOn: shareUsageDataBinding) {
                    Label(L10n.string(.settingsShareUsageData, defaultValue: "Share usage data"), systemImage: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.theme.textPrimary)
                }
                .tint(.theme.primary)

                NavigationLink {
                    NotificationSettingsView()
                } label: {
                    Label(L10n.string(.settingsNotifications, defaultValue: "Notifications"), systemImage: "bell.badge")
                        .foregroundColor(.theme.textPrimary)
                }
            } header: {
                Text(L10n.string(.settingsSectionPrivacy, defaultValue: "Privacy"))
                    .foregroundColor(.theme.textSecondary)
            }

            // MARK: Training preferences
            Section {
                Picker(selection: $trainingWeightUnitRaw) {
                    ForEach(TrainingWeightUnit.allCases) { unit in
                        Text(unit.displayName).tag(unit.rawValue)
                    }
                } label: {
                    Label(L10n.string(.settingsWeightUnit, defaultValue: "Weight Unit"), systemImage: "scalemass")
                        .foregroundColor(.theme.textPrimary)
                }

                Toggle(isOn: $microloadingEnabled) {
                    Label(L10n.string(.settingsMicroPlates, defaultValue: "Micro plates"), systemImage: "plus.forwardslash.minus")
                        .foregroundColor(.theme.textPrimary)
                }
                .tint(.theme.primary)

                NavigationLink {
                    ExercisePreferencesView()
                        .environmentObject(services)
                } label: {
                    Label(L10n.string(.settingsExerciseLibrary, defaultValue: "Exercise Library"), systemImage: "list.bullet.rectangle.portrait")
                        .foregroundColor(.theme.textPrimary)
                }
                NavigationLink {
                    EquipmentSettingsView()
                } label: {
                    Label(L10n.string(.settingsEquipment, defaultValue: "Equipment"), systemImage: "dumbbell.fill")
                        .foregroundColor(.theme.textPrimary)
                }
                NavigationLink {
                    CoachActionHistoryView()
                        .environmentObject(services)
                } label: {
                    Label(L10n.string(.settingsPlanChanges, defaultValue: "Plan changes"), systemImage: "arrow.triangle.2.circlepath")
                        .foregroundColor(.theme.textPrimary)
                }
                NavigationLink {
                    BadgeGalleryView()
                        .environmentObject(services)
                } label: {
                    Label(L10n.string(.settingsBadges, defaultValue: "Badges"), systemImage: "rosette")
                        .foregroundColor(.theme.textPrimary)
                }
            } header: {
                Text(L10n.string(.settingsSectionTraining, defaultValue: "Training"))
                    .foregroundColor(.theme.textSecondary)
            } footer: {
                Text(L10n.string(
                    .settingsTrainingFooter,
                    defaultValue: "Your exact logged weights are preserved. UNBOUND rounds suggestions and progression jumps to the selected plate system."
                ))
                    .font(.caption(11))
                    .foregroundColor(.theme.textMuted)
            }

            // MARK: Appearance
            Section {
                NavigationLink {
                    ProfileCosmeticsView()
                        .environmentObject(services)
                } label: {
                    Label(L10n.string(.settingsProfileCosmetics, defaultValue: "Profile cosmetics"), systemImage: "person.crop.circle.badge.sparkles")
                        .foregroundColor(.theme.textPrimary)
                }
                NavigationLink {
                    SkinPickerView()
                        .environmentObject(services)
                } label: {
                    Label(L10n.string(.settingsSkillTreeCosmetics, defaultValue: "Skill tree cosmetics"), systemImage: "paintpalette")
                        .foregroundColor(.theme.textPrimary)
                }
            } header: {
                Text(L10n.string(.settingsSectionAppearance, defaultValue: "Appearance"))
                    .foregroundColor(.theme.textSecondary)
            } footer: {
                Text(L10n.string(.settingsAppearanceFooter, defaultValue: "Equip unlocked profile frames, backdrops, and skill-tree cosmetics."))
                    .font(.caption(11))
                    .foregroundColor(.theme.textMuted)
            }

            // MARK: Support
            Section {
                if let mailURL = URL(string: "mailto:support@unboundapp.com") {
                    Link(destination: mailURL) {
                        Label(L10n.string(.settingsContactUs, defaultValue: "Contact Us"), systemImage: "envelope.badge")
                            .foregroundColor(.theme.textPrimary)
                    }
                }

                NavigationLink {
                    FAQPlaceholderView()
                } label: {
                    Label(L10n.string(.settingsFAQ, defaultValue: "FAQ"), systemImage: "questionmark.circle")
                        .foregroundColor(.theme.textPrimary)
                }
            } header: {
                Text(L10n.string(.settingsSectionSupport, defaultValue: "Support"))
                    .foregroundColor(.theme.textSecondary)
            }

            // MARK: Legal
            Section {
                Link(destination: AppConstants.Legal.termsURL) {
                    Label(L10n.string(.legalTermsOfService, defaultValue: "Terms of Service"), systemImage: "doc.text")
                        .foregroundColor(.theme.textPrimary)
                }

                Link(destination: AppConstants.Legal.privacyURL) {
                    Label(L10n.string(.legalPrivacyPolicy, defaultValue: "Privacy Policy"), systemImage: "hand.raised")
                        .foregroundColor(.theme.textPrimary)
                }
            } header: {
                Text(L10n.string(.settingsSectionLegal, defaultValue: "Legal"))
                    .foregroundColor(.theme.textSecondary)
            }

            // MARK: Danger Zone
            Section {
                Button(role: .destructive) {
                    showDeleteAccount = true
                } label: {
                    Label(L10n.string(.settingsDeleteAccount, defaultValue: "Delete Account"), systemImage: "trash")
                        .foregroundColor(.theme.danger)
                }
            } header: {
                Text(L10n.string(.settingsSectionDangerZone, defaultValue: "Danger Zone"))
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
                .accessibilityIdentifier("settings.devPlayerTools")

                NavigationLink {
                    SkillRankPrototypeDebugView()
                } label: {
                    Label("Skill Rank (Pull prototype)", systemImage: "chart.bar.fill")
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
        .navigationTitle(L10n.string(.settingsTitle, defaultValue: "Settings"))
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(isPresented: $showDeleteAccount) {
            AccountDeletionView(viewModel: viewModel)
        }
        .alert(L10n.string(.settingsAlertError, defaultValue: "Error"), isPresented: .constant(viewModel.errorMessage != nil)) {
            Button(L10n.string(.settingsAlertOK, defaultValue: "OK")) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onAppear {
            Task { await viewModel.loadProfile() }
        }
    }

    private var shareUsageDataBinding: Binding<Bool> {
        Binding(
            get: { !analyticsOptOut },
            set: { isEnabled in
                analyticsOptOut = !isEnabled
                if isEnabled {
                    services.analytics.optIn()
                } else {
                    services.analytics.optOut()
                }
            }
        )
    }

    private var settingsPlanPro: String {
        L10n.string(.settingsPlanPro, defaultValue: "Pro")
    }

    private var settingsPlanFree: String {
        L10n.string(.settingsPlanFree, defaultValue: "Free")
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

struct NotificationSettingsView: View {
    @State private var preferences = NotificationPreferencesStore.shared.load()
    @State private var authorizationLabel = L10n.string(.notificationSettingsChecking, defaultValue: "Checking...")

    private let store = NotificationPreferencesStore.shared

    var body: some View {
        List {
            Section {
                HStack {
                    Label(L10n.string(.notificationSettingsPermission, defaultValue: "Permission"), systemImage: "bell")
                        .foregroundColor(.theme.textPrimary)
                    Spacer()
                    Text(authorizationLabel)
                        .font(.bodyText(14))
                        .foregroundColor(.theme.textMuted)
                }

                Button {
                    Task { await requestAuthorization() }
                } label: {
                    Label(L10n.string(.notificationSettingsAllowNotifications, defaultValue: "Allow Notifications"), systemImage: "checkmark.circle")
                        .foregroundColor(.theme.textPrimary)
                }
            } header: {
                Text(L10n.string(.notificationSettingsSectionSystem, defaultValue: "System"))
                    .foregroundColor(.theme.textSecondary)
            }

            Section {
                Toggle(isOn: binding(
                    get: { $0.workoutReminders.isEnabled },
                    set: { $0.workoutReminders.isEnabled = $1 }
                )) {
                    Label(L10n.string(.notificationSettingsWorkoutReminders, defaultValue: "Workout reminders"), systemImage: "flame.fill")
                        .foregroundColor(.theme.textPrimary)
                }
                .tint(.theme.primary)

                Picker(L10n.string(.notificationSettingsTime, defaultValue: "Time"), selection: binding(
                    get: { $0.workoutReminders.workoutTime ?? .evening },
                    set: { $0.workoutReminders.workoutTime = $1 }
                )) {
                    ForEach(WorkoutTime.allCases) { time in
                        Text(time.displayName).tag(time)
                    }
                }

                ForEach(Weekday.allCases) { day in
                    Toggle(isOn: dayBinding(day)) {
                        Text(day.short)
                            .foregroundColor(.theme.textPrimary)
                    }
                    .tint(.theme.primary)
                }
            } header: {
                Text(L10n.string(.settingsSectionTraining, defaultValue: "Training"))
                    .foregroundColor(.theme.textSecondary)
            }

            Section {
                Toggle(isOn: binding(
                    get: { $0.retentionNudges.isEnabled },
                    set: { $0.retentionNudges.isEnabled = $1 }
                )) {
                    Label(L10n.string(.notificationSettingsRescanNudge, defaultValue: "Rescan nudge"), systemImage: "calendar.badge.clock")
                        .foregroundColor(.theme.textPrimary)
                }
                .tint(.theme.primary)

                Stepper(value: binding(
                    get: { $0.retentionNudges.daysAfterAnchor },
                    set: { $0.retentionNudges.daysAfterAnchor = max(1, $1) }
                ), in: 1...90) {
                    HStack {
                        Text(L10n.string(.notificationSettingsDaysAfterScan, defaultValue: "Days after scan"))
                            .foregroundColor(.theme.textPrimary)
                        Spacer()
                        Text("\(preferences.retentionNudges.daysAfterAnchor)")
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .foregroundColor(.theme.primary)
                    }
                }
            } header: {
                Text(L10n.string(.notificationSettingsSectionProgress, defaultValue: "Progress"))
                    .foregroundColor(.theme.textSecondary)
            }

            Section {
                Toggle(isOn: binding(
                    get: { $0.milestones.isEnabled },
                    set: { $0.milestones.isEnabled = $1 }
                )) {
                    Label(L10n.string(.notificationSettingsMilestones, defaultValue: "Milestones"), systemImage: "rosette")
                        .foregroundColor(.theme.textPrimary)
                }
                .tint(.theme.primary)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.theme.background)
        .navigationTitle(L10n.string(.settingsNotifications, defaultValue: "Notifications"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            preferences = store.load()
            Task { await refreshAuthorizationLabel() }
        }
    }

    private func binding<Value>(
        get: @escaping (NotificationPreferences) -> Value,
        set: @escaping (inout NotificationPreferences, Value) -> Void
    ) -> Binding<Value> {
        Binding(
            get: { get(preferences) },
            set: { value in
                update { preferences in
                    set(&preferences, value)
                }
            }
        )
    }

    private func dayBinding(_ day: Weekday) -> Binding<Bool> {
        Binding(
            get: { preferences.workoutReminders.trainingDays.contains(day) },
            set: { isEnabled in
                update { preferences in
                    if isEnabled {
                        preferences.workoutReminders.trainingDays.insert(day)
                    } else {
                        preferences.workoutReminders.trainingDays.remove(day)
                    }
                }
            }
        )
    }

    private func update(_ mutate: (inout NotificationPreferences) -> Void) {
        var updated = preferences
        mutate(&updated)
        updated.updatedAt = Date()
        preferences = updated
        store.save(updated)
        Task { await NotificationService.applyStoredPreferences() }
    }

    private func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        await refreshAuthorizationLabel()
        await NotificationService.applyStoredPreferences()
    }

    private func refreshAuthorizationLabel() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run {
            authorizationLabel = settings.authorizationStatus.settingsLabel
        }
    }
}

private extension UNAuthorizationStatus {
    var settingsLabel: String {
        switch self {
        case .authorized:
            return L10n.string(.notificationAuthorizationAllowed, defaultValue: "Allowed")
        case .provisional:
            return L10n.string(.notificationAuthorizationProvisional, defaultValue: "Provisional")
        case .ephemeral:
            return L10n.string(.notificationAuthorizationTemporary, defaultValue: "Temporary")
        case .denied:
            return L10n.string(.notificationAuthorizationDenied, defaultValue: "Denied")
        case .notDetermined:
            return L10n.string(.notificationAuthorizationNotAsked, defaultValue: "Not asked")
        @unknown default:
            return L10n.string(.notificationAuthorizationUnknown, defaultValue: "Unknown")
        }
    }
}

#if DEBUG
private struct DevPlayerToolsView: View {
    @EnvironmentObject private var services: ServiceContainer

    @State private var selectedLevel: Int = 25
    @State private var selectedRank: SkillTier = .ascendant
    @State private var selectedRankTrialTarget: RankTitle = .novice
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
    @State private var devSandboxSnapshot = DevProgramScanSnapshot.empty
    @State private var notificationCategory: ContentNotificationPreset.Category = .streak
    @State private var notificationPresetId: String = ContentNotificationCatalog.streak.first?.id ?? ""
    @State private var notificationDelaySeconds: Double = 3

    private var currentUserId: String {
        AuthService.shared.currentUserId ?? DevBuildBootstrapper.userId
    }

    private static var rankTrialTargets: [RankTitle] {
        OverallRankTrialDefinitions.all.map(\.targetRank)
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

            programScanSection

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
                Picker("Trial Target", selection: $selectedRankTrialTarget) {
                    ForEach(Self.rankTrialTargets, id: \.self) { rank in
                        Text(rank.displayName).tag(rank)
                    }
                }

                Button {
                    let target = selectedRankTrialTarget
                    run(successMessage: "\(target.displayName) rank trial is ready for Dev Player.") {
                        await DevBuildBootstrapper.seedOverallRankTrialReadyProof(targetRankRawValue: target.token)
                    }
                } label: {
                    Label("Make Rank Trial Ready", systemImage: "flag.checkered")
                        .foregroundColor(.theme.primary)
                }
            } header: {
                Text("Rank Trial")
                    .foregroundColor(.theme.textSecondary)
            } footer: {
                Text("Sets the dev player's prior overall rank, level, movement XP, skill tiers, attributes, and compatible equipment so the selected rank gate unlocks.")
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

            notificationPreviewSection

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

    private var notificationPreviewSection: some View {
        let presets = ContentNotificationCatalog.presets(in: notificationCategory)
        let selectedPreset = ContentNotificationCatalog.preset(id: notificationPresetId)
            ?? presets.first
            ?? ContentNotificationCatalog.all[0]

        return Section {
            Picker("Category", selection: $notificationCategory) {
                ForEach(ContentNotificationPreset.Category.allCases) { category in
                    Text(category.displayName).tag(category)
                }
            }
            .onChange(of: notificationCategory) { _, newValue in
                let scoped = ContentNotificationCatalog.presets(in: newValue)
                if !scoped.contains(where: { $0.id == notificationPresetId }) {
                    notificationPresetId = scoped.first?.id ?? ""
                }
            }

            Picker("Message", selection: $notificationPresetId) {
                ForEach(presets) { preset in
                    Text(preset.title).tag(preset.id)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(selectedPreset.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.theme.textPrimary)
                Text(selectedPreset.body)
                    .font(.caption(13))
                    .foregroundColor(.theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Label("Delay", systemImage: "timer")
                        .foregroundColor(.theme.textPrimary)
                    Spacer()
                    Text("\(Int(notificationDelaySeconds.rounded()))s")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(.theme.primary)
                }
                Slider(value: $notificationDelaySeconds, in: 1...15, step: 1)
                    .tint(Color.unbound.accent)
            }

            Button {
                fireNotificationPreview(preset: selectedPreset)
            } label: {
                Label("Send to Lock Screen", systemImage: "bell.badge.fill")
                    .foregroundColor(.theme.primary)
            }
            .accessibilityIdentifier("dev.notification.fire")
        } header: {
            Text("Notification Preview")
                .foregroundColor(.theme.textSecondary)
        } footer: {
            Text("Fires the selected message after the chosen delay. Lock the device before the timer runs out to capture the lock-screen pop for content carousels.")
                .font(.caption(11))
                .foregroundColor(.theme.textMuted)
        }
    }

    private func fireNotificationPreview(preset: ContentNotificationPreset) {
        let delay = max(1, Int(notificationDelaySeconds.rounded()))
        status = "Permission check…"
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            if settings.authorizationStatus == .notDetermined {
                _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
            }
            let content = UNMutableNotificationContent()
            content.title = preset.title
            content.body = preset.body
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(delay), repeats: false)
            let identifier = "com.unbound.devpreview.\(preset.id).\(Int(Date().timeIntervalSince1970))"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            do {
                try await center.add(request)
                await MainActor.run {
                    status = "Notification queued. Lock your screen now — fires in \(delay)s."
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    status = "Failed to schedule notification: \(error.localizedDescription)"
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }

    private var programScanSection: some View {
        Section {
            DevProgramScanSnapshotCard(snapshot: devSandboxSnapshot)

            Button {
                run(successMessage: "Seeded Arc Day 1 with fresh scan history.") {
                    await DevBuildBootstrapper.seedProgramScanSandbox(services: services, state: .arcDay1)
                }
            } label: {
                Label("Seed Arc Day 1", systemImage: "calendar.badge.plus")
                    .foregroundColor(.theme.primary)
            }
            .accessibilityIdentifier("dev.program.seedArcDay1")

            Button {
                run(successMessage: "Forced Wave 2 today. Program now opens on Arc day 15.") {
                    await DevBuildBootstrapper.seedProgramScanSandbox(services: services, state: .wave2)
                }
            } label: {
                Label("Force Wave 2 Today", systemImage: "waveform.path.ecg")
                    .foregroundColor(.theme.primary)
            }
            .accessibilityIdentifier("dev.program.forceWave2")

            Button {
                run(successMessage: "Forced checkpoint due. Program should show block-complete actions.") {
                    await DevBuildBootstrapper.seedProgramScanSandbox(services: services, state: .checkpointDue)
                }
            } label: {
                Label("Force Checkpoint Due", systemImage: "flag.checkered")
                    .foregroundColor(.theme.primary)
            }
            .accessibilityIdentifier("dev.program.forceCheckpointDue")

            Button {
                run(successMessage: "Seeded scan history and made the monthly scan window due.") {
                    await DevBuildBootstrapper.seedScanHistory(daysAgo: 31)
                }
            } label: {
                Label("Seed Scan Due History", systemImage: "camera.viewfinder")
                    .foregroundColor(.theme.primary)
            }
            .accessibilityIdentifier("dev.scan.seedDueHistory")

            Button {
                run(successMessage: "Locked the scan window to today so cadence copy can be checked.") {
                    await DevBuildBootstrapper.seedScanHistory(daysAgo: 0)
                }
            } label: {
                Label("Lock Scan Window", systemImage: "lock.fill")
                    .foregroundColor(.theme.primary)
            }
            .accessibilityIdentifier("dev.scan.lockWindow")

            Button {
                run(successMessage: "Regenerated a deterministic program from the current dev onboarding profile.") {
                    await DevBuildBootstrapper.regenerateProgramFromDevProfile()
                }
            } label: {
                Label("Regenerate From Dev Profile", systemImage: "arrow.triangle.2.circlepath")
                    .foregroundColor(.theme.primary)
            }
            .accessibilityIdentifier("dev.program.regenerateFromProfile")
        } header: {
            Text("Program + Scan Sandbox")
                .foregroundColor(.theme.textSecondary)
        } footer: {
            Text("Seeds real local program, workout log, progress photo, scan checkpoint, and scan-delta records. Launch args: --unbound-dev-program-sandbox arc-day-1|wave-2|checkpoint-due, --unbound-dev-scan due|locked.")
                .font(.caption(11))
                .foregroundColor(.theme.textMuted)
        }
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
        case .vitality: return "heart.fill"
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
            (key, Double(profile.value(for: key).level))
        })
        selectedRankTrialTarget = OverallRankTrialDefinitions.nextTrial(
            after: OverallRankTrialStore.shared.load(userId: currentUserId).currentRank
        )?.targetRank ?? .novice
        devSandboxSnapshot = DevBuildBootstrapper.programScanSnapshot()
    }

    private func run(
        successMessage: String = "Applied. Pull to refresh or switch tabs if a visible screen was already loaded.",
        _ action: @escaping () async -> Void
    ) {
        isApplying = true
        status = "Applying..."
        Task {
            await action()
            await MainActor.run {
                isApplying = false
                status = successMessage
                loadDevControlValues()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }
}

enum DevProgramSandboxState: String, CaseIterable, Identifiable {
    case arcDay1 = "arc-day-1"
    case wave2 = "wave-2"
    case checkpointDue = "checkpoint-due"

    var id: String { rawValue }

    var startOffsetDays: Int {
        switch self {
        case .arcDay1: return 0
        case .wave2: return -14
        case .checkpointDue: return -29
        }
    }

    var scanDaysAgo: Int {
        switch self {
        case .arcDay1: return 31
        case .wave2: return 16
        case .checkpointDue: return 31
        }
    }

    var arcState: ArcState {
        switch self {
        case .arcDay1, .wave2: return .active
        case .checkpointDue: return .checkpointDue
        }
    }

    var completedDayCount: Int {
        switch self {
        case .arcDay1: return 0
        case .wave2: return 8
        case .checkpointDue: return 18
        }
    }
}

struct DevProgramScanSnapshot: Equatable {
    var programName: String
    var arcStatus: String
    var workoutDays: Int
    var requiredEquipment: String
    var scanStatus: String
    var checkpointCount: Int
    var lastScan: String

    static let empty = DevProgramScanSnapshot(
        programName: "No local program",
        arcStatus: "No active Arc",
        workoutDays: 0,
        requiredEquipment: "None",
        scanStatus: "No scan history",
        checkpointCount: 0,
        lastScan: "Never"
    )
}

private struct DevProgramScanSnapshotCard: View {
    let snapshot: DevProgramScanSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "stethoscope")
                    .foregroundColor(.theme.primary)
                Text("Current Sandbox")
                    .font(.caption(12).weight(.semibold))
                    .foregroundColor(.theme.textSecondary)
                Spacer()
            }

            Text(snapshot.programName)
                .font(.bodyText(15))
                .foregroundColor(.theme.textPrimary)
                .lineLimit(2)

            VStack(alignment: .leading, spacing: 6) {
                snapshotLine("Arc", snapshot.arcStatus)
                snapshotLine("Workouts", "\(snapshot.workoutDays) training days")
                snapshotLine("Equipment", snapshot.requiredEquipment)
                snapshotLine("Scans", "\(snapshot.checkpointCount) checkpoints · \(snapshot.lastScan)")
                snapshotLine("Window", snapshot.scanStatus)
            }
        }
        .padding(.vertical, 6)
        .accessibilityIdentifier("dev.programScan.snapshot")
    }

    private func snapshotLine(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.theme.textMuted)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.caption(12))
                .foregroundColor(.theme.textSecondary)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
    }
}

@MainActor
enum DevBuildBootstrapper {
    static let userId = "dev-player"
    static let devLiftNames = ["bench press", "back squat", "deadlift", "overhead press"]

    private static let badgeKey = "unbound.badges.\(userId)"
    private static let sessionXPKey = "unbound.sessionxp.\(userId)"
    private static let didBootstrapKey = "unbound.dev.didBootstrapEverything"
    private static let resetOpenedSkillForProofArg = "--unbound-reset-opened-skill-for-proof"
    private static let resetActiveGoalsForProofArg = "--unbound-reset-active-goals-for-proof"
    private static let scheduledSkillProofArg = "--unbound-proof-scheduled-skill"
    private static let rankTrialReadyProofArg = "--unbound-proof-rank-trial-ready"
    private static let programStateProofArg = "--unbound-proof-program-state"
    private static let programSurfaceProofArg = "--unbound-proof-program-surface"
    private static let devProgramSandboxArg = "--unbound-dev-program-sandbox"
    private static let devScanSandboxArg = "--unbound-dev-scan"
    private static let squadRosterProofArg = "--unbound-seed-squad-roster"
    private static let squadActivityProofArg = "--unbound-proof-squad-activity"

    static func ensureReady() async {
        AuthService.shared.activateDevUser(id: userId)
        DevFlags.shared.unlockAllFeatures = true

        await maxEverything(
            level: 42,
            services: ServiceContainer(),
            completeOnboarding: shouldCompleteOnboardingForDevLaunch
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
        if let rawSandboxState = launchArgumentValue(for: devProgramSandboxArg),
           let sandboxState = DevProgramSandboxState(rawValue: rawSandboxState) {
            await seedProgramScanSandbox(services: ServiceContainer(), state: sandboxState)
        }
        if let rawScanState = launchArgumentValue(for: devScanSandboxArg) {
            let normalized = rawScanState.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            await seedScanHistory(daysAgo: normalized == "locked" ? 0 : 31)
        }
        if shouldSeedBindingVowForProof {
            await seedBindingVowForProof()
        }
        if ProcessInfo.processInfo.arguments.contains(squadRosterProofArg) {
            await seedSquadRosterForProof()
        }
        if ProcessInfo.processInfo.arguments.contains(squadActivityProofArg) {
            await seedSquadActivityProof()
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
            || arguments.contains(where: { $0 == devProgramSandboxArg || $0.hasPrefix("\(devProgramSandboxArg)=") })
            || arguments.contains(where: { $0 == devScanSandboxArg || $0.hasPrefix("\(devScanSandboxArg)=") })
            || arguments.contains(squadActivityProofArg)
    }

    private static var shouldCompleteOnboardingForDevLaunch: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-OnboardingStep") || arguments.contains("--onboarding-step") {
            return false
        }
        return true
    }

    private static var rankTrialProofTargetArgument: String? {
        if let targetRank = launchArgumentValue(for: rankTrialReadyProofArg) {
            return targetRank
        }
        return ProcessInfo.processInfo.arguments.contains(rankTrialReadyProofArg)
            ? RankTitle.novice.token
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
        let progress = OverallLevelProgress(
            userId: userId,
            totalXP: OverallLevelCurve.xpRequired(forLevel: clamped)
        )
        try? await DatabaseService.shared.create(
            progress,
            collection: "overall_level_progress",
            documentId: userId
        )
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
            result[node.id] = .proven
        }
        let dates = graph.nodes.reduce(into: [String: Date]()) { result, node in
            result[node.id] = now
        }
        let activeGoals = Set(graph.nodes.filter { !$0.isMythic }.prefix(6).map(\.id))
        let schedule: [DayCategory?] = [.push, .pull, .legs, .core, .skills, .conditioning, .rest]

        let payload = UserSkillProgress(
            userId: userId,
            nodeStates: states,
            provenAt: dates,
            updatedAt: now,
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

    static func seedSquadRosterForProof() async {
        AuthService.shared.activateDevUser(id: userId)

        let joinerUserId = "dev-player-two"
        try? await SquadService.shared.leaveSquad(userId: joinerUserId)
        await SquadService.shared.loadCurrentSquad(userId: userId)

        let squad: Squad
        if let existing = SquadService.shared.state(userId: userId).currentSquad {
            squad = existing
        } else if let created = try? await SquadService.shared.createSquad(name: "Codex Crew", userId: userId) {
            squad = created
        } else {
            return
        }

        _ = try? await SquadService.shared.joinSquad(inviteCode: squad.inviteCode, userId: joinerUserId)
        await SquadService.shared.loadCurrentSquad(userId: userId)
    }

    static func seedSquadActivityProof() async {
        AuthService.shared.activateDevUser(id: userId)
        await seedSquadRosterForProof()

        let partnerUserId = "dev-player-two"
        guard let userUUID = SquadUserIdentity.uuid(from: userId),
              let partnerUUID = SquadUserIdentity.uuid(from: partnerUserId)
        else { return }

        await SquadService.shared.loadCurrentSquad(userId: userId)
        guard let loadedSquad = SquadService.shared.state(userId: userId).currentSquad else { return }
        LocalSquadDirectory.shared.updateStreakWeeks(squadId: loadedSquad.id, weeks: 6)
        await SquadService.shared.loadCurrentSquad(userId: userId)

        guard let squad = SquadService.shared.state(userId: userId).currentSquad else { return }
        let existingChallenge = await FriendChallengeService.shared
            .activeChallenges(userId: userUUID)
            .first { $0.squadId == squad.id && $0.kind == .mostSessions }

        let challenge: FriendChallenge
        if let existingChallenge {
            challenge = existingChallenge
        } else if let created = try? await FriendChallengeService.shared.createChallenge(
            challengedId: partnerUUID,
            kind: .mostSessions,
            squadId: squad.id
        ) {
            challenge = created
        } else {
            return
        }

        try? await FriendChallengeService.shared.accept(challenge.id)
        for offset in 0..<3 {
            await FriendChallengeService.shared.recordProgress(
                log: proofWorkoutLog(userId: userId, dayOffset: offset),
                userId: userId
            )
        }
        for offset in 0..<2 {
            await FriendChallengeService.shared.recordProgress(
                log: proofWorkoutLog(userId: partnerUserId, dayOffset: offset + 3),
                userId: partnerUserId
            )
        }

        let now = Date()
        var state = SquadService.shared.state(userId: userId)
        state.currentSquad = squad
        state.recentActivity = [
            SquadActivityEntry(
                id: UUID(),
                squadId: squad.id,
                userId: nil,
                kind: .squadStreakExtended,
                payload: .squadStreakExtended(weeks: 6),
                createdAt: now.addingTimeInterval(-60)
            ),
            SquadActivityEntry(
                id: UUID(),
                squadId: squad.id,
                userId: userUUID,
                kind: .linkedSession,
                payload: .linkedSession(participantUserIds: [userUUID, partnerUUID], durationMinutes: 44),
                createdAt: now.addingTimeInterval(-150)
            ),
            SquadActivityEntry(
                id: UUID(),
                squadId: squad.id,
                userId: userUUID,
                kind: .trialCompleted,
                payload: .trialCompleted(trialName: "Upper Body Power", theme: .axis(.power)),
                createdAt: now.addingTimeInterval(-260)
            ),
            SquadActivityEntry(
                id: UUID(),
                squadId: squad.id,
                userId: partnerUUID,
                kind: .trialCompleted,
                payload: .trialCompleted(trialName: "Mobility Reset", theme: .axis(.mobility)),
                createdAt: now.addingTimeInterval(-420)
            ),
            SquadActivityEntry(
                id: UUID(),
                squadId: squad.id,
                userId: partnerUUID,
                kind: .memberJoined,
                payload: .memberJoined(memberDisplayName: "Crewmate 2"),
                createdAt: now.addingTimeInterval(-620)
            )
        ]
        SquadStore.shared.save(state, userId: userId)
        NotificationCenter.default.post(name: .squadStateChanged, object: nil)
    }

    private static func proofWorkoutLog(userId: String, dayOffset: Int) -> WorkoutLog {
        let completedAt = Calendar.current.date(
            byAdding: .day,
            value: -dayOffset,
            to: Date()
        ) ?? Date()
        let startedAt = completedAt.addingTimeInterval(-44 * 60)
        return WorkoutLog(
            id: "squad-proof-\(userId)-\(dayOffset)",
            userId: userId,
            programId: "squad-proof-program",
            dayNumber: max(1, dayOffset + 1),
            plannedWorkoutName: "Squad Proof Session",
            startedAt: startedAt,
            completedAt: completedAt,
            exerciseEntries: [],
            overallNotes: "Simulator proof session",
            overallRPE: 7,
            durationMinutes: 44
        )
    }

    static func seedAttributes() {
        applyAttributes([
            .power: 88,
            .explosiveness: 78,
            .control: 82,
            .vitality: 66,
            .mobility: 60,
            .endurance: 74
        ])
    }

    static func applyAttributes(_ values: [AttributeKey: Double]) {
        let now = Date()
        var profile = AttributeProfile.empty(userId: userId, at: now)
        for key in AttributeKey.allCases {
            // Dev slider value == target LEVEL; back into the xp that lands there.
            let level = Int(min(100, max(0, values[key] ?? 0)).rounded())
            profile.set(
                key,
                AttributeValue(xp: AttributeLevelCurve.xpRequired(forLevel: level), lastContributionAt: now)
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
            programId: "dev-profile",
            dayNumber: 0,
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

    /// Dev seeder bodyweight (matches the seeded Dev Player profile).
    private static let devBodyweightKg: Double = 82

    private static func liftTier(for lift: String, weightKg: Double) -> SkillTier {
        StrengthStandards.rank(
            liftKg: weightKg,
            bodyweightKg: devBodyweightKg,
            exerciseKey: lift,
            sex: .male
        ) ?? .initiate
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

    static func seedOverallRankTrialReadyProof(targetRankRawValue: String = RankTitle.novice.token) async {
        AuthService.shared.activateDevUser(id: userId)
        let now = Date()
        let targetRank = RankTier.fromToken(targetRankRawValue)
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

        // Phase 7: eligibility = aggregateRank >= targetRank. Seed all four
        // tracked lifts at the target tier (clears the ≥4-movement coverage
        // floor and lands the weighted mean on the target), with fresh,
        // mid-level attributes so freshness stays at 1.0.
        seedLiftTiers(tier: definition.targetRank)
        applyAttributes(
            Dictionary(uniqueKeysWithValues: AttributeKey.allCases.map { key in (key, 50.0) })
        )
    }

    private static func sourceRank(before targetRank: RankTitle) -> RankTitle {
        switch targetRank {
        case .novice: return .initiate
        case .apprentice: return .novice
        case .forged: return .apprentice
        case .veteran: return .forged
        case .master: return .veteran
        case .vessel: return .master
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
        case .master: return 4
        case .vessel: return 5
        case .unbound: return 6
        case .ascendant: return 7
        }
    }

    static func seedProgram(
        startDate: Date = Date(),
        arcState: ArcState = .active
    ) async {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: startDate)
        let workouts: [Workout] = [
            Workout(
                name: "Push Strength",
                targetMuscleGroups: [.chest, .shoulders, .arms],
                warmup: [],
                mainExercises: [
                    Exercise(id: "dev-bench", name: "Barbell Bench Press", muscleGroups: [.chest, .shoulders, .arms], sets: 4, reps: "4-6", restSeconds: 180, rpe: 8, notes: "Pause the first rep. Stop one rep before grind.", substitution: "Dumbbell Bench Press"),
                    Exercise(id: "dev-incline-db", name: "Incline Dumbbell Press", muscleGroups: [.chest, .shoulders, .arms], sets: 3, reps: "8-10", restSeconds: 120, rpe: 8, notes: nil, substitution: "Push-Up"),
                    Exercise(id: "dev-ohp", name: "Overhead Press", muscleGroups: [.shoulders, .arms], sets: 3, reps: "5-7", restSeconds: 150, rpe: 8, notes: nil, substitution: "Dumbbell OHP")
                ],
                cooldown: [],
                estimatedMinutes: 55,
                notes: "Debug seeded push session.",
                blockType: .intensification
            ),
            Workout(
                name: "Lower Output",
                targetMuscleGroups: [.legs, .glutes, .core],
                warmup: [],
                mainExercises: [
                    Exercise(id: "dev-squat", name: "Back Squat", muscleGroups: [.legs, .glutes, .core], sets: 4, reps: "3-5", restSeconds: 180, rpe: 8, notes: nil, substitution: nil),
                    Exercise(id: "dev-rdl", name: "Romanian Deadlift", muscleGroups: [.legs, .glutes, .back], sets: 3, reps: "6-8", restSeconds: 150, rpe: 8, notes: nil, substitution: nil),
                    Exercise(id: "dev-split-squat", name: "Bulgarian Split Squat", muscleGroups: [.legs, .glutes], sets: 3, reps: "8-10", restSeconds: 90, rpe: 8, notes: nil, substitution: "Reverse Lunge")
                ],
                cooldown: [],
                estimatedMinutes: 60,
                notes: "Debug seeded lower session.",
                blockType: .intensification
            ),
            Workout(
                name: "Pull Volume",
                targetMuscleGroups: [.back, .lats, .arms],
                warmup: [],
                mainExercises: [
                    Exercise(id: "dev-pullup", name: "Pull-Up", muscleGroups: [.back, .lats, .arms], sets: 4, reps: "6-10", restSeconds: 120, rpe: 8, notes: nil, substitution: "Lat Pulldown"),
                    Exercise(id: "dev-row", name: "Chest-Supported Row", muscleGroups: [.back, .lats, .arms], sets: 4, reps: "8-12", restSeconds: 120, rpe: 8, notes: nil, substitution: "One-Arm Dumbbell Row"),
                    Exercise(id: "dev-face-pull", name: "Face Pull", muscleGroups: [.shoulders, .traps], sets: 3, reps: "12-15", restSeconds: 75, rpe: 7, notes: nil, substitution: "Band Pull-Apart")
                ],
                cooldown: [],
                estimatedMinutes: 50,
                notes: "Debug seeded pull session.",
                blockType: .accumulation
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
                notes: "Debug seeded skill-control session.",
                blockType: .accumulation
            ),
            Workout(
                name: "Full Body Engine",
                targetMuscleGroups: [.legs, .glutes, .back, .shoulders, .forearms],
                warmup: [],
                mainExercises: [
                    Exercise(id: "dev-deadlift", name: "Deadlift", muscleGroups: [.legs, .glutes, .back, .traps], sets: 3, reps: "3-5", restSeconds: 180, rpe: 8, notes: "Leave one clean rep in reserve.", substitution: "Trap Bar Deadlift"),
                    Exercise(id: "dev-push-press", name: "Dumbbell Push Press", muscleGroups: [.shoulders, .arms, .legs], sets: 3, reps: "6-8", restSeconds: 120, rpe: 8, notes: nil, substitution: "Landmine Press"),
                    Exercise(id: "dev-farmer", name: "Farmer Carry", muscleGroups: [.forearms, .traps, .core], sets: 4, reps: "40m", restSeconds: 90, rpe: 8, notes: nil, substitution: "Suitcase Carry")
                ],
                cooldown: [],
                estimatedMinutes: 55,
                notes: "Debug seeded full-body session.",
                blockType: .intensification
            )
        ]

        let weeklyPlan: [(label: String, role: SessionRole, workoutIndex: Int?)] = [
            ("Push Strength", .pushHorizontal, 0),
            ("Lower Output", .squatFocus, 1),
            ("Pull Volume", .pull, 2),
            ("Recovery", .rest, nil),
            ("Skill Control", .skillOnly, 3),
            ("Full Body Engine", .fullBody, 4),
            ("Recovery", .rest, nil)
        ]

        let days = (1...Arc.durationDays).map { day in
            let plan = weeklyPlan[(day - 1) % weeklyPlan.count]
            let isRest = plan.workoutIndex == nil
            let wave = day <= Arc.waveLengthDays ? "Wave 1" : "Wave 2"
            let workout = plan.workoutIndex.map { index -> Workout in
                var copy = workouts[index]
                if day > Arc.waveLengthDays {
                    copy.blockType = .intensification
                    copy.notes = "Wave 2 debug session: same pattern, slightly higher intent."
                }
                return copy
            }
            return ProgramDay(
                id: "dev-day-\(day)",
                dayNumber: day,
                label: isRest ? "Recovery" : "\(wave) · \(plan.label)",
                isRestDay: isRest,
                workout: workout,
                sessionRole: plan.role,
                nutritionOverride: nil,
                recoveryActivities: isRest ? [
                    RecoveryActivity(id: "dev-recovery-\(day)", name: "Walk + Mobility", description: "Zone 2 walk with hip and shoulder range work.", durationMinutes: 30, frequency: "Today")
                ] : []
            )
        }

        let arc = Arc(
            id: "dev-arc-1",
            programId: "dev-program",
            startDate: startDate,
            state: arcState
        )
        let program = TrainingProgram(
            id: "dev-program",
            scanId: "dev-scan",
            analysisId: "dev-analysis",
            userId: userId,
            createdAt: startDate,
            name: "Dev Ascension Block",
            description: "Seeded 28-day debug Arc with strength, skill, recovery, scan, and nutrition surfaces populated.",
            durationDays: Arc.durationDays,
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
            requiredEquipment: ["Barbell", "Dumbbells", "Bench", "Pullup Bar", "Cable or Band"],
            estimatedDailyMinutes: 55,
            rationale: nil,
            arcs: [arc],
            currentArcId: arc.id
        )

        let block = ProgramBlock(
            id: "dev-program-block-1",
            userId: userId,
            programId: program.id,
            blockNumber: 1,
            startedAt: startDate,
            endedAt: arcState == .checkpointDue ? arc.endDate : nil,
            scanId: "dev-scan-latest",
            accessoryBias: [.shoulders: 2, .lats: 2, .glutes: 1],
            cutModeActive: false,
            biasRefreshedFromPrevious: false,
            exerciseRotationsThisBlock: ["Barbell Bench Press", "Back Squat", "Pull-Up"]
        )

        try? await DatabaseService.shared.create(program, collection: "programs", documentId: program.id)
        await ProgramStore.shared.save(program, userId: userId)
        try? await DatabaseService.shared.update(["currentProgramId": program.id], collection: "users", documentId: userId)
        await ProgramBlockStore.shared.save(block)
    }

    static func seedProgramScanSandbox(
        services: ServiceContainer,
        state: DevProgramSandboxState
    ) async {
        await activate(services: services, completeOnboarding: true)
        let calendar = Calendar.current
        let start = calendar.date(
            byAdding: .day,
            value: state.startOffsetDays,
            to: calendar.startOfDay(for: Date())
        ) ?? Date()
        await seedProgram(startDate: start, arcState: state.arcState)
        await seedWorkoutLogs(
            programStartDate: start,
            completedDayNumbers: completedTrainingDays(count: state.completedDayCount)
        )
        await seedScanHistory(daysAgo: state.scanDaysAgo)
    }

    static func seedScanHistory(daysAgo: Int) async {
        AuthService.shared.activateDevUser(id: userId)
        UserDefaults.standard.set(true, forKey: "unbound.scanConsentGranted")

        let now = Date()
        let safeDaysAgo = max(0, daysAgo)
        let latestDate = Calendar.current.date(byAdding: .day, value: -safeDaysAgo, to: now) ?? now
        let baselineDate = Calendar.current.date(byAdding: .day, value: -60, to: latestDate) ?? latestDate.addingTimeInterval(-60 * 86_400)

        let before = devProgressImage(named: "DevProgressBefore", fallbackColor: UIColor(red: 0.06, green: 0.10, blue: 0.13, alpha: 1))
        let after = devProgressImage(named: "DevProgressAfter", fallbackColor: UIColor(red: 0.02, green: 0.23, blue: 0.26, alpha: 1))

        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let scanPhotoDir = docs.appendingPathComponent("scan-photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: scanPhotoDir, withIntermediateDirectories: true)

        let baselineFilename = "dev-scan-baseline-front.jpg"
        let latestFilename = "dev-scan-latest-front.jpg"
        let baselineURL = scanPhotoDir.appendingPathComponent(baselineFilename)
        let latestURL = scanPhotoDir.appendingPathComponent(latestFilename)
        try? before.jpegData(compressionQuality: 0.88)?.write(to: baselineURL, options: [.atomic])
        try? after.jpegData(compressionQuality: 0.88)?.write(to: latestURL, options: [.atomic])

        let baselineIdentity = BuildIdentity(primary: .power, secondary: .endurance, shape: .hybrid)
        let latestIdentity = BuildIdentity(primary: .power, secondary: .control, shape: .hybrid)
        let baselineCheckpoint = ScanCheckpoint(
            id: "dev-scan-baseline",
            userId: userId,
            createdAt: baselineDate,
            photoFilename: baselineFilename,
            buildIdentitySnapshot: baselineIdentity,
            narrative: "Baseline debug scan locked. Power leads the profile with endurance close behind.",
            deltaFromPrior: nil
        )
        let latestCheckpoint = ScanCheckpoint(
            id: "dev-scan-latest",
            userId: userId,
            createdAt: latestDate,
            photoFilename: latestFilename,
            buildIdentitySnapshot: latestIdentity,
            narrative: "Debug checkpoint shows the Arc compounding: pressing strength held while control improved.",
            deltaFromPrior: BuildIdentityDelta(perAxis: [
                .power: 3,
                .control: 8,
                .endurance: 2,
                .explosiveness: 2,
                .vitality: 1,
                .mobility: 1
            ])
        )
        try? ScanCheckpointStore.shared.save(baselineCheckpoint)
        try? ScanCheckpointStore.shared.save(latestCheckpoint)

        let baselinePhoto = ProgressPhoto(
            id: "dev-scan-photo-baseline",
            userId: userId,
            storageUrl: baselineURL.path,
            capturedAt: baselineDate,
            note: "Dev baseline scan",
            angle: .front,
            blockNumber: 1,
            source: .scan
        )
        let latestPhoto = ProgressPhoto(
            id: "dev-scan-photo-latest",
            userId: userId,
            storageUrl: latestURL.path,
            capturedAt: latestDate,
            note: safeDaysAgo == 0 ? "Dev locked scan" : "Dev due scan",
            angle: .front,
            blockNumber: 1,
            source: .scan
        )
        try? await DatabaseService.shared.create(baselinePhoto, collection: "progressPhotos", documentId: baselinePhoto.id)
        try? await DatabaseService.shared.create(latestPhoto, collection: "progressPhotos", documentId: latestPhoto.id)

        let report = ScanDeltaReport(
            id: "dev-scan-delta-report",
            userId: userId,
            baselineScanId: baselineCheckpoint.id,
            comparisonScanId: latestCheckpoint.id,
            createdAt: latestDate,
            shoulders: BodyPartDelta(before: 5, after: 7),
            chest: BodyPartDelta(before: 6, after: 7),
            arms: BodyPartDelta(before: 5, after: 6),
            core: BodyPartDelta(before: 4, after: 6),
            legs: BodyPartDelta(before: 6, after: 6),
            overall: BodyPartDelta(before: 5, after: 7),
            narrative: "Power and control proof signals are trending up. Next block should keep pull volume stable while watching logged recovery.",
            improvements: ["power", "control"],
            laggingAreas: [],
            recommendedFocus: "Let completed sessions, RPE, equipment, and recovery drive the next block."
        )
        try? await DatabaseService.shared.create(report, collection: "scanDeltaReports", documentId: report.id)

        UserDefaults.standard.set(latestDate.timeIntervalSince1970, forKey: "unbound.lastScanTimestamp")
        try? await DatabaseService.shared.update(["totalScans": 2], collection: "users", documentId: userId)
    }

    static func regenerateProgramFromDevProfile() async {
        await activate(services: ServiceContainer(), completeOnboarding: true)
        guard let profile: UserProfile = try? await DatabaseService.shared.read(collection: "users", documentId: userId) else {
            return
        }
        do {
            let program = try await ProgramGenerationService.shared.generateFromOnboarding(
                userId: userId,
                targetFrequency: profile.targetFrequency,
                equipment: Set(profile.equipment ?? [.bodyweight]),
                experience: profile.experience,
                sessionLength: profile.sessionLength,
                exerciseStyles: Set(profile.exerciseStyles ?? []),
                targetAreas: Set(profile.targetAreas ?? []),
                age: profile.age ?? 0,
                gender: profile.gender ?? .unspecified,
                heightCm: profile.heightCm ?? 0,
                weightKg: profile.weightKg ?? 0,
                trainingDays: profile.trainingDays,
                trainingStyleOverride: profile.trainingStyleOverride,
                trainingFeedbackMode: profile.trainingFeedbackMode,
                cutModeActive: profile.cutMode.enabled,
                biologicalSex: profile.biologicalSex
            )
            try? await DatabaseService.shared.create(program, collection: "programs", documentId: program.id)
            await ProgramStore.shared.save(program, userId: userId)
            try? await DatabaseService.shared.update(["currentProgramId": program.id], collection: "users", documentId: userId)
        } catch {
            LoggingService.shared.log(
                "Dev deterministic regeneration failed: \(error)",
                level: .error,
                context: ["userId": userId]
            )
        }
    }

    static func programScanSnapshot() -> DevProgramScanSnapshot {
        let program = ProgramStore.shared.loadLocal(userId: userId) ?? ProgramStore.shared.program
        let checkpoints = (try? ScanCheckpointStore.shared.history(userId: userId)) ?? []
        let lastScan = checkpoints.last?.createdAt
        let scanCadence = ScanCadenceState.compute(lastScanAt: lastScan, now: Date())
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        guard let program else {
            return DevProgramScanSnapshot(
                programName: "No local program",
                arcStatus: "No active Arc",
                workoutDays: 0,
                requiredEquipment: "None",
                scanStatus: scanCadence.isUnlocked ? "Ready" : "Locked \(scanCadence.daysUntilNext)d",
                checkpointCount: checkpoints.count,
                lastScan: lastScan.map { formatter.string(from: $0) } ?? "Never"
            )
        }

        let arcStatus: String = {
            if let context = ArcScheduler.context(for: program) {
                return context.displayText
            }
            if BlockRolloverScheduler.shouldRollover(program: program) {
                return "Checkpoint due"
            }
            return "Day \(BlockRolloverScheduler.currentDayNumber(program: program)) · legacy block"
        }()
        let equipment = program.requiredEquipment.prefix(3).joined(separator: ", ")
        return DevProgramScanSnapshot(
            programName: program.name,
            arcStatus: arcStatus,
            workoutDays: program.days.filter { !$0.isRestDay && $0.workout != nil }.count,
            requiredEquipment: equipment.isEmpty ? "None" : equipment,
            scanStatus: scanCadence.isUnlocked ? "Ready" : "Locked \(scanCadence.daysUntilNext)d",
            checkpointCount: checkpoints.count,
            lastScan: lastScan.map { formatter.string(from: $0) } ?? "Never"
        )
    }

    private static func completedTrainingDays(count: Int) -> [Int] {
        guard count > 0 else { return [] }
        return Array((1...Arc.durationDays).filter { day in
            let weekdayIndex = ((day - 1) % 7) + 1
            return weekdayIndex != 4 && weekdayIndex != 7
        }.prefix(count))
    }

    private static func devProgressImage(named name: String, fallbackColor: UIColor) -> UIImage {
        if let image = UIImage(named: name) {
            return image
        }
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 900, height: 1200))
        return renderer.image { ctx in
            fallbackColor.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 900, height: 1200))
            UIColor.white.withAlphaComponent(0.12).setStroke()
            let path = UIBezierPath(roundedRect: CGRect(x: 300, y: 180, width: 300, height: 780), cornerRadius: 150)
            path.lineWidth = 10
            path.stroke()
        }
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

    static func seedWorkoutLogs(
        programStartDate: Date? = nil,
        completedDayNumbers: [Int] = [1, 2, 3, 5, 6]
    ) async {
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
            programId: "dev-profile",
            dayNumber: 0,
            plannedWorkoutName: "Dev Showcase",
            startedAt: now.addingTimeInterval(-86_400),
            completedAt: now.addingTimeInterval(-86_400 + 3_600),
            exerciseEntries: entries,
            overallNotes: "Seeded debug profile lift proofs.",
            overallRPE: 9,
            durationMinutes: 60
        )
        try? await DatabaseService.shared.create(log, collection: "workoutLogs", documentId: log.id)

        let calendar = Calendar.current
        for day in 1...Arc.durationDays {
            try? await DatabaseService.shared.delete(collection: "workoutLogs", documentId: "dev-program-log-day-\(day)")
        }
        for day in completedDayNumbers where day > 0 {
            let startedAt = programStartDate
                .flatMap { calendar.date(byAdding: .day, value: day - 1, to: $0) }
                ?? now.addingTimeInterval(Double(-day) * 86_400)
            let sessionEntries = [
                ExerciseLogEntry(
                    id: "dev-program-\(day)-main",
                    exerciseName: day % 2 == 0 ? "Back Squat" : "Barbell Bench Press",
                    plannedSets: 4,
                    plannedReps: day % 2 == 0 ? "3-5" : "4-6",
                    sets: (1...4).map { set in
                        SetLog(
                            id: "dev-program-\(day)-main-\(set)",
                            setNumber: set,
                            weightKg: Double(day % 2 == 0 ? 150 + day : 105 + day),
                            reps: day % 2 == 0 ? 5 : 6,
                            rpe: min(9, 7 + (day / 14)),
                            isWarmup: false
                        )
                    },
                    skipped: false,
                    notes: "Seeded debug working sets."
                ),
                ExerciseLogEntry(
                    id: "dev-program-\(day)-accessory",
                    exerciseName: day % 3 == 0 ? "Pull-Up" : "Romanian Deadlift",
                    plannedSets: 3,
                    plannedReps: day % 3 == 0 ? "6-10" : "6-8",
                    sets: (1...3).map { set in
                        SetLog(
                            id: "dev-program-\(day)-accessory-\(set)",
                            setNumber: set,
                            weightKg: day % 3 == 0 ? nil : Double(110 + day),
                            reps: day % 3 == 0 ? 8 : 8,
                            rpe: 8,
                            isWarmup: false
                        )
                    },
                    skipped: false,
                    notes: nil
                )
            ]
            let dayLog = WorkoutLog(
                id: "dev-program-log-day-\(day)",
                userId: userId,
                programId: "dev-program",
                dayNumber: day,
                plannedWorkoutName: "Dev Program Day \(day)",
                startedAt: startedAt,
                completedAt: startedAt.addingTimeInterval(3_300),
                exerciseEntries: sessionEntries,
                overallNotes: "Seeded program sandbox session.",
                overallRPE: 8,
                durationMinutes: 55
            )
            try? await DatabaseService.shared.create(dayLog, collection: "workoutLogs", documentId: dayLog.id)
        }
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

        payload.nodeStates[skillId] = .locked
        payload.provenAt.removeValue(forKey: skillId)
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
            Text(L10n.string(.settingsFAQComingSoon, defaultValue: "FAQ coming soon"))
                .font(.bodyText(16))
                .foregroundColor(.theme.textSecondary)
        }
        .navigationTitle(L10n.string(.settingsFAQ, defaultValue: "FAQ"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SettingsView(services: .mock)
            .environmentObject(ServiceContainer.mock)
    }
}
