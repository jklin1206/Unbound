import SwiftUI

// MARK: - ProgramOverviewView
//
// Three-tab surface for the user's training plan.
//
//   PROGRAM  — current-week strip + selected-day card (workout preview,
//              exercise list, BEGIN button for today).
//   ROUTINES — curated library of off-day / variety routines
//              (cardio, mobility, challenges, alt circuits). Placeholder
//              content until a real RoutineLibrary service ships.
//   HISTORY  — past sessions grouped by week, newest first.
//
// Taps on day tiles open DayDetailView as a preview (always preview-first,
// per user direction).

struct ProgramOverviewView: View {
    @EnvironmentObject var services: ServiceContainer

    /// Observe the singleton so TODAY'S TRAINING refreshes when the user
    /// flips a goal from the skill detail screen. `@Bindable` here would
    /// require a @State container — using direct singleton access via
    /// `@Bindable var` on a property is the same pattern the skill detail
    /// view uses for SkillProgressService.
    @Bindable private var skillProgress = SkillProgressService.shared

    @State private var viewModel: ProgramViewModel?
    @State private var selectedTab: Tab = .program
    @State private var selectedDay: ProgramDay?
    @State private var showPaywall = false
    @State private var showRationale = false

    // Active-goal session launcher state.
    @State private var activeSession: ActiveSessionLaunch?
    @State private var pushedSkillNode: SkillNode?

    // V3 — day-strip preview + schedule editor sheets.
    @State private var previewDay: PreviewDay?
    @State private var showScheduleEditor: Bool = false

    // Program view state
    @State private var weekOffset: Int = 0 // +1 = next week, -1 = prev
    @State private var selectedDayDate: Date = Calendar.current.startOfDay(for: Date())

    // History view state
    @State private var pastLogs: [WorkoutLog] = []

    // Travel override (user hit the TRAVEL coach action)
    @State private var activeTravelOverride: TravelOverride?

    // Routines view state
    @State private var selectedRoutine: RoutineDef?
    @State private var activeRoutinePlayer: RoutineDef?
    @State private var completedRoutineReward: RoutineRewardPayload?
    @State private var selectedChallengeId: String = "100-pushup"
    @State private var selectedRoutineIdsByCategory: [RoutineCategory: String] = [:]
    @State private var travelingRoutine: RoutineDef?
    @State private var routineTravelProgress: CGFloat = 0

    // Block rollover (Chunk 3): block-complete CTA + optional rescan + share.
    @State private var isGeneratingNextBlock: Bool = false
    @State private var showRescanFlow: Bool = false
    @State private var rolloverDeltaReport: ScanDeltaReport?
    @State private var showProgressReveal: Bool = false
    @State private var nextBlockNumberPreview: Int = 2
    @State private var currentBlockNumberPreview: Int = 1

    // Resume draft affordance.
    @State private var resumeDraft: ActiveWorkoutSession?
    @State private var showResume = false
    private let draftStore = WorkoutDraftStore()

    enum Tab: Hashable { case program, routines, history }

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                tabSelector
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 10)

                Group {
                    switch selectedTab {
                    case .program:  programTab
                    case .routines: routinesTab
                    case .history:  historyTab
                    }
                }
            }

            if let travelingRoutine {
                RoutineTravelOverlay(routine: travelingRoutine, progress: routineTravelProgress)
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
                    .zIndex(3)
            }
        }
        .navigationBarHidden(true)
        .task {
            let vm = ProgramViewModel(services: services)
            self.viewModel = vm
            guard let userId = services.auth.currentUserId else { return }

            // History + travel don't depend on the profile — run them
            // concurrently with the profile→program chain instead of after it.
            async let historyDone: Void = refreshHistory()
            async let travelDone: Void = refreshTravelOverride()

            do {
                let profile: UserProfile = try await services.user.fetchProfile(userId: userId)
                if let programId = profile.currentProgramId {
                    await vm.loadProgram(programId: programId)
                } else {
                    // Onboarding done but currentProgramId not saved yet.
                    vm.state = .loading
                    let generated = await ProgramGenerationService.shared.generateFromOnboarding(
                        userId: userId,
                        targetFrequency: profile.targetFrequency,
                        equipment: Set(profile.equipment ?? []),
                        experience: profile.experience,
                        sessionLength: profile.sessionLength,
                        exerciseStyles: [],
                        targetAreas: Set(profile.targetAreas ?? [])
                    )
                    vm.program = generated
                    vm.state = .loaded(generated)
                }
            } catch {}

            _ = await historyDone
            _ = await travelDone

            // Prefetch today's session for every active goal so tapping
            // TRAIN is instant. Each in its own detached task; failures fall
            // back gracefully when the session view actually opens.
            for goalId in skillProgress.activeGoalIds {
                Task.detached { @MainActor in
                    await RPESessionService.shared.prefetch(
                        skillId: goalId,
                        userId: userId
                    )
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallPlaceholderView()
                .environmentObject(services)
        }
        .sheet(isPresented: $showRationale) {
            if let rationale = viewModel?.program?.rationale {
                WhyThisProgramView(rationale: rationale, onDismiss: { showRationale = false })
                    .presentationDragIndicator(.visible)
            }
        }
        .navigationDestination(item: $selectedDay) { day in
            DayDetailView(
                day: day,
                nutritionPlan: viewModel?.dailyNutrition,
                recoveryPlan: viewModel?.recoveryPlan,
                workoutLog: viewModel?.logFor(dayNumber: day.dayNumber),
                programViewModel: viewModel,
                programId: viewModel?.program?.id ?? ""
            )
        }
        .fullScreenCover(item: $activeRoutinePlayer) { routine in
            SideQuestPlayerView(routine: routine.sideQuest) { log in
                completeRoutine(routine, log: log)
            }
            .environmentObject(services)
        }
        .sheet(item: $completedRoutineReward) { reward in
            RoutineCompletionRewardView(reward: reward) {
                completedRoutineReward = nil
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $activeSession) { session in
            SkillSessionView(skillId: session.skillId, skillTitle: session.skillTitle)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(item: $pushedSkillNode) { node in
            NavigationStack {
                SkillDetailView(
                    node: node,
                    graph: SkillGraph.shared,
                    nodeStates: skillProgress.nodeStates
                )
            }
        }
        .sheet(item: $previewDay) { wrapper in
            DayPreviewSheet(
                date: wrapper.date,
                onSelectSkill: { node in
                    previewDay = nil
                    pushedSkillNode = node
                },
                onTrainSkill: { node in
                    previewDay = nil
                    activeSession = ActiveSessionLaunch(
                        skillId: node.id,
                        skillTitle: node.title
                    )
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showScheduleEditor) {
            WeeklyScheduleEditorSheet()
                .environmentObject(services)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showRescanFlow) {
            PhotoCaptureFlow(mode: .scan) { _ in
                showRescanFlow = false
                // After a rescan, refresh the delta-report cache so the
                // block-complete teaser reflects the new comparison.
                if let program = viewModel?.program {
                    Task { await loadBlockRolloverContext(program: program) }
                }
            }
            .environmentObject(services)
        }
    }

    // MARK: - V3 day-preview wrapper
    //
    // Sheet(item:) needs Identifiable but Date isn't, so wrap it.
    fileprivate struct PreviewDay: Identifiable, Hashable {
        let date: Date
        var id: Date { date }
    }

    // MARK: - TODAY'S TRAINING (active goals)
    //
    // V1: surfaces every active goal every day. Each row launches the
    // existing AI-generated `SkillSessionView` directly — tapping the
    // card body navigates into `SkillDetailView` instead. State copy is
    // computed live from `SkillProgressService.canTrain` so the row
    // flips from "Ready" → "Trained today" without a refresh.

    private struct ActiveSessionLaunch: Identifiable, Hashable {
        let skillId: String
        let skillTitle: String
        var id: String { skillId }
    }

    private var todaysTrainingSection: some View {
        let scheduler = ProgramScheduler.shared
        let skillIds = scheduler.todaysSkillSessions()
        let routedCount = skillIds.count
        let totalGoals = skillProgress.activeGoalIds.count
        let todayCat = scheduler.category(for: Date())
        let week = scheduler.weeklyOverview()

        return VStack(alignment: .leading, spacing: 12) {
            // Header — 2-line: "MONDAY · PULL DAY" + count summary, plus
            // an EDIT SCHEDULE pill on the right (V3).
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(headerLine1(for: Date(), category: todayCat))
                        .font(Font.unbound.captionS.weight(.bold))
                        .tracking(1.6)
                        .foregroundStyle(Color.unbound.accent)
                    Text(headerLine2(routedCount: routedCount, totalGoals: totalGoals, category: todayCat))
                        .font(Font.unbound.captionS)
                        .tracking(0.6)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
                Spacer(minLength: 6)
                editScheduleButton
            }

            // Body — either routed goal cards, or a quiet empty state.
            if skillIds.isEmpty {
                routedEmptyState(category: todayCat, week: week)
            } else {
                VStack(spacing: 8) {
                    ForEach(skillIds, id: \.self) { id in
                        if let node = SkillGraph.shared.node(id: id) {
                            activeGoalCard(node: node)
                        }
                    }
                }
            }

            // 7-day horizontal strip.
            weeklyDayStrip(week: week)
                .padding(.top, 4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.unbound.accent.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - TODAY'S TRAINING helpers

    private func headerLine1(for date: Date, category: DayCategory) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        let weekday = f.string(from: date).uppercased()
        if category == .rest {
            return "\(weekday) · REST DAY"
        }
        return "\(weekday) · \(category.displayName.uppercased()) DAY"
    }

    private func headerLine2(routedCount: Int, totalGoals: Int, category: DayCategory) -> String {
        if totalGoals == 0 {
            return "No active goals yet"
        }
        if category == .rest {
            return "Recovery is the work"
        }
        let goalWord = totalGoals == 1 ? "goal" : "goals"
        return "\(routedCount) of \(totalGoals) \(goalWord) routed today"
    }

    @ViewBuilder
    private func routedEmptyState(
        category: DayCategory,
        week: [(date: Date, category: DayCategory, count: Int)]
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: category == .rest ? "moon.fill" : "calendar.badge.clock")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.unbound.textTertiary)
            VStack(alignment: .leading, spacing: 2) {
                Text(category == .rest ? "Rest day" : "No goals routed to \(category.displayName) day")
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(0.4)
                    .foregroundStyle(Color.unbound.textSecondary)
                Text(emptyStateSubcopy(category: category, week: week))
                    .font(Font.unbound.captionS)
                    .tracking(0.4)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surfaceElevated.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private func emptyStateSubcopy(
        category: DayCategory,
        week: [(date: Date, category: DayCategory, count: Int)]
    ) -> String {
        if category == .rest {
            return "Recover hard so tomorrow lands."
        }
        // Find next routed day with at least one goal.
        let next = week.dropFirst().first(where: { $0.count > 0 })
        guard let next else {
            return "Add goals from any skill detail screen."
        }
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        let weekday = f.string(from: next.date)
        return "Your \(next.category.displayName) goals resume \(weekday)."
    }

    // MARK: - 7-day strip

    private func weeklyDayStrip(
        week: [(date: Date, category: DayCategory, count: Int)]
    ) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(week.enumerated()), id: \.offset) { _, slot in
                dayStripChip(date: slot.date, category: slot.category, count: slot.count)
            }
        }
    }

    private func dayStripChip(date: Date, category: DayCategory, count: Int) -> some View {
        let cal = Calendar.current
        let isToday = cal.isDateInToday(date)
        let letter = singleLetterWeekday(for: date)
        let isRest = category == .rest

        return Button {
            UnboundHaptics.soft()
            previewDay = PreviewDay(date: cal.startOfDay(for: date))
        } label: {
            VStack(spacing: 4) {
                Text(letter)
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(0.6)
                    .foregroundStyle(isToday ? Color.unbound.accent : Color.unbound.textTertiary)

                Image(systemName: category.glyph)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(
                        isRest
                            ? Color.unbound.textTertiary
                            : (isToday ? Color.unbound.accent : Color.unbound.textSecondary)
                    )

                // Count badge — show non-zero count, blank for 0/rest.
                Group {
                    if count > 0 {
                        Text("\(count)")
                            .font(Font.unbound.captionS.weight(.bold))
                            .foregroundStyle(isToday ? Color.unbound.textPrimary : Color.unbound.textSecondary)
                            .monospacedDigit()
                    } else {
                        Text(" ")
                            .font(Font.unbound.captionS.weight(.bold))
                    }
                }
                .frame(height: 12)
            }
            .frame(width: 40, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        isToday
                            ? Color.unbound.accent.opacity(0.16)
                            : Color.unbound.surfaceElevated.opacity(0.5)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        isToday
                            ? Color.unbound.accent.opacity(0.6)
                            : Color.unbound.borderSubtle,
                        lineWidth: 1
                    )
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - V3 EDIT SCHEDULE pill

    private var editScheduleButton: some View {
        Button {
            UnboundHaptics.soft()
            showScheduleEditor = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 9, weight: .bold))
                Text("EDIT")
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.4)
            }
            .foregroundStyle(Color.unbound.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.unbound.surfaceElevated.opacity(0.6))
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func singleLetterWeekday(for date: Date) -> String {
        let cal = Calendar.current
        // 1=Sun, 2=Mon, ..., 7=Sat
        let wd = cal.component(.weekday, from: date)
        switch wd {
        case 1: return "S"
        case 2: return "M"
        case 3: return "T"
        case 4: return "W"
        case 5: return "T"
        case 6: return "F"
        case 7: return "S"
        default: return "?"
        }
    }

    private func activeGoalCard(node: SkillNode) -> some View {
        let canTrain = skillProgress.canTrain(nodeId: node.id)
        let sp = skillProgress.currentSkillProgress(for: node.id)
        let stateLabel = canTrain ? "Ready" : "Trained today"
        let buttonLabel = canTrain ? "TRAIN" : "VIEW"
        let asset = node.id.replacingOccurrences(of: ".", with: "_")

        return Button {
            UnboundHaptics.soft()
            pushedSkillNode = node
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.unbound.surfaceElevated)
                        .frame(width: 56, height: 56)
                    if UIImage(named: asset) != nil {
                        Image(asset)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 48, height: 48)
                    } else {
                        Image(systemName: node.glyph)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Color.unbound.accent)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(node.title)
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                    Text("\(node.cluster.displayName) · Lv \(sp.currentLevel) · \(stateLabel)")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(canTrain ? Color.unbound.textSecondary : Color.unbound.textTertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                Button {
                    UnboundHaptics.medium()
                    activeSession = ActiveSessionLaunch(
                        skillId: node.id,
                        skillTitle: node.title
                    )
                } label: {
                    HStack(spacing: 4) {
                        Text(buttonLabel)
                            .font(Font.unbound.captionS.weight(.bold))
                            .tracking(1.2)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(canTrain ? Color.unbound.textPrimary : Color.unbound.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(canTrain ? Color.unbound.accent : Color.unbound.surfaceElevated)
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                canTrain ? Color.clear : Color.unbound.borderSubtle,
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.unbound.surfaceElevated.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Text("PROGRAM")
                .font(Font.unbound.titleS)
                .tracking(2.0)
                .foregroundStyle(Color.unbound.textPrimary)
            Spacer()
            Button {
                UnboundHaptics.soft()
                if viewModel?.program?.rationale != nil { showRationale = true }
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    // MARK: - Tab selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            tabChip(.program, label: "PROGRAM")
            tabChip(.routines, label: "ROUTINES")
            tabChip(.history, label: "HISTORY")
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color.unbound.surface)
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private func tabChip(_ tab: Tab, label: String) -> some View {
        let isActive = selectedTab == tab
        return Button {
            UnboundHaptics.soft()
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            Text(label)
                .font(Font.unbound.captionS.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(isActive ? Color.unbound.textPrimary : Color.unbound.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isActive ? Color.unbound.accent.opacity(0.25) : .clear)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - PROGRAM tab

    @ViewBuilder
    private var programTab: some View {
        if let vm = viewModel {
            switch vm.state {
            case .idle:
                noProgramState
            case .loading:
                ProgressView().tint(Color.unbound.accent).frame(maxHeight: .infinity)
            case .error(let error):
                errorState(error)
            case .loaded(let program):
                if BlockRolloverScheduler.shouldRollover(program: program) {
                    blockCompleteState(program: program)
                } else {
                    programBody(program)
                }
            }
        } else {
            ProgressView().tint(Color.unbound.accent).frame(maxHeight: .infinity)
        }
    }

    // MARK: - Block-complete state (Chunk 3)
    //
    // Surfaces when the current 28-day block has elapsed. Shows a single
    // premium card with one primary CTA ("BUILD BLOCK N+1") and a secondary
    // RESCAN affordance. Pulls the latest ScanDeltaReport (if any) so we can
    // surface a small "what changed" teaser before the user commits.

    @ViewBuilder
    private func blockCompleteState(program: TrainingProgram) -> some View {
        let nextBlock = nextBlockNumberPreview
        let currentBlock = currentBlockNumberPreview
        let arc = arcLabel(for: nextBlock)

        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                blockCompleteHeader(currentBlock: currentBlock)

                blockCompleteSummary(
                    program: program,
                    currentBlock: currentBlock,
                    nextBlock: nextBlock,
                    arc: arc
                )

                if let delta = rolloverDeltaReport {
                    blockCompleteProgressTeaser(delta: delta, nextBlock: nextBlock)
                }

                blockCompleteActions(
                    program: program,
                    nextBlock: nextBlock
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .task { await loadBlockRolloverContext(program: program) }
        .sheet(isPresented: $showProgressReveal) {
            if let delta = rolloverDeltaReport {
                BlockProgressRevealView(
                    deltaReport: delta,
                    blockNumber: currentBlock,
                    nextBlockNumber: nextBlock,
                    onBuildNextBlock: {
                        showProgressReveal = false
                        Task { await runGenerateNextBlock(currentProgram: program) }
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private func blockCompleteHeader(currentBlock: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("BLOCK COMPLETE")
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .tracking(2.4)
                .foregroundStyle(Color.unbound.accent)
            Text("28 days. Block \(currentBlock) done.")
                .font(Font.unbound.titleL)
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func blockCompleteSummary(
        program: TrainingProgram,
        currentBlock: Int,
        nextBlock: Int,
        arc: String
    ) -> some View {
        let trainedDays = trainedDayCount(in: program)
        let totalDays = program.durationDays
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(trainedDays)")
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .monospacedDigit()
                Text("/ \(totalDays) sessions logged")
                    .font(Font.unbound.captionS)
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            Text(blockArcSummary(arc: arc, currentBlock: currentBlock, nextBlock: nextBlock))
                .font(Font.unbound.bodyL)
                .foregroundStyle(Color.unbound.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
        }
        .padding(20)
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

    private func blockCompleteProgressTeaser(delta: ScanDeltaReport, nextBlock: Int) -> some View {
        Button {
            UnboundHaptics.soft()
            showProgressReveal = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis.ascending")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.unbound.accent)
                    Text("PROGRESS SNAPSHOT")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(1.8)
                        .foregroundStyle(Color.unbound.accent)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.unbound.textTertiary)
                }
                Text(blockProgressTeaser(delta: delta, nextBlock: nextBlock))
                    .font(Font.unbound.bodyL)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.unbound.accent.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func blockCompleteActions(program: TrainingProgram, nextBlock: Int) -> some View {
        VStack(spacing: 12) {
            Button {
                UnboundHaptics.soft()
                Task { await runGenerateNextBlock(currentProgram: program) }
            } label: {
                HStack(spacing: 8) {
                    if isGeneratingNextBlock {
                        ProgressView()
                            .controlSize(.small)
                            .tint(Color.unbound.textPrimary)
                    } else {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 13, weight: .bold))
                    }
                    Text(isGeneratingNextBlock ? "BUILDING…" : "BUILD BLOCK \(nextBlock)")
                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        .tracking(1.6)
                }
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.unbound.accent)
                )
            }
            .buttonStyle(.plain)
            .disabled(isGeneratingNextBlock)

            Button {
                UnboundHaptics.soft()
                showRescanFlow = true
            } label: {
                Text("RESCAN FIRST")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.unbound.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(isGeneratingNextBlock)
        }
    }

    // MARK: - Block-complete data + actions

    /// Pull block number + latest delta report so the CTA + teaser are
    /// populated when the block-complete card first appears.
    private func loadBlockRolloverContext(program: TrainingProgram) async {
        guard let userId = services.auth.currentUserId else { return }

        let latest = await ProgramBlockStore.shared.latestBlock(userId: userId)
        let resolvedCurrent = max(latest?.blockNumber ?? 1, 1)
        let resolvedNext = resolvedCurrent + 1

        let delta: ScanDeltaReport? = await {
            do {
                let results: [ScanDeltaReport] = try await services.database.query(
                    collection: "scanDeltaReports",
                    field: "userId",
                    isEqualTo: userId,
                    orderBy: "createdAt",
                    descending: true,
                    limit: 1
                )
                return results.first
            } catch {
                return nil
            }
        }()

        await MainActor.run {
            self.currentBlockNumberPreview = resolvedCurrent
            self.nextBlockNumberPreview = resolvedNext
            self.rolloverDeltaReport = delta
        }
    }

    /// Drives the BUILD BLOCK N CTA: spinner → generate → swap state to the
    /// new program. Failures restore the loaded state silently so the user
    /// can retry; production telemetry catches the failure path.
    private func runGenerateNextBlock(currentProgram: TrainingProgram) async {
        guard let vm = viewModel,
              let userId = services.auth.currentUserId,
              !isGeneratingNextBlock else { return }

        isGeneratingNextBlock = true
        let restoreState: LoadingState<TrainingProgram> = vm.state
        vm.state = .loading

        do {
            let profile: UserProfile = try await services.user.fetchProfile(userId: userId)
            let newProgram = try await BlockRolloverService.performRollover(
                userId: userId,
                profile: profile,
                analysis: nil,
                scan: nil
            )
            vm.program = newProgram
            vm.state = .loaded(newProgram)
            await vm.loadTrackingData()
        } catch {
            services.logging.log(
                "BlockRolloverService.performRollover failed: \(error)",
                level: .error,
                context: ["currentProgramId": currentProgram.id]
            )
            vm.state = restoreState
        }

        isGeneratingNextBlock = false
    }

    // MARK: - Block-complete copy helpers

    private func arcLabel(for blockNumber: Int) -> String {
        // Mirrors LocalProgramGenerator's ((globalWeek-1)/4) % 3 + 1 cycle.
        let arc = ((max(blockNumber, 1) - 1) % 3) + 1
        switch arc {
        case 1: return "accumulation"
        case 2: return "intensification"
        case 3: return "realization"
        default: return "accumulation"
        }
    }

    private func trainedDayCount(in program: TrainingProgram) -> Int {
        guard let vm = viewModel else { return 0 }
        return program.days.reduce(0) { count, day in
            day.isRestDay ? count : (vm.isCompleted(dayNumber: day.dayNumber) ? count + 1 : count)
        }
    }

    private func blockArcSummary(arc: String, currentBlock: Int, nextBlock: Int) -> String {
        let currentArc = arcLabel(for: currentBlock)
        switch currentArc {
        case "accumulation":
            return "Block \(currentBlock) was about laying volume — base reps, base shape. Block \(nextBlock) shifts into \(arc): heavier loads, lower reps, harder finishes."
        case "intensification":
            return "Block \(currentBlock) pushed intensity. Block \(nextBlock) moves into \(arc): peak weights, sharpest output, the highest output of the cycle."
        case "realization":
            return "Block \(currentBlock) was peak. Block \(nextBlock) resets into \(arc): rebuild volume, set the next ceiling."
        default:
            return "Block \(currentBlock) is in the books. Block \(nextBlock) shifts into \(arc) — different stimulus, fresh adaptations."
        }
    }

    private func blockProgressTeaser(delta: ScanDeltaReport, nextBlock: Int) -> String {
        let improvement = delta.improvements.first?.capitalized
        let focus = delta.laggingAreas.first?.capitalized
        switch (improvement, focus) {
        case let (improvement?, focus?):
            return "\(improvement) up. \(focus) flagged as the focus for Block \(nextBlock)."
        case let (improvement?, nil):
            return "\(improvement) trending up. Block \(nextBlock) builds on it."
        case let (nil, focus?):
            return "Block \(nextBlock) leans into your \(focus.lowercased()) — the area we're going to bias next."
        default:
            return "Tap to see the side-by-side."
        }
    }

    private var noProgramState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "dumbbell")
                .font(.system(size: 40, weight: .thin))
                .foregroundStyle(Color.unbound.textTertiary)
            Text("No program yet")
                .font(Font.unbound.titleM)
                .foregroundStyle(Color.unbound.textPrimary)
            Text("Complete onboarding to generate your first training block.")
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func programBody(_ program: TrainingProgram) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                // Resume banner — calm, top-of-content, only when a draft exists.
                if draftStore.hasDraft {
                    Button {
                        resumeDraft = draftStore.load()
                        showResume = resumeDraft != nil
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.uturn.forward.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Color.unbound.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Resume your workout?")
                                    .font(Font.unbound.bodyMStrong)
                                    .foregroundStyle(Color.unbound.textPrimary)
                                Text("Your last session is saved.")
                                    .font(Font.unbound.monoS)
                                    .foregroundStyle(Color.unbound.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.unbound.textSecondary)
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.unbound.surfaceElevated))
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.unbound.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 12)
                }

                if ProgramScheduler.shared.hasActiveGoals() {
                    todaysTrainingSection
                }
                programHeader(program)
                weekStrip(program: program)
                dayCard(program: program)
                CoachActionsRow(
                    program: program,
                    todayDay: programDay(for: Date(), in: program)
                )
                .environmentObject(services)
                if !services.entitlement.isEntitled {
                    subscriptionBanner
                }
                Spacer().frame(height: 28)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .fullScreenCover(isPresented: $showResume, onDismiss: { resumeDraft = nil }) {
            if let draft = resumeDraft {
                ActiveWorkoutContainerView(
                    workout: Workout(name: "", targetMuscleGroups: [], warmup: [],
                                    mainExercises: [], cooldown: [], estimatedMinutes: 0,
                                    notes: nil, blockType: nil),
                    programId: "",
                    dayNumber: 0,
                    services: services,
                    resuming: draft
                )
            }
        }
    }

    private func programHeader(_ program: TrainingProgram) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(program.name.uppercased())
                    .font(Font.unbound.titleM)
                    .tracking(0.4)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text("\(program.durationDays) DAYS")
                    .font(Font.unbound.captionS)
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            Spacer()
        }
    }

    // MARK: - Week strip

    private var weekStart: Date {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        let base = cal.date(from: comps) ?? cal.startOfDay(for: Date())
        return cal.date(byAdding: .day, value: weekOffset * 7, to: base) ?? base
    }

    private func weekDates() -> [Date] {
        let cal = Calendar.current
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private func weekStrip(program: TrainingProgram) -> some View {
        let dates = weekDates()
        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button { shift(weeks: -1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(weekRangeLabel(from: dates.first ?? Date(), to: dates.last ?? Date()))
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textSecondary)

                Spacer()

                Button { shift(weeks: 1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 6) {
                ForEach(dates, id: \.self) { date in
                    dayTile(date: date, program: program)
                }
            }
        }
    }

    private func shift(weeks: Int) {
        UnboundHaptics.soft()
        withAnimation(.easeInOut(duration: 0.18)) {
            weekOffset += weeks
        }
    }

    private func dayTile(date: Date, program: TrainingProgram) -> some View {
        let cal = Calendar.current
        let isToday = cal.isDateInToday(date)
        let isSelected = cal.isDate(selectedDayDate, inSameDayAs: date)
        let isPast = date < cal.startOfDay(for: Date()) && !isToday

        let day = programDay(for: date, in: program)
        let status = tileStatus(isToday: isToday, isPast: isPast, day: day, program: program)

        let letters = ["M", "T", "W", "T", "F", "S", "S"]
        let weekday = ((cal.component(.weekday, from: date) + 5) % 7)
        let dayNum = cal.component(.day, from: date)

        return Button {
            UnboundHaptics.soft()
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedDayDate = cal.startOfDay(for: date)
            }
        } label: {
            VStack(spacing: 6) {
                Text(letters[weekday])
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(isToday ? Color.unbound.accent : Color.unbound.textTertiary)
                Text("\(dayNum)")
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(
                        isToday || isSelected
                            ? Color.unbound.textPrimary
                            : Color.unbound.textSecondary
                    )
                    .monospacedDigit()
                tileStatusGlyph(status: status)
                    .frame(height: 10)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        isSelected
                            ? Color.unbound.accent.opacity(0.16)
                            : Color.unbound.surface
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        isToday
                            ? Color.unbound.accent.opacity(0.75)
                            : Color.unbound.borderSubtle,
                        lineWidth: isToday ? 1.2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private enum TileStatus { case completed, today, rest, planned, locked }

    private func tileStatus(isToday: Bool, isPast: Bool, day: ProgramDay?, program: TrainingProgram) -> TileStatus {
        if let day, day.isRestDay { return .rest }
        if let day, let vm = viewModel, vm.isCompleted(dayNumber: day.dayNumber) { return .completed }
        if isToday { return .today }
        if isPast { return .locked }
        return .planned
    }

    @ViewBuilder
    private func tileStatusGlyph(status: TileStatus) -> some View {
        switch status {
        case .completed:
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.unbound.accent)
        case .today:
            Circle()
                .fill(Color.unbound.accent)
                .frame(width: 6, height: 6)
                .shadow(color: Color.unbound.accent.opacity(0.65), radius: 3)
        case .rest:
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color.unbound.textTertiary)
        case .planned:
            Circle()
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                .frame(width: 6, height: 6)
        case .locked:
            Circle()
                .fill(Color.unbound.borderSubtle)
                .frame(width: 4, height: 4)
        }
    }

    // MARK: - Day card

    private func dayCard(program: TrainingProgram) -> some View {
        let day = programDay(for: selectedDayDate, in: program)
        let cal = Calendar.current
        let isToday = cal.isDateInToday(selectedDayDate)
        let isPast = selectedDayDate < cal.startOfDay(for: Date()) && !isToday

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(isToday ? "TODAY" : dayHeaderLabel(for: selectedDayDate).uppercased())
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.8)
                    .foregroundStyle(isToday ? Color.unbound.accent : Color.unbound.textTertiary)
                Text("·")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text(longDateLabel(for: selectedDayDate).uppercased())
                    .font(Font.unbound.captionS)
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textTertiary)
                Spacer()
                if isPast, let d = day, viewModel?.isCompleted(dayNumber: d.dayNumber) == true {
                    Text("COMPLETED")
                        .font(Font.unbound.captionS.weight(.bold))
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.success)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(cardTitle(for: day))
                    .font(Font.unbound.titleM)
                    .tracking(0.4)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text(cardSubtitle(for: day))
                    .font(Font.unbound.monoS)
                    .tracking(0.4)
                    .foregroundStyle(Color.unbound.textSecondary)
            }

            if let day, !day.isRestDay, let workout = day.workout {
                exerciseList(workout: workout)
            }

            Button {
                UnboundHaptics.medium()
                if !services.entitlement.isEntitled {
                    showPaywall = true
                    return
                }
                if let day { selectedDay = day }
            } label: {
                HStack(spacing: 10) {
                    Text(ctaLabel(for: day, isToday: isToday))
                        .font(Font.unbound.bodyMStrong)
                        .tracking(1.6)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.unbound.accent)
                )
                .shadow(color: Color.unbound.accent.opacity(0.35), radius: 10, y: 2)
            }
            .buttonStyle(.plain)
            .disabled(day == nil)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.unbound.surface)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.unbound.accent.opacity(isToday ? 0.10 : 0.04), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.unbound.accent.opacity(isToday ? 0.35 : 0.15), lineWidth: 1)
        )
    }

    private func exerciseList(workout: Workout) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(workout.mainExercises.prefix(5).enumerated()), id: \.offset) { _, ex in
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.unbound.accent.opacity(0.5))
                        .frame(width: 4, height: 4)
                    Text(ex.name.uppercased())
                        .font(Font.unbound.captionS)
                        .tracking(0.6)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text("\(ex.sets)×\(ex.reps)")
                        .font(Font.unbound.monoS)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .monospacedDigit()
                }
            }
            if workout.mainExercises.count > 5 {
                Text("+\(workout.mainExercises.count - 5) more")
                    .font(Font.unbound.captionS)
                    .tracking(0.6)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .padding(.leading, 12)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - ROUTINES tab

    private var routinesTab: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                Text("Pick a side mission when the main plan is not the move. Each routine earns SP.")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)

                challengeLibrary

                ForEach(RoutineCategory.allCases.filter { $0 != .challenge }, id: \.self) { cat in
                    routineSection(category: cat)
                }

                Spacer().frame(height: 28)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }

    private var challengeLibrary: some View {
        let challenges = RoutineLibrary.placeholderRoutines.filter { $0.category == .challenge }
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: RoutineCategory.challenge.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(RoutineCategory.challenge.color)
                Text("CHALLENGE LIBRARY")
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.6)
                    .foregroundStyle(RoutineCategory.challenge.color)
                Spacer()
                Text("\(challenges.count) missions")
                    .font(Font.unbound.monoS)
                    .foregroundStyle(Color.unbound.textTertiary)
            }

            TabView(selection: $selectedChallengeId) {
                ForEach(challenges) { routine in
                    Button {
                        beginRoutineTravel(routine)
                    } label: {
                        RoutineChallengeCard(routine: routine)
                    }
                    .buttonStyle(RoutineChallengePressStyle())
                    .tag(routine.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 356)

            RoutineChallengeDots(challenges: challenges, selectedId: selectedChallengeId)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(challenges) { routine in
                        Button {
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                                selectedChallengeId = routine.id
                            }
                        } label: {
                            RoutineChallengePill(
                                routine: routine,
                                isSelected: selectedChallengeId == routine.id
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func beginRoutineTravel(_ routine: RoutineDef) {
        UnboundHaptics.medium()
        travelingRoutine = routine
        routineTravelProgress = 0
        withAnimation(.easeInOut(duration: 0.58)) {
            routineTravelProgress = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) {
            activeRoutinePlayer = routine
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
            withAnimation(.easeOut(duration: 0.18)) {
                travelingRoutine = nil
                routineTravelProgress = 0
            }
        }
    }

    private func completeRoutine(_ routine: RoutineDef, log: SideQuestLog?) {
        let didAward = RoutineCompletionStore.complete(routine)
        activeRoutinePlayer = nil
        completedRoutineReward = RoutineRewardPayload(
            title: routine.title,
            category: routine.category,
            elapsedSeconds: elapsedSeconds(from: log),
            completedSets: log?.setLogs.count ?? routine.steps.count,
            totalSets: max(routine.steps.count, log?.setLogs.count ?? 0),
            spAwarded: didAward ? routine.spReward : 0,
            wasAlreadyCleared: !didAward
        )
        Task { await refreshHistory() }
    }

    private func elapsedSeconds(from log: SideQuestLog?) -> Int {
        guard let log, let completedAt = log.completedAt else { return 0 }
        return max(0, Int(completedAt.timeIntervalSince(log.startedAt)))
    }

    private func routineSection(category: RoutineCategory) -> some View {
        let items = RoutineLibrary.placeholderRoutines.filter { $0.category == category }
        let selectedId = selectedRoutineIdsByCategory[category] ?? items.first?.id ?? ""
        let selection = Binding<String>(
            get: { selectedRoutineIdsByCategory[category] ?? items.first?.id ?? "" },
            set: { selectedRoutineIdsByCategory[category] = $0 }
        )

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: category.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(category.color)
                Text(category.label)
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.6)
                    .foregroundStyle(category.color)
                Spacer()
                Text("\(items.count) missions")
                    .font(Font.unbound.monoS)
                    .foregroundStyle(Color.unbound.textTertiary)
            }

            TabView(selection: selection) {
                ForEach(items) { routine in
                    Button {
                        beginRoutineTravel(routine)
                    } label: {
                        RoutineChallengeCard(routine: routine)
                    }
                    .buttonStyle(RoutineChallengePressStyle())
                    .tag(routine.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 356)

            RoutineChallengeDots(challenges: items, selectedId: selectedId)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(items) { routine in
                        Button {
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                                selectedRoutineIdsByCategory[category] = routine.id
                            }
                        } label: {
                            RoutineChallengePill(
                                routine: routine,
                                isSelected: selectedId == routine.id
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func routineCard(routine: RoutineDef) -> some View {
        Button {
            UnboundHaptics.medium()
            selectedRoutine = routine
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(routine.title.uppercased())
                        .font(Font.unbound.bodyMStrong)
                        .tracking(0.4)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .multilineTextAlignment(.leading)
                    Text(routine.durationLabel)
                        .font(Font.unbound.monoS)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
                Spacer()
                Text("+\(routine.spReward) SP")
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(routine.category.color)
                    .monospacedDigit()
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
                    .strokeBorder(routine.category.color.opacity(0.20), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - HISTORY tab

    private var historyTab: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                if pastLogs.isEmpty {
                    historyEmpty
                        .padding(.top, 40)
                } else {
                    ForEach(historyGroups, id: \.weekStart) { group in
                        historyGroup(group)
                    }
                }
                Spacer().frame(height: 28)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
    }

    private var historyEmpty: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(Color.unbound.textTertiary)
            Text("No sessions logged yet")
                .font(Font.unbound.bodyMStrong)
                .foregroundStyle(Color.unbound.textSecondary)
            Text("Your completed workouts land here.")
                .font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private struct HistoryGroup {
        let weekStart: Date
        let logs: [WorkoutLog]
    }

    private var historyGroups: [HistoryGroup] {
        var cal = Calendar.current
        cal.firstWeekday = 2
        var buckets: [Date: [WorkoutLog]] = [:]
        for log in pastLogs {
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: log.startedAt)
            let key = cal.date(from: comps) ?? log.startedAt
            buckets[key, default: []].append(log)
        }
        return buckets
            .map { HistoryGroup(weekStart: $0.key, logs: $0.value.sorted { $0.startedAt > $1.startedAt }) }
            .sorted { $0.weekStart > $1.weekStart }
    }

    private func historyGroup(_ group: HistoryGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(historyWeekLabel(group.weekStart))
                .font(Font.unbound.captionS.weight(.bold))
                .tracking(1.6)
                .foregroundStyle(Color.unbound.textTertiary)

            VStack(spacing: 8) {
                ForEach(group.logs, id: \.id) { log in
                    historyRow(log: log)
                }
            }
        }
    }

    private func historyRow(log: WorkoutLog) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(log.plannedWorkoutName.uppercased())
                    .font(Font.unbound.bodyMStrong)
                    .tracking(0.4)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text(historyDateLabel(log.startedAt))
                    .font(Font.unbound.captionS)
                    .tracking(0.6)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            Spacer()
            if let mins = log.durationMinutes {
                Text("\(mins) MIN")
                    .font(Font.unbound.monoS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .monospacedDigit()
            }
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

    @MainActor
    private func refreshHistory() async {
        let userId = services.auth.currentUserId ?? "anonymous"
        let logs = (try? await services.workoutLog.fetchRecentLogs(userId: userId, limit: 40)) ?? []
        pastLogs = logs.filter { $0.completedAt != nil }
    }

    @MainActor
    private func refreshTravelOverride() async {
        let userId = services.auth.currentUserId ?? "anonymous"
        activeTravelOverride = await TravelOverrideStore.shared.activeOverride(for: userId)
    }

    // MARK: - Helpers

    private func programDay(for date: Date, in program: TrainingProgram) -> ProgramDay? {
        // Travel override wins whenever today falls in its window — the
        // normal program rotation is suspended until the user is back.
        if let override = activeTravelOverride, let tday = override.day(for: date) {
            return travelProgramDay(from: tday, on: date)
        }
        guard !program.days.isEmpty else { return nil }
        let daysSinceStart = Calendar.current.dateComponents(
            [.day], from: program.createdAt, to: date
        ).day ?? 0
        let idx = ((daysSinceStart % program.days.count) + program.days.count) % program.days.count
        return program.days[idx]
    }

    /// Synthesize a ProgramDay from a travel override day so the rest of
    /// the UI renders it like any other scheduled workout.
    private func travelProgramDay(from tday: TravelDay, on date: Date) -> ProgramDay {
        let workout: Workout? = {
            guard !tday.isRest else { return nil }
            let exercises = tday.exercises.map { name in
                Exercise(
                    id: UUID().uuidString,
                    name: name,
                    muscleGroups: [],
                    sets: 3,
                    reps: "8-12",
                    restSeconds: 60,
                    rpe: nil,
                    notes: nil,
                    substitution: nil
                )
            }
            return Workout(
                name: tday.title,
                targetMuscleGroups: [],
                warmup: [],
                mainExercises: exercises,
                cooldown: [],
                estimatedMinutes: parseMinutes(from: tday.duration),
                notes: "Travel plan · \(activeTravelOverride?.summary ?? "")",
                blockType: nil
            )
        }()
        return ProgramDay(
            id: "travel-\(Int(date.timeIntervalSince1970))",
            dayNumber: 0,
            label: tday.isRest ? "TRAVEL · REST" : "TRAVEL · \(tday.title)",
            isRestDay: tday.isRest,
            workout: workout,
            nutritionOverride: nil,
            recoveryActivities: []
        )
    }

    /// Parse the LLM's duration string ("~30 MIN", "45 min", etc.) into
    /// an integer minute count; falls back to 30 if parsing fails.
    private func parseMinutes(from text: String) -> Int {
        let digits = text.compactMap { $0.isNumber ? $0 : nil }
        if let n = Int(String(digits)), n > 0 { return n }
        return 30
    }

    private func cardTitle(for day: ProgramDay?) -> String {
        guard let day else { return "NO SESSION" }
        if day.isRestDay { return "REST DAY" }
        return day.workout?.name.uppercased() ?? "NO SESSION"
    }

    private func cardSubtitle(for day: ProgramDay?) -> String {
        guard let day else { return "Plan your next move." }
        if day.isRestDay { return "Recovery is the work." }
        if let workout = day.workout {
            return "\(workout.mainExercises.count) EXERCISES · ~\(workout.estimatedMinutes)M"
        }
        return "Plan your next move."
    }

    private func ctaLabel(for day: ProgramDay?, isToday: Bool) -> String {
        guard let day else { return "NOTHING PLANNED" }
        if day.isRestDay { return "VIEW RECOVERY" }
        if isToday { return "BEGIN SESSION" }
        return "VIEW DETAILS"
    }

    private func weekRangeLabel(from: Date, to: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return "\(f.string(from: from).uppercased()) — \(f.string(from: to).uppercased())"
    }

    private func dayHeaderLabel(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date)
    }

    private func longDateLabel(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE MMM d"
        return f.string(from: date)
    }

    private func historyWeekLabel(_ date: Date) -> String {
        let cal = Calendar.current
        let now = Date()
        let nowComps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        let lastComps = cal.dateComponents(
            [.yearForWeekOfYear, .weekOfYear],
            from: cal.date(byAdding: .day, value: -7, to: now) ?? now
        )
        let itemComps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        if itemComps == nowComps { return "THIS WEEK" }
        if itemComps == lastComps { return "LAST WEEK" }
        let f = DateFormatter()
        f.dateFormat = "MMMM d"
        return f.string(from: date).uppercased()
    }

    private func historyDateLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE MMM d · h:mm a"
        return f.string(from: date)
    }

    // MARK: - Legacy subviews

    private var subscriptionBanner: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(Color.unbound.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Unlock your full program")
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text("Subscribe to access workouts, nutrition & recovery.")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.unbound.accent.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.unbound.accent.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func errorState(_ error: Error) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundStyle(Color.unbound.alert)
            Text(error.localizedDescription)
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Routine library (placeholder)
//
// Hardcoded routines until a real RoutineService ships. Shape matches what
// the real RoutineDef + categories will expose so wiring it later is a
// data-source swap, not a view rewrite.

enum RoutineCategory: CaseIterable, Hashable {
    case cardio, mobility, challenge, altCircuit

    var label: String {
        switch self {
        case .cardio:     return "CARDIO"
        case .mobility:   return "MOBILITY"
        case .challenge:  return "CHALLENGES"
        case .altCircuit: return "ALT CIRCUITS"
        }
    }

    var systemImage: String {
        switch self {
        case .cardio:     return "figure.run"
        case .mobility:   return "figure.flexibility"
        case .challenge:  return "flame.fill"
        case .altCircuit: return "dumbbell.fill"
        }
    }

    var color: Color {
        switch self {
        case .cardio:     return Color.unbound.coachCyan
        case .mobility:   return Color.unbound.rankGreen
        case .challenge:  return Color.unbound.warnOrange
        case .altCircuit: return Color.unbound.accent
        }
    }
}

struct RoutineDef: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let durationLabel: String
    let category: RoutineCategory
    let spReward: Int
    var steps: [String] = []
}

// MARK: - RoutineCompletionStore
//
// UserDefaults-backed completion log for routines. One award per routine
// per 24h. Bumps the `unbound.gains` total (same key the rest of the app
// reads) so SP shows up everywhere a Gains counter is rendered.
//
// Real RoutineService will replace this with proper logging — interface
// stays the same so the view doesn't change.

@MainActor
enum RoutineCompletionStore {
    private static let keyPrefix = "unbound.routineLastCompleted."
    private static let gainsKey = "unbound.gains"
    private static let cooldown: TimeInterval = 24 * 3600

    static func canComplete(routineId: String) -> Bool {
        guard let last = lastCompleted(routineId: routineId) else { return true }
        return Date().timeIntervalSince(last) >= cooldown
    }

    static func lastCompleted(routineId: String) -> Date? {
        let raw = UserDefaults.standard.double(forKey: keyPrefix + routineId)
        return raw > 0 ? Date(timeIntervalSince1970: raw) : nil
    }

    /// Records the completion + awards SP. Returns true if newly awarded,
    /// false if still inside the 24h cooldown window.
    @discardableResult
    static func complete(_ routine: RoutineDef) -> Bool {
        guard canComplete(routineId: routine.id) else { return false }
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: keyPrefix + routine.id)
        let current = UserDefaults.standard.integer(forKey: gainsKey)
        UserDefaults.standard.set(current + routine.spReward, forKey: gainsKey)
        return true
    }
}

enum RoutineLibrary {
    static let placeholderRoutines: [RoutineDef] = [
        // Cardio
        RoutineDef(id: "z2-walk-20", title: "20-min Zone 2 walk",
                   subtitle: "Keep HR in zone 2. Easy breathing, steady pace.",
                   durationLabel: "~20 MIN", category: .cardio, spReward: 25,
                   steps: ["Warm up 2 min slow walk", "Maintain conversational pace — can hold a sentence", "Target HR: 60–70% max (roughly 180 − your age)", "20 min steady. Do not surge.", "Cool down 1 min slow"]),

        RoutineDef(id: "intervals-15", title: "15-min HR intervals",
                   subtitle: "5 × 1-min hard / 1-min easy. Build conditioning.",
                   durationLabel: "~15 MIN", category: .cardio, spReward: 35,
                   steps: ["Warm up 5 min easy run or bike", "GO — 1 min max effort (sprint, bike, row)", "Recover — 1 min slow walk or easy spin", "Repeat × 5 rounds", "Cool down 3 min easy"]),

        RoutineDef(id: "easy-bike-30", title: "30-min easy bike",
                   subtitle: "Steady-state spin. Low impact recovery cardio.",
                   durationLabel: "~30 MIN", category: .cardio, spReward: 30,
                   steps: ["Adjust seat so leg extends ~90% at bottom", "RPM 80–90, resistance light to moderate", "Maintain steady breathing — nasal if possible", "30 min continuous. No breaks.", "Stretch quads and hip flexors after"]),

        // Mobility
        RoutineDef(id: "mobility-10", title: "Morning mobility flow",
                   subtitle: "Spine, hips, shoulders. Wake the body up.",
                   durationLabel: "~10 MIN", category: .mobility, spReward: 15,
                   steps: ["Cat-cow × 10 reps (slow, full range)", "World's greatest stretch × 5/side", "Thread the needle × 8/side", "Hip 90-90 switches × 10 reps", "Shoulder circles forward + back × 10", "Deep squat hold 60 sec"]),

        RoutineDef(id: "stretch-8", title: "Evening stretch",
                   subtitle: "Cool-down flexibility. Hip openers, hamstring.",
                   durationLabel: "~8 MIN", category: .mobility, spReward: 10,
                   steps: ["Hamstring fold — 60 sec/side", "Pigeon pose — 60 sec/side", "Supine figure-4 stretch — 45 sec/side", "Seated forward fold — 60 sec", "Lying spinal twist — 30 sec/side"]),

        RoutineDef(id: "hip-flow-15", title: "Hip flow",
                   subtitle: "15-min mobility sequence targeting hip health.",
                   durationLabel: "~15 MIN", category: .mobility, spReward: 20,
                   steps: ["Hip circles × 10 each direction", "Deep lunge hold — 45 sec/side", "Side-lying clamshell × 15/side", "Frog stretch — 90 sec", "Hip flexor couch stretch — 60 sec/side", "Lateral band walk × 20 steps/side (bodyweight if no band)", "Glute bridge × 15 reps"]),

        // Challenges
        RoutineDef(id: "100-pushup", title: "100 pushup challenge",
                   subtitle: "As many sets as it takes. Track your count.",
                   durationLabel: "~15 MIN", category: .challenge, spReward: 50,
                   steps: ["Set a timer", "Do as many push-ups as possible with good form", "Rest as needed — no time limit on rest", "Log your sets and counts", "Hit 100 total reps across however many sets", "Standard form: chest to 1 inch from floor, elbows 45°"]),

        RoutineDef(id: "plank-ladder", title: "Plank ladder",
                   subtitle: "30s / 45s / 60s / 75s / 90s — rest 30s between.",
                   durationLabel: "~12 MIN", category: .challenge, spReward: 40,
                   steps: ["Plank 30 sec → rest 30 sec", "Plank 45 sec → rest 30 sec", "Plank 60 sec → rest 30 sec", "Plank 75 sec → rest 30 sec", "Plank 90 sec — finish", "Cues: neutral spine, squeeze glutes, breathe steady"]),

        RoutineDef(id: "tabata-core", title: "Tabata core",
                   subtitle: "8 × 20s on / 10s off. 4 rotating moves.",
                   durationLabel: "~8 MIN", category: .challenge, spReward: 45,
                   steps: ["Set tabata timer: 20s on / 10s off × 8 rounds", "Round 1–2: Mountain climbers", "Round 3–4: Bicycle crunches", "Round 5–6: Hollow body hold", "Round 7–8: V-ups", "Max effort on every working set"]),

        RoutineDef(id: "saitama-protocol", title: "Zero Limit Protocol",
                   subtitle: "100 push-ups, 100 sit-ups, 100 squats, 10km run. Every. Single. Day.",
                   durationLabel: "~60–90 MIN", category: .challenge, spReward: 200,
                   steps: ["100 push-ups — break into sets, complete all", "100 sit-ups — full range, hands behind head", "100 bodyweight squats — parallel depth minimum", "10km run — any pace, no stopping", "No rest days. No excuses.", "Warning: this protocol exists. So does overtraining. Earn it."]),

        RoutineDef(id: "8-gates-protocol", title: "8 Gates Protocol",
                   subtitle: "8 rounds. Each gate adds a layer. You stop when your body does.",
                   durationLabel: "~45 MIN", category: .challenge, spReward: 120,
                   steps: [
                       "Gate 1 — 10 push-ups",
                       "Gate 2 — 10 push-ups + 15 squats",
                       "Gate 3 — 10 push-ups + 15 squats + 10 dips (chair or bench)",
                       "Gate 4 — 10 push-ups + 15 squats + 10 dips + 10 pull-ups (or 15 Australian rows)",
                       "Gate 5 — repeat Gate 4 + 20 mountain climbers",
                       "Gate 6 — repeat Gate 5 + 30s plank hold",
                       "Gate 7 — repeat Gate 6 + 10 burpees",
                       "Gate 8 — repeat Gate 7 + 400m sprint",
                       "Rest 60–90s between gates. No skipping. No half gates.",
                       "Warning: most people DNF after Gate 5. That's the point."
                   ]),

        RoutineDef(id: "beach-forge", title: "Beach Forge",
                   subtitle: "Heavy carries, sprints, pull-ups. Zero to forged in 40 minutes.",
                   durationLabel: "~40 MIN", category: .challenge, spReward: 90,
                   steps: [
                       "Farmer carry — 2 × heaviest DBs or loaded bags, 40m down and back × 4",
                       "Rest 60s",
                       "400m run (or 2 min treadmill at race pace)",
                       "Rest 60s",
                       "Pull-ups × max reps — 4 sets, rest 45s between",
                       "Rest 90s",
                       "Sandbag or loaded backpack squat × 15 reps — 3 sets",
                       "Rest 60s",
                       "400m run — final sprint, leave nothing",
                       "Inspired by carrying dead weight every day until you're not weak anymore"
                   ]),

        RoutineDef(id: "underground-grind", title: "Underground Grind",
                   subtitle: "Pull-ups, dips, push-ups, core. Pure calisthenics. No mercy.",
                   durationLabel: "~30 MIN", category: .challenge, spReward: 85,
                   steps: [
                       "Pull-ups × max reps — do not break form",
                       "Rest 45s",
                       "Dips × max reps (parallel bars or between chairs)",
                       "Rest 45s",
                       "Diamond push-ups × 15",
                       "Rest 45s",
                       "Hanging leg raises × 12",
                       "Rest 45s",
                       "Repeat circuit 4 times total",
                       "Finish: L-sit hold on bars or chairs — max duration × 3 attempts",
                       "If you can't do pull-ups: Australian rows under a table, 15 reps"
                   ]),

        RoutineDef(id: "3d-maneuver-conditioning", title: "3D Conditioning",
                   subtitle: "Core, grip, pulling power. Built for bodies that move in all directions.",
                   durationLabel: "~25 MIN", category: .challenge, spReward: 70,
                   steps: [
                       "Dead hang — 60 sec (build grip and shoulder stability)",
                       "Rest 30s",
                       "Pull-ups × 8 — controlled descent (3 sec down)",
                       "Rest 45s",
                       "Tuck jumps × 10 — drive knees up hard",
                       "Rest 30s",
                       "Hollow body hold — 45 sec",
                       "Rest 30s",
                       "Explosive push-up × 10 (hands leave floor)",
                       "Rest 45s",
                       "Repeat 4 rounds",
                       "Goal: move like you weigh nothing. Train like it costs something."
                   ]),

        RoutineDef(id: "daily-quest", title: "Daily Quest",
                   subtitle: "The weakest start. The discipline compounds. Begin your rank climb.",
                   durationLabel: "~20 MIN", category: .challenge, spReward: 50,
                   steps: [
                       "Push-ups × 30",
                       "Sit-ups × 30",
                       "Bodyweight squats × 30",
                       "2km run (or 12-min treadmill walk/jog)",
                       "This is the E-rank version. Do it every day for 2 weeks.",
                       "Week 3: increase to 50 reps each + 5km",
                       "Week 5: 100 reps each + 10km — you are no longer E-rank",
                       "The only way to level up is to show up"
                   ]),

        RoutineDef(id: "thunder-circuit", title: "Thunder Circuit",
                   subtitle: "Speed, power, explosiveness. Train the fast-twitch you've been ignoring.",
                   durationLabel: "~20 MIN", category: .challenge, spReward: 65,
                   steps: [
                       "Broad jump × 6 — maximum distance each rep",
                       "Rest 30s",
                       "Sprint 40m × 6 (or 10-sec treadmill sprint) — full effort",
                       "Rest 45s",
                       "Clap push-ups × 8",
                       "Rest 30s",
                       "Jump squats × 12 — land soft, explode hard",
                       "Rest 45s",
                       "Lateral bounds × 10/side",
                       "Rest 30s",
                       "Repeat 3 rounds",
                       "Every rep is a strike. Every second of rest is borrowed time."
                   ]),

        RoutineDef(id: "gravity-chamber", title: "Gravity Chamber",
                   subtitle: "High volume. Every rep heavier than the last. Build the body that survives pressure.",
                   durationLabel: "~50 MIN", category: .challenge, spReward: 110,
                   steps: [
                       "Weighted push-ups (plate or loaded pack on back) × 20 — 5 sets",
                       "Rest 60s between sets",
                       "Weighted squats (DBs at sides or barbell) × 15 — 5 sets",
                       "Rest 90s between sets",
                       "Pull-ups with weight belt or DB between legs × 8 — 4 sets",
                       "Rest 60s between sets",
                       "Weighted plank — 60 sec (plate on back) × 3",
                       "Rest 45s between sets",
                       "No equipment? Add 1 extra rep to every set. Volume is the weight.",
                       "The chamber does not adjust to you. You adjust to the chamber."
                   ]),

        RoutineDef(id: "vessel-protocol", title: "Vessel Protocol",
                   subtitle: "Strength and speed. The body is a weapon. Forge it like one.",
                   durationLabel: "~35 MIN", category: .challenge, spReward: 95,
                   steps: [
                       "Clean and press (DBs or barbell) × 8 — 4 sets. Go heavy.",
                       "Rest 60s",
                       "Sprint 100m × 4 — walk back recovery between",
                       "Rest 90s",
                       "Single-arm DB row × 10/side — 3 sets. Drive the elbow, not the hand.",
                       "Rest 45s",
                       "Box jump or step-up jumps × 8 — 3 sets",
                       "Rest 60s",
                       "Bear crawl 20m forward + 20m backward × 3",
                       "Rest 45s",
                       "Finish: 50 push-ups any style — clock running",
                       "A weapon with no edge is dead weight. Stay sharp."
                   ]),

        // Alt circuits
        RoutineDef(id: "bw-full-30", title: "Bodyweight full-body",
                   subtitle: "No equipment. Pushup, squat, lunge, plank.",
                   durationLabel: "~30 MIN", category: .altCircuit, spReward: 40,
                   steps: ["Push-ups × 15", "Bodyweight squats × 20", "Reverse lunges × 12/leg", "Pike push-ups × 10", "Glute bridges × 20", "Plank 45 sec", "Repeat circuit 3 rounds, 60 sec rest between"]),

        RoutineDef(id: "db-full-25", title: "Dumbbell full-body",
                   subtitle: "Compound circuit with a pair of DBs.",
                   durationLabel: "~25 MIN", category: .altCircuit, spReward: 45,
                   steps: ["DB goblet squat × 12", "DB Romanian deadlift × 10", "DB bent-over row × 10/arm", "DB shoulder press × 10", "DB chest press × 12", "DB curl × 12", "3 rounds, 90 sec rest between"])
    ]
}

// MARK: - Routine challenge carousel

private struct RoutineChallengeCard: View {
    let routine: RoutineDef

    private var canComplete: Bool {
        RoutineCompletionStore.canComplete(routineId: routine.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                routineCover
                    .frame(height: 198)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                LinearGradient(
                    colors: [.clear, Color.unbound.bg.opacity(0.70), Color.unbound.bg.opacity(0.92)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    statusChip
                    Text(routine.title.uppercased())
                        .font(Font.unbound.titleL)
                        .tracking(0.6)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.70)
                    Text(routine.subtitle)
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(2)
                }
                .padding(18)
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    metricPill(value: routine.durationLabel, label: "TIME")
                    metricPill(value: "+\(routine.spReward)", label: "SP")
                    metricPill(value: "\(routine.steps.count)", label: "STEPS")
                }

                HStack(spacing: 12) {
                    Text(routine.steps.first ?? "Open the mission and start.")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 6) {
                        Text(canComplete ? "ENTER" : "DONE")
                            .font(Font.unbound.captionS.weight(.heavy))
                            .tracking(1.4)
                        Image(systemName: canComplete ? "arrow.right" : "checkmark.seal.fill")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(Color.unbound.bg)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(canComplete ? routine.category.color : Color.unbound.textTertiary))
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(routine.category.color.opacity(0.28), lineWidth: 1)
        )
        .shadow(color: routine.category.color.opacity(0.18), radius: 18, x: 0, y: 10)
    }

    @ViewBuilder
    private var routineCover: some View {
        if let image = UIImage(named: routine.coverAssetName) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .saturation(canComplete ? 1 : 0.25)
                .opacity(canComplete ? 0.9 : 0.48)
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        routine.category.color.opacity(0.46),
                        Color.unbound.emberDeep.opacity(0.34),
                        Color.unbound.bg
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Path { path in
                    path.move(to: CGPoint(x: 24, y: 146))
                    path.addCurve(
                        to: CGPoint(x: 190, y: 44),
                        control1: CGPoint(x: 78, y: 92),
                        control2: CGPoint(x: 114, y: 34)
                    )
                    path.addCurve(
                        to: CGPoint(x: 335, y: 118),
                        control1: CGPoint(x: 252, y: 54),
                        control2: CGPoint(x: 262, y: 146)
                    )
                }
                .stroke(
                    routine.category.color.opacity(0.72),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                )
                .shadow(color: routine.category.color.opacity(0.30), radius: 10)

                Image(systemName: routine.category.systemImage)
                    .font(.system(size: 118, weight: .black))
                    .foregroundStyle(routine.category.color.opacity(0.18))
                    .offset(x: 90, y: -34)
            }
        }
    }

    private var statusChip: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(canComplete ? routine.category.color : Color.unbound.textTertiary)
                .frame(width: 6, height: 6)
            Text(canComplete ? "MISSION READY" : "CLEARED TODAY")
                .font(Font.unbound.monoS.weight(.heavy))
                .tracking(1.3)
        }
        .foregroundStyle(canComplete ? routine.category.color : Color.unbound.textTertiary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.unbound.bg.opacity(0.62)))
        .overlay(Capsule().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
    }

    private func metricPill(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(Font.unbound.monoS.weight(.bold))
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(1.1)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surfaceElevated)
        )
    }
}

private struct RoutineChallengeDots: View {
    let challenges: [RoutineDef]
    let selectedId: String

    var body: some View {
        HStack(spacing: 9) {
            ForEach(challenges) { routine in
                Capsule()
                    .fill(routine.id == selectedId ? routine.category.color : Color.unbound.textTertiary.opacity(0.32))
                    .frame(width: routine.id == selectedId ? 24 : 7, height: 7)
                    .animation(.easeInOut(duration: 0.2), value: selectedId)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 20)
    }
}

private struct RoutineChallengePill: View {
    let routine: RoutineDef
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: routine.category.systemImage)
                .font(.system(size: 11, weight: .bold))
            Text(routine.title.uppercased())
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.0)
                .lineLimit(1)
        }
        .foregroundStyle(isSelected ? Color.unbound.bg : Color.unbound.textSecondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Capsule().fill(isSelected ? routine.category.color : Color.unbound.surface))
        .overlay(
            Capsule()
                .strokeBorder(isSelected ? Color.clear : Color.unbound.border, lineWidth: 1)
        )
    }
}

private struct RoutineTravelOverlay: View {
    let routine: RoutineDef
    let progress: CGFloat

    var body: some View {
        ZStack {
            Color.unbound.bg.opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .stroke(routine.category.color.opacity(0.16), lineWidth: 18)
                        .frame(width: 166, height: 166)
                        .scaleEffect(1 + progress * 0.45)
                        .opacity(Double(1 - progress * 0.55))
                    Image(systemName: routine.category.systemImage)
                        .font(.system(size: 54, weight: .black))
                        .foregroundStyle(routine.category.color)
                        .offset(x: progress * 22, y: -progress * 18)
                        .scaleEffect(1 + progress * 0.12)
                }

                Text(routine.title.uppercased())
                    .font(Font.unbound.titleM)
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .multilineTextAlignment(.center)
                Text("ENTERING MISSION")
                    .font(Font.unbound.monoS.weight(.heavy))
                    .tracking(2.0)
                    .foregroundStyle(routine.category.color)
            }
            .padding(.horizontal, 28)
        }
    }
}

private struct RoutineChallengePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.spring(response: 0.24, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

private extension RoutineDef {
    var coverAssetName: String { "routine_challenge_\(id)" }

    var sideQuest: SideQuest {
        let exercises = steps.isEmpty
            ? [SideQuestExercise(
                id: "\(id)-mission",
                name: title,
                sets: 1,
                reps: "1",
                restSeconds: 0,
                cue: subtitle
            )]
            : steps.enumerated().map { index, step in
                let parsed = RoutineStepParser.parse(step: step, fallbackIndex: index)
                return SideQuestExercise(
                    id: "\(id)-\(index)",
                    name: parsed.name,
                    sets: parsed.sets,
                    reps: parsed.reps,
                    restSeconds: parsed.restSeconds,
                    cue: parsed.cue
                )
            }

        return SideQuest(
            id: id,
            title: title,
            subtitle: subtitle,
            category: category.sideQuestCategory,
            estimatedMinutes: estimatedMinutes,
            spReward: spReward,
            exercises: exercises
        )
    }

    private var estimatedMinutes: Int {
        let numbers = durationLabel.matches(for: #"\d+"#).compactMap(Int.init)
        return numbers.first ?? max(5, steps.count * 3)
    }
}

private extension RoutineCategory {
    var sideQuestCategory: SideQuestCategory {
        switch self {
        case .cardio: return .cardio
        case .mobility: return .mobility
        case .challenge, .altCircuit: return .circuit
        }
    }
}

private enum RoutineStepParser {
    static func parse(step: String, fallbackIndex: Int) -> (name: String, sets: Int, reps: String, restSeconds: Int, cue: String) {
        let clean = step.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = clean.lowercased()
        let name = parsedName(from: clean, fallbackIndex: fallbackIndex)
        let sets = parsedSets(from: clean)
        let reps = parsedReps(from: clean, lower: lower)
        let rest = parsedRest(from: lower)
        return (name, sets, reps, rest, clean)
    }

    private static func parsedName(from step: String, fallbackIndex: Int) -> String {
        let separators = [" — ", " - ", " → ", " × ", " x "]
        for separator in separators {
            if let range = step.range(of: separator) {
                let name = String(step[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty { return name }
            }
        }
        let clipped = step.components(separatedBy: ".").first ?? step
        let trimmed = clipped.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Step \(fallbackIndex + 1)" : trimmed
    }

    private static func parsedSets(from step: String) -> Int {
        guard let value = step.firstMatch(for: #"(?i)(\d+)\s*(sets|rounds)"#) else { return 1 }
        return Int(value) ?? 1
    }

    private static func parsedReps(from step: String, lower: String) -> String {
        if lower.contains("amrap") || lower.contains("max reps") || lower.contains("max duration") {
            return "AMRAP"
        }
        if lower.contains("km") {
            return "1"
        }
        if lower.contains("min"), let value = step.firstMatch(for: #"(\d+)\s*[-–]?\s*\d*\s*min"#).flatMap(Int.init) {
            return "\(value * 60)s"
        }
        if lower.contains("sec"), let value = step.firstMatch(for: #"(\d+)\s*sec"#).flatMap(Int.init) {
            return "\(value)s"
        }
        if lower.contains("s "), let value = step.firstMatch(for: #"(\d+)s"#).flatMap(Int.init) {
            return "\(value)s"
        }
        if let value = step.firstMatch(for: #"[×x]\s*(\d+)"#) {
            return value
        }
        return step.firstMatch(for: #"(\d+)"#) ?? "1"
    }

    private static func parsedRest(from lower: String) -> Int {
        if let value = lower.firstMatch(for: #"rest\s*(\d+)"#).flatMap(Int.init) {
            return value
        }
        return 30
    }
}

private extension String {
    func matches(for pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(startIndex..<endIndex, in: self)
        return regex.matches(in: self, range: range).compactMap { match in
            guard let range = Range(match.range, in: self) else { return nil }
            return String(self[range])
        }
    }

    func firstMatch(for pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(startIndex..<endIndex, in: self)
        guard let match = regex.firstMatch(in: self, range: range) else { return nil }
        let captureIndex = match.numberOfRanges > 1 ? 1 : 0
        guard let matchRange = Range(match.range(at: captureIndex), in: self) else { return nil }
        return String(self[matchRange])
    }
}

private struct RoutineRewardPayload: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let category: RoutineCategory
    let elapsedSeconds: Int
    let completedSets: Int
    let totalSets: Int
    let spAwarded: Int
    let wasAlreadyCleared: Bool

    var elapsedLabel: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

private struct RoutineCompletionRewardView: View {
    let reward: RoutineRewardPayload
    let onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            RadialGradient(
                colors: [reward.category.color.opacity(0.28), Color.unbound.bg.opacity(0)],
                center: .top,
                startRadius: 20,
                endRadius: 480
            )
            .ignoresSafeArea()
            .opacity(appeared ? 1 : 0)

            VStack(spacing: 18) {
                Spacer(minLength: 24)

                ZStack {
                    Circle()
                        .fill(reward.category.color.opacity(0.16))
                        .frame(width: 126, height: 126)
                    Circle()
                        .stroke(reward.category.color.opacity(0.45), lineWidth: 1)
                        .frame(width: 126, height: 126)
                    Image(systemName: reward.wasAlreadyCleared ? "checkmark.seal.fill" : "sparkles")
                        .font(.system(size: 46, weight: .black))
                        .foregroundStyle(reward.category.color)
                }
                .scaleEffect(appeared ? 1 : 0.72)
                .shadow(color: reward.category.color.opacity(0.55), radius: 22)

                VStack(spacing: 7) {
                    Text(reward.wasAlreadyCleared ? "MISSION RECORDED" : "MISSION COMPLETE")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(2.0)
                        .foregroundStyle(reward.category.color)
                    Text(reward.title.uppercased())
                        .font(Font.unbound.displayM)
                        .tracking(0.4)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.72)
                }

                HStack(spacing: 0) {
                    rewardStat(value: reward.elapsedLabel, label: "TIME")
                    divider
                    rewardStat(value: "\(reward.completedSets)/\(reward.totalSets)", label: "SETS")
                    divider
                    rewardStat(value: reward.wasAlreadyCleared ? "BANKED" : "+\(reward.spAwarded)", label: "SP")
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.unbound.surface))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(reward.category.color.opacity(0.32), lineWidth: 1)
                )
                .padding(.horizontal, 24)

                Text(reward.wasAlreadyCleared ? "Daily reward cooldown is active. The work still counts." : "Stats collected. Reward locked into your run.")
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 34)

                Spacer(minLength: 24)

                UnboundButton(title: "CONTINUE", icon: "arrow.right") {
                    UnboundHaptics.medium()
                    onDismiss()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.54, dampingFraction: 0.78)) {
                appeared = true
            }
            UnboundHaptics.success()
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.unbound.border)
            .frame(width: 1, height: 34)
    }

    private func rewardStat(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(Font.unbound.monoL)
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - RoutinePreviewSheet

private struct RoutinePreviewSheet: View {
    let routine: RoutineDef
    @Environment(\.dismiss) private var dismiss
    @State private var didComplete: Bool = false

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: routine.category.systemImage)
                                .font(.system(size: 12, weight: .semibold))
                            Text(routine.category.label)
                                .font(Font.unbound.captionS.weight(.bold))
                                .tracking(1.6)
                        }
                        .foregroundStyle(routine.category.color)
                        Spacer()
                        HStack(spacing: 4) {
                            Text(routine.durationLabel)
                                .font(Font.unbound.monoS)
                                .foregroundStyle(Color.unbound.textTertiary)
                            Text("·")
                                .foregroundStyle(Color.unbound.textTertiary)
                            Text("+\(routine.spReward) SP")
                                .font(Font.unbound.monoM.weight(.bold))
                                .foregroundStyle(routine.category.color)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(routine.title.uppercased())
                            .font(Font.unbound.titleL)
                            .tracking(0.4)
                            .foregroundStyle(Color.unbound.textPrimary)
                        Text(routine.subtitle)
                            .font(Font.unbound.bodyM)
                            .foregroundStyle(Color.unbound.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !routine.steps.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("HOW TO DO IT")
                                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                .tracking(2.0)
                                .foregroundStyle(Color.unbound.textTertiary)
                                .padding(.bottom, 10)

                            ForEach(Array(routine.steps.enumerated()), id: \.offset) { i, step in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(i + 1)")
                                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                        .foregroundStyle(routine.category.color)
                                        .frame(width: 20, alignment: .trailing)
                                        .padding(.top, 1)
                                    Text(step)
                                        .font(Font.unbound.bodyM)
                                        .foregroundStyle(Color.unbound.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(.vertical, 10)
                                if i < routine.steps.count - 1 {
                                    Divider()
                                        .background(Color.unbound.borderSubtle)
                                }
                            }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.unbound.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.unbound.border, lineWidth: 1)
                        )
                    }

                    let canComplete = RoutineCompletionStore.canComplete(routineId: routine.id)
                    let label: String = {
                        if didComplete { return "+\(routine.spReward) SP LOCKED IN" }
                        if !canComplete { return "DONE TODAY · COME BACK TOMORROW" }
                        return "MARK COMPLETE · +\(routine.spReward) SP"
                    }()
                    let icon: String = {
                        if didComplete || !canComplete { return "checkmark.seal.fill" }
                        return "arrow.right"
                    }()
                    let isDisabled = didComplete || !canComplete

                    Button {
                        UnboundHaptics.medium()
                        let awarded = RoutineCompletionStore.complete(routine)
                        if awarded {
                            withAnimation(.easeOut(duration: 0.2)) { didComplete = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { dismiss() }
                        } else {
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Text(label)
                                .font(Font.unbound.bodyMStrong)
                                .tracking(1.6)
                            Image(systemName: icon)
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundStyle(Color.unbound.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(routine.category.color)
                        )
                        .opacity(isDisabled ? 0.55 : 1.0)
                        .shadow(color: routine.category.color.opacity(0.45), radius: 10, y: 2)
                    }
                    .buttonStyle(.plain)
                    .disabled(isDisabled)

                    Spacer().frame(height: 8)
                }
                .padding(24)
            }
        }
    }
}

// MARK: - DayPreviewSheet (V3)
//
// Modal sheet showing the routed goals for any day in the 7-day strip.
// Reuses the same launchers as TODAY'S TRAINING — tap card body to open
// SkillDetailView, tap the right-side button to launch the AI session.
// Doesn't filter by canTrain, so the user can preview future-day plans.

private struct DayPreviewSheet: View {
    let date: Date
    let onSelectSkill: (SkillNode) -> Void
    let onTrainSkill: (SkillNode) -> Void

    @Environment(\.dismiss) private var dismiss
    @Bindable private var skillProgress = SkillProgressService.shared

    var body: some View {
        let category = ProgramScheduler.shared.category(for: date)
        let skillIds = ProgramScheduler.shared.skillIds(forDate: date)

        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                header(category: category)

                if category == .rest {
                    restEmptyState
                } else if skillIds.isEmpty {
                    noGoalsEmptyState(category: category)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 8) {
                            ForEach(skillIds, id: \.self) { id in
                                if let node = SkillGraph.shared.node(id: id) {
                                    skillCard(node: node)
                                }
                            }
                        }
                    }
                    Text("Tap a card to view skill details.")
                        .font(Font.unbound.captionS)
                        .tracking(0.4)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                Spacer(minLength: 0)
            }
            .padding(20)
        }
    }

    private func header(category: DayCategory) -> some View {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        let weekday = f.string(from: date).uppercased()
        let title = category == .rest
            ? "\(weekday) · REST DAY"
            : "\(weekday) · \(category.displayName.uppercased()) DAY"

        return HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.accent)
                Text(longDate(date).uppercased())
                    .font(Font.unbound.captionS)
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            Spacer()
            Button {
                UnboundHaptics.soft()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle().fill(Color.unbound.surfaceElevated.opacity(0.6))
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func longDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE MMM d"
        return f.string(from: date)
    }

    private var restEmptyState: some View {
        emptyState(
            icon: "moon.fill",
            title: "Rest day",
            subtitle: "Recover hard. Tomorrow lands harder."
        )
    }

    private func noGoalsEmptyState(category: DayCategory) -> some View {
        emptyState(
            icon: "calendar.badge.clock",
            title: "No goals routed",
            subtitle: "No active goals match \(category.displayName) day yet. Add one from any skill detail screen."
        )
    }

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(Color.unbound.textTertiary)
            Text(title)
                .font(Font.unbound.bodyMStrong)
                .foregroundStyle(Color.unbound.textSecondary)
            Text(subtitle)
                .font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
    }

    private func skillCard(node: SkillNode) -> some View {
        let sp = skillProgress.currentSkillProgress(for: node.id)
        let asset = node.id.replacingOccurrences(of: ".", with: "_")

        return Button {
            UnboundHaptics.soft()
            onSelectSkill(node)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.unbound.surfaceElevated)
                        .frame(width: 56, height: 56)
                    if UIImage(named: asset) != nil {
                        Image(asset)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 48, height: 48)
                    } else {
                        Image(systemName: node.glyph)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Color.unbound.accent)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(node.title)
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                    Text("\(node.cluster.displayName) · Lv \(sp.currentLevel)")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                Button {
                    UnboundHaptics.medium()
                    onTrainSkill(node)
                } label: {
                    HStack(spacing: 4) {
                        Text("TRAIN")
                            .font(Font.unbound.captionS.weight(.bold))
                            .tracking(1.2)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(Color.unbound.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(Color.unbound.accent)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.unbound.surfaceElevated.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - WeeklyScheduleEditorSheet (V4)
//
// V4 changes vs V3:
//   1. Drag-to-reorder via SwiftUI `List` + `.onMove`. Day labels stay
//      pinned (Mon-Sun); the user reorders the CATEGORIES, so dragging
//      Pull from Mon to Sun swaps the categories on those rows. Drag
//      handles stay visible via `.environment(\.editMode, .active)`.
//   2. AI SUGGEST OPTIMAL — one-tap Claude call generates a 7-day split
//      tailored to the user's active goals; populates the draft (no
//      auto-save).
//   3. WEEK PHASE picker — chip + bottom sheet (heavy/moderate/light/
//      deload). Persists immediately via setWeekPhase.
//   4. Tap-a-chip per row still works for picking the category.

private struct WeeklyScheduleEditorSheet: View {
    @EnvironmentObject var services: ServiceContainer
    @Environment(\.dismiss) private var dismiss
    @Bindable private var skillProgress = SkillProgressService.shared

    /// Local working copy — committed to service on Save.
    @State private var draft: [DayCategory] = []

    /// V4 — AI suggest in-flight + error state.
    @State private var isSuggesting: Bool = false
    @State private var suggestErrorVisible: Bool = false

    /// V4 — phase picker sheet.
    @State private var showPhasePicker: Bool = false

    /// V4 — chip-pick sheet for an individual day (replaces the inline
    /// horizontal scroll so the row stays drag-friendly).
    @State private var editingDayIndex: Int? = nil

    private static let dayLabels = ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY", "SUNDAY"]

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                phaseChipRow
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)

                // V4: SwiftUI `List` with `.onMove` so each row gets a
                // drag handle. `.environment(\.editMode, .active)` keeps
                // handles visible without a separate Edit toggle.
                List {
                    Section {
                        ForEach(Array(draft.enumerated()), id: \.offset) { idx, _ in
                            dayRow(index: idx)
                                .listRowBackground(Color.unbound.bg)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                        }
                        .onMove(perform: moveCategories)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.unbound.bg)
                .environment(\.editMode, .constant(.active))

                bottomActions
            }
        }
        .onAppear { hydrateDraft() }
        .sheet(isPresented: $showPhasePicker) {
            WeekPhasePickerSheet(
                current: skillProgress.currentWeekPhase,
                onPick: { phase in
                    Task {
                        await SkillProgressService.shared.setWeekPhase(phase)
                        UnboundHaptics.medium()
                    }
                    showPhasePicker = false
                }
            )
            .presentationDetents([.fraction(0.4)])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: Binding(
            get: { editingDayIndex.map { DayPickIndex(idx: $0) } },
            set: { editingDayIndex = $0?.idx }
        )) { wrapper in
            DayCategoryPickerSheet(
                dayLabel: Self.dayLabels[wrapper.idx],
                current: draft.indices.contains(wrapper.idx) ? draft[wrapper.idx] : .rest,
                onPick: { cat in
                    if draft.indices.contains(wrapper.idx) {
                        draft[wrapper.idx] = cat
                    }
                    editingDayIndex = nil
                }
            )
            .presentationDetents([.fraction(0.45)])
            .presentationDragIndicator(.visible)
        }
    }

    // Wrapper because Int isn't Identifiable directly.
    private struct DayPickIndex: Identifiable, Hashable {
        let idx: Int
        var id: Int { idx }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("WEEKLY SCHEDULE")
                    .font(Font.unbound.titleS)
                    .tracking(2.0)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text("Drag to reorder. Tap a chip to change.")
                    .font(Font.unbound.captionS)
                    .tracking(0.4)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            Spacer()
            Button {
                UnboundHaptics.soft()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle().fill(Color.unbound.surfaceElevated.opacity(0.6))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    // MARK: - V4 Phase chip row

    private var phaseChipRow: some View {
        let phase = skillProgress.currentWeekPhase
        return HStack(spacing: 8) {
            Button {
                UnboundHaptics.soft()
                showPhasePicker = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: phase.glyph)
                        .font(.system(size: 10, weight: .bold))
                    Text("\(phase.displayName.uppercased()) WEEK")
                        .font(Font.unbound.captionS.weight(.bold))
                        .tracking(1.4)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(Color.unbound.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(Color.unbound.accent.opacity(0.14))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Color.unbound.accent.opacity(0.4), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    // MARK: - Day row

    private func dayRow(index: Int) -> some View {
        let cat = draft.indices.contains(index) ? draft[index] : .rest

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.dayLabels[index])
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .frame(width: 96, alignment: .leading)

            Button {
                UnboundHaptics.soft()
                editingDayIndex = index
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: cat.glyph)
                        .font(.system(size: 11, weight: .bold))
                    Text(cat.displayName.uppercased())
                        .font(Font.unbound.captionS.weight(.bold))
                        .tracking(1.2)
                }
                .foregroundStyle(Color.unbound.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.unbound.accent.opacity(cat == .rest ? 0.10 : 0.85))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            cat == .rest
                                ? Color.unbound.borderSubtle
                                : Color.clear,
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    /// Reorder the CATEGORIES while day labels stay pinned. SwiftUI's
    /// `.onMove` already gives us the right semantics — we just apply
    /// it to the categories array.
    private func moveCategories(from source: IndexSet, to destination: Int) {
        UnboundHaptics.soft()
        draft.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Bottom actions

    private var bottomActions: some View {
        VStack(spacing: 10) {
            // V4 — AI SUGGEST OPTIMAL button.
            UnboundButton(
                title: isSuggesting ? "GENERATING…" : "SUGGEST OPTIMAL",
                variant: .secondary,
                icon: "sparkles",
                isEnabled: !isSuggesting
            ) {
                Task { await runSuggest() }
            }
            .overlay(alignment: .trailing) {
                if isSuggesting {
                    ProgressView()
                        .tint(Color.unbound.accent)
                        .scaleEffect(0.85)
                        .padding(.trailing, 18)
                }
            }

            if suggestErrorVisible {
                Text("Couldn't generate. Try again?")
                    .font(Font.unbound.captionS)
                    .tracking(0.4)
                    .foregroundStyle(Color.unbound.alert)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .transition(.opacity)
            }

            UnboundButton(title: "SAVE", icon: "checkmark") {
                Task { await save() }
            }

            Button {
                UnboundHaptics.soft()
                Task { await resetToDefault() }
            } label: {
                Text("RESET TO DEFAULT")
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 18)
        .background(
            Color.unbound.bg
                .overlay(
                    Rectangle()
                        .fill(Color.unbound.borderSubtle)
                        .frame(height: 1),
                    alignment: .top
                )
        )
    }

    // MARK: - Actions

    private func hydrateDraft() {
        // Seed the draft from the user's current effective schedule
        // so the picker shows what's actually in effect today.
        draft = ProgramScheduler.shared.effectiveWeeklySchedule()
    }

    private func runSuggest() async {
        guard !isSuggesting else { return }
        let userId = services.auth.currentUserId ?? "anonymous"
        let goals = skillProgress.activeGoalIds
        withAnimation(.easeInOut(duration: 0.15)) {
            isSuggesting = true
            suggestErrorVisible = false
        }
        do {
            let suggested = try await AISessionGeneratorService.shared.suggestWeeklySchedule(
                activeGoalIds: goals,
                userId: userId
            )
            // Populate draft — let user review and tap SAVE to commit.
            draft = suggested
            UnboundHaptics.medium()
        } catch {
            LoggingService.shared.log(
                "suggestWeeklySchedule failed: \(error.localizedDescription)",
                level: .warning
            )
            withAnimation(.easeInOut(duration: 0.15)) {
                suggestErrorVisible = true
            }
        }
        withAnimation(.easeInOut(duration: 0.15)) {
            isSuggesting = false
        }
    }

    private func save() async {
        // Persist all 7 picks. Even if the user didn't change a slot, we
        // store the resolved value so the schedule survives default tweaks.
        let payload: [DayCategory?] = draft.map { Optional($0) }
        await SkillProgressService.shared.setWeeklySchedule(payload)
        UnboundHaptics.medium()
        dismiss()
    }

    private func resetToDefault() async {
        let nilled: [DayCategory?] = Array(repeating: nil, count: 7)
        await SkillProgressService.shared.setWeeklySchedule(nilled)
        UnboundHaptics.medium()
        dismiss()
    }
}

// MARK: - WeekPhasePickerSheet (V4)

private struct WeekPhasePickerSheet: View {
    let current: WeekPhase
    let onPick: (WeekPhase) -> Void

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                Text("WEEK PHASE")
                    .font(Font.unbound.titleS)
                    .tracking(2.0)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text("Sets the intensity for this week's AI sessions.")
                    .font(Font.unbound.captionS)
                    .tracking(0.4)
                    .foregroundStyle(Color.unbound.textTertiary)

                VStack(spacing: 8) {
                    ForEach(WeekPhase.allCases) { phase in
                        phaseRow(phase: phase)
                    }
                }
                .padding(.top, 6)

                Spacer(minLength: 0)
            }
            .padding(20)
        }
    }

    private func phaseRow(phase: WeekPhase) -> some View {
        let isCurrent = phase == current
        return Button {
            UnboundHaptics.soft()
            onPick(phase)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: phase.glyph)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isCurrent ? Color.unbound.accent : Color.unbound.textSecondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(phase.displayName.uppercased())
                        .font(Font.unbound.bodyMStrong)
                        .tracking(1.0)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text(phase.description)
                        .font(Font.unbound.captionS)
                        .tracking(0.4)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                if isCurrent {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.unbound.accent)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isCurrent ? Color.unbound.accent.opacity(0.12) : Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isCurrent ? Color.unbound.accent.opacity(0.45) : Color.unbound.borderSubtle,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - DayCategoryPickerSheet (V4)
//
// Sheet for picking a category for a single day in the editor. Replaces
// the inline horizontal chip scroller from V3 — drag-to-reorder needs
// the row to be tap-and-hold-to-drag, so a separate sheet is cleaner.

private struct DayCategoryPickerSheet: View {
    let dayLabel: String
    let current: DayCategory
    let onPick: (DayCategory) -> Void

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                Text(dayLabel)
                    .font(Font.unbound.titleS)
                    .tracking(2.0)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text("Pick the category for this day.")
                    .font(Font.unbound.captionS)
                    .tracking(0.4)
                    .foregroundStyle(Color.unbound.textTertiary)

                VStack(spacing: 8) {
                    ForEach(DayCategory.allCases) { cat in
                        catRow(category: cat)
                    }
                }
                .padding(.top, 6)

                Spacer(minLength: 0)
            }
            .padding(20)
        }
    }

    private func catRow(category: DayCategory) -> some View {
        let isCurrent = category == current
        return Button {
            UnboundHaptics.soft()
            onPick(category)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: category.glyph)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isCurrent ? Color.unbound.accent : Color.unbound.textSecondary)
                    .frame(width: 28)
                Text(category.displayName.uppercased())
                    .font(Font.unbound.bodyMStrong)
                    .tracking(1.0)
                    .foregroundStyle(Color.unbound.textPrimary)
                Spacer(minLength: 0)
                if isCurrent {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.unbound.accent)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isCurrent ? Color.unbound.accent.opacity(0.12) : Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isCurrent ? Color.unbound.accent.opacity(0.45) : Color.unbound.borderSubtle,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
