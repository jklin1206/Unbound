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
//   1. Top bar       — UNBOUND wordmark + flame streak chip + bell
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

    @ObservedObject private var photoStore = ProfilePhotoStore.shared

    // Profile + program
    @State private var profile: UserProfile?
    @State private var program: TrainingProgram?
    @State private var bodyWeightLogs: [BodyWeightLog] = []
    @State private var isLoading = true
    @AppStorage(WeightPlatePolicy.unitDefaultsKey) private var weightUnitRaw: String = TrainingWeightUnit.localeDefault.rawValue

    // Sessions / XP
    @State private var overallLevel: OverallLevelProgress?
    @AppStorage("unbound.streakDays") private var streakDays: Int = 0
    @AppStorage("unbound.lastPhotoTimestamp") private var lastPhotoTimestamp: Double = 0
    @AppStorage("unbound.lastSessionDate") private var lastSessionTimestamp: Double = 0
    @State private var sessionXP: SessionXPRecord?

    // Ranking + stats
    @State private var aggregateRank: RankTier = .initiate
    @State private var aggregateTier: SkillTier = .initiate
    @State private var overallRankTrialReadiness: OverallRankTrialReadiness?

    // Contextual triggers
    @State private var plateaus: [PlateauedExercise] = []
    @State private var calibrationSkipRatio: Double = 0
    @State private var hasLoggedAnyWorkout: Bool = false
    @State private var lastLog: WorkoutLog?
    @State private var weekSessionDays: Set<Int> = [] // Mon=1...Sun=7
    @State private var bodyRegionLoads: [BodyRegion: Double] = [:]

    // Modal state
    @State private var workoutReadyDraft: TrainingSessionDraft?
    @State private var showingCalibrationWorkout = false
    // navigateToCoach removed — replaced by CoachModesStrip
    @State private var showingNotificationSettings = false
    @State private var showingBodyWeightLog = false
    @State private var showingBodyWeightHistory = false
    @State private var bodyWeightJustLogged = false
    @State private var isSavingBodyWeight = false
    @State private var bodyWeightSaveError: String?

    // Attribute profile (Phase 8+)
    @State private var attributeProfile: AttributeProfile = AttributeProfile.empty(userId: "", at: .now)

    // Ambient animation state
    @State private var rankGlowRadius: CGFloat = 6
    @State private var streakFlameRadius: CGFloat = 3
    @State private var xpShimmerPhase: CGFloat = -1
    @State private var statsRendered = false

    // Daily Quest — launches the same canonical routine completion path as
    // the routine library. Rotation service lands later; fixed entry for now.
    @State private var activeRoutine: RoutineDef = Self.defaultDailyQuestRoutine
    @State private var showRoutinePlayer = false
    @State private var dailyQuestRewardSequence: WorkoutRewardSequenceSummary?
    @State private var isCompletingDailyQuest = false
    @State private var pendingDailyQuestCompletionRecord: RoutineCompletionRecord?
    @State private var dailyQuestCompletionError: String?

    // Photo/Scan capture flow presentation
    @State private var captureMode: PhotoCaptureFlow.Mode?

    // Travel override (user hit the TRAVEL coach action)
    @State private var activeTravelOverride: TravelOverride?

    // Scan cadence — drives ScanDueCard visibility
    @State private var scanCadence: ScanCadenceState = .compute(lastScanAt: nil, now: .now)
    @State private var lastScanAt: Date? = nil
    @State private var showScanCaptureFlow = false

    // Weekly Vows
    @State private var trialsState: TrialsState = .empty
    @State private var showTrialPicker = false

    // Level derivation reads the XP-backed OverallLevelProgress.
    private var lvlValue: Int { overallLevel?.level ?? 0 }
    private var lvlFraction: Double { overallLevel?.progressToNextLevel ?? 0 }
    private var lvlTotalXP: Int { Int(overallLevel?.totalXP ?? 0) }
    private var lvlXPInLevel: Int {
        guard let p = overallLevel else { return 0 }
        return max(0, Int(p.totalXP - OverallLevelCurve.xpRequired(forLevel: p.level)))
    }
    private var lvlXPForLevel: Int {
        let lvl = overallLevel?.level ?? 0
        return max(1, Int(OverallLevelCurve.xpRequired(forLevel: lvl + 1) - OverallLevelCurve.xpRequired(forLevel: lvl)))
    }

    private static let defaultDailyQuestRoutine: RoutineDef = {
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

            if isLoading {
                HomeLoadingSkeleton()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        topBar
                        homeBriefing
                        trainingConsole
                        homeStatusPanel
                        BodyLoadHeatmapView(loads: bodyRegionLoads, plannedRegions: todayPlannedBodyRegions)
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
    }

    // MARK: - Top bar

    private var topBar: some View {
        let level = lvlValue
        return HStack(alignment: .center, spacing: 10) {
            avatarBadge(level: level)

            VStack(alignment: .leading, spacing: 2) {
                Text("UNBOUND")
                    .font(Font.unbound.captionS.weight(.black))
                    .tracking(2.0)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text(archetypeName.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.3)
                    .foregroundStyle(Color.unbound.textTertiary)
            }

            Spacer()

            streakChip

            Button {
                UnboundHaptics.soft()
                showingNotificationSettings = true
            } label: {
                Image(systemName: "bell")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(height: 44)
    }

    // MARK: - Briefing

    private var homeBriefing: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(briefingTitle)
                    .font(.system(size: 31, weight: .black))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: 10)

                Text(shortDayString())
                    .font(Font.unbound.monoS.weight(.semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
                    .monospacedDigit()
            }

            Text(briefingCopy)
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
                .frame(maxWidth: 330, alignment: .leading)
        }
        .padding(.top, 2)
    }

    // MARK: - Premium Home Concept

    private var trainingConsole: some View {
        let day = todayProgramDay
        let workout = day?.workout
        let isRest = day?.isRestDay ?? false
        let canStart = workout != nil && !isRest
        let tint = protocolTint(canStart: canStart, isRest: isRest)
        let title = workout?.name ?? (isRest ? "Recovery Protocol" : "Plan Session")
        let minutes = workout?.estimatedMinutes ?? (isRest ? 18 : 30)
        let focus = workout?.targetMuscleGroups.first?.displayName.uppercased() ?? (isRest ? "RECOVERY" : "CUSTOM")
        let planValue = workout.map { "\($0.mainExercises.count) MOVES" } ?? (isRest ? "REST" : "OPEN")

        return ZStack(alignment: .topTrailing) {
            ProtocolHeroBackground(tint: tint)

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            protocolStatusPill(label: "TODAY STATUS", value: todayStatusValue, tint: tint)
                            Text(focus)
                                .font(Font.unbound.captionS.weight(.bold))
                                .tracking(1.4)
                                .foregroundStyle(Color.unbound.textTertiary)
                                .lineLimit(1)
                        }

                        Text(title)
                            .font(.system(size: 33, weight: .black))
                            .foregroundStyle(Color.unbound.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.58)

                        Text(protocolHeroSubtitle(workout: workout, isRest: isRest))
                            .font(Font.unbound.bodyM)
                            .foregroundStyle(Color.unbound.textSecondary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.76)
                    }

                    Spacer(minLength: 0)

                    integratedRankRail
                }

                HStack(spacing: 8) {
                    protocolMetaTile(label: "DAY", value: programDayLabel, tint: tint)
                    protocolMetaTile(label: "TIME", value: "\(minutes)M", tint: tint)
                    protocolMetaTile(label: "PLAN", value: planValue, tint: tint)
                }

                Button {
                    UnboundHaptics.medium()
                    if canStart {
                        beginTodaySession()
                    } else if isRest {
                        captureMode = .photo
                    } else {
                        NotificationCenter.default.post(name: .requestNavigateToProgramTab, object: nil)
                    }
                } label: {
                    HStack(spacing: 11) {
                        Text(protocolPrimaryLabel(canStart: canStart, isRest: isRest).uppercased())
                            .font(Font.unbound.bodyMStrong)
                            .tracking(1.4)
                        Image(systemName: canStart ? "arrow.right" : (isRest ? "camera.fill" : "calendar.badge.plus"))
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(Color.unbound.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(tint)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                    )
                    .shadow(color: tint.opacity(0.22), radius: 18, y: 8)
                }
                .buttonStyle(.plain)
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.16),
                            tint.opacity(0.28),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: Color.black.opacity(0.28), radius: 24, y: 14)
    }

    private var integratedRankRail: some View {
        let level = lvlValue
        let xpInLevel = lvlXPInLevel
        let fraction = lvlFraction
        let rankColor = aggregateRank.rewardTint

        return VStack(alignment: .trailing, spacing: 8) {
            Text(aggregateTier.displayName.uppercased())
                .font(Font.unbound.captionS.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(rankColor)
            Text("LVL \(level)")
                .font(Font.unbound.monoM.weight(.semibold))
                .foregroundStyle(Color.unbound.textPrimary)
                .monospacedDigit()
            GeometryReader { proxy in
                ZStack(alignment: .bottom) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(rankColor)
                        .frame(height: max(8, proxy.size.height * fraction))
                        .shadow(color: rankColor.opacity(0.35), radius: 8)
                }
            }
            .frame(width: 5, height: 58)
            Text("\(xpInLevel)/\(lvlXPForLevel) XP")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.unbound.textTertiary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(width: 76, alignment: .trailing)
    }

    /// Streak countdown chip: how long until the streak breaks (Liftoff rule —
    /// log a workout within 3 days). nil when there's no active streak.
    private var streakCountdown: (text: String, urgent: Bool, safe: Bool)? {
        guard let xp = sessionXP, xp.currentStreak > 0 else { return nil }
        if xp.loggedToday() { return ("LOGGED TODAY", false, true) }
        guard let left = xp.streakDaysRemaining() else { return nil }
        if left <= 0 { return ("LOG TODAY", true, false) }
        return ("\(left)D LEFT", left <= 1, false)
    }

    private var weekPath: some View {
        let todayIndex = ((Calendar.current.component(.weekday, from: Date()) + 5) % 7) + 1
        let currentStreak = sessionXP?.currentStreak ?? streakDays
        let completedCount = weekSessionDays.count
        let weekdayLabels = ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]

        return HStack(alignment: .center, spacing: 16) {
            ZStack(alignment: .leading) {
                StreakSlashShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.unbound.ember.opacity(0.36),
                                Color.unbound.ember.opacity(0.08)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 108, height: 62)
                    .offset(x: -12)

                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text("\(currentStreak)")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                    Text(currentStreak == 1 ? "DAY" : "DAYS")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.ember)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                }
                .layoutPriority(1)
            }

            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Text("IGNITION")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1.7)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .lineLimit(1)
                    Text("\(completedCount)/7")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(Color.unbound.ember)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    if let cd = streakCountdown {
                        Text(cd.text)
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .tracking(1.0)
                            .foregroundStyle(cd.urgent ? Color.unbound.alert : (cd.safe ? Color.unbound.rankGreen : Color.unbound.ember))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill((cd.urgent ? Color.unbound.alert : (cd.safe ? Color.unbound.rankGreen : Color.unbound.ember)).opacity(0.14))
                            )
                    }
                }

                HStack(alignment: .bottom, spacing: 5) {
                    ForEach(0..<7, id: \.self) { index in
                        weekHeatFlame(
                            dayLabel: weekdayLabels[index],
                            hasSession: weekSessionDays.contains(index + 1),
                            isToday: (index + 1) == todayIndex
                        )
                    }
                }
                .frame(height: 44, alignment: .bottom)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
    }

    private func weekHeatFlame(dayLabel: String, hasSession: Bool, isToday: Bool) -> some View {
        let flameColor = hasSession
            ? Color.unbound.ember
            : (isToday ? Color.unbound.ember.opacity(0.82) : Color.unbound.textTertiary.opacity(0.48))
        let labelColor = isToday ? Color.unbound.textPrimary : Color.unbound.textTertiary

        return VStack(spacing: 3) {
            ZStack {
                Circle()
                    .fill(isToday ? Color.unbound.ember.opacity(0.13) : Color.clear)
                    .frame(width: 28, height: 28)

                Image(systemName: hasSession ? "flame.fill" : "flame")
                    .font(.system(size: hasSession ? 22 : 19, weight: .black))
                    .foregroundStyle(flameColor)
                    .shadow(
                        color: hasSession ? Color.unbound.ember.opacity(0.48) : Color.clear,
                        radius: hasSession ? 7 : 0,
                        y: hasSession ? 2 : 0
                    )

                if hasSession {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(Color.unbound.rankGold.opacity(0.92))
                        .offset(y: 4)
                }
            }
            .frame(width: 28, height: 28)

            Text(dayLabel)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(0.7)
                .foregroundStyle(labelColor)
                .lineLimit(1)
        }
        .frame(width: 28)
        .accessibilityLabel("\(dayLabel) \(hasSession ? "lit" : "unlit")")
            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: hasSession)
            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: isToday)
    }

    private var rankMomentumCard: some View {
        let level = lvlValue
        let fraction = lvlFraction
        let rankColor = aggregateRank.rewardTint

        return HStack(alignment: .center, spacing: 14) {
            TierBadge(tier: aggregateRank)
                .frame(width: 62, height: 62)

            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Text("RANK MOMENTUM")
                        .font(Font.unbound.captionS.weight(.bold))
                        .tracking(1.7)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Spacer(minLength: 0)
                    Text("LVL \(level)")
                        .font(Font.unbound.monoS.weight(.semibold))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .monospacedDigit()
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(tierName(for: aggregateRank).uppercased())
                        .font(Font.unbound.titleS)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text(nextRankMomentumLabel(for: aggregateRank))
                        .font(Font.unbound.monoS.weight(.semibold))
                        .tracking(1.0)
                        .foregroundStyle(rankColor)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.unbound.bg.opacity(0.7))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [rankColor, Color.unbound.impact.opacity(0.9)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(6, proxy.size.width * fraction))
                            .overlay(
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.clear, .white.opacity(0.45), .clear],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: 24)
                                    .offset(x: xpShimmerPhase * max(6, proxy.size.width * fraction))
                                    .blendMode(.plusLighter)
                            )
                            .clipShape(Capsule())
                    }
                }
                .frame(height: 5)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.unbound.surface)
                DiagonalAccentShape()
                    .fill(rankColor.opacity(0.10))
                    .frame(width: 150)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .allowsHitTesting(false)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private var dailyQuestBand: some View {
        let categoryColor = questColor

        return Button {
            UnboundHaptics.medium()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(categoryColor.opacity(0.16))
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(categoryColor)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text("DAILY QUEST")
                        .font(Font.unbound.captionS.weight(.bold))
                        .tracking(1.6)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text(activeRoutine.title)
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

                Spacer(minLength: 0)

                Text("PROOF-GATED XP")
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(categoryColor)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(categoryColor.opacity(0.24), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func protocolTint(canStart: Bool, isRest: Bool) -> Color {
        canStart ? Color.unbound.accent : (isRest ? Color.unbound.coachCyan : Color.unbound.ember)
    }

    private var todayStatusValue: String {
        if !plateaus.isEmpty { return "WATCH" }
        if shouldShowCalibrationCard { return "CALIBRATE" }
        if todayProgramDay?.isRestDay == true { return "REST" }
        if todayProgramDay?.workout != nil { return "TRAIN" }
        return "PLAN"
    }

    private var programDayLabel: String {
        guard let day = todayProgramDay else { return "No program" }
        let total = program?.days.count ?? 28
        if day.dayNumber > 0 {
            return "Day \(day.dayNumber) / \(max(total, day.dayNumber))"
        }
        return "Travel day"
    }

    private func protocolHeroSubtitle(workout: Workout?, isRest: Bool) -> String {
        if let workout {
            return "\(workout.mainExercises.count) movements are queued. Start clean and log the sets that matter."
        }
        if isRest {
            return "Recovery is scheduled. Keep the check-in light and come back fresh."
        }
        return "No session is queued. Pick today's work before you train."
    }

    private func protocolPrimaryLabel(canStart: Bool, isRest: Bool) -> String {
        if canStart { return "Begin Session" }
        return isRest ? "Log Check-In" : "Plan Session"
    }

    private func protocolMetaTile(label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textTertiary)
            Text(value)
                .font(Font.unbound.monoS.weight(.bold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.74)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
        )
    }

    private var questColor: Color {
        activeRoutine.category.color
    }

    private func protocolStatusPill(label: String, value: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(Font.unbound.captionS.weight(.bold))
                .tracking(1.6)
                .foregroundStyle(Color.unbound.textTertiary)
            Text(value)
                .font(Font.unbound.monoS.weight(.bold))
                .foregroundStyle(tint)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(tint.opacity(0.12)))
        .overlay(Capsule().strokeBorder(tint.opacity(0.30), lineWidth: 1))
    }

    private var progressionSnapshot: some View {
        let level = lvlValue
        let fraction = lvlFraction
        let rankColor = aggregateRank.rewardTint

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                TierBadge(tier: aggregateRank, compact: true)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Text(tierName(for: aggregateRank).uppercased())
                            .font(Font.unbound.captionS.weight(.bold))
                            .tracking(1.6)
                            .foregroundStyle(rankColor)
                        Text("LVL \(level)")
                            .font(Font.unbound.monoS.weight(.semibold))
                            .foregroundStyle(Color.unbound.textSecondary)
                            .monospacedDigit()
                    }

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.unbound.borderSubtle)
                            Capsule()
                                .fill(rankColor)
                                .frame(width: max(4, proxy.size.width * fraction))
                                .overlay(
                                    Rectangle()
                                        .fill(
                                            LinearGradient(
                                                colors: [.clear, .white.opacity(0.45), .clear],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: 22)
                                        .offset(x: xpShimmerPhase * max(4, proxy.size.width * fraction))
                                        .blendMode(.plusLighter)
                                )
                                .clipShape(Capsule())
                        }
                    }
                    .frame(height: 4)
                }

            }

        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private func miniStatPill(label: String, rank: RankTier) -> some View {
        let tint = rank.rewardTint
        return HStack(spacing: 5) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(1.0)
                .foregroundStyle(Color.unbound.textTertiary)
            Text(rank.displayName.uppercased())
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.66)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.74)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(tint.opacity(0.10))
        )
    }

    private var briefingTitle: String {
        if let name = profile?.displayName,
           !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Move, \(name.components(separatedBy: " ").first ?? name)"
        }
        return "Move today"
    }

    private var briefingCopy: String {
        if let day = todayProgramDay {
            if day.isRestDay {
                return "Recovery is scheduled. Keep the arc alive with a scan, a photo, or a low-friction quest."
            }
            if let workout = day.workout {
                return "\(workout.name) is ready. \(workout.mainExercises.count) main lifts, about \(workout.estimatedMinutes) minutes."
            }
        }
        return "No session is queued. Open Program to plan today's work or use a quick action below."
    }

    /// Placeholder avatar: initials in a chamfered charcoal circle with a
    /// small violet LVL chip overlapping the bottom-right. Swap to the real
    /// user photo once the scan pipeline feeds it in. Frame derives from
    /// the user's currently equipped rank-tier cosmetic.
    private func avatarBadge(level: Int) -> some View {
        let letter = avatarInitial
        return HStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                CosmeticAvatar(
                    tier: aggregateRank,
                    size: 44,
                    image: photoStore.image(userId: services.auth.currentUserId ?? ""),
                    letterFallback: letter
                )

                Text("\(level)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .monospacedDigit()
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        Capsule()
                            .fill(Color.unbound.accent)
                    )
                    .offset(x: 4, y: 4)
            }
            .shadow(color: Color.unbound.accent.opacity(0.35), radius: 6)
        }
    }

    private var avatarInitial: String {
        if let name = profile?.displayName, let first = name.first {
            return String(first).uppercased()
        }
        return "U"
    }

    private var streakChip: some View {
        let streak = sessionXP?.currentStreak ?? 0
        let fireOrange = Color(red: 0.97, green: 0.45, blue: 0.09)
        let fireRed = Color(red: 0.94, green: 0.27, blue: 0.27)
        let fireGradient = LinearGradient(
            colors: [fireOrange, fireRed],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        return HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(fireGradient)
                .shadow(color: fireOrange.opacity(0.55), radius: streakFlameRadius)
            Text("\(streak)")
                .font(Font.unbound.titleS)
                .foregroundStyle(Color.unbound.textPrimary)
                .monospacedDigit()
            Text(streak == 1 ? "DAY" : "DAYS")
                .font(Font.unbound.captionS.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(fireOrange)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(fireOrange.opacity(0.14))
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [fireOrange.opacity(0.55), fireRed.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: fireOrange.opacity(0.25), radius: 8)
    }

    // MARK: - Bodyweight quick log

    private var homeStatusPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            weekPath
            bodyWeightQuickLogRow
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.unbound.surface.opacity(0.42))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.unbound.borderSubtle.opacity(0.65))
                .frame(height: 0.5)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.unbound.borderSubtle.opacity(0.45))
                .frame(height: 0.5)
        }
    }

    private var bodyWeightQuickLogRow: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                UnboundHaptics.medium()
                showingBodyWeightHistory = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: hasLoggedBodyWeightToday ? "checkmark.circle.fill" : "scalemass.fill")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(bodyWeightStatusColor)
                        .frame(width: 24, height: 24)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text(bodyWeightValueText)
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundStyle(Color.unbound.textPrimary)
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)

                            Text(selectedWeightUnit.shortLabel.uppercased())
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .tracking(0.8)
                                .foregroundStyle(Color.unbound.textSecondary)
                        }

                        Text(bodyWeightRecencyText)
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(bodyWeightStatusColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open bodyweight history")

            Button {
                bodyWeightSaveError = nil
                UnboundHaptics.medium()
                showingBodyWeightLog = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: hasLoggedBodyWeightToday ? "checkmark" : "plus")
                        .font(.system(size: 10, weight: .black))
                    Text(hasLoggedBodyWeightToday ? "LOGGED" : "LOG")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(1.0)
                }
                .foregroundStyle(Color.unbound.textPrimary)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(
                    Capsule()
                        .fill(bodyWeightStatusColor.opacity(hasLoggedBodyWeightToday ? 0.20 : 0.92))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(bodyWeightStatusColor.opacity(0.40), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Log bodyweight")
        }
        .padding(.vertical, 11)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.unbound.borderSubtle.opacity(0.62))
                .frame(height: 0.5)
        }
    }

    // MARK: - Contextual stack

    @ViewBuilder
    private var contextualStack: some View {
        VStack(spacing: 12) {
            RecalibratingBanner()

            if shouldShowCalibrationCard {
                DayOneCalibrationCard(style: .slim) {
                    UnboundHaptics.medium()
                    showingCalibrationWorkout = true
                }
            }

            if shouldShowRankGatePulse,
               let overallRankTrialReadiness {
                rankGatePulseCard(overallRankTrialReadiness)
            }

            // ── Weekly Vow status card ─────────────────────────────
            if let activeTrial = trialsState.currentTrial,
               activeTrial.capstoneState != .missed {
                ActiveTrialCard(trial: activeTrial)
            } else if !trialsState.skippedCurrentWeek && !trialsState.currentWeekCards.isEmpty {
                TrialPickerPromptCard {
                    showTrialPicker = true
                }
            }
        }
    }

    private var shouldShowRankGatePulse: Bool {
        guard let readiness = overallRankTrialReadiness,
              readiness.definition != nil
        else { return false }
        return true
    }

    private func rankGatePulseCard(_ readiness: OverallRankTrialReadiness) -> some View {
        let tint = rankGatePulseTint(readiness)
        let target = readiness.targetRank?.displayName ?? "Title"
        let metCount = readiness.requirements.filter(\.isMet).count
        let totalCount = max(1, readiness.requirements.count)

        return Button {
            UnboundHaptics.soft()
            NotificationCenter.default.post(name: .requestNavigateToProfileRankGate, object: nil)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tint.opacity(0.14))
                    Image(systemName: "seal.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(tint)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Text("RANK TRIAL")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .tracking(1.5)
                            .foregroundStyle(Color.unbound.textTertiary)
                        Text(rankGatePulseStatus(readiness))
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .tracking(1.0)
                            .foregroundStyle(tint)
                    }

                    Text("\(target) Trial · \(metCount)/\(totalCount) proofs")
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(rankGatePulseDetail(readiness))
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .layoutPriority(1)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(tint.opacity(0.26), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.rankGatePulse")
    }

    private func rankGatePulseStatus(_ readiness: OverallRankTrialReadiness) -> String {
        if readiness.isReady { return "READY" }
        if readiness.status == .attempted { return "REBUILD" }
        let missing = readiness.missingRequirements.count
        if missing == 1 { return "1 LEFT" }
        return "\(missing) LEFT"
    }

    private func rankGatePulseDetail(_ readiness: OverallRankTrialReadiness) -> String {
        if readiness.isReady {
            return "All proofs are in. Open Profile to run the trial."
        }
        if readiness.status == .attempted {
            return "Trial attempted. Rebuild the missing proofs before the next run."
        }
        if let closest = readiness.missingRequirements.first {
            return "Next proof: \(closest.label) · \(closest.current) of \(closest.required)"
        }
        return "Open Profile for the full trial checklist."
    }

    private func rankGatePulseTint(_ readiness: OverallRankTrialReadiness) -> Color {
        if readiness.isReady {
            return readiness.targetRank?.rewardTextTint ?? Color.unbound.accent
        }
        return Color.unbound.rankGold
    }

    // MARK: - Stats grid


    // MARK: - Last session recap (inline, no card)

    @ViewBuilder
    private var lastSessionRecap: some View {
        if let log = lastLog {
            HStack(spacing: 6) {
                Text(dayWord(for: log.startedAt))
                    .font(Font.unbound.captionS)
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text("·")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text(log.plannedWorkoutName.uppercased())
                    .font(Font.unbound.captionS)
                    .tracking(1.0)
                    .foregroundStyle(Color.unbound.textSecondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Loading

    @MainActor
    private func load() async {
        guard let userId = services.auth.currentUserId else {
            LoggingService.shared.log(
                "Home load skipped without authenticated user",
                level: .warning
            )
            isLoading = false
            return
        }
        services.badges.bind(userId: userId)

        // ── Phase 1: essentials → paint ASAP ─────────────────────────────
        // Cached program is an instant local read (no network); ranks are
        // fast; sync reads are free. A placeholder profile guarantees no
        // card renders against nil — the real profile replaces it in Phase 2.
        if let cached = loadCachedProgram(userId) { program = cached }
        profile = UserProfile(
            id: userId, email: nil, displayName: nil,
            createdAt: Date(), onboardingCompleted: true, totalScans: 0,
            currentProgramId: program?.id,
            heightCm: nil, weightKg: nil, age: nil, biologicalSex: nil
        )
        let (r0, t0) = await loadRanks(userId)
        aggregateRank = r0
        aggregateTier = t0
        sessionXP = services.sessionXP.record(userId: userId)
        calibrationSkipRatio = services.calibration.skipRatio(userId: userId)
        attributeProfile = services.attribute.profile(userId: userId)
        trialsState = services.trials.state(userId: userId)
        overallLevel = (try? await services.database.read(collection: "overall_level_progress", documentId: userId)) ?? OverallLevelProgress(userId: userId)

        isLoading = false
        // Kick off ambient loops once content is on screen.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            startAmbientAnimations()
        }

        // ── Phase 2: secondary, concurrent, streams into the cards ────────
        async let skillLoad: Void = SkillProgressService.shared.load(userId: userId)
        async let rankDecay: Void = RankDecayService.shared.evaluateOnForeground(userId: userId)
        async let plateausResult: [PlateauedExercise] = {
            let states = await ProgressionStateStore.shared.fetchAll(userId: userId)
            return await PlateauDetector.shared.detect(userId: userId, states: states)
        }()
        async let profileProgram: (UserProfile?, TrainingProgram?) = loadProfileAndProgram(userId)
        async let recentLogs: [WorkoutLog] = fetchRecentLogsSafe(userId: userId, limit: 40)
        async let weightLogs: [BodyWeightLog] = fetchBodyWeightLogsSafe(userId: userId, limit: 30)
        async let travel: TravelOverride? = TravelOverrideStore.shared.activeOverride(for: userId)

        _ = await skillLoad
        _ = await rankDecay
        plateaus = await plateausResult

        let (fetchedProfile, loadedProgram) = await profileProgram
        if let fetchedProfile {
            profile = fetchedProfile
            if let loadedProgram { program = loadedProgram }
        }

        applyRecentLogs(await recentLogs)
        bodyWeightLogs = await weightLogs
        activeTravelOverride = await travel

        let history = (try? ScanCheckpointStore.shared.history(userId: userId)) ?? []
        lastScanAt = history.last?.createdAt
        scanCadence = ScanCadenceState.compute(lastScanAt: lastScanAt, now: .now)
        overallRankTrialReadiness = await TrialReadinessService.shared.readiness(
            userId: userId,
            services: services
        )
    }

    /// Instant local program read (no network) for the Phase-1 paint.
    private func loadCachedProgram(_ userId: String) -> TrainingProgram? {
        ProgramStore.shared.loadLocal(userId: userId)
    }

    private func loadProfileAndProgram(_ userId: String) async -> (UserProfile?, TrainingProgram?) {
        do {
            let fetched: UserProfile = try await services.user.fetchProfile(userId: userId)
            let store = ProgramStore.shared
            if let programId = fetched.currentProgramId {
                // Instant local paint; revalidate is a no-op unless a new
                // programId (rollover) superseded it.
                if store.loadLocal(userId: userId)?.id == programId {
                    await store.revalidate(userId: userId, expectedProgramId: programId)
                    return (fetched, store.program)
                }
                if let existing: TrainingProgram = try? await services.database.read(
                    collection: "programs", documentId: programId) {
                    store.adopt(existing, userId: userId)
                    return (fetched, existing)
                }
                // programId present but read failed — do NOT generate on a
                // transient blip; surface no program, next load retries.
                return (fetched, nil)
            }
            // Genuine first run: no program id yet.
            let generated = try await ProgramGenerationService.shared.generateFromOnboarding(
                userId: userId,
                targetFrequency: fetched.targetFrequency,
                equipment: Set(fetched.equipment ?? []),
                experience: fetched.experience,
                sessionLength: fetched.sessionLength,
                exerciseStyles: Set(fetched.exerciseStyles ?? []),
                targetAreas: Set(fetched.targetAreas ?? []),
                age: fetched.age ?? 0,
                gender: fetched.gender ?? .unspecified,
                heightCm: fetched.heightCm ?? 0,
                weightKg: fetched.weightKg ?? 0,
                trainingDays: fetched.trainingDays,
                trainingStyleOverride: fetched.trainingStyleOverride,
                trainingFeedbackMode: fetched.trainingFeedbackMode,
                cutModeActive: fetched.cutMode.enabled,
                biologicalSex: fetched.biologicalSex
            )
            store.adopt(generated, userId: userId)
            return (fetched, generated)
        } catch {
            return (nil, nil)
        }
    }

    private func loadRanks(_ userId: String) async -> (RankTier, SkillTier) {
        async let r = services.rank.aggregateRank(userId: userId)
        async let t = services.rank.aggregateTier(userId: userId)
        return (await r, await t)
    }

    private func fetchRecentLogsSafe(userId: String, limit: Int) async -> [WorkoutLog] {
        (try? await services.workoutLog.fetchRecentLogs(userId: userId, limit: limit)) ?? []
    }

    private func fetchBodyWeightLogsSafe(userId: String, limit: Int) async -> [BodyWeightLog] {
        let logs: [BodyWeightLog] = (try? await services.database.query(
            collection: "bodyWeightLogs",
            field: "userId",
            isEqualTo: userId,
            orderBy: "loggedAt",
            descending: true,
            limit: limit
        )) ?? []
        return logs.sorted { $0.loggedAt > $1.loggedAt }
    }

    @MainActor
    private func applyRecentLogs(_ logs: [WorkoutLog]) {
        lastLog = HomeLoadDerivations.lastLog(logs)
        hasLoggedAnyWorkout = HomeLoadDerivations.hasLogged(logs)
        weekSessionDays = HomeLoadDerivations.weekSessionDays(logs.map(\.startedAt))
        bodyRegionLoads = HomeLoadDerivations.bodyRegionLoads(logs)
    }

    @MainActor
    private func refreshRanksAndStats() async {
        guard let userId = services.auth.currentUserId else { return }
        aggregateRank = await services.rank.aggregateRank(userId: userId)
        aggregateTier = await services.rank.aggregateTier(userId: userId)
    }

    @MainActor
    private func refreshTravelOverride() async {
        guard let userId = services.auth.currentUserId else { return }
        activeTravelOverride = await TravelOverrideStore.shared.activeOverride(for: userId)
    }

    @MainActor
    private func refreshRecentTrainingSignals() async {
        guard let userId = services.auth.currentUserId else { return }
        applyRecentLogs(await fetchRecentLogsSafe(userId: userId, limit: 40))
    }

    @MainActor
    private func refreshBodyWeightLogs() async {
        guard let userId = services.auth.currentUserId else { return }
        bodyWeightLogs = await fetchBodyWeightLogsSafe(userId: userId, limit: 30)
    }

    @MainActor
    private func saveBodyWeight(weightKg: Double, note: String?) async {
        guard let userId = services.auth.currentUserId else {
            bodyWeightSaveError = "Sign in before logging bodyweight."
            return
        }
        guard weightKg.isFinite, weightKg > 0 else {
            bodyWeightSaveError = "Enter a valid bodyweight."
            return
        }

        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedNote = trimmedNote?.isEmpty == false ? trimmedNote : nil
        let log = BodyWeightLog(
            userId: userId,
            weightKg: weightKg,
            loggedAt: Date(),
            note: normalizedNote
        )

        isSavingBodyWeight = true
        bodyWeightSaveError = nil
        defer { isSavingBodyWeight = false }

        do {
            try await services.database.create(log, collection: "bodyWeightLogs", documentId: log.id)
        } catch {
            bodyWeightSaveError = "Could not save bodyweight."
            LoggingService.shared.log(
                "Bodyweight log save failed: \(error)",
                level: .error,
                context: ["userId": userId]
            )
            return
        }

        do {
            try await services.user.updateProfile(userId: userId, fields: ["weightKg": weightKg])
        } catch {
            LoggingService.shared.log(
                "Profile bodyweight refresh failed: \(error)",
                level: .warning,
                context: ["userId": userId]
            )
        }

        if var currentProfile = profile {
            currentProfile.weightKg = weightKg
            profile = currentProfile
        }
        bodyWeightLogs = Array(
            ([log] + bodyWeightLogs.filter { $0.id != log.id })
                .sorted { $0.loggedAt > $1.loggedAt }
                .prefix(30)
        )
        bodyWeightJustLogged = true
        showingBodyWeightLog = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            showingBodyWeightHistory = true
        }
        UnboundHaptics.medium()
    }

    @MainActor
    private func refreshWeeklyRhythm() async {
        guard let userId = services.auth.currentUserId else { return }
        let logs = (try? await services.workoutLog.fetchRecentLogs(userId: userId, limit: 14)) ?? []
        weekSessionDays = HomeLoadDerivations.weekSessionDays(logs.map(\.startedAt))
    }

    @MainActor
    private func refreshSessionXP() async {
        guard let userId = services.auth.currentUserId else { return }
        sessionXP = services.sessionXP.record(userId: userId)
    }

    @MainActor
    private func refreshCalibrationState() async {
        guard let userId = services.auth.currentUserId else { return }
        calibrationSkipRatio = services.calibration.skipRatio(userId: userId)
        let logs = (try? await services.workoutLog.fetchRecentLogs(userId: userId, limit: 1)) ?? []
        hasLoggedAnyWorkout = !logs.isEmpty
    }

    @MainActor
    private func refreshLastLog() async {
        guard let userId = services.auth.currentUserId else { return }
        let logs = (try? await services.workoutLog.fetchRecentLogs(userId: userId, limit: 1)) ?? []
        lastLog = logs.first
        hasLoggedAnyWorkout = !logs.isEmpty
    }

    @MainActor
    private func refreshWorkoutCompletionState() async {
        await refreshSessionXP()
        await refreshRanksAndStats()
        await refreshRecentTrainingSignals()
    }

    // MARK: - Session flow

    private func beginTodaySession() {
        guard let day = todayProgramDay,
              let workout = day.workout
        else {
            NotificationCenter.default.post(name: .requestNavigateToProgramTab, object: nil)
            return
        }
        guard let userId = services.auth.currentUserId else {
            LoggingService.shared.log(
                "Today session launch skipped without authenticated user",
                level: .warning
            )
            return
        }
        workoutReadyDraft = DailyWorkoutResolver.programDraft(
            from: workout,
            userId: userId,
            programId: program?.id,
            dayNumber: day.dayNumber,
            date: Date()
        )
    }

    // MARK: - Derived

    private var archetypeName: String {
        "UNBOUND"
    }

    private var todayProgramDay: ProgramDay? {
        // Travel override short-circuits the normal rotation.
        if let override = activeTravelOverride, let tday = override.day(for: Date()) {
            return synthesizeTravelDay(from: tday, override: override)
        }
        guard let program else { return nil }
        guard !program.days.isEmpty else { return nil }
        let daysSinceStart = max(
            0,
            Calendar.current.dateComponents([.day], from: program.createdAt, to: Date()).day ?? 0
        )
        let dayIndex = daysSinceStart % program.days.count
        return program.days[dayIndex]
    }

    private func synthesizeTravelDay(from tday: TravelDay, override: TravelOverride) -> ProgramDay {
        let workout = tday.workout(summary: "Travel block: \(override.summary)")
        return ProgramDay(
            id: "travel-home",
            dayNumber: 0,
            label: tday.isRest ? "TRAVEL · REST" : "TRAVEL · \(tday.title)",
            isRestDay: tday.isRest,
            workout: workout,
            nutritionOverride: nil,
            recoveryActivities: []
        )
    }

    private var todayPlannedBodyRegions: [BodyRegion] {
        guard let day = todayProgramDay,
              !day.isRestDay,
              let workout = day.workout
        else { return [] }
        return BodyRegionTrainingLedger.loads(for: workout).map(\.region)
    }

    private var selectedWeightUnit: TrainingWeightUnit {
        TrainingWeightUnit(rawValue: weightUnitRaw) ?? .localeDefault
    }

    private var latestBodyWeightKg: Double? {
        bodyWeightLogs.first?.weightKg ?? profile?.weightKg
    }

    private var bodyWeightValueText: String {
        guard let latestBodyWeightKg else { return "--" }
        return WeightPlatePolicy.formatLoggedWeight(latestBodyWeightKg, unit: selectedWeightUnit)
    }

    private var bodyWeightRecencyText: String {
        if let loggedAt = bodyWeightLogs.first?.loggedAt {
            return "LOGGED \(dayWord(for: loggedAt))"
        }
        if latestBodyWeightKg != nil {
            return "FROM PROFILE"
        }
        return "NO ENTRIES YET"
    }

    private var hasLoggedBodyWeightToday: Bool {
        guard let loggedAt = bodyWeightLogs.first?.loggedAt else { return false }
        return Calendar.current.isDateInToday(loggedAt)
    }

    private var bodyWeightStatusColor: Color {
        hasLoggedBodyWeightToday ? Color.unbound.success : Color.unbound.accent
    }

    private var shouldShowCalibrationCard: Bool {
        calibrationSkipRatio > 0.5 && !hasLoggedAnyWorkout
    }

    /// Home's capture card is always shown — it's the daily photo entry
    /// point, not just a rescan nudge.
    private var shouldShowScanCTA: Bool { true }

    /// Swaps the card's label from PHOTO +5 to SCAN +25 using the same
    /// monthly cadence rule as the scan gate.
    private var shouldShowScanEligibility: Bool {
        scanCadence.isUnlocked
    }

    /// Player-facing rank title. The underlying ordinal ladder remains
    /// strength-based; the UI now shows titles instead of letter grades.
    private func tierName(for rank: RankTier) -> String {
        rank.displayName
    }

    private func nextRankMomentumLabel(for rank: RankTier) -> String {
        let nextTitle = rank.advanced(by: 1)
        guard nextTitle != rank else { return "PROOF +1" }
        return "TO \(nextTitle.displayName.uppercased())"
    }

    private func dayWord(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "TODAY" }
        if cal.isDateInYesterday(date) { return "YESTERDAY" }
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date).uppercased()
    }

    private func shortDayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: Date()).uppercased()
    }

    // MARK: - Daily Quest
    //
    // Bite-sized side activity — walks, mobility, stretch, alt circuits.
    // Shown alongside Today's Session to motivate movement on rest days
    // or as a lighter add-on on program days. Placeholder content until
    // QuestLibrary + QuestService ship.

    /// On rest days (or when no program is scheduled), the quest is the
    /// primary CTA — ordered above the session card. On program days,
    /// the session CTA stays primary and the quest appears below.
    private var isQuestPrimary: Bool {
        guard let day = todayProgramDay else { return true }
        return day.isRestDay || day.workout == nil
    }

    private func dailyQuestCard(isHero: Bool) -> some View {
        let categoryColor = questColor

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("DAILY QUEST")
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.8)
                    .foregroundStyle(categoryColor)
                Text("·")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text(activeRoutine.category.label)
                    .font(Font.unbound.captionS)
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textTertiary)
                Spacer()
                Text("PROOF-GATED XP")
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(categoryColor)
                    .monospacedDigit()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(activeRoutine.title.uppercased())
                    .font(Font.unbound.titleM)
                    .tracking(0.4)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text(activeRoutine.subtitle)
                    .font(Font.unbound.monoS)
                    .tracking(0.4)
                    .foregroundStyle(Color.unbound.textSecondary)
            }

            Button {
                UnboundHaptics.medium()
                activeRoutine = Self.defaultDailyQuestRoutine
                showRoutinePlayer = true
            } label: {
                HStack(spacing: 10) {
                    Text("ACCEPT")
                        .font(Font.unbound.bodyMStrong)
                        .tracking(1.6)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(categoryColor)
                )
                .shadow(color: categoryColor.opacity(0.45), radius: isHero ? 14 : 6, y: 2)
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.unbound.surface)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                categoryColor.opacity(isHero ? 0.14 : 0.06),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(categoryColor.opacity(isHero ? 0.40 : 0.22), lineWidth: 1)
        )
    }

    private var dailyQuestCompletionOverlay: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                    .tint(questColor)
                    .scaleEffect(1.12)
                Text("LOCKING IN")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(2.0)
                    .foregroundStyle(questColor)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(questColor.opacity(0.32), lineWidth: 1)
            )
        }
        .accessibilityIdentifier("home.dailyQuest.completing")
    }

    private func dailyQuestRetryOverlay(record: RoutineCompletionRecord) -> some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(questColor)
                Text("COULD NOT LOCK IN")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(2.0)
                    .foregroundStyle(questColor)
                if let dailyQuestCompletionError {
                    Text(dailyQuestCompletionError)
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button {
                    Task { await completeDailyQuest(record) }
                } label: {
                    Text("TRY AGAIN")
                        .font(Font.unbound.bodyMStrong)
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .frame(width: 180, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(questColor)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(questColor.opacity(0.32), lineWidth: 1)
            )
            .padding(.horizontal, 28)
        }
        .accessibilityIdentifier("home.dailyQuest.retry")
    }

    @MainActor
    private func completeDailyQuest(_ record: RoutineCompletionRecord) async {
        guard !isCompletingDailyQuest, dailyQuestRewardSequence == nil else { return }
        pendingDailyQuestCompletionRecord = pendingDailyQuestCompletionRecord ?? record
        dailyQuestCompletionError = nil
        isCompletingDailyQuest = true

        guard let userId = services.auth.currentUserId else {
            LoggingService.shared.log(
                "Daily Quest completion skipped without authenticated user",
                level: .warning,
                context: ["routineId": activeRoutine.id, "recordId": record.id]
            )
            isCompletingDailyQuest = false
            pendingDailyQuestCompletionRecord = nil
            showRoutinePlayer = false
            return
        }

        let routine = activeRoutine
        let canClaimDailyReward = RoutineHistoryStore.shared.canComplete(routineId: routine.id)

        let performanceLog = TrainingSessionAdapters.performanceLogForRoutine(
            routine,
            record: record,
            userId: userId
        )

        do {
            let completionResult = try await TrainingCompletionService.shared.complete(
                performanceLog,
                services: services
            )
            RoutineHistoryStore.shared.record(record)
            if canClaimDailyReward, completionResult.overallLevelXPGained > 0 {
                RoutineHistoryStore.shared.complete(routine)
            }

            var rewardSummary = RewardSummary()
            rewardSummary.progression = completionResult.progressionReceipt

            dailyQuestRewardSequence = WorkoutRewardSequenceSummary.trainingReceipt(
                performanceLog: performanceLog,
                completionResult: completionResult,
                rewardSummary: rewardSummary,
                fallbackXP: 0,
                sourceName: "Daily Quest"
            )
            pendingDailyQuestCompletionRecord = nil
            dailyQuestCompletionError = nil
            isCompletingDailyQuest = false
        } catch {
            LoggingService.shared.log(
                "Daily Quest canonical completion failed",
                level: .warning,
                context: ["routineId": routine.id, "recordId": record.id, "error": "\(error)"]
            )
            isCompletingDailyQuest = false
            dailyQuestCompletionError = "Unable to save this quest. Try again."
        }
    }

    // MARK: - Ambient animations
    //
    // Loops that start once on appear and keep going. Subtle by design —
    // rank letter glow breathes, streak flame flickers, XP bar shimmer
    // travels left→right. No rotation, no bouncing, no ≥1% scale.

    private func startAmbientAnimations() {
        // Rank letter glow — bigger swing so it's perceptible, not subliminal.
        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
            rankGlowRadius = 22
        }

        // Streak flame glow — flickers if there's an active streak.
        if (sessionXP?.currentStreak ?? 0) > 0 {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                streakFlameRadius = 10
            }
        }

        // XP bar shimmer — traveling highlight.
        withAnimation(.linear(duration: 2.6).repeatForever(autoreverses: false)) {
            xpShimmerPhase = 1.2
        }

        // Stat bars sweep from 0 → value on load.
        withAnimation(.easeOut(duration: 1.0)) {
            statsRendered = true
        }
    }
}

private struct ProtocolHeroBackground: View {
    let tint: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.unbound.surfaceElevated,
                            Color.unbound.surface,
                            Color.unbound.bg.opacity(0.95)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            TopographicLines()
                .stroke(Color.white.opacity(0.035), lineWidth: 1)

            DiagonalAccentShape()
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.28),
                            tint.opacity(0.08),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 210)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [tint.opacity(0.22), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 140
                    )
                )
                .frame(width: 230, height: 230)
                .offset(x: 126, y: -96)
                .allowsHitTesting(false)
        }
    }
}

private struct DiagonalAccentShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.38, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct StreakSlashShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let lean = rect.width * 0.42
        path.move(to: CGPoint(x: rect.minX + lean, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - lean, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct TopographicLines: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let rows = 8
        for row in 0..<rows {
            let baseY = rect.minY + CGFloat(row) * rect.height / CGFloat(rows - 1)
            path.move(to: CGPoint(x: rect.minX - 20, y: baseY))
            for step in 0...8 {
                let x = rect.minX + CGFloat(step) * rect.width / 8
                let wave = sin(CGFloat(step) * 0.95 + CGFloat(row) * 0.72) * 13
                let next = CGPoint(x: x, y: baseY + wave)
                path.addLine(to: next)
            }
        }
        return path
    }
}

private struct BodyWeightOverTimeChart: View {
    let logs: [BodyWeightLog]
    let unit: TrainingWeightUnit

    private var orderedLogs: [BodyWeightLog] {
        Array(logs.prefix(30).reversed())
    }

    private var values: [Double] {
        orderedLogs.map { unit.displayValue(fromKilograms: $0.weightKg) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("OVER TIME")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(Color.unbound.textTertiary)

                Spacer()

                Text(changeSummary)
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(0.7)
                    .foregroundStyle(changeColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
            }

            GeometryReader { proxy in
                chartBody(size: proxy.size)
            }

            HStack {
                Text(startDateText)
                Spacer()
                Text(endDateText)
            }
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .tracking(0.7)
            .foregroundStyle(Color.unbound.textTertiary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.bg.opacity(0.28))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle.opacity(0.72), lineWidth: 1)
        )
        .accessibilityLabel("Bodyweight over time")
    }

    private var changeSummary: String {
        guard values.count >= 2,
              let first = values.first,
              let latest = values.last
        else {
            let count = values.count
            if count == 1 { return "1 LOG" }
            return "NO LOGS"
        }

        let delta = latest - first
        if abs(delta) < 0.05 {
            return "STEADY · \(values.count) LOGS"
        }
        let sign = delta > 0 ? "+" : "-"
        let formatted = WeightPlatePolicy.formatDisplayValue(abs(delta))
        return "\(sign)\(formatted) \(unit.shortLabel.uppercased()) · \(values.count) LOGS"
    }

    private var changeColor: Color {
        guard values.count >= 2,
              let first = values.first,
              let latest = values.last,
              abs(latest - first) >= 0.05
        else { return Color.unbound.textSecondary }

        return latest > first ? Color.unbound.success : Color.unbound.coachCyan
    }

    private var startDateText: String {
        guard let first = orderedLogs.first else { return "START" }
        return Self.shortDateFormatter.string(from: first.loggedAt).uppercased()
    }

    private var endDateText: String {
        guard let latest = orderedLogs.last else { return "NOW" }
        return Self.shortDateFormatter.string(from: latest.loggedAt).uppercased()
    }

    private func chartBody(size: CGSize) -> some View {
        let points = chartPoints(in: size)
        return ZStack {
            gridPath(in: size)
                .stroke(Color.unbound.borderSubtle.opacity(0.65), style: StrokeStyle(lineWidth: 0.6, dash: [3, 5]))

            if points.count >= 2 {
                linePath(points: points)
                    .stroke(
                        LinearGradient(
                            colors: [Color.unbound.coachCyan, Color.unbound.accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                    )

                ForEach(points.indices, id: \.self) { index in
                    Circle()
                        .fill(index == points.count - 1 ? Color.unbound.accent : Color.unbound.textSecondary)
                        .frame(width: index == points.count - 1 ? 7 : 4, height: index == points.count - 1 ? 7 : 4)
                        .position(points[index])
                        .shadow(color: Color.unbound.accent.opacity(index == points.count - 1 ? 0.38 : 0), radius: 5)
                }
            } else {
                Text(values.isEmpty ? "NO CHECK-INS" : "ONE CHECK-IN")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.0)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
    }

    private func chartPoints(in size: CGSize) -> [CGPoint] {
        guard !values.isEmpty else { return [] }
        guard let minValue = values.min(), let maxValue = values.max() else { return [] }

        let padding = max((maxValue - minValue) * 0.14, 0.5)
        let lowerBound = minValue - padding
        let upperBound = maxValue + padding
        let span = max(upperBound - lowerBound, 1)

        return values.enumerated().map { index, value in
            let x = values.count == 1
                ? size.width / 2
                : CGFloat(index) / CGFloat(values.count - 1) * size.width
            let normalized = (value - lowerBound) / span
            let y = size.height - CGFloat(normalized) * size.height
            return CGPoint(x: x, y: y)
        }
    }

    private func gridPath(in size: CGSize) -> Path {
        Path { path in
            for row in 0...2 {
                let y = size.height * CGFloat(row) / 2
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
        }
    }

    private func linePath(points: [CGPoint]) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            points.dropFirst().forEach { path.addLine(to: $0) }
        }
    }

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
}

private struct BodyWeightHistoryScreen: View {
    let logs: [BodyWeightLog]
    let latestWeightKg: Double?
    let unit: TrainingWeightUnit
    let didJustLog: Bool
    let onLog: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var latestLog: BodyWeightLog? {
        logs.first
    }

    private var recentLogs: [BodyWeightLog] {
        Array(logs.prefix(8))
    }

    private var latestValueText: String {
        guard let latestWeightKg else { return "--" }
        return WeightPlatePolicy.formatLoggedWeight(latestWeightKg, unit: unit)
    }

    private var latestDateText: String {
        guard let loggedAt = latestLog?.loggedAt else { return "FROM PROFILE" }
        if Calendar.current.isDateInToday(loggedAt) { return "TODAY" }
        if Calendar.current.isDateInYesterday(loggedAt) { return "YESTERDAY" }
        return Self.dateFormatter.string(from: loggedAt).uppercased()
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                if didJustLog {
                    loggedConfirmation
                }

                latestPanel

                BodyWeightOverTimeChart(logs: logs, unit: unit)
                    .frame(height: 250)

                recentLogsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 34)
        }
        .background(Color.unbound.bg.ignoresSafeArea())
        .navigationTitle("Bodyweight")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
                .foregroundStyle(Color.unbound.textSecondary)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    onLog()
                } label: {
                    Label("Log", systemImage: "plus")
                }
                .foregroundStyle(Color.unbound.accent)
            }
        }
    }

    private var loggedConfirmation: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Color.unbound.success)

            VStack(alignment: .leading, spacing: 2) {
                Text("LOGGED")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.success)
                Text("Your bodyweight trend updated below.")
                    .font(Font.unbound.monoS.weight(.semibold))
                    .foregroundStyle(Color.unbound.textSecondary)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.success.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.unbound.success.opacity(0.28), lineWidth: 1)
        )
    }

    private var latestPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(latestValueText)
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                Text(unit.shortLabel.uppercased())
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(Color.unbound.textSecondary)

                Spacer()
            }

            HStack(spacing: 8) {
                metricPill(title: latestDateText, icon: "calendar")
                metricPill(title: "\(logs.count) LOG\(logs.count == 1 ? "" : "S")", icon: "list.bullet")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private var recentLogsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("RECENT CHECK-INS")
                    .font(Font.unbound.captionS.weight(.black))
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.textTertiary)
                Spacer()
            }

            if logs.isEmpty {
                Text("Log your first bodyweight to start the graph.")
                    .font(Font.unbound.monoS.weight(.semibold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(recentLogs.indices, id: \.self) { index in
                        recentLogRow(recentLogs[index])

                        if index < recentLogs.count - 1 {
                            Rectangle()
                                .fill(Color.unbound.borderSubtle)
                                .frame(height: 0.5)
                                .padding(.leading, 2)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.unbound.surface.opacity(0.66))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                )
            }
        }
    }

    private func recentLogRow(_ log: BodyWeightLog) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(Self.dateFormatter.string(from: log.loggedAt).uppercased())
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.0)
                    .foregroundStyle(Color.unbound.textSecondary)
                if let note = log.note, !note.isEmpty {
                    Text(note)
                        .font(Font.unbound.monoS)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text("\(WeightPlatePolicy.formatLoggedWeight(log.weightKg, unit: unit)) \(unit.shortLabel.uppercased())")
                .font(Font.unbound.monoS.weight(.bold))
                .foregroundStyle(Color.unbound.textPrimary)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func metricPill(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .black))
            Text(title)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(0.8)
        }
        .foregroundStyle(Color.unbound.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(Color.unbound.surfaceElevated)
        )
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
}

private struct BodyWeightLogSheet: View {
    let unit: TrainingWeightUnit
    let isSaving: Bool
    let errorMessage: String?
    let onSave: (Double, String?) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var weightText: String
    @State private var note: String = ""

    private let fallbackDisplayWeight: Double

    init(
        initialWeightKg: Double?,
        unit: TrainingWeightUnit,
        isSaving: Bool,
        errorMessage: String?,
        onSave: @escaping (Double, String?) async -> Void
    ) {
        self.unit = unit
        self.isSaving = isSaving
        self.errorMessage = errorMessage
        self.onSave = onSave

        let displayWeight = initialWeightKg.map {
            WeightPlatePolicy.editingValue(fromKilograms: $0, unit: unit)
        } ?? Self.defaultDisplayWeight(for: unit)
        self.fallbackDisplayWeight = displayWeight
        _weightText = State(initialValue: WeightPlatePolicy.formatDisplayValue(displayWeight))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("LOG BODYWEIGHT")
                        .font(Font.unbound.captionS.weight(.black))
                        .tracking(1.8)
                        .foregroundStyle(Color.unbound.accent)
                    Text("TODAY")
                        .font(Font.unbound.monoS.weight(.bold))
                        .tracking(1.0)
                        .foregroundStyle(Color.unbound.textTertiary)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.unbound.surfaceElevated))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }

            HStack(alignment: .center, spacing: 12) {
                adjustmentButton(systemName: "minus", delta: -stepSize)

                VStack(spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        TextField("0", text: $weightText)
                            .font(.system(size: 44, weight: .black, design: .rounded))
                            .foregroundStyle(Color.unbound.textPrimary)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .monospacedDigit()
                            .frame(minWidth: 104, maxWidth: 170)

                        Text(unit.shortLabel.uppercased())
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .tracking(1.0)
                            .foregroundStyle(Color.unbound.textSecondary)
                    }

                    Text(validityText)
                        .font(Font.unbound.monoS.weight(.semibold))
                        .tracking(0.5)
                        .foregroundStyle(parsedWeightKg == nil ? Color.unbound.alert : Color.unbound.textTertiary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)

                adjustmentButton(systemName: "plus", delta: stepSize)
            }
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
            )

            TextField("Optional note", text: $note)
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textPrimary)
                .tint(Color.unbound.accent)
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.unbound.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                )

            if let errorMessage {
                Text(errorMessage)
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(Color.unbound.alert)
                    .lineLimit(2)
            }

            Button {
                guard let parsedWeightKg else { return }
                Task { await onSave(parsedWeightKg, note) }
            } label: {
                HStack(spacing: 10) {
                    if isSaving {
                        ProgressView()
                            .tint(Color.unbound.textPrimary)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .black))
                    }
                    Text(isSaving ? "SAVING" : "SAVE WEIGHT")
                        .font(Font.unbound.bodyMStrong)
                        .tracking(1.5)
                }
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(parsedWeightKg == nil ? Color.unbound.border : Color.unbound.accent)
                )
            }
            .buttonStyle(.plain)
            .disabled(parsedWeightKg == nil || isSaving)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.unbound.bg.ignoresSafeArea())
    }

    private var stepSize: Double {
        unit == .pounds ? 0.5 : 0.25
    }

    private var displayWeightRange: ClosedRange<Double> {
        unit == .pounds ? 40...700 : 20...320
    }

    private var parsedDisplayWeight: Double? {
        let raw = weightText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }

        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal

        let fallback = Double(raw.replacingOccurrences(of: ",", with: "."))
        guard let value = formatter.number(from: raw)?.doubleValue ?? fallback,
              displayWeightRange.contains(value)
        else { return nil }
        return value
    }

    private var parsedWeightKg: Double? {
        parsedDisplayWeight.map { unit.kilograms(fromDisplayValue: $0) }
    }

    private var validityText: String {
        parsedWeightKg == nil ? "OUT OF RANGE" : "READY TO LOG"
    }

    private static func defaultDisplayWeight(for unit: TrainingWeightUnit) -> Double {
        unit == .pounds ? 180 : 82
    }

    private func adjustmentButton(systemName: String, delta: Double) -> some View {
        Button {
            adjust(by: delta)
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(width: 46, height: 46)
                .background(
                    Circle()
                        .fill(Color.unbound.surfaceElevated)
                )
                .overlay(
                    Circle()
                        .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func adjust(by delta: Double) {
        let current = parsedDisplayWeight ?? fallbackDisplayWeight
        let next = min(max(current + delta, displayWeightRange.lowerBound), displayWeightRange.upperBound)
        weightText = WeightPlatePolicy.formatDisplayValue(next)
    }
}

private struct HomeLoadingSkeleton: View {
    @State private var shimmer: CGFloat = -0.7

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 10) {
                    skeletonCircle(size: 40)
                    VStack(alignment: .leading, spacing: 6) {
                        skeletonLine(width: 86, height: 10)
                        skeletonLine(width: 72, height: 8)
                    }
                    Spacer()
                    skeletonCapsule(width: 76, height: 30)
                }
                .frame(height: 44)

                VStack(alignment: .leading, spacing: 12) {
                    skeletonLine(width: 220, height: 30)
                    skeletonLine(width: 318, height: 13)
                    skeletonLine(width: 242, height: 13)
                }

                skeletonPanel(height: 238, cornerRadius: 16)

                VStack(spacing: 0) {
                    skeletonRailRow()
                    skeletonDivider
                    skeletonRailRow()
                    skeletonDivider
                    HStack(spacing: 0) {
                        skeletonRailRow()
                        Rectangle()
                            .fill(Color.unbound.borderSubtle)
                            .frame(width: 0.5, height: 42)
                        skeletonRailRow()
                    }
                }
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Color.unbound.ember.opacity(0.55))
                        .frame(width: 2)
                }

                skeletonPanel(height: 154, cornerRadius: 16)
                skeletonPanel(height: 94, cornerRadius: 12)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(Color.unbound.bg.ignoresSafeArea())
        .overlay(shimmerOverlay.mask(skeletonMask))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.45).repeatForever(autoreverses: false)) {
                shimmer = 1.15
            }
        }
    }

    private var shimmerOverlay: some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            .clear,
                            Color.white.opacity(0.075),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: proxy.size.width * 0.48)
                .offset(x: proxy.size.width * shimmer)
        }
        .allowsHitTesting(false)
    }

    private var skeletonMask: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 10) {
                Circle().frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 5).frame(width: 86, height: 10)
                    RoundedRectangle(cornerRadius: 4).frame(width: 72, height: 8)
                }
                Spacer()
                Capsule().frame(width: 76, height: 30)
            }
            .frame(height: 44)

            VStack(alignment: .leading, spacing: 12) {
                RoundedRectangle(cornerRadius: 8).frame(width: 220, height: 30)
                RoundedRectangle(cornerRadius: 6).frame(width: 318, height: 13)
                RoundedRectangle(cornerRadius: 6).frame(width: 242, height: 13)
            }

            RoundedRectangle(cornerRadius: 16).frame(height: 238)
            RoundedRectangle(cornerRadius: 8).frame(height: 146)
            RoundedRectangle(cornerRadius: 16).frame(height: 154)
            RoundedRectangle(cornerRadius: 12).frame(height: 94)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var skeletonDivider: some View {
        Rectangle()
            .fill(Color.unbound.borderSubtle)
            .frame(height: 0.5)
            .padding(.leading, 16)
    }

    private func skeletonRailRow() -> some View {
        HStack(spacing: 12) {
            skeletonLine(width: 72, height: 9)
            skeletonLine(width: 48, height: 17)
            Spacer()
            skeletonLine(width: 62, height: 9)
        }
        .padding(.leading, 16)
        .padding(.vertical, 10)
    }

    private func skeletonPanel(height: CGFloat, cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.unbound.surface)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
            )
            .frame(maxWidth: .infinity)
            .frame(height: height)
    }

    private func skeletonLine(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(Color.unbound.surfaceElevated)
            .frame(width: width, height: height)
    }

    private func skeletonCircle(size: CGFloat) -> some View {
        Circle()
            .fill(Color.unbound.surfaceElevated)
            .frame(width: size, height: size)
    }

    private func skeletonCapsule(width: CGFloat, height: CGFloat) -> some View {
        Capsule()
            .fill(Color.unbound.surfaceElevated)
            .frame(width: width, height: height)
    }
}

private struct BodyLoadHeatmapView: View {
    let loads: [BodyRegion: Double]
    let plannedRegions: [BodyRegion]

    private var readings: [BodyLoadRegionReading] {
        loads
            .filter { $0.value > 0.05 }
            .map { BodyLoadRegionReading(region: $0.key, load: $0.value) }
            .sorted { lhs, rhs in
                if lhs.load == rhs.load { return lhs.region.displayName < rhs.region.displayName }
                return lhs.load > rhs.load
            }
    }

    private var topReading: BodyLoadRegionReading? {
        readings.first
    }

    private var plannedSummary: String? {
        let regions = Array(Set(plannedRegions))
            .sorted { $0.displayName < $1.displayName }
        guard !regions.isEmpty else { return nil }

        let names = regions.prefix(2).map(\.displayName)
        if regions.count > names.count {
            return names.joined(separator: " + ") + " +\(regions.count - names.count)"
        }
        return names.joined(separator: " + ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            HStack(alignment: .top, spacing: 12) {
                BodyLoadFigure(side: .front, loads: loads)
                BodyLoadFigure(side: .back, loads: loads)
            }

            footer
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            if let topReading {
                VStack(alignment: .leading, spacing: 5) {
                    Text("BODY LOAD")
                        .font(Font.unbound.captionS.weight(.black))
                        .tracking(1.8)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text(topReading.region.displayName.uppercased())
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text("Last 7 days")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.unbound.textTertiary)
                }

                Spacer(minLength: 8)

                BodyLoadBandPill(band: topReading.band)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("BODY LOAD")
                        .font(Font.unbound.captionS.weight(.black))
                        .tracking(1.8)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text("NO RECENT LOAD")
                        .font(.system(size: 23, weight: .black))
                        .foregroundStyle(Color.unbound.textPrimary)
                }
                Spacer()
            }
        }
    }

    private var footer: some View {
        HStack(alignment: .center, spacing: 10) {
            miniLegend

            Spacer(minLength: 8)

            if let plannedSummary {
                HStack(spacing: 5) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10, weight: .semibold))
                    Text(plannedSummary.uppercased())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(Color.unbound.textTertiary)
            }
        }
    }

    private var miniLegend: some View {
        HStack(spacing: 5) {
            ForEach(BodyLoadBand.allCases) { band in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(band.tint)
                    .frame(width: 16, height: 6)
            }
            Text("FRESH TO HEAVY")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(Color.unbound.textTertiary)
        }
    }
}

private struct BodyLoadFigure: View {
    let side: BodyMapSide
    let loads: [BodyRegion: Double]

    var body: some View {
        VStack(spacing: 8) {
            BodyLoadFigureCanvas(
                side: side,
                loads: loads
            )
            .overlay(alignment: .topTrailing) {
                Text(side.shortTitle)
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.0)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.unbound.bg.opacity(0.62))
                    )
                    .padding(5)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct BodyLoadFigureCanvas: View {
    let side: BodyMapSide
    let loads: [BodyRegion: Double]

    var body: some View {
        GeometryReader { proxy in
            let viewBox = BodyLoadSVGRegionAsset.viewBox(for: side)
            let drawRect = Self.drawRect(in: proxy.size, viewBox: viewBox)
            ZStack {
                if let baseImage = BodyLoadImageAsset.image(for: side) {
                    Image(uiImage: baseImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: drawRect.width, height: drawRect.height)
                        .position(x: drawRect.midX, y: drawRect.midY)
                        .opacity(1)
                }

                ZStack {
                    ForEach(BodyLoadSVGRegionAsset.paths(for: side)) { spec in
                        let load = loads[spec.region] ?? 0

                        spec.path(in: drawRect, viewBox: viewBox)
                            .fill(
                                BodyLoadHeatColor.color(
                                    forLoad: load,
                                    kind: spec.kind
                                ),
                                style: FillStyle(eoFill: spec.usesEvenOdd)
                            )
                            .blendMode(spec.kind == .fill ? .multiply : .normal)
                            .shadow(
                                color: BodyLoadHeatColor.color(forLoad: load, kind: .stroke)
                                    .opacity(load > 0.5 ? 0.20 : 0),
                                radius: spec.kind == .stroke ? 2 : 0
                            )
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(BodyLoadSVGRegionAsset.viewBox(for: side).width / BodyLoadSVGRegionAsset.viewBox(for: side).height, contentMode: .fit)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.bg.opacity(0.28))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private static func drawRect(in size: CGSize, viewBox: CGSize) -> CGRect {
        let scale = min(size.width / viewBox.width, size.height / viewBox.height)
        let width = viewBox.width * scale
        let height = viewBox.height * scale
        return CGRect(
            x: (size.width - width) / 2,
            y: (size.height - height) / 2,
            width: width,
            height: height
        )
    }
}

private enum BodyLoadSVGRegionAsset {
    static let defaultViewBox = CGSize(width: 1280, height: 1908)
    private static let frontAsset = load(side: .front)
    private static let backAsset = load(side: .back)

    static func viewBox(for side: BodyMapSide) -> CGSize {
        switch side {
        case .front:
            return frontAsset.viewBox
        case .back:
            return backAsset.viewBox
        }
    }

    static func paths(for side: BodyMapSide) -> [BodyLoadRegionSpec] {
        switch side {
        case .front:
            return frontAsset.paths
        case .back:
            return backAsset.paths
        }
    }

    private static func load(side: BodyMapSide) -> Loaded {
        guard let url = Bundle.main.url(
            forResource: side.bodyLoadSVGName,
            withExtension: "svg",
            subdirectory: "BodyMap"
        ) ?? Bundle.main.url(
            forResource: side.bodyLoadSVGName,
            withExtension: "svg"
        ),
              let data = try? Data(contentsOf: url)
        else {
            return Loaded(viewBox: defaultViewBox, paths: [])
        }

        let parser = BodyLoadSVGRegionParser(side: side)
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        _ = xmlParser.parse()
        return Loaded(viewBox: parser.viewBox ?? defaultViewBox, paths: parser.paths)
    }

    private struct Loaded {
        let viewBox: CGSize
        let paths: [BodyLoadRegionSpec]
    }
}

private final class BodyLoadSVGRegionParser: NSObject, XMLParserDelegate {
    let side: BodyMapSide
    var viewBox: CGSize?
    var paths: [BodyLoadRegionSpec] = []

    init(side: BodyMapSide) {
        self.side = side
    }

    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        if elementName == "svg", let rawViewBox = attributeDict["viewBox"] {
            viewBox = Self.parseViewBox(rawViewBox)
            return
        }

        guard elementName == "path",
              let rawRegion = attributeDict["data-region"],
              let region = BodyLoadSVGRegionMapper.region(from: rawRegion),
              let pathData = attributeDict["d"]
        else { return }

        let id = attributeDict["id"] ?? "\(side.shortTitle)-\(rawRegion)-\(paths.count)"
        let className = attributeDict["class"] ?? ""
        let kind: BodyLoadPathKind = id.contains("-stroke") || className.contains("stroke")
            ? .stroke
            : .fill

        paths.append(
            BodyLoadRegionSpec(
                id: id,
                region: region,
                kind: kind,
                pathData: pathData,
                usesEvenOdd: attributeDict["fill-rule"] == "evenodd"
            )
        )
    }

    private static func parseViewBox(_ rawValue: String) -> CGSize? {
        let values = rawValue
            .split { $0 == " " || $0 == "," }
            .compactMap { Double($0) }
        guard values.count == 4 else { return nil }
        return CGSize(width: CGFloat(values[2]), height: CGFloat(values[3]))
    }
}

private struct BodyLoadRegionSpec: Identifiable {
    let id: String
    let region: BodyRegion
    let kind: BodyLoadPathKind
    let pathData: String
    let usesEvenOdd: Bool

    func path(in rect: CGRect, viewBox: CGSize) -> Path {
        let scale = rect.width / viewBox.width
        let transform = CGAffineTransform(
            a: scale,
            b: 0,
            c: 0,
            d: scale,
            tx: rect.minX,
            ty: rect.minY
        )
        return SVGPathParser.path(from: pathData).applying(transform)
    }
}

private enum BodyLoadSVGRegionMapper {
    static func region(from rawValue: String) -> BodyRegion? {
        switch rawValue {
        case "deltoids":
            return .shoulders
        case "traps_upper_back":
            return .traps
        case "lower_back":
            return .lowerBack
        default:
            return BodyRegion(rawValue: rawValue)
        }
    }
}

private enum BodyLoadImageAsset {
    static func image(for side: BodyMapSide) -> UIImage? {
        switch side {
        case .front:
            return frontImage
        case .back:
            return backImage
        }
    }

    private static let frontImage = load(side: .front)
    private static let backImage = load(side: .back)

    private static func load(side: BodyMapSide) -> UIImage? {
        if let url = Bundle.main.url(
            forResource: side.bodyLoadBaseImageName,
            withExtension: "png",
            subdirectory: "BodyMap"
        ) ?? Bundle.main.url(
            forResource: side.bodyLoadBaseImageName,
            withExtension: "png"
        ),
           let image = UIImage(contentsOfFile: url.path) {
            return image
        }
        return UIImage(named: side.bodyLoadBaseImageName)
    }
}

private enum BodyLoadPathKind {
    case fill
    case stroke
}

private enum BodyLoadHeatColor {
    static func color(forLoad load: Double, kind: BodyLoadPathKind) -> Color {
        guard load >= 0.5 else {
            return Color.clear
        }

        let band = BodyLoadBand.band(for: load)
        let intensity = min(1, max(0.18, load / BodyLoadBand.heavyThreshold))

        switch kind {
        case .fill:
            return band.tint.opacity(0.20 + intensity * 0.36)
        case .stroke:
            return band.tint.opacity(0.62 + intensity * 0.28)
        }
    }
}

private struct BodyLoadRegionReading: Identifiable {
    var id: BodyRegion { region }
    let region: BodyRegion
    let load: Double

    var band: BodyLoadBand {
        BodyLoadBand.band(for: load)
    }

    var loadText: String {
        if load < 1 {
            return "<1"
        }
        return "\(Int(load.rounded()))"
    }
}

private struct BodyLoadBandPill: View {
    let band: BodyLoadBand

    var body: some View {
        Text(band.label.uppercased())
            .font(.system(size: 11, weight: .heavy, design: .monospaced))
            .tracking(0.7)
            .foregroundStyle(band.tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(band.tint.opacity(0.13))
            )
            .overlay(
                Capsule()
                    .strokeBorder(band.tint.opacity(0.28), lineWidth: 1)
            )
    }
}

private enum BodyLoadBand: CaseIterable, Identifiable {
    case fresh
    case steady
    case high
    case heavy

    static let heavyThreshold: Double = 22

    var id: String { label }

    static func band(for load: Double) -> BodyLoadBand {
        let displayedLoad = load < 1 ? load : Double(Int(load.rounded()))
        switch displayedLoad {
        case ..<6:
            return .fresh
        case ..<13:
            return .steady
        case ..<heavyThreshold:
            return .high
        default:
            return .heavy
        }
    }

    var label: String {
        switch self {
        case .fresh:
            return "Fresh"
        case .steady:
            return "Steady"
        case .high:
            return "High"
        case .heavy:
            return "Heavy"
        }
    }

    var rangeLabel: String {
        switch self {
        case .fresh:
            return "0-5"
        case .steady:
            return "6-12"
        case .high:
            return "13-21"
        case .heavy:
            return "22+"
        }
    }

    var tint: Color {
        switch self {
        case .fresh:
            return Color.unbound.rankGreen
        case .steady:
            return Color.unbound.rankAmber
        case .high:
            return Color.unbound.warnOrange
        case .heavy:
            return Color.unbound.alert
        }
    }
}

private extension BodyMapSide {
    var shortTitle: String {
        switch self {
        case .front:
            return "FRONT"
        case .back:
            return "BACK"
        }
    }

    var bodyLoadBaseImageName: String {
        switch self {
        case .front:
            return "heatmap_front"
        case .back:
            return "heatmap_back"
        }
    }

    var bodyLoadSVGName: String {
        switch self {
        case .front:
            return "source_frontmap_character_mirrored_filled"
        case .back:
            return "source_backmap_character_mirrored_filled"
        }
    }
}
