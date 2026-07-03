import SwiftUI
import UserNotifications
import UIKit

#if DEBUG
struct DevPlayerToolsView: View {
    @EnvironmentObject var services: ServiceContainer
    @AppStorage(ExerciseVisualAssetSet.userDefaultsKey) var exerciseVisualAssetSetRawValue = ExerciseVisualAssetSet.defaultSet.rawValue
    @AppStorage(WeightPlatePolicy.unitDefaultsKey) var weightUnitRaw = TrainingWeightUnit.localeDefault.rawValue

    @State var selectedLevel: Int = 25
    @State var selectedRank: SkillTier = .unbound
    @State var selectedRankTrialTarget: RankTitle = .novice
    @State var devTotalSessions: Int = 96
    @State var devCurrentStreak: Int = 21
    @State var devLongestStreak: Int = 45
    @State var devWeeklySessions: Int = 5
    @State var devAttributes: [AttributeKey: Double] = Dictionary(uniqueKeysWithValues: AttributeKey.allCases.map { ($0, 70) })
    @State var selectedBestLift: String = "deadlift"
    @State var selectedBestLiftWeight: Double = 225
    @State var selectedBestLiftReps: Int = 1
    @State var isApplying = false
    @State var status = "Dev account is local-only and hidden in release builds."
    @State var devSandboxSnapshot = DevProgramScanSnapshot.empty
    @State var notificationCategory: ContentNotificationPreset.Category = .streak
    @State var notificationPresetId: String = ContentNotificationCatalog.streak.first?.id ?? ""
    @State var notificationDelaySeconds: Double = 3

    var currentUserId: String {
        AuthService.shared.currentUserId ?? DevBuildBootstrapper.userId
    }

    var selectedWeightUnit: TrainingWeightUnit {
        TrainingWeightUnit(rawValue: weightUnitRaw) ?? .localeDefault
    }

    static var rankTrialTargets: [RankTitle] {
        OverallRankTrialDefinitions.all.map(\.targetRank)
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center, spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.unbound.accent.opacity(0.16))
                                .frame(width: 54, height: 54)
                            Image(systemName: "gamecontroller.fill")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(Color.unbound.accent)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Dev Player")
                                .font(.subheadline(18))
                                .foregroundColor(Color.unbound.textPrimary)
                            Text(currentUserId)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(Color.unbound.textTertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        Spacer()
                    }

                    Text(status)
                        .font(.caption(12))
                        .foregroundColor(Color.unbound.textSecondary)
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
                    .foregroundColor(Color.unbound.textTertiary)
            }

            Section {
                Picker("Exercise Art", selection: $exerciseVisualAssetSetRawValue) {
                    ForEach(ExerciseVisualAssetSet.allCases) { set in
                        Text(set.displayName).tag(set.rawValue)
                    }
                }

                HStack {
                    Label("Active Set", systemImage: "photo.stack")
                        .foregroundColor(Color.unbound.textPrimary)
                    Spacer()
                    Text(ExerciseVisualAssetSet.active.displayName)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color.unbound.accent)
                }
            } header: {
                Text("Exercise Visuals")
                    .foregroundColor(Color.unbound.textSecondary)
            } footer: {
                Text("Set UNBOUND_EXERCISE_VISUAL_SET to jot, legacy, or current to override this picker from the scheme.")
                    .font(.caption(11))
                    .foregroundColor(Color.unbound.textTertiary)
            }

            programScanSection

            Section {
                Stepper(value: $selectedLevel, in: 1...80) {
                    HStack {
                        Label("Level", systemImage: "bolt.fill")
                            .foregroundColor(Color.unbound.textPrimary)
                        Spacer()
                        Text("\(selectedLevel)")
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color.unbound.accent)
                    }
                }

                Button {
                    run { await DevBuildBootstrapper.applyLevel(selectedLevel) }
                } label: {
                    Label("Apply Level", systemImage: "bolt.badge.checkmark")
                        .foregroundColor(Color.unbound.accent)
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
                        .foregroundColor(Color.unbound.accent)
                }

            } header: {
                Text("Fast Tuning")
                    .foregroundColor(Color.unbound.textSecondary)
            } footer: {
                Text("Rank updates the profile tier, badge frame, lift proof tiers, and skill-tier state for the dev player.")
                    .font(.caption(11))
                    .foregroundColor(Color.unbound.textTertiary)
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
                        .foregroundColor(Color.unbound.accent)
                }
            } header: {
                Text("Rank Trial")
                    .foregroundColor(Color.unbound.textSecondary)
            } footer: {
                Text("Sets the dev player's prior overall rank, level, movement XP, skill tiers, attributes, and compatible equipment so the selected rank gate unlocks.")
                    .font(.caption(11))
                    .foregroundColor(Color.unbound.textTertiary)
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
                        .foregroundColor(Color.unbound.accent)
                }
            } header: {
                Text("Profile Stats")
                    .foregroundColor(Color.unbound.textSecondary)
            } footer: {
                Text("Controls the profile Sessions, Streak, weekly count, and related session XP record.")
                    .font(.caption(11))
                    .foregroundColor(Color.unbound.textTertiary)
            }

            Section {
                ForEach(AttributeKey.allCases, id: \.self) { key in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label(key.displayName, systemImage: attributeIcon(for: key))
                                .foregroundColor(Color.unbound.textPrimary)
                            Spacer()
                            Text("\(Int(devAttributes[key, default: 0].rounded()))")
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .foregroundColor(Color.unbound.accent)
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
                        .foregroundColor(Color.unbound.accent)
                }
            } header: {
                Text("Attribute Hex")
                    .foregroundColor(Color.unbound.textSecondary)
            } footer: {
                Text("Writes directly to AttributeProfileStore, so the profile radar and build identity use these values.")
                    .font(.caption(11))
                    .foregroundColor(Color.unbound.textTertiary)
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
                            .foregroundColor(Color.unbound.textPrimary)
                        Spacer()
                        Text(WeightPlatePolicy.formatLoggedWeightWithUnit(selectedBestLiftWeight, unit: selectedWeightUnit, separator: " "))
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color.unbound.accent)
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
                        .foregroundColor(Color.unbound.accent)
                }
            } header: {
                Text("Best Lift")
                    .foregroundColor(Color.unbound.textSecondary)
            } footer: {
                Text("Seeds the profile PR workout log so Best Lift shows this lift and its rank badge.")
                    .font(.caption(11))
                    .foregroundColor(Color.unbound.textTertiary)
            }

            Section {
                Button {
                    run { await DevBuildBootstrapper.unlockAllBadges() }
                } label: {
                    Label("Unlock All Badges", systemImage: "rosette")
                        .foregroundColor(Color.unbound.accent)
                }

                Button {
                    run { await DevBuildBootstrapper.masterSkillTree() }
                } label: {
                    Label("Master Skill Tree", systemImage: "circle.hexagongrid.fill")
                        .foregroundColor(Color.unbound.accent)
                }

                Button {
                    run { await DevBuildBootstrapper.seedSessionStats() }
                } label: {
                    Label("Seed Streak + Session Stats", systemImage: "flame.fill")
                        .foregroundColor(Color.unbound.accent)
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
                        .foregroundColor(Color.unbound.accent)
                }
                .disabled(isApplying)
            } header: {
                Text("Feature Unlocks")
                    .foregroundColor(Color.unbound.textSecondary)
            }

            notificationPreviewSection

            Section {
                Button {
                    run(successMessage: "Dev account reset to a fresh logged-in user.") {
                        await DevBuildBootstrapper.seedFreshLoginDevAccount(services: services)
                    }
                } label: {
                    Label("Fresh Login Dev Account", systemImage: "person.crop.circle.badge.checkmark")
                        .foregroundColor(Color.unbound.accent)
                }
                .accessibilityIdentifier("dev.account.freshLogin")

                Button(role: .destructive) {
                    run(successMessage: "Completed workouts reset for Dev Player.") {
                        await DevBuildBootstrapper.resetCompletedWorkouts()
                    }
                } label: {
                    Label("Reset Completed Workouts", systemImage: "arrow.counterclockwise.circle")
                        .foregroundColor(Color.unbound.alert)
                }
                .disabled(isApplying)
                .accessibilityIdentifier("dev.account.resetCompletedWorkouts")

                Button(role: .destructive) {
                    DevBuildBootstrapper.clearDevProgress()
                    status = "Dev progress cleared. Activate again when you want a fresh sandbox."
                } label: {
                    Label("Clear Dev Progress", systemImage: "trash")
                        .foregroundColor(Color.unbound.alert)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.unbound.bg)
        .navigationTitle("Dev Player")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadDevControlValues() }
    }

    var notificationPreviewSection: some View {
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
                    .foregroundColor(Color.unbound.textPrimary)
                Text(selectedPreset.body)
                    .font(.caption(13))
                    .foregroundColor(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Label("Delay", systemImage: "timer")
                        .foregroundColor(Color.unbound.textPrimary)
                    Spacer()
                    Text("\(Int(notificationDelaySeconds.rounded()))s")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color.unbound.accent)
                }
                Slider(value: $notificationDelaySeconds, in: 1...15, step: 1)
                    .tint(Color.unbound.accent)
            }

            Button {
                fireNotificationPreview(preset: selectedPreset)
            } label: {
                Label("Send to Lock Screen", systemImage: "bell.badge.fill")
                    .foregroundColor(Color.unbound.accent)
            }
            .accessibilityIdentifier("dev.notification.fire")
        } header: {
            Text("Notification Preview")
                .foregroundColor(Color.unbound.textSecondary)
        } footer: {
            Text("Fires the selected message after the chosen delay. Lock the device before the timer runs out to capture the lock-screen pop for content carousels.")
                .font(.caption(11))
                .foregroundColor(Color.unbound.textTertiary)
        }
    }

    func fireNotificationPreview(preset: ContentNotificationPreset) {
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

    var programScanSection: some View {
        Section {
            DevProgramScanSnapshotCard(snapshot: devSandboxSnapshot)

            Button {
                run(successMessage: "Seeded Arc Day 1 with fresh scan history.") {
                    await DevBuildBootstrapper.seedProgramScanSandbox(services: services, state: .arcDay1)
                }
            } label: {
                Label("Seed Arc Day 1", systemImage: "calendar.badge.plus")
                    .foregroundColor(Color.unbound.accent)
            }
            .accessibilityIdentifier("dev.program.seedArcDay1")

            Button {
                run(successMessage: "Forced checkpoint due. Program should show block-complete actions.") {
                    await DevBuildBootstrapper.seedProgramScanSandbox(services: services, state: .checkpointDue)
                }
            } label: {
                Label("Force Checkpoint Due", systemImage: "flag.checkered")
                    .foregroundColor(Color.unbound.accent)
            }
            .accessibilityIdentifier("dev.program.forceCheckpointDue")

            Button {
                run(successMessage: "Seeded scan history and made the monthly scan window due.") {
                    await DevBuildBootstrapper.seedScanHistory(daysAgo: 31)
                }
            } label: {
                Label("Seed Scan Due History", systemImage: "camera.viewfinder")
                    .foregroundColor(Color.unbound.accent)
            }
            .accessibilityIdentifier("dev.scan.seedDueHistory")

            Button {
                run(successMessage: "Locked the scan window to today so cadence copy can be checked.") {
                    await DevBuildBootstrapper.seedScanHistory(daysAgo: 0)
                }
            } label: {
                Label("Lock Scan Window", systemImage: "lock.fill")
                    .foregroundColor(Color.unbound.accent)
            }
            .accessibilityIdentifier("dev.scan.lockWindow")

            Button {
                run(successMessage: "Regenerated a deterministic program from the current dev onboarding profile.") {
                    await DevBuildBootstrapper.regenerateProgramFromDevProfile()
                }
            } label: {
                Label("Regenerate From Dev Profile", systemImage: "arrow.triangle.2.circlepath")
                    .foregroundColor(Color.unbound.accent)
            }
            .accessibilityIdentifier("dev.program.regenerateFromProfile")

            ForEach(DevDynamicProgramScenario.allCases) { scenario in
                Button {
                    run(successMessage: scenario.successMessage) {
                        await DevBuildBootstrapper.seedDynamicProgramScenario(
                            services: services,
                            scenario: scenario
                        )
                    }
                } label: {
                    Label(scenario.title, systemImage: scenario.systemImage)
                        .foregroundColor(Color.unbound.accent)
                }
                .accessibilityIdentifier("dev.program.dynamic.\(scenario.rawValue)")
            }
        } header: {
            Text("Program + Scan Sandbox")
                .foregroundColor(Color.unbound.textSecondary)
        } footer: {
            Text("Seeds real local program, scan state, dynamic setup contexts, Program Focuses, and user-owned workout fixtures. Launch args: --unbound-dev-program-sandbox arc-day-1|checkpoint-due, --unbound-dev-dynamic-program \(DevDynamicProgramScenario.launchArgumentList).")
                .font(.caption(11))
                .foregroundColor(Color.unbound.textTertiary)
        }
    }

    func devStepper(label: String, systemName: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        Stepper(value: value, in: range) {
            HStack {
                Label(label, systemImage: systemName)
                    .foregroundColor(Color.unbound.textPrimary)
                Spacer()
                Text("\(value.wrappedValue)")
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color.unbound.accent)
            }
        }
    }

    func attributeIcon(for key: AttributeKey) -> String {
        switch key {
        case .power: return "bolt.fill"
        case .explosiveness: return "hare.fill"
        case .control: return "scope"
        case .vitality: return "heart.fill"
        case .mobility: return "figure.flexibility"
        case .endurance: return "infinity"
        }
    }

    func loadDevControlValues() {
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

    func run(
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

@MainActor
enum DevBuildBootstrapper {
    static let userId = "dev-player"
    static let devLiftNames = ["bench press", "back squat", "deadlift", "overhead press"]

    static let badgeKey = "unbound.badges.\(userId)"
    static let sessionXPKey = "unbound.sessionxp.\(userId)"
    static let didBootstrapKey = "unbound.dev.didBootstrapEverything"
    static let resetOpenedSkillForProofArg = "--unbound-reset-opened-skill-for-proof"
    static let resetActiveGoalsForProofArg = "--unbound-reset-active-goals-for-proof"
    static let scheduledSkillProofArg = "--unbound-proof-scheduled-skill"
    static let rankTrialReadyProofArg = "--unbound-proof-rank-trial-ready"
    static let programStateProofArg = "--unbound-proof-program-state"
    static let programSurfaceProofArg = "--unbound-proof-program-surface"
    static let devProgramSandboxArg = "--unbound-dev-program-sandbox"
    static let dynamicProgramScenarioArg = "--unbound-dev-dynamic-program"
    static let freshLoginDevAccountArg = "--unbound-dev-fresh-login"
    static let devScanSandboxArg = "--unbound-dev-scan"
    static let squadRosterProofArg = "--unbound-seed-squad-roster"
    static let squadActivityProofArg = "--unbound-proof-squad-activity"
    /// `--unbound-dev-prove-skill <skillId>`: logs a qualifying proof of the
    /// skill's top criterion movement through the REAL completion path, so the
    /// live skill-rank advance can be demoed on-sim (pair with
    /// `--unbound-dev-fresh-login` for a clean Initiate → advanced before/after).
    static let proveSkillDemoArg = "--unbound-dev-prove-skill"
    /// `--unbound-dev-seed-skill-history <skillId>`: logs a realistic, dated climb
    /// of the skill's own criterion through the REAL completion path, so the rank
    /// + stats render an actual user's experience (pair with `--unbound-dev-fresh-login`).
    static let seedSkillHistoryArg = "--unbound-dev-seed-skill-history"
    static let devAccountModeKey = "unbound.dev.accountMode"
    static let freshLoginDevAccountMode = "fresh-login"
    static let resetCompletedWorkoutsDevAccountMode = "reset-completed-workouts"
    /// `-genuineNewUser` (or env `UNBOUND_GENUINE_NEW_USER=1`): skip ALL dev
    /// seeding so the app boots as a real first-launch user — no dev account and
    /// no unlock flags — for genuine end-to-end onboarding verification on the
    /// simulator. Everything else stays a normal DEBUG build, so the paywall's
    /// local purchase stub still crosses the gate with no Apple Account.
    static let genuineNewUserArg = "-genuineNewUser"
    /// `--unbound-dev-keep-state`: activate the dev account but skip every
    /// seeding step, keeping all persisted stores (program, schedule
    /// occurrences, logs) exactly as the previous run left them. A plain dev
    /// launch re-seeds `seedProgram()` and would clobber state like a
    /// rolled-over arc, so persistence across relaunches can only be verified
    /// with this flag.
    static let keepStateArg = "--unbound-dev-keep-state"

    static var isGenuineNewUserLaunch: Bool {
        ProcessInfo.processInfo.arguments.contains(genuineNewUserArg)
            || ProcessInfo.processInfo.environment["UNBOUND_GENUINE_NEW_USER"] == "1"
    }

    static func ensureReady() async {
        guard !isGenuineNewUserLaunch else { return }
        AuthService.shared.activateDevUser(id: userId)
        DevFlags.shared.unlockAllFeatures = true
        if ProcessInfo.processInfo.arguments.contains(keepStateArg) { return }

        let services = ServiceContainer()
        if shouldSeedFreshLoginDevAccount {
            await seedFreshLoginDevAccount(services: services)
        } else if shouldSeedResetCompletedWorkoutsDevAccount {
            await maxEverything(
                level: 42,
                services: services,
                completeOnboarding: shouldCompleteOnboardingForDevLaunch
            )
            await resetCompletedWorkouts()
        } else {
            await maxEverything(
                level: 42,
                services: services,
                completeOnboarding: shouldCompleteOnboardingForDevLaunch
            )
        }
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
            await seedProgramScanSandbox(services: services, state: sandboxState)
        }
        if let rawDynamicScenario = launchArgumentValue(for: dynamicProgramScenarioArg),
           let scenario = DevDynamicProgramScenario(rawValue: rawDynamicScenario) {
            await seedDynamicProgramScenario(services: services, scenario: scenario)
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
        if let skillId = launchArgumentValue(for: proveSkillDemoArg) {
            await proveSkillForDemo(skillId: skillId)
        }
        if let skillId = launchArgumentValue(for: seedSkillHistoryArg) {
            await seedSkillHistory(skillId: skillId)
        }
        UserDefaults.standard.set(true, forKey: didBootstrapKey)
    }

    static var shouldCompleteOnboardingForLaunchRoute: Bool {
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
            || arguments.contains(where: { $0 == dynamicProgramScenarioArg || $0.hasPrefix("\(dynamicProgramScenarioArg)=") })
            || arguments.contains(freshLoginDevAccountArg)
            || arguments.contains(where: { $0 == devScanSandboxArg || $0.hasPrefix("\(devScanSandboxArg)=") })
            || arguments.contains(where: { $0 == seedSkillHistoryArg || $0.hasPrefix("\(seedSkillHistoryArg)=") })
            || arguments.contains(squadActivityProofArg)
    }

    static var shouldCompleteOnboardingForDevLaunch: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-OnboardingStep") || arguments.contains("--onboarding-step") {
            return false
        }
        return true
    }

    static var shouldSeedFreshLoginDevAccount: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains(freshLoginDevAccountArg) {
            return true
        }
        if arguments.contains(where: { $0 == dynamicProgramScenarioArg || $0.hasPrefix("\(dynamicProgramScenarioArg)=") })
            || arguments.contains(where: { $0 == devProgramSandboxArg || $0.hasPrefix("\(devProgramSandboxArg)=") })
            || arguments.contains(where: { $0 == programStateProofArg || $0.hasPrefix("\(programStateProofArg)=") })
            || arguments.contains(where: { $0 == programSurfaceProofArg || $0.hasPrefix("\(programSurfaceProofArg)=") }) {
            return false
        }
        return UserDefaults.standard.string(forKey: devAccountModeKey) == freshLoginDevAccountMode
    }

    static var shouldSeedResetCompletedWorkoutsDevAccount: Bool {
        UserDefaults.standard.string(forKey: devAccountModeKey) == resetCompletedWorkoutsDevAccountMode
    }

    static var rankTrialProofTargetArgument: String? {
        if let targetRank = launchArgumentValue(for: rankTrialReadyProofArg) {
            return targetRank
        }
        return ProcessInfo.processInfo.arguments.contains(rankTrialReadyProofArg)
            ? RankTitle.novice.token
            : nil
    }

    static var shouldSeedBindingVowForProof: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("--unbound-open-program")
            || arguments.contains(where: { $0 == programStateProofArg || $0.hasPrefix("\(programStateProofArg)=") })
            || arguments.contains(where: { $0 == programSurfaceProofArg || $0.hasPrefix("\(programSurfaceProofArg)=") })
            || arguments.contains(where: { $0 == dynamicProgramScenarioArg || $0.hasPrefix("\(dynamicProgramScenarioArg)=") })
    }

}
#endif
