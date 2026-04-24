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

    @State private var viewModel: ProgramViewModel?
    @State private var selectedTab: Tab = .program
    @State private var selectedDay: ProgramDay?
    @State private var showPaywall = false
    @State private var showRationale = false

    // Program view state
    @State private var weekOffset: Int = 0 // +1 = next week, -1 = prev
    @State private var selectedDayDate: Date = Calendar.current.startOfDay(for: Date())

    // History view state
    @State private var pastLogs: [WorkoutLog] = []

    // Routines view state
    @State private var selectedRoutine: RoutineDef?

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
        }
        .navigationBarHidden(true)
        .task {
            let vm = ProgramViewModel(services: services)
            self.viewModel = vm
            guard let userId = services.auth.currentUserId else { return }
            do {
                let profile: UserProfile = try await services.user.fetchProfile(userId: userId)
                if let programId = profile.currentProgramId {
                    await vm.loadProgram(programId: programId)
                }
            } catch {}
            await refreshHistory()
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
                workoutLog: viewModel?.logFor(dayNumber: day.dayNumber)
            )
        }
        .sheet(item: $selectedRoutine) { routine in
            RoutinePreviewSheet(routine: routine)
                .presentationDragIndicator(.visible)
                .presentationDetents([.medium])
        }
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
            case .idle, .loading:
                ProgressView().tint(Color.unbound.accent).frame(maxHeight: .infinity)
            case .error(let error):
                errorState(error)
            case .loaded(let program):
                programBody(program)
            }
        } else {
            ProgressView().tint(Color.unbound.accent).frame(maxHeight: .infinity)
        }
    }

    private func programBody(_ program: TrainingProgram) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                programHeader(program)
                weekStrip(program: program)
                dayCard(program: program)
                if !services.entitlement.isEntitled {
                    subscriptionBanner
                }
                Spacer().frame(height: 28)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }

    private func programHeader(_ program: TrainingProgram) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(program.name.uppercased())
                    .font(Font.unbound.titleM)
                    .tracking(0.4)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text("\(program.archetype.displayName.uppercased()) · \(program.durationDays) DAYS")
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
            VStack(alignment: .leading, spacing: 20) {
                Text("Variety for off-days, cardio, and challenges. Each routine earns SP.")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)

                ForEach(RoutineCategory.allCases, id: \.self) { cat in
                    routineSection(category: cat)
                }

                Spacer().frame(height: 28)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }

    private func routineSection(category: RoutineCategory) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: category.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(category.color)
                Text(category.label)
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.6)
                    .foregroundStyle(category.color)
            }

            let items = RoutineLibrary.placeholderRoutines.filter { $0.category == category }
            VStack(spacing: 8) {
                ForEach(items) { r in
                    routineCard(routine: r)
                }
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

    // MARK: - Helpers

    private func programDay(for date: Date, in program: TrainingProgram) -> ProgramDay? {
        guard !program.days.isEmpty else { return nil }
        let daysSinceStart = Calendar.current.dateComponents(
            [.day], from: program.createdAt, to: date
        ).day ?? 0
        let idx = ((daysSinceStart % program.days.count) + program.days.count) % program.days.count
        return program.days[idx]
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
}

enum RoutineLibrary {
    static let placeholderRoutines: [RoutineDef] = [
        // Cardio
        RoutineDef(id: "z2-walk-20", title: "20-min Zone 2 walk",
                   subtitle: "Keep HR in zone 2. Easy breathing, steady pace.",
                   durationLabel: "~20 MIN", category: .cardio, spReward: 25),
        RoutineDef(id: "intervals-15", title: "15-min HR intervals",
                   subtitle: "5 × 1-min hard / 1-min easy. Build conditioning.",
                   durationLabel: "~15 MIN", category: .cardio, spReward: 35),
        RoutineDef(id: "easy-bike-30", title: "30-min easy bike",
                   subtitle: "Steady-state spin. Low impact recovery cardio.",
                   durationLabel: "~30 MIN", category: .cardio, spReward: 30),

        // Mobility
        RoutineDef(id: "mobility-10", title: "Morning mobility flow",
                   subtitle: "Spine, hips, shoulders. Wake the body up.",
                   durationLabel: "~10 MIN", category: .mobility, spReward: 15),
        RoutineDef(id: "stretch-8", title: "Evening stretch",
                   subtitle: "Cool-down flexibility. Hip openers, hamstring.",
                   durationLabel: "~8 MIN", category: .mobility, spReward: 10),
        RoutineDef(id: "hip-flow-15", title: "Hip flow",
                   subtitle: "15-min mobility sequence targeting hip health.",
                   durationLabel: "~15 MIN", category: .mobility, spReward: 20),

        // Challenges
        RoutineDef(id: "100-pushup", title: "100 pushup challenge",
                   subtitle: "As many sets as it takes. Track your count.",
                   durationLabel: "~15 MIN", category: .challenge, spReward: 50),
        RoutineDef(id: "plank-ladder", title: "Plank ladder",
                   subtitle: "30s / 45s / 60s / 75s / 90s — rest 30s between.",
                   durationLabel: "~12 MIN", category: .challenge, spReward: 40),
        RoutineDef(id: "tabata-core", title: "Tabata core",
                   subtitle: "8 × 20s on / 10s off. 4 rotating moves.",
                   durationLabel: "~8 MIN", category: .challenge, spReward: 45),

        // Alt circuits
        RoutineDef(id: "bw-full-30", title: "Bodyweight full-body",
                   subtitle: "No equipment. Pushup, squat, lunge, plank.",
                   durationLabel: "~30 MIN", category: .altCircuit, spReward: 40),
        RoutineDef(id: "db-full-25", title: "Dumbbell full-body",
                   subtitle: "Compound circuit with a pair of DBs.",
                   durationLabel: "~25 MIN", category: .altCircuit, spReward: 45)
    ]
}

// MARK: - RoutinePreviewSheet

private struct RoutinePreviewSheet: View {
    let routine: RoutineDef
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: routine.category.systemImage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(routine.category.color)
                    Text(routine.category.label)
                        .font(Font.unbound.captionS.weight(.bold))
                        .tracking(1.6)
                        .foregroundStyle(routine.category.color)
                    Spacer()
                    Text("+\(routine.spReward) SP")
                        .font(Font.unbound.monoM.weight(.bold))
                        .foregroundStyle(routine.category.color)
                }

                Text(routine.title.uppercased())
                    .font(Font.unbound.titleL)
                    .tracking(0.4)
                    .foregroundStyle(Color.unbound.textPrimary)

                Text(routine.subtitle)
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(routine.durationLabel)
                    .font(Font.unbound.monoS)
                    .foregroundStyle(Color.unbound.textTertiary)

                Spacer()

                Button {
                    UnboundHaptics.medium()
                    // Real accept-routine flow ships with RoutineService.
                    dismiss()
                } label: {
                    HStack(spacing: 10) {
                        Text("START ROUTINE")
                            .font(Font.unbound.bodyMStrong)
                            .tracking(1.6)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(Color.unbound.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(routine.category.color)
                    )
                    .shadow(color: routine.category.color.opacity(0.45), radius: 10, y: 2)
                }
                .buttonStyle(.plain)
            }
            .padding(24)
        }
    }
}
