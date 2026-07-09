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
                if viewModel.isCloudLinked {
                    HStack {
                        Label(L10n.string(.settingsEmail, defaultValue: "Email"), systemImage: "envelope")
                            .foregroundColor(Color.unbound.textPrimary)
                        Spacer()
                        Text(viewModel.userProfile?.email ?? "Apple ID")
                            .font(.bodyText(14))
                            .foregroundColor(Color.unbound.textTertiary)
                    }

                    Button(role: .destructive) {
                        viewModel.signOut()
                    } label: {
                        Label(L10n.string(.settingsSignOut, defaultValue: "Sign Out"), systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(Color.unbound.alert)
                    }
                } else {
                    Button {
                        Task { await viewModel.signInWithApple() }
                    } label: {
                        Label("Sign in with Apple", systemImage: "apple.logo")
                            .foregroundColor(Color.unbound.textPrimary)
                    }
                    .disabled(viewModel.isLoading)
                }
            } header: {
                Text(L10n.string(.settingsSectionAccount, defaultValue: "Account"))
                    .foregroundColor(Color.unbound.textSecondary)
            } footer: {
                if !viewModel.isCloudLinked {
                    Text("Your progress is saved on this device. Sign in to back it up and keep it if you switch phones.")
                        .font(.caption(11))
                        .foregroundColor(Color.unbound.textTertiary)
                }
            }

            // MARK: Subscription
            Section {
                HStack {
                    Label(L10n.string(.settingsPlan, defaultValue: "Plan"), systemImage: "crown")
                        .foregroundColor(Color.unbound.textPrimary)
                    Spacer()
                    Text(viewModel.hasActiveSubscription ? settingsPlanPro : settingsPlanFree)
                        .font(.bodyMedium(14))
                        .foregroundColor(viewModel.hasActiveSubscription ? Color.unbound.accent : Color.unbound.textTertiary)
                }

                if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
                    Link(destination: url) {
                        Label(L10n.string(.settingsManageSubscription, defaultValue: "Manage Subscription"), systemImage: "arrow.up.circle")
                            .foregroundColor(Color.unbound.textPrimary)
                    }
                }

                Button {
                    Task { await viewModel.restorePurchases() }
                } label: {
                    if viewModel.isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(Color.unbound.accent)
                            Text(L10n.string(.subscriptionRestoreRestoring, defaultValue: "Restoring..."))
                                .foregroundColor(Color.unbound.textSecondary)
                        }
                    } else {
                        Label(L10n.string(.subscriptionRestoreIdle, defaultValue: "Restore Purchases"), systemImage: "arrow.counterclockwise")
                            .foregroundColor(Color.unbound.textPrimary)
                    }
                }
                .disabled(viewModel.isLoading)
            } header: {
                Text(L10n.string(.settingsSectionSubscription, defaultValue: "Subscription"))
                    .foregroundColor(Color.unbound.textSecondary)
            }

            // MARK: Privacy
            Section {
                Toggle(isOn: shareUsageDataBinding) {
                    Label(L10n.string(.settingsShareUsageData, defaultValue: "Share usage data"), systemImage: "chart.line.uptrend.xyaxis")
                        .foregroundColor(Color.unbound.textPrimary)
                }
                .tint(Color.unbound.accent)

                NavigationLink {
                    NotificationSettingsView()
                } label: {
                    Label(L10n.string(.settingsNotifications, defaultValue: "Notifications"), systemImage: "bell.badge")
                        .foregroundColor(Color.unbound.textPrimary)
                }
            } header: {
                Text(L10n.string(.settingsSectionPrivacy, defaultValue: "Privacy"))
                    .foregroundColor(Color.unbound.textSecondary)
            }

            // MARK: Training preferences
            Section {
                Picker(selection: $trainingWeightUnitRaw) {
                    ForEach(TrainingWeightUnit.allCases) { unit in
                        Text(unit.displayName).tag(unit.rawValue)
                    }
                } label: {
                    Label(L10n.string(.settingsWeightUnit, defaultValue: "Weight Unit"), systemImage: "scalemass")
                        .foregroundColor(Color.unbound.textPrimary)
                }

                Toggle(isOn: $microloadingEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label(L10n.string(.settingsMicroPlates, defaultValue: "Micro plates"), systemImage: "plus.forwardslash.minus")
                            .foregroundColor(Color.unbound.textPrimary)
                        Text("Smaller weight jumps (2.5 lb / 1.25 kg) for gyms with fractional plates")
                            .font(.caption(11))
                            .foregroundColor(Color.unbound.textTertiary)
                    }
                }
                .tint(Color.unbound.accent)

                NavigationLink {
                    EquipmentSettingsView()
                        .environmentObject(services)
                } label: {
                    HStack {
                        Label(L10n.string(.settingsEquipment, defaultValue: "Equipment"), systemImage: "dumbbell.fill")
                            .foregroundColor(Color.unbound.textPrimary)
                        Spacer()
                        Text(equipmentSummary)
                            .font(.bodyText(14))
                            .foregroundColor(Color.unbound.textTertiary)
                    }
                }
            } header: {
                Text(L10n.string(.settingsSectionTraining, defaultValue: "Training"))
                    .foregroundColor(Color.unbound.textSecondary)
            } footer: {
                Text(L10n.string(
                    .settingsTrainingFooter,
                    defaultValue: "Your exact logged weights are preserved. UNBOUND rounds suggestions and progression jumps to the selected plate system."
                ))
                    .font(.caption(11))
                    .foregroundColor(Color.unbound.textTertiary)
            }

            // MARK: Support
            Section {
                if let mailURL = URL(string: "mailto:support@unboundbtr.com") {
                    Link(destination: mailURL) {
                        Label(L10n.string(.settingsContactUs, defaultValue: "Contact Us"), systemImage: "envelope.badge")
                            .foregroundColor(Color.unbound.textPrimary)
                    }
                }

                if let faqURL = URL(string: "https://unboundbtr.com/faq") {
                    Link(destination: faqURL) {
                        Label(L10n.string(.settingsFAQ, defaultValue: "FAQ"), systemImage: "questionmark.circle")
                            .foregroundColor(Color.unbound.textPrimary)
                    }
                }
            } header: {
                Text(L10n.string(.settingsSectionSupport, defaultValue: "Support"))
                    .foregroundColor(Color.unbound.textSecondary)
            }

            // MARK: Legal
            Section {
                Link(destination: AppConstants.Legal.termsURL) {
                    Label(L10n.string(.legalTermsOfService, defaultValue: "Terms of Service"), systemImage: "doc.text")
                        .foregroundColor(Color.unbound.textPrimary)
                }

                Link(destination: AppConstants.Legal.privacyURL) {
                    Label(L10n.string(.legalPrivacyPolicy, defaultValue: "Privacy Policy"), systemImage: "hand.raised")
                        .foregroundColor(Color.unbound.textPrimary)
                }
            } header: {
                Text(L10n.string(.settingsSectionLegal, defaultValue: "Legal"))
                    .foregroundColor(Color.unbound.textSecondary)
            }

            // MARK: Danger Zone
            Section {
                Button(role: .destructive) {
                    showDeleteAccount = true
                } label: {
                    Label(L10n.string(.settingsDeleteAccount, defaultValue: "Delete Account"), systemImage: "trash")
                        .foregroundColor(Color.unbound.alert)
                }
            } header: {
                Text(L10n.string(.settingsSectionDangerZone, defaultValue: "Danger Zone"))
                    .foregroundColor(Color.unbound.textSecondary)
            }

            // MARK: Dev (DEBUG only)
            #if DEBUG
            Section {
                NavigationLink {
                    DevPlayerToolsView()
                        .environmentObject(services)
                } label: {
                    Label("Dev Player Tools", systemImage: "gamecontroller")
                        .foregroundColor(Color.unbound.textPrimary)
                }
                .accessibilityIdentifier("settings.devPlayerTools")

                Toggle(isOn: Binding(
                    get: { DevFlags.shared.unlockAllFeatures },
                    set: { DevFlags.shared.unlockAllFeatures = $0 }
                )) {
                    Label("Unlock all features", systemImage: "lock.open")
                        .foregroundColor(Color.unbound.textPrimary)
                }
                .tint(Color.unbound.accent)

                Button {
                    resetOnboarding()
                } label: {
                    Label("Reset Onboarding", systemImage: "arrow.counterclockwise.circle")
                        .foregroundColor(Color.unbound.accent)
                }

                Button {
                    resetEverything()
                } label: {
                    Label("Reset Everything (wipe)", systemImage: "arrow.triangle.2.circlepath")
                        .foregroundColor(Color.unbound.alert)
                }
            } header: {
                Text("Dev")
                    .foregroundColor(Color.unbound.textSecondary)
            } footer: {
                Text("Debug-only controls. Hidden in release builds. Unlock bypasses the paywall without charging.")
                    .font(.caption(11))
                    .foregroundColor(Color.unbound.textTertiary)
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
        // Restore outcomes (restored / nothing to restore) confirm under their
        // own title; only real failures use the Error alert above.
        .alert(L10n.string(.subscriptionRestoreIdle, defaultValue: "Restore Purchases"), isPresented: .constant(viewModel.restoreMessage != nil)) {
            Button(L10n.string(.settingsAlertOK, defaultValue: "OK")) { viewModel.restoreMessage = nil }
        } message: {
            Text(viewModel.restoreMessage ?? "")
        }
        .onAppear {
            Task { await viewModel.loadProfile() }
        }
    }

    /// Reflects the live equipment declaration next to the Equipment row so
    /// the setting shows its state without navigating in.
    private var equipmentSummary: String {
        guard let equipment = viewModel.userProfile?.equipment, !equipment.isEmpty else {
            return "Bodyweight"
        }
        if equipment.contains(.fullGym) { return "Full gym" }
        return "\(equipment.count) selected"
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
                        .foregroundColor(Color.unbound.textPrimary)
                    Spacer()
                    Text(authorizationLabel)
                        .font(.bodyText(14))
                        .foregroundColor(Color.unbound.textTertiary)
                }

                Button {
                    Task { await requestAuthorization() }
                } label: {
                    Label(L10n.string(.notificationSettingsAllowNotifications, defaultValue: "Allow Notifications"), systemImage: "checkmark.circle")
                        .foregroundColor(Color.unbound.textPrimary)
                }
            } header: {
                Text(L10n.string(.notificationSettingsSectionSystem, defaultValue: "System"))
                    .foregroundColor(Color.unbound.textSecondary)
            }

            Section {
                Toggle(isOn: binding(
                    get: { $0.workoutReminders.isEnabled },
                    set: { $0.workoutReminders.isEnabled = $1 }
                )) {
                    Label(L10n.string(.notificationSettingsWorkoutReminders, defaultValue: "Workout reminders"), systemImage: "flame.fill")
                        .foregroundColor(Color.unbound.textPrimary)
                }
                .tint(Color.unbound.accent)

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
                            .foregroundColor(Color.unbound.textPrimary)
                    }
                    .tint(Color.unbound.accent)
                }
            } header: {
                Text(L10n.string(.settingsSectionTraining, defaultValue: "Training"))
                    .foregroundColor(Color.unbound.textSecondary)
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
        // Once denied, requestAuthorization returns immediately without a
        // prompt — the only path back is the system notification settings.
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        if status == .denied {
            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                await MainActor.run { UIApplication.shared.open(url) }
            }
            return
        }
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

#Preview {
    NavigationStack {
        SettingsView(services: .mock)
            .environmentObject(ServiceContainer.mock)
    }
}
