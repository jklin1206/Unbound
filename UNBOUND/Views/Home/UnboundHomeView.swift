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

    // Contextual triggers
    @State private var plateaus: [PlateauedExercise] = []
    @State private var calibrationSkipRatio: Double = 0
    @State private var hasLoggedAnyWorkout: Bool = false
    @State private var lastLog: WorkoutLog?
    @State private var weekSessionDays: Set<Int> = [] // Mon=1...Sun=7

    // Modal state
    @State private var showingSession = false
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

    // Coach note (daily AI insight, bounded to 1 call/user/day)
    @State private var coachNote: CoachNote?

    // Travel override (user hit the TRAVEL coach action)
    @State private var activeTravelOverride: TravelOverride?

    // Scan cadence — drives ScanDueCard visibility
    @State private var scanCadence: ScanCadenceState = .compute(lastScanAt: nil, now: .now)
    @State private var lastScanAt: Date? = nil
    @State private var showScanCaptureFlow = false

    // Trials
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
                        modesStrip
                        dailyQuestBand
                        contextualStack
                        HomeBuildChipCard(profile: attributeProfile) {
                            NotificationCenter.default.post(name: .requestNavigateToProfileTab, object: nil)
                        }
                        lastSessionRecap
                        Spacer().frame(height: 28)
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
        .fullScreenCover(isPresented: $showingSession, onDismiss: onSessionComplete) {
            if let workout = todayProgramDay?.workout, let program {
                NavigationStack {
                    WorkoutLoggingView(
                        workout: workout,
                        programId: program.id,
                        dayNumber: todayProgramDay?.dayNumber ?? 1,
                        services: services
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
                    services.trials.pickCard(card, userId: userId)
                    trialsState = services.trials.state(userId: userId)
                }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .trialCompleted)) { _ in
            if let userId = services.auth.currentUserId {
                trialsState = services.trials.state(userId: userId)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .trialWeekRolled)) { _ in
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
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
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
        let title = workout?.name ?? (isRest ? "Recovery Protocol" : "Coach Protocol")
        let minutes = workout?.estimatedMinutes ?? (isRest ? 18 : 30)
        let focus = workout?.targetMuscleGroups.first?.displayName.uppercased() ?? (isRest ? "RECOVERY" : "CUSTOM")

        return ZStack(alignment: .topTrailing) {
            ProtocolHeroBackground(tint: tint)

            VStack(alignment: .leading, spacing: 18) {
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
                            .lineLimit(2)
                            .minimumScaleFactor(0.72)

                        HStack(spacing: 8) {
                            Text(programDayLabel)
                            Text("·")
                                .foregroundStyle(Color.unbound.textTertiary.opacity(0.55))
                            Text("\(minutes) min")
                            Text("·")
                                .foregroundStyle(Color.unbound.textTertiary.opacity(0.55))
                            Text("\(workout?.mainExercises.count ?? 0) movements")
                        }
                        .font(Font.unbound.monoS.weight(.semibold))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.70)
                    }

                    Spacer(minLength: 0)

                    integratedRankRail
                }

                Button {
                    UnboundHaptics.medium()
                    if canStart {
                        showingSession = true
                    } else if isRest {
                        captureMode = .photo
                    }
                } label: {
                    HStack(spacing: 11) {
                        Text(protocolPrimaryLabel(canStart: canStart, isRest: isRest).uppercased())
                            .font(Font.unbound.bodyMStrong)
                            .tracking(1.4)
                        Image(systemName: canStart ? "arrow.right" : "camera.fill")
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

                consoleDivider

                consoleExercisePlan(workout: workout)

                coachCueAnnotation

                consoleDivider

                weekPath
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
            Text("\(xpInLevel)/\(xpPerLevel) SP")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.unbound.textTertiary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(width: 76, alignment: .trailing)
    }

    private func consoleExercisePlan(workout: Workout?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("SESSION PLAN")
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.7)
                    .foregroundStyle(Color.unbound.textTertiary)
                Spacer()
                Text(workout == nil ? "ADAPTIVE" : "\(workout?.mainExercises.count ?? 0) MOVES")
                    .font(Font.unbound.monoS.weight(.semibold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .monospacedDigit()
            }
            .padding(.bottom, 6)

            if let workout {
                ForEach(Array(workout.mainExercises.prefix(3).enumerated()), id: \.offset) { index, exercise in
                    premiumExerciseRow(index: index + 1, exercise: exercise)
                    if index < min(2, workout.mainExercises.count - 1) {
                        Rectangle()
                            .fill(Color.white.opacity(0.07))
                            .frame(height: 0.5)
                            .padding(.leading, 38)
                    }
                }
            } else {
                protocolRecoveryRow(isRest: todayProgramDay?.isRestDay ?? false)
            }
        }
    }

    private var coachCueAnnotation: some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle()
                .fill(Color.unbound.accent.opacity(0.85))
                .frame(width: 2)
                .padding(.vertical, 3)

            VStack(alignment: .leading, spacing: 3) {
                Text("COACH CUE")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.accent)
                Text(coachCueText)
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(2)
                    .lineSpacing(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
    }

    private var weekPath: some View {
        let labels = ["M", "T", "W", "T", "F", "S", "S"]
        let todayIndex = ((Calendar.current.component(.weekday, from: Date()) + 5) % 7) + 1

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 7) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.unbound.ember)
                    Text("\(sessionXP?.currentStreak ?? streakDays) DAY STREAK")
                        .font(Font.unbound.captionS.weight(.bold))
                        .tracking(1.5)
                        .foregroundStyle(Color.unbound.ember)
                        .monospacedDigit()
                }
                Spacer()
                Text("WEEK PATH \(weekSessionDays.count)/7")
                    .font(Font.unbound.monoS.weight(.semibold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .monospacedDigit()
            }

            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { index in
                    VStack(spacing: 7) {
                        ZStack {
                            if index < 6 {
                                Rectangle()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(height: 1)
                                    .offset(x: 18)
                            }
                            Circle()
                                .fill(weekPathColor(index: index, todayIndex: todayIndex))
                                .frame(width: (index + 1) == todayIndex ? 13 : 10, height: (index + 1) == todayIndex ? 13 : 10)
                                .overlay(
                                    Circle()
                                        .strokeBorder((index + 1) == todayIndex ? Color.white.opacity(0.45) : Color.clear, lineWidth: 1)
                                )
                        }
                        Text(labels[index])
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.unbound.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var consoleDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 0.5)
    }

    private var exercisePreviewCard: some View {
        let workout = todayProgramDay?.workout

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SESSION PLAN")
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.8)
                    .foregroundStyle(Color.unbound.textTertiary)
                Spacer()
                Text(workout == nil ? "ADAPTIVE" : "\(workout?.mainExercises.count ?? 0) MOVES")
                    .font(Font.unbound.monoS.weight(.semibold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .monospacedDigit()
            }

            if let workout {
                VStack(spacing: 0) {
                    ForEach(Array(workout.mainExercises.prefix(4).enumerated()), id: \.offset) { index, exercise in
                        premiumExerciseRow(index: index + 1, exercise: exercise)
                        if index < min(3, workout.mainExercises.count - 1) {
                            Rectangle()
                                .fill(Color.unbound.borderSubtle)
                                .frame(height: 0.5)
                                .padding(.leading, 38)
                        }
                    }
                }
            } else {
                protocolRecoveryRow(isRest: todayProgramDay?.isRestDay ?? false)
            }
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

    private var weeklyCoachBento: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("WEEK")
                        .font(Font.unbound.captionS.weight(.bold))
                        .tracking(1.7)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Spacer()
                    Text("\(weekSessionDays.count)/7")
                        .font(Font.unbound.monoS.weight(.semibold))
                        .foregroundStyle(Color.unbound.ember)
                        .monospacedDigit()
                }
                compactWeekGlyphs
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.unbound.surface)
            )

            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 7) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.unbound.accent)
                    Text("COACH")
                        .font(Font.unbound.captionS.weight(.bold))
                        .tracking(1.7)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
                Text(coachNote?.text ?? "Keep the first lift crisp. If bar speed drops, trim one accessory set.")
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(4)
                    .lineSpacing(2)
                    .minimumScaleFactor(0.86)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.unbound.surface)
            )
        }
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle.opacity(0.45), lineWidth: 1)
                .allowsHitTesting(false)
        )
    }

    private var compactWeekGlyphs: some View {
        let labels = ["M", "T", "W", "T", "F", "S", "S"]
        let todayIndex = ((Calendar.current.component(.weekday, from: Date()) + 5) % 7) + 1
        return HStack(spacing: 5) {
            ForEach(0..<7, id: \.self) { index in
                VStack(spacing: 7) {
                    Text(labels[index])
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.unbound.textTertiary)
                    Capsule()
                        .fill(weekSessionDays.contains(index + 1) ? Color.unbound.ember : ((index + 1) == todayIndex ? Color.unbound.accent : Color.unbound.borderSubtle))
                        .frame(width: 12, height: weekSessionDays.contains(index + 1) ? 28 : ((index + 1) == todayIndex ? 18 : 10))
                        .shadow(color: weekSessionDays.contains(index + 1) ? Color.unbound.ember.opacity(0.28) : .clear, radius: 6)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 54, alignment: .bottom)
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

                Text("+\(dailyQuest.spReward)")
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(categoryColor)
                    .monospacedDigit()
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
        canStart ? Color.unbound.accent : (isRest ? Color.unbound.coachCyan : Color.unbound.warnOrange)
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
        let total = program?.days.count ?? 14
        if day.dayNumber > 0 {
            return "Day \(day.dayNumber) / \(max(total, day.dayNumber))"
        }
        return "Travel day"
    }

    private var coachCueText: String {
        if let note = coachNote?.text, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return note
        }
        // Trial-aware cue: surface the first aligned exercise when a trial is active
        if let trial = trialsState.currentTrial,
           trial.capstoneState == .pending || trial.capstoneState == .windowOpen,
           let workout = todayProgramDay?.workout,
           let alignedExercise = workout.mainExercises.first(where: { isAlignedExercise($0) }) {
            let motivation = trial.chosenCard.kind == .prestige
                ? "Stretch the envelope."
                : "This is your trial axis — push +1 RPE on your top set."
            return "Trial: push +1 RPE on \(alignedExercise.name). \(motivation)"
        }
        if let first = todayProgramDay?.workout?.mainExercises.first {
            return "Keep the first lift crisp: \(first.name). Stop one rep before form breaks."
        }
        if todayProgramDay?.isRestDay == true {
            return "Recovery protects the block. Keep movement easy and log a photo check-in."
        }
        return "Build a useful session from your current program before you train."
    }

    private func weekPathColor(index: Int, todayIndex: Int) -> Color {
        if weekSessionDays.contains(index + 1) { return Color.unbound.rankGreen }
        if (index + 1) == todayIndex { return Color.unbound.ember }
        return Color.white.opacity(0.16)
    }

    private func protocolHeroSubtitle(workout: Workout?, isRest: Bool) -> String {
        if let workout {
            return "\(workout.mainExercises.count) main lifts calibrated for today's block. Start clean, log every top set."
        }
        if isRest {
            return "Recovery is scheduled. Bank the day with a photo check-in or low-intensity work."
        }
        return "No session is queued. Coach can build a practical session from your current program."
    }

    private func protocolPrimaryLabel(canStart: Bool, isRest: Bool) -> String {
        if canStart { return "Begin Session" }
        return isRest ? "Log Check-In" : "Ask Coach"
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

    private func premiumExerciseRow(index: Int, exercise: Exercise) -> some View {
        let trialAligned = isAlignedExercise(exercise)
        let trialTint = trialsState.currentTrial?.chosenCard.theme.tintColor ?? Color.unbound.accent

        return HStack(alignment: .center, spacing: 12) {
            Text(String(format: "%02d", index))
                .font(Font.unbound.monoS.weight(.bold))
                .foregroundStyle(Color.unbound.textTertiary)
                .frame(width: 26, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                Text("\(exercise.sets) x \(exercise.reps) · \(exercise.restSeconds)s rest")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }

            Spacer(minLength: 0)

            // Trial-aligned indicator (shown before RPE chip when active)
            if trialAligned {
                HStack(spacing: 4) {
                    Text("TRIAL")
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(trialTint)
                    Text("+1 RPE")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(trialTint.opacity(0.8))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Capsule().fill(trialTint.opacity(0.14)))
                .overlay(Capsule().strokeBorder(trialTint.opacity(0.28), lineWidth: 0.5))
            }

            if let rpe = exercise.rpe {
                Text("RPE \(rpe)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.unbound.accent)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.unbound.accent.opacity(0.12)))
            }
        }
        .padding(.vertical, 10)
    }

    /// Returns true if the exercise name contributes to any axis that the
    /// current trial's theme targets. No trial = always false.
    private func isAlignedExercise(_ exercise: Exercise) -> Bool {
        guard let trial = trialsState.currentTrial,
              trial.capstoneState != .missed,
              trial.capstoneState != .completed else { return false }
        guard case .axis(let targetAxis) = trial.chosenCard.theme else { return false }
        let contribution = AttributeCatalog.shared.contribution(forExerciseName: exercise.name)
        return contribution.weight(for: targetAxis) > 0.05
    }

    private var questColor: Color {
        switch dailyQuest.category {
        case .cardio:   return Color.unbound.coachCyan
        case .mobility: return Color.unbound.rankGreen
        case .activity: return Color.unbound.warnOrange
        case .circuit:  return Color.unbound.accent
        }
    }

    // MARK: - Today protocol

    private var todayProtocolCard: some View {
        let day = todayProgramDay
        let workout = day?.workout
        let isRest = day?.isRestDay ?? false
        let canStart = workout != nil && !isRest
        let tint = canStart ? Color.unbound.accent : (isRest ? Color.unbound.coachCyan : Color.unbound.warnOrange)
        let title = workout?.name ?? (isRest ? "Recovery protocol" : "No protocol queued")
        let subtitle: String = {
            if let workout {
                return "\(workout.mainExercises.count) main lifts · about \(workout.estimatedMinutes) min"
            }
            if isRest {
                return "Keep the day useful with a photo check-in, light movement, or mobility."
            }
            return "Ask coach to rebuild today's work from your current program."
        }()
        let primaryLabel = canStart ? "Begin Session" : (isRest ? "Log Check-In" : "Ask Coach")
        let primaryIcon = canStart ? "arrow.right" : (isRest ? "camera.fill" : "message.fill")

        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 10) {
                protocolStatusPill(label: "TODAY", value: readinessValue, tint: tint)
                Spacer()
                Text(shortDayString())
                    .font(Font.unbound.monoS.weight(.semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
                    .monospacedDigit()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.76)

                Text(subtitle)
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }

            if let workout {
                VStack(spacing: 0) {
                    ForEach(Array(workout.mainExercises.prefix(3).enumerated()), id: \.offset) { index, exercise in
                        protocolExerciseRow(index: index + 1, exercise: exercise)
                        if index < min(2, workout.mainExercises.count - 1) {
                            Rectangle()
                                .fill(Color.unbound.borderSubtle)
                                .frame(height: 0.5)
                                .padding(.leading, 34)
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Color.unbound.bg.opacity(0.34))
                )
            } else {
                protocolRecoveryRow(isRest: isRest)
            }

            Button {
                UnboundHaptics.medium()
                if canStart {
                    showingSession = true
                } else if isRest {
                    captureMode = .photo
                }
            } label: {
                HStack(spacing: 10) {
                    Text(primaryLabel.uppercased())
                        .font(Font.unbound.bodyMStrong)
                        .tracking(1.4)
                    Image(systemName: primaryIcon)
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tint)
                )
                .contentShape(Rectangle())
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
                            colors: [tint.opacity(0.10), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(tint.opacity(0.28), lineWidth: 1)
        )
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

    private func protocolExerciseRow(index: Int, exercise: Exercise) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(String(format: "%02d", index))
                .font(Font.unbound.monoS.weight(.semibold))
                .foregroundStyle(Color.unbound.textTertiary)
                .monospacedDigit()
                .frame(width: 22, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text("\(exercise.sets) SETS · \(exercise.reps) · \(exercise.restSeconds)S REST")
                    .font(Font.unbound.captionS)
                    .tracking(1.0)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }

    private func protocolRecoveryRow(isRest: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill((isRest ? Color.unbound.coachCyan : Color.unbound.warnOrange).opacity(0.15))
                Image(systemName: isRest ? "figure.cooldown" : "wand.and.stars")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isRest ? Color.unbound.coachCyan : Color.unbound.warnOrange)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(isRest ? "Recovery still counts" : "Coach can patch the gap")
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text(isRest ? "Photo, walk, mobility, or stretch." : "Generate a useful session from your current state.")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.unbound.bg.opacity(0.34))
        )
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
                railMetric(label: "SP", value: "\(gains)", detail: "banked", tint: Color.unbound.textPrimary)
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
        return "No session is queued. Use the rail below to decide whether to train, scan, or recalibrate."
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
                    image: nil,
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

    // MARK: - Rank card

    // MARK: - Today's Mission CTA

    private var todayMissionCTA: some View {
        let day = todayProgramDay
        let isRest = day?.isRestDay ?? false
        let title: String = {
            if let day {
                if day.isRestDay { return "REST DAY" }
                if let workout = day.workout { return workout.name.uppercased() }
            }
            return "NO SESSION"
        }()
        let subtitle: String = {
            if let day {
                if day.isRestDay { return "Recovery is the work." }
                if let workout = day.workout {
                    return "\(workout.mainExercises.count) EXERCISES · ~\(workout.estimatedMinutes)M"
                }
            }
            return "Plan your next move."
        }()
        let canStart = day?.workout != nil && !isRest

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("TODAY")
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.8)
                    .foregroundStyle(Color.unbound.accent)
                Text("·")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text(shortDayString())
                    .font(Font.unbound.captionS)
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textTertiary)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Font.unbound.titleM)
                    .tracking(0.4)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text(subtitle)
                    .font(Font.unbound.monoS)
                    .tracking(0.8)
                    .foregroundStyle(Color.unbound.textSecondary)
            }

            Button {
                guard canStart else { return }
                UnboundHaptics.medium()
                showingSession = true
            } label: {
                HStack(spacing: 10) {
                    Text(canStart ? "BEGIN SESSION" : (isRest ? "TAKE THE REST" : "NOTHING PLANNED"))
                        .font(Font.unbound.bodyMStrong)
                        .tracking(1.6)
                    if canStart {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                }
                .foregroundStyle(canStart ? Color.unbound.textPrimary : Color.unbound.textTertiary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(canStart ? Color.unbound.accent : Color.unbound.borderSubtle)
                )
                .shadow(
                    color: canStart ? Color.unbound.accent.opacity(0.45) : .clear,
                    radius: 14, y: 2
                )
            }
            .buttonStyle(.plain)
            .disabled(!canStart)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.unbound.surface)
                // Soft violet wash — the mission card is the one module on
                // home that carries the brand accent as ambient color.
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.unbound.accent.opacity(0.08),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.unbound.accent.opacity(0.30), lineWidth: 1)
        )
    }

    // MARK: - Weekly rhythm
    //
    // Seven-day strip showing which days had sessions this week. Light
    // motion signal — "am I showing up?" without a full history chart.

    private var weeklyRhythm: some View {
        let labels = ["M", "T", "W", "T", "F", "S", "S"]
        let todayIndex = ((Calendar.current.component(.weekday, from: Date()) + 5) % 7) + 1
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("THIS WEEK")
                    .font(Font.unbound.captionS)
                    .tracking(1.8)
                    .foregroundStyle(Color.unbound.textTertiary)
                Spacer()
                Text("\(weekSessionDays.count) / 7")
                    .font(Font.unbound.monoS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .monospacedDigit()
            }

            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    VStack(spacing: 6) {
                        Text(labels[i])
                            .font(Font.unbound.captionS)
                            .tracking(1.2)
                            .foregroundStyle(Color.unbound.textTertiary)
                        dayGlyph(
                            hasSession: weekSessionDays.contains(i + 1),
                            isToday: (i + 1) == todayIndex,
                            isPast: (i + 1) < todayIndex
                        )
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surface)
        )
    }

    @ViewBuilder
    private func dayGlyph(hasSession: Bool, isToday: Bool, isPast: Bool) -> some View {
        if hasSession {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.unbound.accent)
                .frame(width: 14, height: 14)
        } else if isToday {
            Circle()
                .fill(Color.unbound.accent)
                .frame(width: 8, height: 8)
                .shadow(color: Color.unbound.accent.opacity(0.55), radius: 3)
        } else if isPast {
            Circle()
                .fill(Color.unbound.borderSubtle)
                .frame(width: 4, height: 4)
        } else {
            Circle()
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                .frame(width: 8, height: 8)
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

            if scanCadence.isUnlocked || lastScanAt == nil {
                ScanDueCard(
                    cadenceState: scanCadence,
                    isFirstScan: lastScanAt == nil,
                    onTap: { showScanCaptureFlow = true }
                )
            }

            // ── Trial status card ──────────────────────────────────
            if let activeTrial = trialsState.currentTrial,
               activeTrial.capstoneState != .missed {
                ActiveTrialCard(trial: activeTrial)
            } else if !trialsState.skippedCurrentWeek && !trialsState.currentWeekCards.isEmpty {
                TrialPickerPromptCard {
                    showTrialPicker = true
                }
            }

            if shouldShowScanCTA {
                scanCTACard
            }
        }
    }

    private var modesStrip: some View {
        CoachModesStrip(
            plateaus: plateaus,
            userId: services.auth.currentUserId ?? ""
        ) { override in
            activeTravelOverride = override
        }
    }

    private var scanCTACard: some View {
        let isScanDue = shouldShowScanEligibility
        let title = isScanDue ? "Bi-weekly scan due" : "Lock in today's photo"
        let subtitle = isScanDue
            ? "3-sentence coach read · +25 SP"
            : "Keep the arc honest · +5 SP"
        let icon = isScanDue ? "sparkle.magnifyingglass" : "camera.fill"

        return Button {
            UnboundHaptics.medium()
            captureMode = isScanDue ? .scan : .photo
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.unbound.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text(subtitle)
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isScanDue ? Color.unbound.accent.opacity(0.35) : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Stats grid


    // MARK: - Coach note card
    //
    // One AI-generated insight per day. Surfaced on home in a compact
    // card above Today's Mission. Generated once per calendar day via
    // `CoachNotesService` — subsequent appearances hit the cache.

    private func coachNoteCard(note: CoachNote) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.unbound.accent.opacity(0.15))
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.unbound.accent)
            }
            .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 4) {
                Text("COACH · TODAY")
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.accent)
                Text(note.text)
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.unbound.accent.opacity(0.25), lineWidth: 1)
        )
    }

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
                    Text("+\(lastGainsAwarded) SP")
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
                Text("+\(lastGainsAwarded) SP")
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

        async let skillLoad: Void = SkillProgressService.shared.load(userId: userId)
        async let rankDecay: Void = RankDecayService.shared.evaluateOnForeground(userId: userId)
        async let plateausResult: [PlateauedExercise] = {
            let states = await ProgressionStateStore.shared.fetchAll(userId: userId)
            return await PlateauDetector.shared.detect(userId: userId, states: states)
        }()
        async let profileProgram: (UserProfile?, TrainingProgram?) = loadProfileAndProgram(userId)
        async let recentLogs: [WorkoutLog] = fetchRecentLogsSafe(userId: userId, limit: 40)
        async let ranks: (SubRank, SkillTier) = loadRanks(userId)
        async let travel: TravelOverride? = TravelOverrideStore.shared.activeOverride(for: userId)
        async let coach: CoachNote? = CoachNotesService.shared.todaysNote(userId: userId)

        _ = await skillLoad
        _ = await rankDecay
        plateaus = await plateausResult

        let (fetchedProfile, loadedProgram) = await profileProgram
        if let fetchedProfile {
            profile = fetchedProfile
            program = loadedProgram
        } else {
            profile = UserProfile(
                id: userId, email: nil, displayName: nil,
                createdAt: Date(), onboardingCompleted: true, totalScans: 0,
                currentProgramId: nil,
                heightCm: nil, weightKg: nil, age: nil, biologicalSex: nil
            )
        }

        applyRecentLogs(await recentLogs)

        let (r, t) = await ranks
        aggregateRank = r
        aggregateTier = t
        activeTravelOverride = await travel
        coachNote = await coach

        // Cheap synchronous reads — keep last, same values as before.
        sessionXP = services.sessionXP.record(userId: userId)
        calibrationSkipRatio = services.calibration.skipRatio(userId: userId)
        attributeProfile = services.attribute.profile(userId: userId)

        let history = (try? ScanCheckpointStore.shared.history(userId: userId)) ?? []
        lastScanAt = history.last?.createdAt
        scanCadence = ScanCadenceState.compute(lastScanAt: lastScanAt, now: .now)

        trialsState = services.trials.state(userId: userId)

        isLoading = false
        // Kick off ambient loops once the content is actually on screen —
        // .onAppear fires while still in the loading state, so the
        // animation bindings never connect to rendered views.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            startAmbientAnimations()
        }
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
                exerciseStyles: [],
                targetAreas: Set(fetched.targetAreas ?? [])
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
    private func refreshCoachNote() async {
        let userId = services.auth.currentUserId ?? "anonymous"
        coachNote = await CoachNotesService.shared.todaysNote(userId: userId)
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
        let oneDay: TimeInterval = 24 * 3600

        if today == lastDay { return }

        let earned = 30
        gains += earned
        lastGainsAwarded = earned

        if today - lastDay <= oneDay * 2 {
            streakDays += 1
        } else {
            streakDays = 1
        }
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
                Text("+\(dailyQuest.spReward) SP")
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
