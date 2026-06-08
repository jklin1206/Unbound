import SwiftUI

struct ProgramCommandDock: View {
    struct SetupTile {
        let title: String
        let detail: String
        let icon: String
        let tint: Color
        let badge: String?
        let isLoading: Bool

        static func resolve(
            style: TrainingStyle,
            equipment: [Equipment],
            activeContext: ProgramTrainingContextOverride?,
            pendingContext: ProgramTrainingContextOverride?,
            isLoading: Bool
        ) -> SetupTile {
            let displayedContext = activeContext ?? pendingContext
            return SetupTile(
                title: compactTrainingStyleLabel(style),
                detail: contextDockDetail(
                    override: displayedContext,
                    style: style,
                    equipment: equipment
                ),
                icon: trainingStyleIcon(style),
                tint: trainingStyleTint(style),
                badge: contextDockBadge(
                    activeContext: activeContext,
                    pendingContext: pendingContext
                ),
                isLoading: isLoading
            )
        }

        private static func compactTrainingStyleLabel(_ style: TrainingStyle) -> String {
            switch style {
            case .bodyweight: return "Calis"
            case .freeWeights: return "Lift"
            case .hybrid: return "Hybrid"
            case .machines: return "Gym"
            }
        }

        private static func trainingStyleIcon(_ style: TrainingStyle) -> String {
            switch style {
            case .bodyweight: return "figure.strengthtraining.functional"
            case .freeWeights: return "dumbbell.fill"
            case .hybrid: return "arrow.triangle.2.circlepath"
            case .machines: return "cable.connector"
            }
        }

        private static func trainingStyleTint(_ style: TrainingStyle) -> Color {
            switch style {
            case .bodyweight: return Color.unbound.success
            case .freeWeights: return Color.unbound.accent
            case .hybrid: return Color.unbound.coachCyan
            case .machines: return Color.unbound.warnOrange
            }
        }

        private static func equipmentDockLabel(_ equipment: [Equipment]) -> String {
            let sorted = ProgramTrainingContextResolver.sortedEquipment(Set(equipment))
            guard let first = sorted.first else { return "Auto gear" }
            if sorted.count == 1 { return first.displayName }
            return "\(first.displayName) +\(sorted.count - 1)"
        }

        private static func contextDockBadge(
            activeContext: ProgramTrainingContextOverride?,
            pendingContext: ProgramTrainingContextOverride?
        ) -> String {
            let active: String? = activeContext.map { context in
                context.selection.scope == .thisWeek ? "WEEK" : "TODAY"
            }
            if let active, pendingContext != nil { return "\(active)+NEXT" }
            if let active { return active }
            if pendingContext != nil { return "NEXT" }
            return "BASE"
        }

        private static func contextDockDetail(
            override: ProgramTrainingContextOverride?,
            style: TrainingStyle,
            equipment: [Equipment]
        ) -> String {
            let styleLabel = compactTrainingStyleLabel(style)
            switch override?.selection.scope {
            case .todayOnly, .thisWeek:
                return "\(styleLabel) / \(equipmentDockLabel(equipment))"
            case .nextBlock:
                return "\(styleLabel) queued"
            case .ongoing, .freeformManual, .none:
                return equipmentDockLabel(equipment)
            }
        }
    }

    let setupTile: SetupTile
    let savedWorkouts: [SavedWorkout]
    let onWorkout: (SavedWorkout) -> Void
    let onPlan: () -> Void
    let onChangeSetup: () -> Void
    let onCreateWorkout: () -> Void
    let onShowAllWorkouts: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            actionBar
            workoutList
        }
        .accessibilityIdentifier("program.quickStart.card")
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Workouts")
                    .font(Font.unbound.titleS)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text(savedWorkouts.isEmpty ? "Create one, then start it from here." : "\(savedWorkouts.count) saved")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }

    private var actionBar: some View {
        HStack(spacing: 14) {
            actionLink(
                title: "Plan",
                systemName: "calendar",
                tint: Color.unbound.coachCyan,
                action: onPlan
            )
            .accessibilityIdentifier("program.monthPlanner.open")

            actionLink(
                title: "Create",
                systemName: "plus.circle",
                tint: Color.unbound.accent,
                action: onCreateWorkout
            )
            .accessibilityIdentifier("program.createWorkout.open")

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    private var workoutList: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(Color.unbound.borderSubtle.opacity(0.72))

            if savedWorkouts.isEmpty {
                emptyWorkoutRow
            } else {
                ForEach(Array(savedWorkouts.prefix(4).enumerated()), id: \.element.id) { index, workout in
                    workoutRow(workout)
                    if index < min(savedWorkouts.count, 4) - 1 {
                        Divider()
                            .padding(.leading, 44)
                            .overlay(Color.unbound.borderSubtle.opacity(0.5))
                    }
                }

                if savedWorkouts.count > 4 {
                    Divider()
                        .padding(.leading, 44)
                        .overlay(Color.unbound.borderSubtle.opacity(0.5))
                    allWorkoutsRow
                }
            }

            Divider()
                .overlay(Color.unbound.borderSubtle.opacity(0.72))
        }
    }

    private var workoutRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if savedWorkouts.isEmpty {
                    emptyWorkoutTile
                } else {
                    ForEach(savedWorkouts.prefix(8)) { workout in
                        workoutTile(workout)
                    }

                    if savedWorkouts.count > 8 {
                        allWorkoutsTile
                    }
                }
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 1)
        }
    }

    private func workoutRow(_ workout: SavedWorkout) -> some View {
        Button {
            onWorkout(workout)
        } label: {
            HStack(spacing: 12) {
                WorkoutReferenceImageView(
                    exerciseName: workout.effectiveReferenceExerciseName,
                    fallbackSystemName: icon(for: workout),
                    fallbackTint: tint(for: workout)
                )
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 3) {
                    Text(workout.title.isEmpty ? "Workout" : workout.title)
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text("\(roleText(workout)) / \(workout.exerciseCount) moves / ~\(workout.estimatedMinutes)m")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("program.savedWorkout.quickStart.\(workout.id.uuidString)")
    }

    private var emptyWorkoutRow: some View {
        Button(action: onCreateWorkout) {
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.unbound.accent)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.unbound.accent.opacity(0.12)))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Build Workout")
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text("Save it once. Start it fast.")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textTertiary)
                }

                Spacer(minLength: 8)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("program.savedWorkout.create")
    }

    private var allWorkoutsRow: some View {
        Button(action: onShowAllWorkouts) {
            HStack(spacing: 12) {
                Image(systemName: "tray.full")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.unbound.coachCyan)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.unbound.coachCyan.opacity(0.12)))
                Text("Show all workouts")
                    .font(Font.unbound.bodyS.weight(.semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
                Spacer(minLength: 8)
                Text("\(savedWorkouts.count)")
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("program.savedWorkouts.open")
    }

    private func workoutTile(_ workout: SavedWorkout) -> some View {
        Button {
            onWorkout(workout)
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    WorkoutReferenceImageView(
                        exerciseName: workout.effectiveReferenceExerciseName,
                        fallbackSystemName: icon(for: workout),
                        fallbackTint: tint(for: workout)
                    )
                    .frame(width: 34, height: 34)
                    Spacer(minLength: 0)
                    Text(roleText(workout).uppercased())
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(0.8)
                        .foregroundStyle(tint(for: workout))
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                }

                Text(workout.title.isEmpty ? "Workout" : workout.title)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.76)

                HStack(spacing: 8) {
                    metric("\(workout.exerciseCount)", "moves")
                    metric("~\(workout.estimatedMinutes)m", "time")
                }
            }
            .padding(12)
            .frame(width: 164, height: 112, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.unbound.surfaceElevated.opacity(0.88))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(tint(for: workout).opacity(0.34), lineWidth: 1)
            )
            .shadow(color: tint(for: workout).opacity(0.10), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("program.savedWorkout.quickStart.\(workout.id.uuidString)")
    }

    private var emptyWorkoutTile: some View {
        Button(action: onCreateWorkout) {
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Color.unbound.accent))

                VStack(alignment: .leading, spacing: 3) {
                    Text("BUILD WORKOUT")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.0)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text("Save it once. Start it fast.")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(width: 246, height: 82, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.unbound.surfaceElevated.opacity(0.88))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.unbound.accent.opacity(0.34), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("program.savedWorkout.create")
    }

    private var allWorkoutsTile: some View {
        Button(action: onShowAllWorkouts) {
            VStack(spacing: 8) {
                Image(systemName: "tray.full")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.unbound.coachCyan)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.unbound.coachCyan.opacity(0.14)))
                Text("ALL")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text("\(savedWorkouts.count)")
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .frame(width: 76, height: 112)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.unbound.surfaceElevated.opacity(0.78))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("program.savedWorkouts.open")
    }

    private func compactActionButton(
        title: String,
        systemName: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: systemName)
                    .font(.system(size: 13, weight: .bold))
                Text(title.uppercased())
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(0.7)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(tint)
            .frame(width: 58, height: 46)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(tint.opacity(0.24), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func actionLink(
        title: String,
        systemName: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 20)
                Text(title)
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(0.7)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
            }
            .frame(height: 34)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var trainSetupButton: some View {
        Button(action: onChangeSetup) {
            HStack(spacing: 7) {
                Image(systemName: setupTile.isLoading ? "arrow.triangle.2.circlepath" : setupTile.icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(setupTile.tint)
                    .frame(width: 20)
                Text(setupTile.title)
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(0.7)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)

                if let badge = setupTile.badge, badge != "BASE" {
                    Text(badge)
                        .font(Font.unbound.monoS.weight(.bold))
                        .foregroundStyle(setupTile.tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
            }
            .frame(height: 34)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(setupTile.isLoading)
        .accessibilityLabel("Training setup")
        .accessibilityIdentifier("program.focusSwitch")
    }

    private func metric(_ value: String, _ label: String) -> some View {
        HStack(spacing: 3) {
            Text(value.uppercased())
                .font(Font.unbound.monoS.weight(.bold))
            Text(label.uppercased())
                .font(Font.unbound.captionS.weight(.semibold))
        }
        .foregroundStyle(Color.unbound.textTertiary)
        .lineLimit(1)
        .minimumScaleFactor(0.72)
    }

    private func roleText(_ workout: SavedWorkout) -> String {
        SessionRole.fromStorageValue(workout.sessionRole)?.displayName ?? "Custom"
    }

    private func tint(for workout: SavedWorkout) -> Color {
        switch SavedWorkout.normalizedSessionRole(workout.sessionRole) {
        case "push", "upper": return Color.unbound.accent
        case "pull": return Color.unbound.coachCyan
        case "legs", "lower": return Color.unbound.success
        case "full-body", "full_body": return Color.unbound.warnOrange
        case "skill-only", "skill_only": return Color.unbound.success
        default: return Color.unbound.textSecondary
        }
    }

    private func icon(for workout: SavedWorkout) -> String {
        switch SavedWorkout.normalizedSessionRole(workout.sessionRole) {
        case "push", "upper": return "figure.strengthtraining.traditional"
        case "pull": return "figure.pull"
        case "legs", "lower": return "figure.run"
        case "full-body", "full_body": return "figure.mixed.cardio"
        case "skill-only", "skill_only": return "sparkles"
        case "cardio": return "heart.fill"
        default: return "dumbbell.fill"
        }
    }
}

private struct ProgramMonthPlanMarker: Hashable {
    let title: String
    let kind: ProgramScheduleOccurrenceKind

    var isRest: Bool { kind == .rest }
}

struct ProgramMonthPlannerView: View {
    private struct DaySelection: Identifiable {
        let date: Date

        var id: TimeInterval { date.timeIntervalSinceReferenceDate }
    }

    let workouts: [SavedWorkout]
    let initialDate: Date
    let occurrences: [ProgramScheduleOccurrence]
    let onPlace: (SavedWorkout, Date) -> Void
    let onMarkRest: (Date) -> Void
    let onClearPlan: (Date) -> Void
    let onCreateWorkout: () -> Void
    let onDismiss: () -> Void

    @State private var visibleMonth: Date
    @State private var planMarkers: [Date: ProgramMonthPlanMarker]
    @State private var activeDaySelection: DaySelection?

    private let calendar: Calendar
    private let dayCellHeight: CGFloat = 54
    private let weekdaySymbols = ["M", "T", "W", "T", "F", "S", "S"]

    init(
        workouts: [SavedWorkout],
        initialDate: Date,
        occurrences: [ProgramScheduleOccurrence],
        calendar: Calendar = .current,
        onPlace: @escaping (SavedWorkout, Date) -> Void,
        onMarkRest: @escaping (Date) -> Void,
        onClearPlan: @escaping (Date) -> Void,
        onCreateWorkout: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.workouts = workouts
        self.initialDate = initialDate
        self.occurrences = occurrences
        self.calendar = calendar
        self.onPlace = onPlace
        self.onMarkRest = onMarkRest
        self.onClearPlan = onClearPlan
        self.onCreateWorkout = onCreateWorkout
        self.onDismiss = onDismiss

        let month = calendar.dateInterval(of: .month, for: initialDate)?.start
            ?? calendar.startOfDay(for: initialDate)
        _visibleMonth = State(initialValue: month)
        _planMarkers = State(initialValue: Self.indexedMarkers(from: occurrences, calendar: calendar))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.unbound.bg.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    header
                    calendarGrid
                    self.plannerLegend
                    Spacer(minLength: 0)
                }
                .padding(20)
            }
            .navigationTitle("Plan Month")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", action: onDismiss)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
            }
            .sheet(item: $activeDaySelection) { selection in
                ProgramMonthWorkoutPickerView(
                    date: selection.date,
                    workouts: workouts,
                    planMarker: planMarkers[calendar.startOfDay(for: selection.date)],
                    onSelect: { workout in
                        let normalized = calendar.startOfDay(for: selection.date)
                        UnboundHaptics.success()
                        onPlace(workout, normalized)
                        planMarkers[normalized] = ProgramMonthPlanMarker(
                            title: workout.title,
                            kind: .saved
                        )
                        activeDaySelection = nil
                    },
                    onMarkRest: {
                        let normalized = calendar.startOfDay(for: selection.date)
                        UnboundHaptics.success()
                        onMarkRest(normalized)
                        planMarkers[normalized] = ProgramMonthPlanMarker(
                            title: "Rest",
                            kind: .rest
                        )
                        activeDaySelection = nil
                    },
                    onClearPlan: {
                        let normalized = calendar.startOfDay(for: selection.date)
                        UnboundHaptics.medium()
                        onClearPlan(normalized)
                        planMarkers.removeValue(forKey: normalized)
                        activeDaySelection = nil
                    },
                    onCreateWorkout: {
                        activeDaySelection = nil
                        onCreateWorkout()
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.unbound.bg)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(monthTitle(visibleMonth))
                    .font(Font.unbound.titleM)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text(monthSummary)
                    .font(Font.unbound.captionS.weight(.semibold))
                    .foregroundStyle(Color.unbound.textSecondary)
            }

            Spacer(minLength: 0)

            monthButton(systemName: "chevron.left") { shiftMonth(-1) }
            monthButton(systemName: "chevron.right") { shiftMonth(1) }
        }
    }

    private var calendarGrid: some View {
        VStack(spacing: 10) {
            LazyVGrid(columns: dayColumns, spacing: 6) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, label in
                    Text(label)
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(0.7)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: dayColumns, spacing: 6) {
                ForEach(monthCells.indices, id: \.self) { index in
                    if let date = monthCells[index] {
                        dayCell(date)
                    } else {
                        Color.clear.frame(height: dayCellHeight)
                    }
                }
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let normalized = calendar.startOfDay(for: date)
        let marker = planMarkers[normalized]
        let isToday = calendar.isDateInToday(date)
        let isSelected = calendar.isDate(date, inSameDayAs: initialDate)
        let isPast = normalized < calendar.startOfDay(for: Date())

        return Button {
            UnboundHaptics.medium()
            activeDaySelection = DaySelection(date: normalized)
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    if isToday {
                        Circle()
                            .fill(Color.unbound.accent)
                            .frame(width: 34, height: 34)
                    } else if isSelected {
                        Circle()
                            .strokeBorder(Color.unbound.accent.opacity(0.55), lineWidth: 1.5)
                            .frame(width: 34, height: 34)
                    }
                    Text("\(calendar.component(.day, from: date))")
                        .font(Font.unbound.monoS.weight(.bold))
                        .foregroundStyle(dayNumberColor(isToday: isToday, isPast: isPast))
                }
                .frame(height: 34)

                dayIndicator(marker)
            }
            .frame(maxWidth: .infinity, minHeight: dayCellHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isPast && marker == nil ? 0.5 : 1)
        .accessibilityLabel(accessibilityLabel(for: date, marker: marker))
    }

    @ViewBuilder
    private func dayIndicator(_ marker: ProgramMonthPlanMarker?) -> some View {
        if let marker {
            if marker.isRest {
                Image(systemName: "moon.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(height: 8)
            } else {
                Circle()
                    .fill(Color.unbound.accent)
                    .frame(width: 7, height: 7)
            }
        } else {
            Color.clear.frame(height: 8)
        }
    }

    private var plannerLegend: some View {
        HStack(spacing: 18) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.unbound.accent)
                    .frame(width: 7, height: 7)
                Text("Workout")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
            }
            HStack(spacing: 6) {
                Image(systemName: "moon.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.unbound.textSecondary)
                Text("Rest")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
            }
            Spacer(minLength: 0)
            Text("Tap a day to plan")
                .font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textTertiary)
        }
    }

    private func dayNumberColor(isToday: Bool, isPast: Bool) -> Color {
        if isToday { return Color.unbound.bg }
        if isPast { return Color.unbound.textTertiary }
        return Color.unbound.textPrimary
    }

    private func accessibilityLabel(for date: Date, marker: ProgramMonthPlanMarker?) -> String {
        let day = accessibilityDayTitle(date)
        guard let marker else { return "\(day), no plan. Tap to plan." }
        return marker.isRest ? "\(day), rest day" : "\(day), \(marker.title) planned"
    }

    private var monthSummary: String {
        let monthMarkers = planMarkers.filter {
            calendar.isDate($0.key, equalTo: visibleMonth, toGranularity: .month)
        }
        let workouts = monthMarkers.values.filter { !$0.isRest }.count
        let rests = monthMarkers.values.filter { $0.isRest }.count
        if workouts == 0 && rests == 0 { return "Nothing planned yet" }
        var parts: [String] = []
        if workouts > 0 { parts.append("\(workouts) workout\(workouts == 1 ? "" : "s")") }
        if rests > 0 { parts.append("\(rests) rest") }
        return parts.joined(separator: " · ")
    }

    private var dayColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    }

    private var monthCells: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: visibleMonth),
              let dayRange = calendar.range(of: .day, in: .month, for: visibleMonth)
        else { return [] }

        let firstWeekday = (calendar.component(.weekday, from: monthInterval.start) + 5) % 7
        var cells: [Date?] = Array(repeating: nil, count: firstWeekday)
        for day in dayRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start) {
                cells.append(calendar.startOfDay(for: date))
            }
        }
        while cells.count % 7 != 0 {
            cells.append(nil)
        }
        return cells
    }

    private func shiftMonth(_ value: Int) {
        UnboundHaptics.soft()
        visibleMonth = calendar.date(byAdding: .month, value: value, to: visibleMonth) ?? visibleMonth
    }

    private func monthButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color.unbound.surfaceElevated))
                .overlay(Circle().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func monthTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func accessibilityDayTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private static func indexedMarkers(
        from occurrences: [ProgramScheduleOccurrence],
        calendar: Calendar
    ) -> [Date: ProgramMonthPlanMarker] {
        occurrences.reduce(into: [:]) { result, occurrence in
            result[calendar.startOfDay(for: occurrence.date)] = ProgramMonthPlanMarker(
                title: occurrence.displayTitle,
                kind: occurrence.kind
            )
        }
    }
}

private struct ProgramMonthWorkoutPickerView: View {
    let date: Date
    let workouts: [SavedWorkout]
    let planMarker: ProgramMonthPlanMarker?
    let onSelect: (SavedWorkout) -> Void
    let onMarkRest: () -> Void
    let onClearPlan: () -> Void
    let onCreateWorkout: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.unbound.bg.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        pickerHeader
                        quickActions

                        if workouts.isEmpty {
                            emptyState
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(workouts.enumerated()), id: \.element.id) { index, workout in
                                    workoutRow(workout)
                                    if index < workouts.count - 1 {
                                        Divider()
                                            .padding(.leading, 46)
                                            .overlay(Color.unbound.borderSubtle.opacity(0.52))
                                    }
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.unbound.surface.opacity(0.82))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Color.unbound.borderSubtle.opacity(0.82), lineWidth: 1)
                            )
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(dayTitle(date))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.unbound.textSecondary)
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
    }

    private var pickerHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: headerIcon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(headerTint)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(headerTint.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(planMarker?.title ?? "Choose Workout")
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                Text(planMarker?.isRest == true ? "Recovery day" : "\(workouts.count) saved")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }

    private var quickActions: some View {
        VStack(spacing: 0) {
            actionRow(
                title: "Rest Day",
                subtitle: "No workout",
                icon: "moon.fill",
                tint: Color.unbound.textSecondary,
                action: onMarkRest
            )

            if planMarker != nil {
                Divider()
                    .padding(.leading, 46)
                    .overlay(Color.unbound.borderSubtle.opacity(0.52))

                actionRow(
                    title: "Use Block Plan",
                    subtitle: "Clear override",
                    icon: "arrow.counterclockwise",
                    tint: Color.unbound.coachCyan,
                    action: onClearPlan
                )
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.unbound.surface.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle.opacity(0.82), lineWidth: 1)
        )
    }

    private var headerIcon: String {
        if planMarker?.isRest == true { return "moon.fill" }
        return planMarker == nil ? "calendar.badge.plus" : "calendar.badge.checkmark"
    }

    private var headerTint: Color {
        if planMarker?.isRest == true { return Color.unbound.textSecondary }
        return planMarker == nil ? Color.unbound.coachCyan : Color.unbound.accent
    }

    private var emptyState: some View {
        Button(action: onCreateWorkout) {
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.unbound.bg)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.unbound.accent))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Build Workout")
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text("Create once, then place it here.")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.unbound.accent.opacity(0.34), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func workoutRow(_ workout: SavedWorkout) -> some View {
        Button {
            onSelect(workout)
        } label: {
            HStack(spacing: 12) {
                WorkoutReferenceImageView(
                    exerciseName: workout.effectiveReferenceExerciseName,
                    fallbackSystemName: icon(for: workout),
                    fallbackTint: tint(for: workout)
                )
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text(workout.title.isEmpty ? "Workout" : workout.title)
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                    Text("\(roleText(workout)) / \(workout.exerciseCount) moves / ~\(workout.estimatedMinutes)m")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer(minLength: 0)

                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.unbound.accent)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func actionRow(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(tint.opacity(0.12)))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func dayTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }

    private func roleText(_ workout: SavedWorkout) -> String {
        SessionRole.fromStorageValue(workout.sessionRole)?.displayName ?? "Custom"
    }

    private func tint(for workout: SavedWorkout) -> Color {
        switch SavedWorkout.normalizedSessionRole(workout.sessionRole) {
        case "push", "upper": return Color.unbound.accent
        case "pull": return Color.unbound.coachCyan
        case "legs", "lower": return Color.unbound.success
        case "full-body", "full_body": return Color.unbound.warnOrange
        case "skill-only", "skill_only": return Color.unbound.success
        default: return Color.unbound.textSecondary
        }
    }

    private func icon(for workout: SavedWorkout) -> String {
        switch SavedWorkout.normalizedSessionRole(workout.sessionRole) {
        case "push", "upper": return "figure.strengthtraining.traditional"
        case "pull": return "figure.pull"
        case "legs", "lower": return "figure.run"
        case "full-body", "full_body": return "figure.mixed.cardio"
        case "skill-only", "skill_only": return "sparkles"
        case "cardio": return "heart.fill"
        default: return "dumbbell.fill"
        }
    }
}
