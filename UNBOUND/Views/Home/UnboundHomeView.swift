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
// Reads SessionXPService for streak, AttributeService for the six axes,
// RankService for aggregate rank, WorkoutLogService for the recap line.

struct UnboundHomeView: View {
    @EnvironmentObject var services: ServiceContainer
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    @ObservedObject var photoStore = ProfilePhotoStore.shared
    @StateObject var walletStore = CurrencyWalletStore.shared
    @StateObject var shopInventoryStore = ShopInventoryStore.shared
    @State var equippedShopProfileBorder: ShopProfileBorderID?
    @State var equippedHomeBackdrop: ShopItem?

    // Profile + program
    @State var profile: UserProfile?
    @State var program: TrainingProgram?
    @State var bodyWeightLogs: [BodyWeightLog] = []
    @State var isLoading = true
    @AppStorage(WeightPlatePolicy.unitDefaultsKey) var weightUnitRaw: String = TrainingWeightUnit.localeDefault.rawValue

    // Sessions / XP
    @State var overallLevel: OverallLevelProgress?
    @AppStorage("unbound.streakDays") var streakDays: Int = 0
    @AppStorage("unbound.lastPhotoTimestamp") var lastPhotoTimestamp: Double = 0
    @AppStorage("unbound.lastSessionDate") var lastSessionTimestamp: Double = 0
    @State var sessionXP: SessionXPRecord?

    // Ranking + stats
    @State var aggregateRank: RankTier = .initiate
    @State var aggregateTier: SkillTier = .initiate
    @State var overallRankTrialReadiness: OverallRankTrialReadiness?

    // Contextual triggers
    @State var plateaus: [PlateauedExercise] = []
    @State var calibrationSkipRatio: Double = 0
    @State var hasLoggedAnyWorkout: Bool = false
    @State var lastLog: WorkoutLog?
    @State var weekSessionDays: Set<Int> = [] // Mon=1...Sun=7
    @State var bodyRegionLoads: [BodyRegion: Double] = [:]

    // Modal state
    @State var workoutReadyDraft: TrainingSessionDraft?
    @State var showingCalibrationWorkout = false
    // navigateToCoach removed — replaced by CoachModesStrip
    @State var showingNotificationSettings = false
    @State var showingBodyWeightLog = false
    @State var showingBodyWeightHistory = false
    @State var showingShop = false
    @State var showingBackdropPicker = false
    @State var bodyWeightJustLogged = false
    @State var isSavingBodyWeight = false
    @State var bodyWeightSaveError: String?

    // Attribute profile (Phase 8+)
    @State var attributeProfile: AttributeProfile = AttributeProfile.empty(userId: "", at: .now)

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

    // Travel override (user hit the TRAVEL coach action)
    @State var activeTravelOverride: TravelOverride?

    // Scan cadence — drives ScanDueCard visibility
    @State var scanCadence: ScanCadenceState = .compute(lastScanAt: nil, now: .now)
    @State var lastScanAt: Date? = nil
    @State var showScanCaptureFlow = false

    // Weekly Vows
    @State var trialsState: TrialsState = .empty
    @State var showTrialPicker = false

    // Level derivation reads the XP-backed OverallLevelProgress.
    var lvlValue: Int { overallLevel?.level ?? 0 }
    var lvlFraction: Double { overallLevel?.progressToNextLevel ?? 0 }
    var lvlTotalXP: Int { Int(overallLevel?.totalXP ?? 0) }
    var lvlXPInLevel: Int {
        guard let p = overallLevel else { return 0 }
        return max(0, Int(p.totalXP - OverallLevelCurve.xpRequired(forLevel: p.level)))
    }
    var lvlXPForLevel: Int {
        let lvl = overallLevel?.level ?? 0
        return max(1, Int(OverallLevelCurve.xpRequired(forLevel: lvl + 1) - OverallLevelCurve.xpRequired(forLevel: lvl)))
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

            if isLoading {
                HomeLoadingSkeleton()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 14) {
                            topBar
                            homeBriefing
                        }
                        .homeLegibilityPlane(cornerRadius: 24, horizontalPadding: 14, verticalPadding: 14)
                        trainingConsole
                        homeControlSurface
                            .homeLegibilityPlane(cornerRadius: 22, horizontalPadding: 14, verticalPadding: 10)
                        BodyLoadHeatmapView(loads: bodyRegionLoads, plannedRegions: todayPlannedBodyRegions)
                            .homeLegibilityPlane(cornerRadius: 22, horizontalPadding: 14, verticalPadding: 0)
                        contextualStack
                        lastSessionRecap
                        Spacer().frame(height: 118)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
            }
        }
        .task { await load() }
        .tierBloomToast()
        .onReceive(NotificationCenter.default.publisher(for: .rankAdvanced)) { _ in
            Task { await refreshRanksAndStats() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .skillTierAdvanced)) { _ in
            if let userId = services.auth.currentUserId {
                Task {
                    aggregateTier = await services.rank.aggregateTier(userId: userId)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sessionXPUpdated)) { _ in
            Task {
                await refreshSessionXP()
                await refreshRanksAndStats()
                await refreshRecentTrainingSignals()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .attributeRankUp)) { _ in
            if let userId = services.auth.currentUserId {
                attributeProfile = services.attribute.profile(userId: userId)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .shopInventoryChanged)) { _ in
            equippedShopProfileBorder = shopInventoryStore.equippedProfileBorder()
            equippedHomeBackdrop = shopInventoryStore.equippedBackdrop(for: .home)
        }
        .fullScreenCover(isPresented: $showingCalibrationWorkout, onDismiss: {
            Task { await refreshCalibrationState() }
        }) {
            CalibrationWorkoutView(onComplete: { calibrationSkipRatio = 0 })
                .environmentObject(services)
        }
        .fullScreenCover(item: $workoutReadyDraft, onDismiss: {
            workoutReadyDraft = nil
            Task { await refreshWorkoutCompletionState() }
        }) { draft in
            WorkoutReadyView(draft: draft)
                .environmentObject(services)
        }
        .fullScreenCover(item: $captureMode) { mode in
            PhotoCaptureFlow(mode: mode) { outcome in
                captureMode = nil
                if outcome == .photoSaved || outcome == .scanCompleted || outcome == .scanDegradedToPhoto {
                    // Updated timestamps already persisted by the flow.
                    // Just refresh rank/stat triggers that might care.
                    Task { await refreshRanksAndStats() }
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
                                Task { await refreshRanksAndStats() }
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
                initialWeightKg: latestBodyWeightKg,
                unit: selectedWeightUnit,
                isSaving: isSavingBodyWeight,
                errorMessage: bodyWeightSaveError,
                onSave: { weightKg, note in
                    await saveBodyWeight(weightKg: weightKg, note: note)
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
                    logs: bodyWeightLogs,
                    latestWeightKg: latestBodyWeightKg,
                    unit: selectedWeightUnit,
                    didJustLog: bodyWeightJustLogged,
                    onLog: {
                        showingBodyWeightHistory = false
                        bodyWeightSaveError = nil
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
        .fullScreenCover(isPresented: $showScanCaptureFlow, onDismiss: {
            // Refresh cadence after a scan completes
            guard let userId = services.auth.currentUserId else { return }
            let history = (try? ScanCheckpointStore.shared.history(userId: userId)) ?? []
            lastScanAt = history.last?.createdAt
            scanCadence = ScanCadenceState.compute(lastScanAt: lastScanAt, now: .now)
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
                cards: trialsState.currentWeekCards,
                onPick: { card in
                    guard let userId = services.auth.currentUserId else { return }
                    services.trials.pickVowCard(card, userId: userId)
                    trialsState = services.trials.state(userId: userId)
                },
                onSkip: {
                    guard let userId = services.auth.currentUserId else { return }
                    services.trials.skipThisWeek(userId: userId)
                    trialsState = services.trials.state(userId: userId)
                }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .weeklyVowCompleted)) { _ in
            if let userId = services.auth.currentUserId {
                trialsState = services.trials.state(userId: userId)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .weeklyVowWeekRolled)) { _ in
            if let userId = services.auth.currentUserId {
                trialsState = services.trials.state(userId: userId)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .weeklyVowWindowOpen)) { _ in
            if let userId = services.auth.currentUserId {
                trialsState = services.trials.state(userId: userId)
            }
        }
    }

    // MARK: - Top bar

}
