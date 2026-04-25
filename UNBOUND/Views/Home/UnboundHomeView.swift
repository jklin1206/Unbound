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
    @AppStorage("unbound.lastPhotoTimestamp") private var lastPhotoTimestamp: Double = 0
    @AppStorage("unbound.lastSessionDate") private var lastSessionTimestamp: Double = 0
    @State private var sessionXP: SessionXPRecord?

    // Ranking + stats
    @State private var aggregateRank: SubRank = .eMinus
    @State private var statScore: StatScore = .empty
    @State private var liftRanks: [LiftRank] = []
    @State private var regionRanks: [BodyRegion: RegionRank] = [:]
    @State private var heatmapRanks: [MuscleHeatGroup: SubRank] = [:]

    // Contextual triggers
    @State private var plateaus: [PlateauedExercise] = []
    @State private var calibrationSkipRatio: Double = 0
    @State private var hasLoggedAnyWorkout: Bool = false
    @State private var lastLog: WorkoutLog?
    @State private var weekSessionDays: Set<Int> = [] // Mon=1...Sun=7

    // Modal state
    @State private var selectedRegion: BodyRegion?
    @State private var showingSession = false
    @State private var showingCalibrationWorkout = false
    @State private var showingExpandedMap = false
    @State private var navigateToCoach: String?
    @State private var showingGainsToast = false
    @State private var lastGainsAwarded: Int = 0

    // Ambient animation state
    @State private var rankGlowRadius: CGFloat = 6
    @State private var streakFlameRadius: CGFloat = 3
    @State private var xpShimmerPhase: CGFloat = -1
    @State private var statsRendered = false

    // Daily Quest placeholder. Real library + rotation service lands in the
    // QuestService follow-up pass; today's quest is hardcoded so the card
    // layout can be reviewed before content is authored.
    @State private var dailyQuest = DailyQuestPlaceholder.sample

    // Photo/Scan capture flow presentation
    @State private var captureMode: PhotoCaptureFlow.Mode?

    // Coach note (daily AI insight, bounded to 1 call/user/day)
    @State private var coachNote: CoachNote?

    // Travel override (user hit the TRAVEL coach action)
    @State private var activeTravelOverride: TravelOverride?

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
                    VStack(alignment: .leading, spacing: 20) {
                        topBar
                        playerCard
                        if let note = coachNote {
                            coachNoteCard(note: note)
                        }
                        // Priority swap — on rest days / empty program, the
                        // Daily Quest takes the hero CTA slot above the
                        // session card.
                        if isQuestPrimary {
                            dailyQuestCard(isHero: true)
                            todayMissionCTA
                        } else {
                            todayMissionCTA
                            dailyQuestCard(isHero: false)
                        }
                        weeklyRhythm
                        contextualStack
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
                await refreshWeeklyRhythm()
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
        .fullScreenCover(isPresented: $showingExpandedMap) {
            ExpandedBodyMapView(
                regionRanks: regionRanks,
                groupRanks: heatmapRanks,
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
        let level = (gains / xpPerLevel) + 1
        return HStack(alignment: .center, spacing: 10) {
            avatarBadge(level: level)

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

    /// Placeholder avatar: initials in a chamfered charcoal circle with a
    /// small violet LV chip overlapping the bottom-right. Swap to the real
    /// user photo once the scan pipeline feeds it in.
    private func avatarBadge(level: Int) -> some View {
        let letter = avatarInitial
        return HStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    Circle()
                        .fill(Color.unbound.surface)
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.unbound.accent.opacity(0.65),
                                    Color.unbound.accent.opacity(0.20)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                    Text(letter)
                        .font(Font.unbound.titleS)
                        .tracking(0.5)
                        .foregroundStyle(Color.unbound.textPrimary)
                }
                .frame(width: 40, height: 40)

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
        if let archetype = profile?.preferredArchetype {
            return String(archetype.shortName.prefix(1)).uppercased()
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

    // MARK: - Player card
    //
    // Character-sheet hero: compact heatmap on the left, rank + level + 4
    // stats on the right. One block that tells the whole "who I am right
    // now" story at a glance. Tapping the body opens the expanded view or
    // a muscle-detail sheet. The card's ambient wash takes the rank-tier
    // color so E reads dormant-red, A reads brand-violet, S reads gold.

    private var playerCard: some View {
        let level = (gains / xpPerLevel) + 1
        let xpInLevel = gains % xpPerLevel
        let fraction = Double(xpInLevel) / Double(xpPerLevel)
        let tierLabel = tierName(for: aggregateRank)
        let rankColor = aggregateRank.regionTint
        let nextRank = aggregateRank.advanced(by: 1)

        return HStack(alignment: .top, spacing: 14) {
            // LEFT — compact body. Tap → expanded map.
            Button {
                UnboundHaptics.medium()
                showingExpandedMap = true
            } label: {
                MuscleHeatmapView(groupRanks: heatmapRanks, onGroupTapped: { group in
                    UnboundHaptics.medium()
                    if let representative = BodyRegion.allCases.first(where: { $0.heatGroup == group }) {
                        selectedRegion = representative
                    }
                })
                .frame(width: 128)
            }
            .buttonStyle(.plain)

            // RIGHT — rank, level, stats stack.
            VStack(alignment: .leading, spacing: 8) {
                // Rank letter + tier + next
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(aggregateRank.letter)
                        .font(Font.unbound.displayL)
                        .foregroundStyle(rankColor)
                        .shadow(color: rankColor.opacity(0.55), radius: rankGlowRadius)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tierLabel.uppercased())
                            .font(Font.unbound.monoS)
                            .tracking(1.6)
                            .foregroundStyle(rankColor.opacity(0.9))
                        Text("NEXT · \(nextRank.displayName)")
                            .font(.system(size: 9, weight: .medium))
                            .tracking(1.0)
                            .foregroundStyle(Color.unbound.textTertiary)
                    }
                    Spacer(minLength: 0)
                }

                // Level + XP bar
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("LV")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(Color.unbound.textTertiary)
                        Text("\(level)")
                            .font(Font.unbound.monoM)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .monospacedDigit()
                        Spacer(minLength: 0)
                        Text("\(xpInLevel) / \(xpPerLevel)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.unbound.textTertiary)
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
                                .overlay(
                                    // Traveling shimmer highlight — a thin
                                    // gradient streaks across the filled XP
                                    // portion, clipped to the Capsule so it
                                    // never leaks outside the bar.
                                    Rectangle()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    .clear,
                                                    .white.opacity(0.55),
                                                    .clear
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: 24)
                                        .offset(x: xpShimmerPhase * max(4, proxy.size.width * fraction))
                                        .blendMode(.plusLighter)
                                        .allowsHitTesting(false)
                                )
                                .clipShape(Capsule())
                        }
                    }
                    .frame(height: 3)
                }

                // Thin divider separating identity from stats
                Rectangle()
                    .fill(Color.unbound.borderSubtle)
                    .frame(height: 0.5)

                // Meta stats — 4 rank letters for the overall axes.
                VStack(spacing: 3) {
                    statRow(label: "STR", rank: statScore.strengthRank)
                    statRow(label: "STA", rank: statScore.staminaRank)
                    statRow(label: "TEC", rank: statScore.techniqueRank)
                    statRow(label: "VIT", rank: statScore.vitalityRank)
                }

                // Body ranks — aggregated per anatomical group from the
                // heatmap data. Shows where the user is strong/weak by
                // body part, complementing the 4 meta-stats above. 2x3
                // grid keeps it tight inside the card.
                Rectangle()
                    .fill(Color.unbound.borderSubtle)
                    .frame(height: 0.5)

                let bodyColumns = [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ]
                LazyVGrid(columns: bodyColumns, spacing: 4) {
                    bodyStatCell(label: "CHEST", rank: aggregate(of: [.chest]))
                    bodyStatCell(label: "BACK",  rank: aggregate(of: [.back]))
                    bodyStatCell(label: "SHLDR", rank: aggregate(of: [.shoulders, .traps]))
                    bodyStatCell(label: "ARMS",  rank: aggregate(of: [.biceps, .triceps, .forearms]))
                    bodyStatCell(label: "CORE",  rank: aggregate(of: [.core]))
                    bodyStatCell(label: "LEGS",  rank: aggregate(of: [.legs, .hamstrings, .glutes, .calves]))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.unbound.surface)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [rankColor.opacity(0.10), .clear],
                            center: .topTrailing,
                            startRadius: 0,
                            endRadius: 280
                        )
                    )
            }
        )
    }

    /// Aggregate SubRank for a set of MuscleHeatGroups — mean of their
    /// ordinals, rounded to the nearest sub-rank. Missing groups are
    /// treated as .eMinus so the cell always renders a readable letter.
    private func aggregate(of groups: [MuscleHeatGroup]) -> SubRank {
        guard !groups.isEmpty else { return .eMinus }
        let ordinals = groups.map { Double(heatmapRanks[$0]?.ordinal ?? 0) }
        let mean = ordinals.reduce(0, +) / Double(ordinals.count)
        return SubRank.nearest(for: mean)
    }

    /// Compact body-region cell: label + rank letter packed left,
    /// trailing Spacer so the pair hugs the cell's leading edge.
    private func bodyStatCell(label: String, rank: SubRank) -> some View {
        let color = rank.regionTint
        return HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(1.3)
                .foregroundStyle(Color.unbound.textTertiary)
                .frame(width: 38, alignment: .leading)
            Text(rank.displayName)
                .font(Font.unbound.monoS.weight(.semibold))
                .foregroundStyle(color)
                .shadow(color: color.opacity(0.4), radius: 2)
                .monospacedDigit()
            Spacer(minLength: 0)
        }
    }

    /// One stat row inside the player card: 3-letter label + sub-rank
    /// letter, left-aligned and compact. Tier color on the rank letter.
    private func statRow(label: String, rank: SubRank) -> some View {
        let color = rank.regionTint
        return HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textTertiary)
                .frame(width: 28, alignment: .leading)

            Text(rank.displayName)
                .font(Font.unbound.monoS.weight(.bold))
                .foregroundStyle(color)
                .shadow(color: color.opacity(0.5), radius: 3)
                .monospacedDigit()

            Spacer(minLength: 0)
        }
        .frame(height: 15)
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
        await refreshWeeklyRhythm()
        await refreshTravelOverride()
        await refreshCoachNote()

        isLoading = false
        // Kick off ambient loops once the content is actually on screen —
        // .onAppear fires while still in the loading state, so the
        // animation bindings never connect to rendered views.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            startAmbientAnimations()
        }
    }

    @MainActor
    private func refreshRanksAndStats() async {
        let userId = services.auth.currentUserId ?? "anonymous"
        let archetype = profile?.preferredArchetype ?? .vTaper
        aggregateRank = await services.rank.archetypeRank(userId: userId, archetype: archetype)
        statScore = await services.statScore.compute(userId: userId, archetype: archetype)

        liftRanks = await services.rank.fetchAll(userId: userId)
        regionRanks = MuscleRankCalculator.computeAll(liftRanks: liftRanks)
        var computed = MuscleRankCalculator.heatmapRanks(liftRanks: liftRanks)
        // Backfill missing groups with .eMinus so every muscle always
        // tints — the vector body should never have dark gaps.
        for group in MuscleHeatGroup.allCases where computed[group] == nil {
            computed[group] = .eMinus
        }
        heatmapRanks = computed
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
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        guard let weekStart = cal.date(from: components) else {
            weekSessionDays = []
            return
        }
        var days: Set<Int> = []
        for log in logs where log.startedAt >= weekStart {
            let weekday = cal.component(.weekday, from: log.startedAt)
            let monIndex = ((weekday + 5) % 7) + 1
            days.insert(monIndex)
        }
        weekSessionDays = days
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
        profile?.preferredArchetype?.shortName ?? "UNBOUND"
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
                // Accept wiring lands with QuestService.
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
            title: "20-min Zone 2 walk",
            subtitle: "Keep heart rate in zone 2. Earn while you recover.",
            category: .cardio,
            spReward: 25
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
