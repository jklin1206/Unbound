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
