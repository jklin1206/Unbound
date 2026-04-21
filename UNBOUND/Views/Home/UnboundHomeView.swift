import SwiftUI

// MARK: - UnboundHomeView
//
// Character-sheet-first home hub. The body map is the emotional anchor and
// sits at the top of the screen; everything else is secondary action.
//
// Layout (top to bottom):
//   - Slim header (archetype · rank · stats + progress-to-next)
//   - CHARACTER HERO — full-width body map with rank-tinted muscle heatmap
//   - TODAY mission — full-width primary CTA (violet accent)
//   - Phase chip (slim pill, tappable → rationale sheet)
//   - Recalibrating / plateau banners (when relevant)
//   - 2-col: Coach (cyan accent) | Needs Work (orange accent)
//   - Weekly strip (M-S session dots)
//   - Badges horizontal scroll
//   - Calibration slim banner (only when calibration incomplete)
//   - Stamina card + rescan CTA (when relevant)
//
// Preserves: DayOneCalibrationCard, RecalibratingBanner, StaminaCardView,
// weight-bump / tier-unlock / badge / skin / gains toasts, RankUpCinematic
// (mounted on HomeTabView), CoachTabView navigation, session flow,
// calibration-workout cover, rank-advance notification handler.

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

    // Ranking
    @State private var liftRanks: [LiftRank] = []
    @State private var regionRanks: [BodyRegion: RegionRank] = [:]
    @State private var aggregateRank: SubRank = .eMinus

    // Phase engine
    @State private var phase: ProgramPhase?

    // Progression / plateaus
    @State private var progressionStates: [ProgressionState] = []
    @State private var plateaus: [PlateauedExercise] = []

    // Coach preview
    @State private var latestCoachMessage: String?

    // Modal state
    @State private var selectedRegion: BodyRegion?
    @State private var showingSession = false
    @State private var showingCalibrationWorkout = false
    @State private var showingExpandedMap = false
    @State private var showingBadgeGallery = false
    @State private var calibrationSkipRatio: Double = 0
    @State private var hasLoggedAnyWorkout: Bool = false
    @State private var navigateToCoach: String?
    @State private var showingGainsToast = false
    @State private var lastGainsAwarded: Int = 0
    @State private var streakAtRisk: Bool = false

    // Recent badges + weekly strip
    @State private var recentBadges: [Badge] = []
    @State private var weekSessionDays: Set<Int> = [] // 1...7 Monday = 1

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .tint(Color.unbound.accent)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 18) {
                        slimHeader

                        // HERO: character body map, full-width, top of hub.
                        characterHero

                        // Primary CTA — today's mission.
                        todayHeroCTA

                        if let phase {
                            PhaseChip(phase: phase)
                        }

                        RecalibratingBanner()

                        if !plateaus.isEmpty {
                            plateauBanner
                        }

                        // Secondary info row: Coach (cyan) + Needs Work (orange).
                        secondaryTilesRow

                        weeklyStrip

                        badgesStrip

                        // Calibration collapses to a slim banner below badges
                        // once the character hero takes the top slot.
                        if shouldShowCalibrationCard {
                            DayOneCalibrationCard(style: .slim, onStart: {
                                UnboundHaptics.medium()
                                showingCalibrationWorkout = true
                            })
                        }

                        StaminaCardView()
                            .environmentObject(services)

                        if shouldShowScanCTA {
                            scanCTACard
                        }

                        Spacer().frame(height: 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
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
            Task { await refreshRanks() }
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
        .fullScreenCover(isPresented: $showingExpandedMap) {
            ExpandedBodyMapView(
                regionRanks: regionRanks,
                archetypeName: archetypeName,
                aggregateRank: aggregateRank,
                allLiftRanks: liftRanks
            )
            .environmentObject(services)
        }
        .sheet(item: $selectedRegion) { region in
            MuscleDetailSheet(
                region: region,
                regionRank: regionRanks[region] ?? RegionRank(
                    region: region,
                    rank: .eMinus,
                    topContributingLifts: [],
                    needsWork: true
                ),
                allLiftRanks: liftRanks
            )
            .environmentObject(services)
        }
        .navigationDestination(isPresented: $showingBadgeGallery) {
            BadgeGalleryView()
                .environmentObject(services)
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

    // MARK: Load

    @MainActor
    private func load() async {
        let userId = services.auth.currentUserId ?? "anonymous"
        services.badges.bind(userId: userId)

        await SkillProgressService.shared.load(userId: userId)
        await RankDecayService.shared.evaluateOnForeground(userId: userId)

        progressionStates = await ProgressionStateStore.shared.fetchAll(userId: userId)
        plateaus = await PlateauDetector.shared.detect(userId: userId, states: progressionStates)
        await refreshCalibrationState()
        await refreshRanks()

        phase = await services.programPhase.currentPhase(userId: userId)

        recentBadges = Array(
            services.badges.unlockedBadges(userId: userId)
                .sorted { ($0.unlockedAt ?? .distantPast) > ($1.unlockedAt ?? .distantPast) }
                .prefix(6)
        )
        weekSessionDays = await loadWeeklySessionDays(userId: userId)
        latestCoachMessage = await loadLatestCoachMessage(userId: userId)

        do {
            let fetched: UserProfile = try await services.user.fetchProfile(userId: userId)
            profile = fetched

            if let programId = fetched.currentProgramId,
               let existing: TrainingProgram = try? await services.database.read(collection: "programs", documentId: programId) {
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
        isLoading = false
    }

    @MainActor
    private func refreshRanks() async {
        let userId = services.auth.currentUserId ?? "anonymous"
        liftRanks = await services.rank.fetchAll(userId: userId)
        regionRanks = MuscleRankCalculator.computeAll(liftRanks: liftRanks)
        let archetype = profile?.preferredArchetype ?? .vTaper
        aggregateRank = await services.rank.archetypeRank(userId: userId, archetype: archetype)
    }

    private func loadWeeklySessionDays(userId: String) async -> Set<Int> {
        let logs = (try? await services.workoutLog.fetchRecentLogs(userId: userId, limit: 14)) ?? []
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        guard let weekStart = cal.date(from: components) else { return [] }

        var days: Set<Int> = []
        for log in logs {
            guard log.startedAt >= weekStart else { continue }
            let weekday = cal.component(.weekday, from: log.startedAt)
            // Convert to Mon=1..Sun=7
            let monIndex = ((weekday + 5) % 7) + 1
            days.insert(monIndex)
        }
        return days
    }

    private func loadLatestCoachMessage(userId: String) async -> String? {
        // Coach tab persists assistant messages in `coach_messages` keyed by
        // userId. Pull the newest assistant reply as a one-line preview.
        let messages: [CoachMessage] = (try? await services.database.query(
            collection: "coach_messages",
            field: "userId",
            isEqualTo: userId,
            orderBy: "timestamp",
            descending: true,
            limit: 10
        )) ?? []
        return messages.first(where: { $0.role == .assistant })?.content
    }

    // MARK: Session completion hook

    private func onSessionComplete() {
        let today = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
        let lastDay = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: lastSessionTimestamp)).timeIntervalSince1970
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
            let userId = services.auth.currentUserId ?? "anonymous"
            await refreshRanks()
            await refreshSessionXP()
            phase = await services.programPhase.currentPhase(userId: userId)
            weekSessionDays = await loadWeeklySessionDays(userId: userId)
            latestCoachMessage = await loadLatestCoachMessage(userId: userId)
        }
    }

    // MARK: Slim header

    private var slimHeader: some View {
        let record = sessionXP ?? SessionXPService.shared.record(userId: services.auth.currentUserId ?? "anonymous")
        let streakColor = streakAtRisk ? Color.unbound.alert : Color.unbound.impact
        let next = aggregateRank.advanced(by: 1)
        let ordinal = aggregateRank.ordinal
        let fraction = min(max(Double(ordinal % 3) / 3.0 + 0.15, 0.1), 0.95)

        return VStack(alignment: .leading, spacing: 10) {
            // Row 1: archetype · rank  |  streak · weekly · xp (mono dots)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(archetypeName.uppercased())
                    .font(Font.unbound.captionS)
                    .tracking(2.0)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text("·")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text(aggregateRank.displayName)
                    .font(Font.unbound.monoM)
                    .foregroundStyle(aggregateRank.regionTint)
                Spacer(minLength: 8)
                statsStrip(
                    streak: record.currentStreak,
                    streakColor: streakColor,
                    weekly: record.weeklyCount,
                    gains: gains
                )
            }

            // Row 2: full-width progress bar; NEXT label sits BELOW the bar so
            // it never clips at narrow widths and the bar reads cleanly on its
            // own line.
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.unbound.borderSubtle)
                        Capsule()
                            .fill(aggregateRank.regionTint)
                            .frame(width: max(6, proxy.size.width * fraction))
                            .shadow(color: aggregateRank.regionTint.opacity(0.55), radius: 4)
                    }
                }
                .frame(height: 5)

                HStack(spacing: 4) {
                    Text("NEXT")
                        .font(Font.unbound.captionS)
                        .tracking(1.2)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text("·")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text(next.displayName)
                        .font(Font.unbound.monoS)
                        .foregroundStyle(next.regionTint)
                    Spacer(minLength: 0)
                    if let tagline = profile?.preferredArchetype?.characterTagline {
                        Text(tagline)
                            .font(Font.unbound.monoS)
                            .tracking(1.0)
                            .foregroundStyle(Color.unbound.textTertiary)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
        .onReceive(NotificationCenter.default.publisher(for: .sessionXPUpdated)) { _ in
            Task { await refreshSessionXP() }
        }
    }

    private func statsStrip(streak: Int, streakColor: Color, weekly: Int, gains: Int) -> some View {
        HStack(spacing: 6) {
            headerStat(icon: "flame.fill", value: "\(streak)", tint: streakColor)
            dotSep
            headerStat(icon: "calendar", value: "\(weekly)", tint: Color.unbound.textPrimary)
            dotSep
            headerStat(icon: "bolt.fill", value: "\(gains)", tint: Color.unbound.accent)
        }
    }

    private var dotSep: some View {
        Text("·")
            .font(Font.unbound.monoS)
            .foregroundStyle(Color.unbound.textTertiary)
    }

    private func headerStat(icon: String, value: String, tint: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(Font.unbound.monoS)
                .foregroundStyle(tint)
                .monospacedDigit()
        }
    }

    @MainActor
    private func refreshSessionXP() async {
        let userId = services.auth.currentUserId ?? "anonymous"
        let record = services.sessionXP.record(userId: userId)
        sessionXP = record
        if let last = record.lastSessionDate {
            streakAtRisk = record.currentStreak > 0
                && Date().timeIntervalSince(last) > 24 * 3600
        } else {
            streakAtRisk = false
        }
    }

    // MARK: Character hero (full-width body map)

    /// Full-width body map with rank-tinted muscle heatmap. Tap anywhere on
    /// the figure to open the expanded view; the figure itself is a gauge,
    /// not a control — the outer card is the tap target.
    private var characterHero: some View {
        Button {
            UnboundHaptics.medium()
            showingExpandedMap = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("CHARACTER")
                        .font(Font.unbound.captionS)
                        .tracking(1.6)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text("·")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text(archetypeName.uppercased())
                        .font(Font.unbound.captionS.weight(.bold))
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textSecondary)
                    Spacer()
                    HStack(spacing: 4) {
                        Text("EXPAND")
                            .font(Font.unbound.captionS)
                            .tracking(1.2)
                            .foregroundStyle(Color.unbound.textTertiary)
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.unbound.textTertiary)
                    }
                }

                BodyMapView(regionRanks: regionRanks, onRegionTapped: { region in
                    UnboundHaptics.medium()
                    selectedRegion = region
                })
                .frame(maxWidth: .infinity)

                heatmapLegend
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.unbound.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    /// Tiny horizontal legend mapping the rank-tint ramp so users learn the
    /// red → green → violet → gold heatmap language at a glance.
    private var heatmapLegend: some View {
        HStack(spacing: 10) {
            legendSwatch(color: Color.unbound.rankRed, label: "E")
            legendSwatch(color: Color.unbound.rankOrange, label: "D")
            legendSwatch(color: Color.unbound.rankAmber, label: "C")
            legendSwatch(color: Color.unbound.rankGreen, label: "B")
            legendSwatch(color: Color.unbound.accent, label: "A")
            legendSwatch(color: Color.unbound.rankGold, label: "S")
            Spacer(minLength: 0)
        }
    }

    private func legendSwatch(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .shadow(color: color.opacity(0.6), radius: 3)
            Text(label)
                .font(Font.unbound.monoS)
                .foregroundStyle(Color.unbound.textTertiary)
        }
    }

    // MARK: Today hero CTA

    /// Full-width primary action. Dominant after the character map.
    /// Violet-accented since it's the brand primary action.
    private var todayHeroCTA: some View {
        let day = todayProgramDay
        return Button {
            guard let day, !day.isRestDay, day.workout != nil else { return }
            UnboundHaptics.medium()
            showingSession = true
        } label: {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.unbound.accent.opacity(0.18))
                        .frame(width: 48, height: 48)
                    Image(systemName: todayHeroIcon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.unbound.accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("TODAY")
                            .font(Font.unbound.captionS.weight(.bold))
                            .tracking(1.6)
                            .foregroundStyle(Color.unbound.accent)
                        Text("·")
                            .font(Font.unbound.captionS)
                            .foregroundStyle(Color.unbound.textTertiary)
                        Text(shortDayString())
                            .font(Font.unbound.captionS)
                            .tracking(1.2)
                            .foregroundStyle(Color.unbound.textTertiary)
                    }
                    Text(todayHeroTitle)
                        .font(Font.unbound.titleS)
                        .tracking(0.4)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                    Text(todayHeroSubtitle)
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Color.unbound.accent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.unbound.accent.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.unbound.accent.opacity(0.55), lineWidth: 1.5)
            )
            .shadow(color: Color.unbound.accent.opacity(0.22), radius: 10, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var todayHeroIcon: String {
        guard let day = todayProgramDay else { return "calendar" }
        if day.isRestDay { return "leaf.fill" }
        if day.workout != nil { return "bolt.fill" }
        return "calendar"
    }

    private var todayHeroTitle: String {
        guard let day = todayProgramDay else { return "NO SESSION" }
        if day.isRestDay { return "REST DAY" }
        return day.workout?.name.uppercased() ?? "NO SESSION"
    }

    private var todayHeroSubtitle: String {
        guard let day = todayProgramDay else { return "Plan your next move." }
        if day.isRestDay { return "Recovery is the work." }
        if let workout = day.workout {
            return "\(workout.estimatedMinutes) min  ·  \(workout.mainExercises.count) lifts"
        }
        return "Plan your next move."
    }

    // MARK: Secondary tiles row (Coach + Needs Work)

    private var secondaryTilesRow: some View {
        HStack(alignment: .top, spacing: 12) {
            coachTile
                .frame(maxWidth: .infinity)
            needsWorkTile
                .frame(maxWidth: .infinity)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Coach tile (cyan accent — communication category)

    private var coachTile: some View {
        Button {
            UnboundHaptics.medium()
            navigateToCoach = ""
        } label: {
            accentTileShell(accent: Color.unbound.coachCyan) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("COACH")
                            .font(Font.unbound.captionS.weight(.bold))
                            .tracking(1.4)
                            .foregroundStyle(Color.unbound.coachCyan)
                        Spacer()
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.unbound.coachCyan)
                    }
                    if let message = latestCoachMessage {
                        Text("\u{201C}\(message)\u{201D}")
                            .font(Font.unbound.bodyS)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("Ask me anything about your training.")
                            .font(Font.unbound.bodyS)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    accentTileCTA(
                        title: latestCoachMessage == nil ? "START CHAT" : "OPEN CHAT",
                        color: Color.unbound.coachCyan
                    )
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Needs Work tile (orange accent — attention category)

    private var needsWorkTile: some View {
        let weakest = MuscleRankCalculator.weakestMuscle(from: liftRanks)
        return Button {
            UnboundHaptics.medium()
            if let weakest {
                selectedRegion = weakest.0
            } else {
                showingExpandedMap = true
            }
        } label: {
            accentTileShell(accent: Color.unbound.warnOrange) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("NEEDS WORK")
                            .font(Font.unbound.captionS.weight(.bold))
                            .tracking(1.4)
                            .foregroundStyle(Color.unbound.warnOrange)
                        Spacer()
                        Image(systemName: "target")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.unbound.warnOrange)
                    }
                    if let weakest {
                        Text(weakest.0.displayName.uppercased())
                            .font(Font.unbound.titleS)
                            .tracking(0.4)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            Text("RANK")
                                .font(Font.unbound.captionS)
                                .tracking(1.0)
                                .foregroundStyle(Color.unbound.textTertiary)
                            Text(weakest.1.rank.displayName)
                                .font(Font.unbound.monoS.weight(.bold))
                                .foregroundStyle(weakest.1.rank.regionTint)
                        }
                        Text(weakest.0.needsWorkDirective)
                            .font(Font.unbound.captionS)
                            .foregroundStyle(Color.unbound.textSecondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("IN BALANCE")
                            .font(Font.unbound.titleS)
                            .tracking(0.4)
                            .foregroundStyle(Color.unbound.textPrimary)
                        Text("No weak points. Keep stacking reps.")
                            .font(Font.unbound.captionS)
                            .foregroundStyle(Color.unbound.textSecondary)
                            .lineLimit(2)
                    }
                    accentTileCTA(
                        title: weakest == nil ? "VIEW MAP" : "VIEW MUSCLE",
                        color: Color.unbound.warnOrange
                    )
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Tile chrome

    @ViewBuilder
    private func accentTileShell<Content: View>(
        accent: Color,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(accent.opacity(0.45), lineWidth: 1)
            )
            .shadow(color: accent.opacity(0.10), radius: 8, y: 1)
    }

    private func accentTileCTA(title: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(Font.unbound.captionS.weight(.bold))
                .tracking(1.2)
            Image(systemName: "arrow.right")
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(color)
        .padding(.top, 2)
    }

    // MARK: Plateau banner

    private var plateauBanner: some View {
        let first = plateaus[0]
        return Button {
            UnboundHaptics.medium()
            navigateToCoach = "Why is my \(first.displayName.lowercased()) stuck?"
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.unbound.alert)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(first.displayName) has stalled")
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text("\(first.stalledSessions) sessions without progress. Ask the coach.")
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.unbound.alert.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Weekly strip

    private var weeklyStrip: some View {
        let labels = ["M", "T", "W", "T", "F", "S", "S"]
        let todayIndex = ((Calendar.current.component(.weekday, from: Date()) + 5) % 7) + 1
        return VStack(spacing: 8) {
            // Labels row
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    Text(labels[i])
                        .font(Font.unbound.captionS)
                        .tracking(2.0)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            // Glyph row
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    let day = i + 1
                    let hasSession = weekSessionDays.contains(day)
                    let isToday = day == todayIndex
                    let isPast = day < todayIndex
                    dayGlyph(hasSession: hasSession, isToday: isToday, isPast: isPast)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 14)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func dayGlyph(hasSession: Bool, isToday: Bool, isPast: Bool) -> some View {
        if hasSession {
            // Logged: checkmark
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.unbound.accent)
        } else if isToday {
            // Today: filled violet dot
            Circle()
                .fill(Color.unbound.accent)
                .frame(width: 8, height: 8)
                .shadow(color: Color.unbound.accent.opacity(0.6), radius: 4)
        } else if isPast {
            // Past + skipped: dim dot
            Circle()
                .fill(Color.unbound.borderSubtle)
                .frame(width: 4, height: 4)
        } else {
            // Future: empty outline
            Circle()
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                .frame(width: 8, height: 8)
        }
    }

    // MARK: Badges strip

    private var badgesStrip: some View {
        let total = BadgeCatalog.all.count
        let unlocked = recentBadges.count
        let minSlots = 6
        let lockedPlaceholderCount = max(0, minSlots - unlocked)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 8) {
                    Text("BADGES")
                        .font(Font.unbound.captionS)
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text("·")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text("\(unlocked) / \(total)")
                        .font(Font.unbound.monoS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .monospacedDigit()
                }
                Spacer()
                Button {
                    UnboundHaptics.soft()
                    showingBadgeGallery = true
                } label: {
                    Text("ALL")
                        .font(Font.unbound.captionS)
                        .tracking(1.2)
                        .foregroundStyle(Color.unbound.accent)
                }
                .buttonStyle(.plain)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(recentBadges) { badge in
                        Button {
                            UnboundHaptics.soft()
                            showingBadgeGallery = true
                        } label: {
                            unlockedBadgeSlot(badge: badge)
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(0..<lockedPlaceholderCount, id: \.self) { _ in
                        Button {
                            UnboundHaptics.soft()
                            showingBadgeGallery = true
                        } label: {
                            lockedBadgeSlot
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
            .frame(height: 64)
        }
    }

    private func unlockedBadgeSlot(badge: Badge) -> some View {
        ZStack {
            ChamferedRectangle(inset: 8)
                .fill(badge.rarity.tint.opacity(0.12))
            ChamferedRectangle(inset: 8)
                .stroke(badge.rarity.tint.opacity(0.6), lineWidth: 1)
            Image(systemName: badge.iconSystemName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(badge.rarity.tint)
                .shadow(color: badge.rarity.tint.opacity(0.5), radius: 6)
        }
        .frame(width: 60, height: 60)
    }

    private var lockedBadgeSlot: some View {
        ZStack {
            ChamferedRectangle(inset: 8)
                .fill(Color.unbound.surface.opacity(0.5))
            ChamferedRectangle(inset: 8)
                .stroke(Color.unbound.borderSubtle, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            Image(systemName: "lock.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.unbound.textTertiary.opacity(0.5))
        }
        .frame(width: 60, height: 60)
        .opacity(0.55)
    }

    // MARK: Scan CTA

    private var shouldShowScanCTA: Bool {
        guard lastScanTimestamp > 0 else { return false }
        let days = Date().timeIntervalSince1970 - lastScanTimestamp
        return days >= 30 * 24 * 3600
    }

    private var scanCTACard: some View {
        UnboundCard {
            HStack(spacing: 14) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.unbound.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Time to rescan")
                        .font(Font.unbound.bodyLStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text("See what's changed in the last 30 days.")
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
        }
    }

    // MARK: Gains toast

    private var gainsToast: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.unbound.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("+\(lastGainsAwarded) Gains")
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

    // MARK: Calibration visibility

    private var shouldShowCalibrationCard: Bool {
        calibrationSkipRatio > 0.5 && !hasLoggedAnyWorkout
    }

    @MainActor
    private func refreshCalibrationState() async {
        let userId = services.auth.currentUserId ?? "anonymous"
        calibrationSkipRatio = services.calibration.skipRatio(userId: userId)
        let logs = (try? await services.workoutLog.fetchRecentLogs(userId: userId, limit: 1)) ?? []
        hasLoggedAnyWorkout = !logs.isEmpty
    }

    // MARK: Derived values

    private var archetypeName: String {
        profile?.preferredArchetype?.shortName ?? "UNBOUND"
    }

    private var todayProgramDay: ProgramDay? {
        guard let program else { return nil }
        guard !program.days.isEmpty else { return nil }
        let daysSinceStart = max(0, Calendar.current.dateComponents([.day], from: program.createdAt, to: Date()).day ?? 0)
        let dayIndex = daysSinceStart % program.days.count
        return program.days[dayIndex]
    }

    private func shortDayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: Date()).uppercased()
    }
}

