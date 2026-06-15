import Foundation
import SwiftUI
import UIKit

// MARK: - UnboundHomeView
//
// Quiet dashboard. Charcoal cards on black, violet as the sole accent,
// heavy breathing room. The dramatic bits (rank-up cinematic, node-unlock
// reveal, gains toast) still fire — they're mounted by `HomeTabView` and
// trigger on notifications, so nothing visual lives on home that isn't
// essential at a glance.
//
// Modules top → bottom:
//   1. Top bar       — UNBOUND wordmark + ember wallet + bell
//   2. Rank card     — rank letter + tier name + level + thin XP bar
//   3. Today's CTA   — "BEGIN SESSION" violet button. The only violet fill.
//   4. Contextual    — Recalibrating / Plateau / Scan-due / Day-one cal
//                      (each renders only when its trigger fires)
//   5. Stats grid    — 2×2 Strength / Stamina / Technique / Vitality
//   6. Last session  — inline recap line, no card
//
// Data state lives in `HomeViewModel`; this view keeps only presentation
// state (sheets, cosmetics, animation phases).

struct UnboundHomeView: View {
    @EnvironmentObject var services: ServiceContainer
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    @StateObject var model: HomeViewModel

    @ObservedObject var photoStore = ProfilePhotoStore.shared
    @StateObject var walletStore = CurrencyWalletStore.shared
    @StateObject var shopInventoryStore = ShopInventoryStore.shared
    @State var equippedShopProfileBorder: ShopProfileBorderID?
    @State var equippedHomeBackdrop: ShopItem?

    @AppStorage(WeightPlatePolicy.unitDefaultsKey) var weightUnitRaw: String = TrainingWeightUnit.localeDefault.rawValue
    @AppStorage("unbound.streakDays") var streakDays: Int = 0
    @AppStorage("unbound.lastPhotoTimestamp") var lastPhotoTimestamp: Double = 0
    @AppStorage("unbound.lastSessionDate") var lastSessionTimestamp: Double = 0

    // Modal state
    @State var showRankLibrary = false
    @State var workoutReadyDraft: TrainingSessionDraft?
    @State var showingCalibrationWorkout = false
    // navigateToCoach removed — replaced by CoachModesStrip
    @State var showingNotificationSettings = false
    @State var showingBodyWeightLog = false
    @State var showingBodyWeightHistory = false
    @State var showingShop = false
    @State var showingBackdropPicker = false
    @State var showRankInfo = false
    @State var bodyWeightJustLogged = false

    // Ambient animation state
    @State var rankGlowRadius: CGFloat = 6
    @State var xpShimmerPhase: CGFloat = -1
    @State var statsRendered = false

    // Daily Quest — launches the same canonical routine completion path as
    // the routine library. Rotation service lands later; fixed entry for now.
    @State var activeRoutine: RoutineDef = Self.defaultDailyQuestRoutine
    @State var showRoutinePlayer = false
    @State var dailyQuestRewardSequence: WorkoutRewardSequenceSummary?
    @State var isCompletingDailyQuest = false
    @State var pendingDailyQuestCompletionRecord: RoutineCompletionRecord?
    @State var dailyQuestCompletionError: String?

    // Photo/Scan capture flow presentation
    @State var captureMode: PhotoCaptureFlow.Mode?

    @State var showScanCaptureFlow = false

    @State var showTrialPicker = false

    init(services: ServiceContainer) {
        _model = StateObject(wrappedValue: HomeViewModel(services: services))
    }

    static let defaultDailyQuestRoutine: RoutineDef = {
        RoutineLibrary.placeholderRoutines.first { $0.id == "daily-quest" }
            ?? RoutineDef(
                id: "daily-quest",
                title: "Daily Quest",
                subtitle: "Show up and log the work you actually complete.",
                durationLabel: "~20 MIN",
                category: .challenge,
                spReward: 0,
                steps: []
            )
    }()

    // MARK: Body

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            homeBackground

            if model.isLoading {
                HomeLoadingSkeleton()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        homeHeroStack

                        VStack(spacing: 0) {
                            homeControlSurface

                            BodyLoadHeatmapView(loads: model.bodyRegionLoads, plannedRegions: model.todayPlannedBodyRegions)

                            contextualStack
                                .padding(.top, 14)

                            lastSessionRecap
                                .padding(.top, 18)

                            Spacer().frame(height: 118)
                        }
                        .padding(.horizontal, 20)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .task {
            bindCosmeticStores()
            await model.load()
        }
        .onChange(of: model.isLoading) { _, isLoading in
            guard !isLoading else { return }
            // Kick off ambient loops once content is on screen.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                startAmbientAnimations()
            }
        }
        .tierBloomToast()
        .onReceive(NotificationCenter.default.publisher(for: .rankAdvanced)) { _ in
            Task { await model.refreshRanksAndStats() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .skillTierAdvanced)) { _ in
            if let userId = services.auth.currentUserId {
                Task {
                    model.aggregateTier = await services.rank.aggregateTier(userId: userId)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sessionXPUpdated)) { _ in
            Task {
                await model.refreshSessionXP()
                await model.refreshRanksAndStats()
                await model.refreshRecentTrainingSignals()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .attributeRankUp)) { _ in
            if let userId = services.auth.currentUserId {
                model.attributeProfile = services.attribute.profile(userId: userId)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .shopInventoryChanged)) { _ in
            equippedShopProfileBorder = shopInventoryStore.equippedProfileBorder()
            equippedHomeBackdrop = shopInventoryStore.equippedBackdrop(for: .home)
        }
        .fullScreenCover(isPresented: $showingCalibrationWorkout, onDismiss: {
            Task { await model.refreshCalibrationState() }
        }) {
            CalibrationWorkoutView(onComplete: { model.calibrationSkipRatio = 0 })
                .environmentObject(services)
        }
        .fullScreenCover(item: $workoutReadyDraft, onDismiss: {
            workoutReadyDraft = nil
            Task { await model.refreshWorkoutCompletionState() }
        }) { draft in
            // Rank trials walk in through the gate entrance; weekly vows keep the
            // standard ready screen (this cover is shared by both).
            if draft.source == .overallRankTrial {
                GateTrialLaunchView(draft: draft, services: services, onFinished: {
                    workoutReadyDraft = nil
                })
                .environmentObject(services)
            } else {
                WorkoutReadyView(draft: draft)
                    .environmentObject(services)
            }
        }
        .fullScreenCover(item: $captureMode) { mode in
            PhotoCaptureFlow(mode: mode) { outcome in
                captureMode = nil
                if outcome == .photoSaved || outcome == .scanCompleted || outcome == .scanDegradedToPhoto {
                    // Updated timestamps already persisted by the flow.
                    // Just refresh rank/stat triggers that might care.
                    Task { await model.refreshRanksAndStats() }
                }
            }
            .environmentObject(services)
        }
        .background(
            EmptyView()
                .fullScreenCover(isPresented: $showRoutinePlayer) {
                    ZStack {
                        if let dailyQuestRewardSequence {
                            WorkoutRewardSequenceView(summary: dailyQuestRewardSequence) {
                                UnboundHaptics.medium()
                                self.dailyQuestRewardSequence = nil
                                showRoutinePlayer = false
                                Task { await model.refreshRanksAndStats() }
                            }
                            .interactiveDismissDisabled(true)
                        } else if let pendingRecord = pendingDailyQuestCompletionRecord,
                                  dailyQuestCompletionError != nil {
                            dailyQuestRetryOverlay(record: pendingRecord)
                        } else if isCompletingDailyQuest {
                            dailyQuestCompletionOverlay
                        } else {
                            RoutinePlayerView(routine: activeRoutine) { record in
                                let stableRecord = pendingDailyQuestCompletionRecord ?? record
                                pendingDailyQuestCompletionRecord = stableRecord
                                Task { await completeDailyQuest(stableRecord) }
                            }
                            .environmentObject(services)
                        }
                    }
                }
        )
        .sheet(isPresented: $showingNotificationSettings) {
            NavigationStack {
                NotificationSettingsView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(L10n.string("common.done", defaultValue: "Done")) {
                                showingNotificationSettings = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingBodyWeightLog) {
            BodyWeightLogSheet(
                initialWeightKg: model.latestBodyWeightKg,
                unit: selectedWeightUnit,
                isSaving: model.isSavingBodyWeight,
                errorMessage: model.bodyWeightSaveError,
                onSave: { weightKg, note in
                    let saved = await model.saveBodyWeight(weightKg: weightKg, note: note)
                    if saved {
                        bodyWeightJustLogged = true
                        showingBodyWeightLog = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                            showingBodyWeightHistory = true
                        }
                        UnboundHaptics.medium()
                    }
                }
            )
            .presentationDetents([.height(430), .medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingBodyWeightHistory, onDismiss: {
            bodyWeightJustLogged = false
        }) {
            NavigationStack {
                BodyWeightHistoryScreen(
                    logs: model.bodyWeightLogs,
                    latestWeightKg: model.latestBodyWeightKg,
                    unit: selectedWeightUnit,
                    didJustLog: bodyWeightJustLogged,
                    onLog: {
                        showingBodyWeightHistory = false
                        model.bodyWeightSaveError = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            showingBodyWeightLog = true
                        }
                    }
                )
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingShop) {
            NavigationStack {
                ShopView()
                    .environmentObject(services)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingBackdropPicker) {
            NavigationStack {
                BackdropPickerView(initialSurface: .home) {
                    showingBackdropPicker = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                        showingShop = true
                    }
                }
                .environmentObject(services)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showRankLibrary) {
            NavigationStack {
                ProgramRankLibraryView()
                    .environmentObject(services)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(L10n.string("common.done", defaultValue: "Done")) {
                                showRankLibrary = false
                            }
                        }
                    }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showRankInfo) {
            // Rank-trial gate details live HERE now (moved off the profile's
            // ⓘ). Starting a trial reuses the home workout-ready cover.
            RankInfoSheet(
                currentTier: model.aggregateTier,
                readiness: model.overallRankTrialReadiness,
                progress: OverallRankTrialStore.shared.load(userId: services.auth.currentUserId ?? "anonymous")
            ) { definition in
                showRankInfo = false
                let userId = services.auth.currentUserId ?? "anonymous"
                let readiness = model.overallRankTrialReadiness
                let resolvedTrial = readiness?.resolvedTrial?.definitionId == definition.id
                    ? readiness?.resolvedTrial
                    : nil
                workoutReadyDraft = OverallRankTrialRunner.shared.draft(
                    for: definition,
                    userId: userId,
                    resolvedTrial: resolvedTrial,
                    bodyweightKg: model.profile?.weightKg
                )
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onReceive(NotificationCenter.default.publisher(for: .requestOpenRankInfo)) { _ in
            showRankInfo = true
        }
        .fullScreenCover(isPresented: $showScanCaptureFlow, onDismiss: {
            // Refresh cadence after a scan completes
            guard let userId = services.auth.currentUserId else { return }
            let history = (try? ScanCheckpointStore.shared.history(userId: userId)) ?? []
            model.lastScanAt = history.last?.createdAt
            model.scanCadence = ScanCadenceState.compute(lastScanAt: model.lastScanAt, now: .now)
        }) {
            PhotoCaptureFlow(mode: .scan) { _ in
                showScanCaptureFlow = false
            }
            .environmentObject(services)
        }
        .nodeUnlockOverlay()
        .weightBumpToast()
        .tierUnlockToast()
        .attributeRankUpToast()
        .trialCapstoneToast()
        .sheet(isPresented: $showTrialPicker) {
            TrialPickerSheet(
                cards: model.trialsState.currentWeekCards,
                onPick: { card in
                    guard let userId = services.auth.currentUserId else { return }
                    services.trials.pickVowCard(card, userId: userId)
                    model.trialsState = services.trials.state(userId: userId)
                },
                onSkip: {
                    guard let userId = services.auth.currentUserId else { return }
                    services.trials.skipThisWeek(userId: userId)
                    model.trialsState = services.trials.state(userId: userId)
                }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .weeklyVowCompleted)) { _ in
            if let userId = services.auth.currentUserId {
                model.trialsState = services.trials.state(userId: userId)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .weeklyVowWeekRolled)) { _ in
            if let userId = services.auth.currentUserId {
                model.trialsState = services.trials.state(userId: userId)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .weeklyVowWindowOpen)) { _ in
            if let userId = services.auth.currentUserId {
                model.trialsState = services.trials.state(userId: userId)
            }
        }
    }

    // MARK: - Top bar

}
