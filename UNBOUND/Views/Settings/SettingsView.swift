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
                    RewardsVaultView()
                        .environmentObject(services)
                } label: {
                    Label("Rewards", systemImage: "trophy.fill")
                        .foregroundColor(.theme.textPrimary)
                }
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
        .background(Color.unbound.bg)
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

        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.unbound.bg)
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
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
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

// MARK: - FAQ Placeholder

private struct FAQPlaceholderView: View {
    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
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
