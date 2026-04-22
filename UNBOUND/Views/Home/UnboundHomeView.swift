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
// Reads SessionXPService for streak, StatScoreService for the four axes,
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
    @AppStorage("unbound.lastSessionDate") private var lastSessionTimestamp: Double = 0
    @State private var sessionXP: SessionXPRecord?

    // Ranking + stats
    @State private var aggregateRank: SubRank = .eMinus
    @State private var statScore: StatScore = .empty

    // Contextual triggers
    @State private var plateaus: [PlateauedExercise] = []
    @State private var calibrationSkipRatio: Double = 0
    @State private var hasLoggedAnyWorkout: Bool = false
    @State private var lastLog: WorkoutLog?

    // Modal state
    @State private var showingSession = false
    @State private var showingCalibrationWorkout = false
    @State private var navigateToCoach: String?
    @State private var showingGainsToast = false
    @State private var lastGainsAwarded: Int = 0

    // Level derivation: 250 XP per level. Simple, overrideable later.
    private let xpPerLevel: Int = 250

    // MARK: Body

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(Color.unbound.accent)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        topBar
                        rankCard
                        todayMissionCTA
                        contextualStack
                        statsGrid
                        lastSessionRecap
                        Spacer().frame(height: 28)
                    }
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
        .onReceive(NotificationCenter.default.publisher(for: .rankAdvanced)) { _ in
            Task { await refreshRanksAndStats() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sessionXPUpdated)) { _ in
            Task {
                await refreshSessionXP()
                await refreshRanksAndStats()
                await refreshLastLog()
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
        .nodeUnlockOverlay()
        .weightBumpToast()
        .tierUnlockToast()
        .navigationDestination(isPresented: Binding(
            get: { navigateToCoach != nil },
            set: { if !$0 { navigateToCoach = nil } }
        )) {
            if let prompt = navigateToCoach {
                CoachTabView(prefill: prompt)
                    .environmentObject(services)
            }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("UNBOUND")
                .font(Font.unbound.titleS)
                .tracking(2.0)
                .foregroundStyle(Color.unbound.textPrimary)

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
        .frame(height: 36)
    }

    private var streakChip: some View {
        let streak = sessionXP?.currentStreak ?? 0
        let fireGradient = LinearGradient(
            colors: [
                Color(red: 0.97, green: 0.45, blue: 0.09), // #F97316 orange
                Color(red: 0.94, green: 0.27, blue: 0.27)  // #EF4444 red
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        return HStack(spacing: 5) {
            Image(systemName: "flame.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(fireGradient)
            Text("\(streak)")
                .font(Font.unbound.monoS)
                .foregroundStyle(fireGradient)
                .monospacedDigit()
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color(red: 0.97, green: 0.45, blue: 0.09).opacity(0.10))
        )
        .overlay(
            Capsule()
                .strokeBorder(Color(red: 0.97, green: 0.45, blue: 0.09).opacity(0.35), lineWidth: 0.8)
        )
    }

    // MARK: - Rank card

    private var rankCard: some View {
        let level = (gains / xpPerLevel) + 1
        let xpInLevel = gains % xpPerLevel
        let fraction = Double(xpInLevel) / Double(xpPerLevel)
        let tierName = tierName(for: aggregateRank)
        let rankColor = aggregateRank.regionTint
        let nextRank = aggregateRank.advanced(by: 1)

        return HStack(alignment: .top, spacing: 18) {
            // Rank letter tinted by its tier (E red → B green → A violet → S gold).
            // Meaningful color, not decorative — the letter IS the identity.
            VStack(alignment: .leading, spacing: 6) {
                Text(aggregateRank.letter)
                    .font(Font.unbound.displayXL)
                    .foregroundStyle(rankColor)
                    .shadow(color: rankColor.opacity(0.55), radius: 10)
                Text(tierName.uppercased())
                    .font(Font.unbound.monoS)
                    .tracking(2.0)
                    .foregroundStyle(rankColor.opacity(0.85))
                Text("NEXT · \(nextRank.displayName)")
                    .font(Font.unbound.captionS)
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textTertiary)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 6) {
                    Text("LV")
                        .font(Font.unbound.captionS)
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text("\(level)")
                        .font(Font.unbound.monoL)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .monospacedDigit()
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.unbound.borderSubtle)
                        Capsule()
                            .fill(Color.unbound.accent)
                            .frame(width: max(4, proxy.size.width * fraction))
                            .shadow(color: Color.unbound.accent.opacity(0.45), radius: 3)
                    }
                }
                .frame(width: 140, height: 4)

                Text("\(xpInLevel) / \(xpPerLevel) SP")
                    .font(Font.unbound.captionS)
                    .tracking(0.8)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .background(
            // Subtle radial wash of the rank color so the card feels alive
            // at high tiers without shouting. At E-tier the wash is red and
            // the card looks appropriately "dormant"; at S it glows gold.
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.unbound.surface)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [rankColor.opacity(0.12), .clear],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: 260
                        )
                    )
            }
        )
    }

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

    // MARK: - Contextual stack

    @ViewBuilder
    private var contextualStack: some View {
        VStack(spacing: 12) {
            RecalibratingBanner()

            if !plateaus.isEmpty {
                plateauBanner
            }

            if shouldShowCalibrationCard {
                DayOneCalibrationCard(style: .slim) {
                    UnboundHaptics.medium()
                    showingCalibrationWorkout = true
                }
            }

            if shouldShowScanCTA {
                scanCTACard
            }
        }
    }

    private var plateauBanner: some View {
        let first = plateaus[0]
        return Button {
            UnboundHaptics.medium()
            navigateToCoach = "Why is my \(first.displayName.lowercased()) stuck?"
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.unbound.warnOrange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(first.displayName) has stalled")
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text("\(first.stalledSessions) sessions without progress.")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(1)
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
        }
        .buttonStyle(.plain)
    }

    private var scanCTACard: some View {
        HStack(spacing: 14) {
            Image(systemName: "camera.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.unbound.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Time to rescan")
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text("See what's changed in the last 30 days.")
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
    }

    // MARK: - Stats grid

    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("STATS")
                .font(Font.unbound.captionS)
                .tracking(1.8)
                .foregroundStyle(Color.unbound.textTertiary)

            // Single compact row of 4 rings. Color per stat gives identity
            // without screaming — each ring stroke uses a muted token from
            // the existing rank palette.
            HStack(spacing: 10) {
                statPill(
                    label: "STR",
                    value: statScore.strength,
                    color: Color.unbound.rankRed
                )
                statPill(
                    label: "STA",
                    value: statScore.stamina,
                    color: Color.unbound.rankGreen
                )
                statPill(
                    label: "TEC",
                    value: statScore.technique,
                    color: Color.unbound.accent
                )
                statPill(
                    label: "VIT",
                    value: statScore.vitality,
                    color: Color.unbound.coachCyan
                )
            }
        }
    }

    private func statPill(label: String, value: Int, color: Color) -> some View {
        let fraction = max(0, min(1, Double(value) / 100.0))
        return HStack(spacing: 8) {
            // Tiny ring indicator — 22pt, thin stroke. Color is ambient;
            // the number is the readable element.
            ZStack {
                Circle()
                    .stroke(Color.unbound.borderSubtle, lineWidth: 2)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(
                        color.opacity(0.85),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("\(value)")
                    .font(Font.unbound.monoS.weight(.semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .monospacedDigit()
                Text(label)
                    .font(.system(size: 8, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.unbound.surface)
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

        await SkillProgressService.shared.load(userId: userId)
        await RankDecayService.shared.evaluateOnForeground(userId: userId)

        let progressionStates = await ProgressionStateStore.shared.fetchAll(userId: userId)
        plateaus = await PlateauDetector.shared.detect(userId: userId, states: progressionStates)
        await refreshCalibrationState()

        do {
            let fetched: UserProfile = try await services.user.fetchProfile(userId: userId)
            profile = fetched

            if let programId = fetched.currentProgramId,
               let existing: TrainingProgram = try? await services.database.read(
                collection: "programs", documentId: programId
               ) {
                program = existing
            } else {
                let generated = await ProgramGenerationService.shared.generateFromOnboarding(
                    userId: userId,
                    archetype: fetched.preferredArchetype ?? .vTaper,
                    targetFrequency: fetched.targetFrequency,
                    equipment: Set(fetched.equipment ?? []),
                    experience: fetched.experience,
                    sessionLength: fetched.sessionLength,
                    exerciseStyles: [],
                    targetAreas: Set(fetched.targetAreas ?? [])
                )
                program = generated
            }
        } catch {
            profile = UserProfile(
                id: userId, email: nil, displayName: nil,
                createdAt: Date(), onboardingCompleted: true, totalScans: 0,
                currentProgramId: nil, preferredArchetype: .vTaper,
                heightCm: nil, weightKg: nil, age: nil, biologicalSex: nil
            )
        }

        await refreshSessionXP()
        await refreshRanksAndStats()
        await refreshLastLog()

        isLoading = false
    }

    @MainActor
    private func refreshRanksAndStats() async {
        let userId = services.auth.currentUserId ?? "anonymous"
        let archetype = profile?.preferredArchetype ?? .vTaper
        aggregateRank = await services.rank.archetypeRank(userId: userId, archetype: archetype)
        statScore = await services.statScore.compute(userId: userId, archetype: archetype)
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
        }
    }

    // MARK: - Derived

    private var archetypeName: String {
        profile?.preferredArchetype?.shortName ?? "UNBOUND"
    }

    private var todayProgramDay: ProgramDay? {
        guard let program else { return nil }
        guard !program.days.isEmpty else { return nil }
        let daysSinceStart = max(
            0,
            Calendar.current.dateComponents([.day], from: program.createdAt, to: Date()).day ?? 0
        )
        let dayIndex = daysSinceStart % program.days.count
        return program.days[dayIndex]
    }

    private var shouldShowCalibrationCard: Bool {
        calibrationSkipRatio > 0.5 && !hasLoggedAnyWorkout
    }

    private var shouldShowScanCTA: Bool {
        guard lastScanTimestamp > 0 else { return false }
        let secondsSince = Date().timeIntervalSince1970 - lastScanTimestamp
        return secondsSince >= 30 * 24 * 3600
    }

    /// E/D/C/B/A/S → Dormant/Awakened/Forged/Sharpened/Unbound/Ascended
    /// per the brand rank tier system.
    private func tierName(for rank: SubRank) -> String {
        switch rank.letter {
        case "E": return "Dormant"
        case "D": return "Awakened"
        case "C": return "Forged"
        case "B": return "Sharpened"
        case "A": return "Unbound"
        case "S": return "Ascended"
        default:  return "Dormant"
        }
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
}
