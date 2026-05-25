import SwiftUI

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
    @State private var isLoading = true

    // Sessions / XP
    @AppStorage("unbound.gains") private var gains: Int = 0
    @AppStorage("unbound.streakDays") private var streakDays: Int = 0
    @AppStorage("unbound.lastScanTimestamp") private var lastScanTimestamp: Double = 0
    @AppStorage("unbound.lastPhotoTimestamp") private var lastPhotoTimestamp: Double = 0
    @AppStorage("unbound.lastSessionDate") private var lastSessionTimestamp: Double = 0
    @State private var sessionXP: SessionXPRecord?

    // Ranking + stats
    @State private var aggregateRank: SubRank = .eMinus
    @State private var aggregateTier: SkillTier = .initiate
    @State private var overallRankTrialReadiness: OverallRankTrialReadiness?

    // Contextual triggers
    @State private var plateaus: [PlateauedExercise] = []
    @State private var calibrationSkipRatio: Double = 0
    @State private var hasLoggedAnyWorkout: Bool = false
    @State private var lastLog: WorkoutLog?
    @State private var weekSessionDays: Set<Int> = [] // Mon=1...Sun=7

    // Modal state
    @State private var showingSession = false
    @State private var completedPresentedWorkout = false
    @State private var showingCalibrationWorkout = false
    // navigateToCoach removed — replaced by CoachModesStrip
    @State private var showingGainsToast = false
    @State private var lastGainsAwarded: Int = 0

    // Attribute profile (Phase 8+)
    @State private var attributeProfile: AttributeProfile = AttributeProfile.empty(userId: "", at: .now)

    // Ambient animation state
    @State private var rankGlowRadius: CGFloat = 6
    @State private var streakFlameRadius: CGFloat = 3
    @State private var xpShimmerPhase: CGFloat = -1
    @State private var statsRendered = false

    // Daily Quest — wired to RoutineLibrary. Rotation service lands later.
    @State private var dailyQuest = DailyQuestPlaceholder.sample
    @State private var activeRoutine: SideQuest = SideQuestLibrary.pushProtocol
    @State private var showRoutinePlayer = false

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

    // Level derivation: 250 XP per level. Simple, overrideable later.
    private let xpPerLevel: Int = 250

    // MARK: Body

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            if isLoading {
                HomeLoadingSkeleton()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        topBar
                        homeBriefing
                        trainingConsole
                        homeMomentumCard
                        contextualStack
                        HomeBuildChipCard(profile: attributeProfile) {
                            NotificationCenter.default.post(name: .requestNavigateToProfileTab, object: nil)
                        }
                        lastSessionRecap
                        Spacer().frame(height: 118)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
            }

            if showingGainsToast {
                VStack {
                    Spacer()
                    gainsToast
                    Spacer().frame(height: 80)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(10)
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
                await refreshLastLog()
                await refreshWeeklyRhythm()
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
        .fullScreenCover(isPresented: $showingSession, onDismiss: {
            guard completedPresentedWorkout else { return }
            completedPresentedWorkout = false
            onSessionComplete()
        }) {
            if let workout = todayProgramDay?.workout, let program {
                NavigationStack {
                    WorkoutLoggingView(
                        workout: workout,
                        programId: program.id,
                        dayNumber: todayProgramDay?.dayNumber ?? 1,
                        services: services,
                        onFinished: {
                            completedPresentedWorkout = true
                            showingSession = false
                        }
                    )
                }
            }
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
                    SideQuestPlayerView(routine: activeRoutine) { _ in
                        showRoutinePlayer = false
                    }
                    .environmentObject(services)
                }
        )
        .fullScreenCover(isPresented: $showScanCaptureFlow, onDismiss: {
            // Refresh cadence after a scan completes
            let userId = services.auth.currentUserId ?? "anonymous"
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
        let level = (gains / xpPerLevel) + 1
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
                // Notifications destination is a follow-up — no-op for now.
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
                        showingSession = true
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
        let level = (gains / xpPerLevel) + 1
        let xpInLevel = gains % xpPerLevel
        let fraction = Double(xpInLevel) / Double(xpPerLevel)
        let rankColor = aggregateRank.regionTint

        return VStack(alignment: .trailing, spacing: 8) {
            Text(aggregateTier.displayName.uppercased())
                .font(Font.unbound.captionS.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(rankColor)
            Text("LV \(level)")
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
            Text("\(xpInLevel)/\(xpPerLevel) XP")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.unbound.textTertiary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(width: 76, alignment: .trailing)
    }

    private var weekPath: some View {
        let todayIndex = ((Calendar.current.component(.weekday, from: Date()) + 5) % 7) + 1
        let currentStreak = sessionXP?.currentStreak ?? streakDays
        let completedCount = weekSessionDays.count

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
                }

                HStack(alignment: .bottom, spacing: 5) {
                    ForEach(0..<7, id: \.self) { index in
                        weekHeatSlash(
                            hasSession: weekSessionDays.contains(index + 1),
                            isToday: (index + 1) == todayIndex
                        )
                    }
                }
                .frame(height: 34, alignment: .bottom)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
    }

    private func weekHeatSlash(hasSession: Bool, isToday: Bool) -> some View {
        let fill = hasSession
            ? Color.unbound.rankGreen
            : (isToday ? Color.unbound.ember : Color.white.opacity(0.11))
        let height: CGFloat = hasSession ? 32 : (isToday ? 26 : 16)

        return StreakSlashShape()
            .fill(fill)
            .frame(width: 13)
            .frame(height: height)
            .overlay(
                StreakSlashShape()
                    .stroke(Color.white.opacity(hasSession || isToday ? 0.24 : 0.07), lineWidth: 0.7)
            )
            .shadow(color: fill.opacity(hasSession || isToday ? 0.30 : 0), radius: 7, y: 2)
            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: hasSession)
            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: isToday)
    }

    private var rankMomentumCard: some View {
        let level = (gains / xpPerLevel) + 1
        let xpInLevel = gains % xpPerLevel
        let fraction = Double(xpInLevel) / Double(xpPerLevel)
        let rankColor = aggregateRank.regionTint

        return HStack(alignment: .center, spacing: 14) {
            TierBadge(tier: aggregateRank.asSkillTier)
                .frame(width: 62, height: 62)

            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Text("RANK MOMENTUM")
                        .font(Font.unbound.captionS.weight(.bold))
                        .tracking(1.7)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Spacer(minLength: 0)
                    Text("LV \(level)")
                        .font(Font.unbound.monoS.weight(.semibold))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .monospacedDigit()
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(tierName(for: aggregateRank).uppercased())
                        .font(Font.unbound.titleS)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text("TO \(aggregateRank.advanced(by: 1).displayName)")
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
                    Text(dailyQuest.title)
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

                Spacer(minLength: 0)

                Text("+\(dailyQuest.spReward) LV XP")
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
        switch dailyQuest.category {
        case .cardio:   return Color.unbound.coachCyan
        case .mobility: return Color.unbound.rankGreen
        case .activity: return Color.unbound.warnOrange
        case .circuit:  return Color.unbound.accent
        }
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
        let level = (gains / xpPerLevel) + 1
        let xpInLevel = gains % xpPerLevel
        let fraction = Double(xpInLevel) / Double(xpPerLevel)
        let rankColor = aggregateRank.regionTint

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                TierBadge(tier: aggregateRank.asSkillTier, compact: true)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Text(tierName(for: aggregateRank).uppercased())
                            .font(Font.unbound.captionS.weight(.bold))
                            .tracking(1.6)
                            .foregroundStyle(rankColor)
                        Text("LV \(level)")
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

    private func miniStatPill(label: String, rank: SubRank) -> some View {
        let tint = rank.regionTint
        return HStack(spacing: 5) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(1.0)
                .foregroundStyle(Color.unbound.textTertiary)
            Text(rank.displayName)
                .font(Font.unbound.monoS.weight(.bold))
                .foregroundStyle(tint)
                .monospacedDigit()
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

    private var readinessRail: some View {
        VStack(spacing: 0) {
            railMetric(label: "READINESS", value: readinessValue, detail: readinessDetail, tint: readinessTint)
            railDivider
            railMetric(label: "NEXT RANK", value: aggregateRank.advanced(by: 1).displayName, detail: tierName(for: aggregateRank.advanced(by: 1)), tint: aggregateRank.advanced(by: 1).regionTint)
            railDivider
            HStack(spacing: 0) {
                railMetric(label: "WEEK", value: "\(weekSessionDays.count)/7", detail: "sessions", tint: Color.unbound.ember)
                verticalRailDivider
                railMetric(label: "LV XP", value: "\(gains)", detail: "banked", tint: Color.unbound.textPrimary)
            }
        }
        .padding(.vertical, 4)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.unbound.ember.opacity(0.82))
                .frame(width: 2)
        }
    }

    private func railMetric(label: String, value: String, detail: String, tint: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(Font.unbound.captionS.weight(.bold))
                .tracking(1.5)
                .foregroundStyle(Color.unbound.textTertiary)
                .frame(width: 86, alignment: .leading)

            Text(value)
                .font(Font.unbound.monoM.weight(.semibold))
                .foregroundStyle(tint)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Spacer(minLength: 10)

            Text(detail)
                .font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.leading, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
    }

    private var railDivider: some View {
        Rectangle()
            .fill(Color.unbound.borderSubtle)
            .frame(height: 0.5)
            .padding(.leading, 16)
    }

    private var verticalRailDivider: some View {
        Rectangle()
            .fill(Color.unbound.borderSubtle)
            .frame(width: 0.5, height: 42)
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

    private var readinessValue: String {
        if !plateaus.isEmpty { return "WATCH" }
        if shouldShowCalibrationCard { return "CAL" }
        if todayProgramDay?.isRestDay == true { return "REST" }
        return "GO"
    }

    private var readinessDetail: String {
        if let first = plateaus.first {
            return "\(first.displayName) stalled"
        }
        if shouldShowCalibrationCard {
            return "baseline"
        }
        if todayProgramDay?.isRestDay == true {
            return "recovery"
        }
        return "clear"
    }

    private var readinessTint: Color {
        if !plateaus.isEmpty { return Color.unbound.warnOrange }
        if shouldShowCalibrationCard { return Color.unbound.ember }
        if todayProgramDay?.isRestDay == true { return Color.unbound.coachCyan }
        return Color.unbound.success
    }

    /// Placeholder avatar: initials in a chamfered charcoal circle with a
    /// small violet LV chip overlapping the bottom-right. Swap to the real
    /// user photo once the scan pipeline feeds it in. Frame derives from
    /// the user's currently equipped rank-tier cosmetic.
    private func avatarBadge(level: Int) -> some View {
        let letter = avatarInitial
        return HStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                CosmeticAvatar(
                    tier: aggregateRank.title,
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

    // MARK: - Momentum + quick actions

    private var homeMomentumCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            weekPath

            HStack(spacing: 0) {
                homeCommandButton(
                    title: "Quest",
                    subtitle: "+\(dailyQuest.spReward) LV XP",
                    icon: "bolt.fill",
                    tint: questColor
                ) {
                    activeRoutine = SideQuestLibrary.pushProtocol
                    showRoutinePlayer = true
                }

                commandDivider

                homeCommandButton(
                    title: shouldShowScanEligibility ? "Scan" : "Photo",
                    subtitle: shouldShowScanEligibility ? "+25 LV XP" : "+5 LV XP",
                    icon: shouldShowScanEligibility ? "sparkle.magnifyingglass" : "camera.fill",
                    tint: shouldShowScanEligibility ? Color.unbound.accent : Color.unbound.ember
                ) {
                    captureMode = shouldShowScanEligibility ? .scan : .photo
                }

                commandDivider

                homeCommandButton(
                    title: "Program",
                    subtitle: "Plan",
                    icon: "calendar.badge.plus",
                    tint: Color.unbound.textSecondary
                ) {
                    NotificationCenter.default.post(name: .requestNavigateToProgramTab, object: nil)
                }
            }
            .frame(height: 54)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.unbound.borderSubtle.opacity(0.55))
                    .frame(height: 0.5)
            }
        }
        .padding(16)
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

    private var commandDivider: some View {
        Rectangle()
            .fill(Color.unbound.borderSubtle.opacity(0.65))
            .frame(width: 0.5, height: 30)
            .padding(.horizontal, 8)
    }

    private func homeCommandButton(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            UnboundHaptics.medium()
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(tint)
                    .frame(width: 16, height: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title.uppercased())
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text(subtitle.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
        return readiness.isReady || readiness.missingRequirements.count <= 2
    }

    private func rankGatePulseCard(_ readiness: OverallRankTrialReadiness) -> some View {
        let tint = rankGatePulseTint(readiness)
        let target = readiness.targetRank?.displayName ?? "Rank"
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
                        Text("NEXT GATE")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .tracking(1.5)
                            .foregroundStyle(Color.unbound.textTertiary)
                        Text(rankGatePulseStatus(readiness))
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .tracking(1.0)
                            .foregroundStyle(tint)
                    }

                    Text("\(target) · \(metCount)/\(totalCount) proofs")
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
        let missing = readiness.missingRequirements.count
        if missing == 1 { return "1 LEFT" }
        return "\(missing) LEFT"
    }

    private func rankGatePulseDetail(_ readiness: OverallRankTrialReadiness) -> String {
        if readiness.isReady {
            return "Open Profile to run the gate when you want it."
        }
        if let closest = readiness.missingRequirements.first {
            return "Closest: \(closest.label) \(closest.current)/\(closest.required)"
        }
        return "Open Profile for the full gate checklist."
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
                if lastGainsAwarded > 0 {
                    Text("+\(lastGainsAwarded) LV XP")
                        .font(Font.unbound.monoS)
                        .foregroundStyle(Color.unbound.accent)
                        .monospacedDigit()
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Gains toast

    private var gainsToast: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.unbound.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("+\(lastGainsAwarded) LV XP")
                    .font(Font.unbound.bodyLStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text("Session logged. Streak: \(streakDays) day\(streakDays == 1 ? "" : "s").")
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textSecondary)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.unbound.accent.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: Color.unbound.accent.opacity(0.3), radius: 16)
        .padding(.horizontal, 20)
    }

    // MARK: - Loading

    @MainActor
    private func load() async {
        let userId = services.auth.currentUserId ?? "anonymous"
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
            let generated = await ProgramGenerationService.shared.generateFromOnboarding(
                userId: userId,
                targetFrequency: fetched.targetFrequency,
                equipment: Set(fetched.equipment ?? []),
                experience: fetched.experience,
                sessionLength: fetched.sessionLength,
                exerciseStyles: Set(fetched.exerciseStyles ?? []),
                targetAreas: Set(fetched.targetAreas ?? []),
                goals: Set(fetched.goals ?? []),
                obstacles: Set(fetched.obstacles ?? []),
                sleepQuality: fetched.sleepQuality ?? 5,
                stressLevel: fetched.stressLevel ?? 5,
                currentFrequency: fetched.currentFrequency,
                commitment: fetched.commitment ?? 8,
                displayHandle: fetched.displayHandle ?? fetched.displayName ?? "",
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

    private func loadRanks(_ userId: String) async -> (SubRank, SkillTier) {
        async let r = services.rank.aggregateRank(userId: userId)
        async let t = services.rank.aggregateTier(userId: userId)
        return (await r, await t)
    }

    private func fetchRecentLogsSafe(userId: String, limit: Int) async -> [WorkoutLog] {
        (try? await services.workoutLog.fetchRecentLogs(userId: userId, limit: limit)) ?? []
    }

    @MainActor
    private func applyRecentLogs(_ logs: [WorkoutLog]) {
        lastLog = HomeLoadDerivations.lastLog(logs)
        hasLoggedAnyWorkout = HomeLoadDerivations.hasLogged(logs)
        weekSessionDays = HomeLoadDerivations.weekSessionDays(logs.map(\.startedAt))
    }

    @MainActor
    private func refreshRanksAndStats() async {
        let userId = services.auth.currentUserId ?? "anonymous"
        aggregateRank = await services.rank.aggregateRank(userId: userId)
        aggregateTier = await services.rank.aggregateTier(userId: userId)
    }

    @MainActor
    private func refreshTravelOverride() async {
        let userId = services.auth.currentUserId ?? "anonymous"
        activeTravelOverride = await TravelOverrideStore.shared.activeOverride(for: userId)
    }

    @MainActor
    private func refreshWeeklyRhythm() async {
        let userId = services.auth.currentUserId ?? "anonymous"
        let logs = (try? await services.workoutLog.fetchRecentLogs(userId: userId, limit: 14)) ?? []
        weekSessionDays = HomeLoadDerivations.weekSessionDays(logs.map(\.startedAt))
    }

    @MainActor
    private func refreshSessionXP() async {
        let userId = services.auth.currentUserId ?? "anonymous"
        sessionXP = services.sessionXP.record(userId: userId)
    }

    @MainActor
    private func refreshCalibrationState() async {
        let userId = services.auth.currentUserId ?? "anonymous"
        calibrationSkipRatio = services.calibration.skipRatio(userId: userId)
        let logs = (try? await services.workoutLog.fetchRecentLogs(userId: userId, limit: 1)) ?? []
        hasLoggedAnyWorkout = !logs.isEmpty
    }

    @MainActor
    private func refreshLastLog() async {
        let userId = services.auth.currentUserId ?? "anonymous"
        let logs = (try? await services.workoutLog.fetchRecentLogs(userId: userId, limit: 1)) ?? []
        lastLog = logs.first
    }

    // MARK: - Session completion hook

    private func onSessionComplete() {
        let today = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
        let lastDay = Calendar.current.startOfDay(
            for: Date(timeIntervalSince1970: lastSessionTimestamp)
        ).timeIntervalSince1970

        if today == lastDay { return }

        let earned = 30
        gains += earned
        lastGainsAwarded = earned

        let streakDecision = ProgramAwareStreakPolicy.shouldExtendStreak(
            from: Date(timeIntervalSince1970: lastDay),
            to: Date(),
            currentStreak: streakDays,
            resetWindowDays: 14,
            activeProgram: program
        )
        streakDays = streakDecision.streak
        lastSessionTimestamp = Date().timeIntervalSince1970

        RankDecayService.shared.clearRecalibration()

        UnboundHaptics.success()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            showingGainsToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.4)) {
                showingGainsToast = false
            }
        }

        Task {
            await refreshSessionXP()
            await refreshRanksAndStats()
            await refreshLastLog()
            await refreshWeeklyRhythm()
        }
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
        let workout: Workout? = {
            guard !tday.isRest else { return nil }
            let exercises = tday.exercises.map { name in
                Exercise(
                    id: UUID().uuidString, name: name, muscleGroups: [],
                    sets: 3, reps: "8-12", restSeconds: 60,
                    rpe: nil, notes: nil, substitution: nil
                )
            }
            let mins = Int(String(tday.duration.filter(\.isNumber))) ?? 30
            return Workout(
                name: tday.title,
                targetMuscleGroups: [],
                warmup: [],
                mainExercises: exercises,
                cooldown: [],
                estimatedMinutes: mins,
                notes: "Travel · \(override.summary)",
                blockType: nil
            )
        }()
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

    private var shouldShowCalibrationCard: Bool {
        calibrationSkipRatio > 0.5 && !hasLoggedAnyWorkout
    }

    /// Home's capture card is always shown — it's the daily photo entry
    /// point, not just a rescan nudge.
    private var shouldShowScanCTA: Bool { true }

    /// True when ≥14 days since last successful scan (or never scanned).
    /// Swaps the card's label from PHOTO +5 → SCAN +25.
    private var shouldShowScanEligibility: Bool {
        guard lastScanTimestamp > 0 else { return true }
        let secondsSince = Date().timeIntervalSince1970 - lastScanTimestamp
        return secondsSince >= 14 * 24 * 3600
    }

    /// Player-facing rank title. The underlying ordinal ladder remains
    /// strength-based; the UI now shows titles instead of letter grades.
    private func tierName(for rank: SubRank) -> String {
        rank.displayName
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
        let categoryColor: Color = {
            switch dailyQuest.category {
            case .cardio:   return Color.unbound.coachCyan
            case .mobility: return Color.unbound.rankGreen
            case .activity: return Color.unbound.warnOrange
            case .circuit:  return Color.unbound.accent
            }
        }()

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("DAILY QUEST")
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.8)
                    .foregroundStyle(categoryColor)
                Text("·")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text(dailyQuest.category.label)
                    .font(Font.unbound.captionS)
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textTertiary)
                Spacer()
                Text("+\(dailyQuest.spReward) LV XP")
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(categoryColor)
                    .monospacedDigit()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(dailyQuest.title.uppercased())
                    .font(Font.unbound.titleM)
                    .tracking(0.4)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text(dailyQuest.subtitle)
                    .font(Font.unbound.monoS)
                    .tracking(0.4)
                    .foregroundStyle(Color.unbound.textSecondary)
            }

            Button {
                UnboundHaptics.medium()
                activeRoutine = SideQuestLibrary.pushProtocol
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

    // MARK: - Daily Quest placeholder model
    //
    // Hardcoded sample until QuestService + QuestLibrary land. Shape here
    // mirrors what the real QuestDef will expose so the card doesn't need
    // rewiring — only the data source changes.
    struct DailyQuestPlaceholder {
        enum Category {
            case cardio, mobility, activity, circuit
            var label: String {
                switch self {
                case .cardio:   return "CARDIO"
                case .mobility: return "MOBILITY"
                case .activity: return "ACTIVITY"
                case .circuit:  return "CIRCUIT"
                }
            }
        }
        var title: String
        var subtitle: String
        var category: Category
        var spReward: Int

        static let sample = DailyQuestPlaceholder(
            title: "Push Protocol",
            subtitle: "5 exercises · 15 sets · ~25 min",
            category: .circuit,
            spReward: 40
        )
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
