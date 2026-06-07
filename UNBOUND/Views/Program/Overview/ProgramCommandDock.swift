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
    let onExercises: () -> Void
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
                title: "Exercises",
                systemName: "list.bullet.rectangle",
                tint: Color.unbound.accent,
                action: onExercises
            )
            .accessibilityIdentifier("program.exerciseStarter.open")

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
                Image(systemName: icon(for: workout))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(tint(for: workout))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(tint(for: workout).opacity(0.12)))

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
                    Image(systemName: icon(for: workout))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.unbound.bg)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(tint(for: workout)))
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

struct ProgramMonthPlannerView: View {
    let workouts: [SavedWorkout]
    let initialDate: Date
    let occurrences: [ProgramScheduleOccurrence]
    let onPlace: (SavedWorkout, Date) -> Void
    let onCreateWorkout: () -> Void
    let onDismiss: () -> Void

    @State private var visibleMonth: Date
    @State private var selectedWorkoutId: UUID?
    @State private var placedTitles: [Date: String]

    private let calendar: Calendar

    init(
        workouts: [SavedWorkout],
        initialDate: Date,
        occurrences: [ProgramScheduleOccurrence],
        calendar: Calendar = .current,
        onPlace: @escaping (SavedWorkout, Date) -> Void,
        onCreateWorkout: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.workouts = workouts
        self.initialDate = initialDate
        self.occurrences = occurrences
        self.calendar = calendar
        self.onPlace = onPlace
        self.onCreateWorkout = onCreateWorkout
        self.onDismiss = onDismiss

        let month = calendar.dateInterval(of: .month, for: initialDate)?.start
            ?? calendar.startOfDay(for: initialDate)
        _visibleMonth = State(initialValue: month)
        _selectedWorkoutId = State(initialValue: workouts.first?.id)
        _placedTitles = State(initialValue: Self.indexedTitles(from: occurrences, calendar: calendar))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.unbound.bg.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 14) {
                    header
                    workoutPicker
                    calendarGrid
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
        }
    }

    private var selectedWorkout: SavedWorkout? {
        guard let selectedWorkoutId else { return workouts.first }
        return workouts.first { $0.id == selectedWorkoutId } ?? workouts.first
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("MONTH PLAN")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.coachCyan)
                Text(monthTitle(visibleMonth))
                    .font(Font.unbound.titleM)
                    .foregroundStyle(Color.unbound.textPrimary)
            }

            Spacer(minLength: 0)

            monthButton(systemName: "chevron.left") { shiftMonth(-1) }
            monthButton(systemName: "chevron.right") { shiftMonth(1) }
        }
    }

    @ViewBuilder
    private var workoutPicker: some View {
        if workouts.isEmpty {
            Button(action: onCreateWorkout) {
                HStack(spacing: 12) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Color.unbound.accent))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("BUILD A WORKOUT")
                            .font(Font.unbound.captionS.weight(.heavy))
                            .tracking(1.0)
                            .foregroundStyle(Color.unbound.textPrimary)
                        Text("Saved workouts appear here for planning.")
                            .font(Font.unbound.captionS)
                            .foregroundStyle(Color.unbound.textSecondary)
                    }
                    Spacer()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.unbound.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.unbound.accent.opacity(0.34), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(workouts) { workout in
                        workoutChip(workout)
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }

    private var calendarGrid: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { label in
                    Text(label)
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(0.7)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: dayColumns, spacing: 8) {
                ForEach(monthCells.indices, id: \.self) { index in
                    if let date = monthCells[index] {
                        dayCell(date)
                    } else {
                        Color.clear.frame(height: 74)
                    }
                }
            }
        }
    }

    private func workoutChip(_ workout: SavedWorkout) -> some View {
        let isSelected = selectedWorkout?.id == workout.id
        return Button {
            UnboundHaptics.soft()
            selectedWorkoutId = workout.id
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.title.isEmpty ? "Workout" : workout.title)
                    .font(Font.unbound.bodyS.weight(.heavy))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text("\(workout.exerciseCount) moves / ~\(workout.estimatedMinutes)m")
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(Color.unbound.textTertiary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .frame(width: 152, height: 54, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.unbound.accent.opacity(0.18) : Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.unbound.accent.opacity(0.52) : Color.unbound.borderSubtle,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func dayCell(_ date: Date) -> some View {
        let normalized = calendar.startOfDay(for: date)
        let title = placedTitles[normalized]
        let isToday = calendar.isDateInToday(date)
        let isInitial = calendar.isDate(date, inSameDayAs: initialDate)

        return Button {
            guard let workout = selectedWorkout else { return }
            UnboundHaptics.medium()
            onPlace(workout, normalized)
            placedTitles[normalized] = workout.title
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("\(calendar.component(.day, from: date))")
                        .font(Font.unbound.monoS.weight(.heavy))
                        .foregroundStyle(Color.unbound.textPrimary)
                    Spacer()
                    if isToday {
                        Circle()
                            .fill(Color.unbound.coachCyan)
                            .frame(width: 6, height: 6)
                    }
                }

                Spacer(minLength: 0)

                if let title {
                    Text(title.uppercased())
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(0.5)
                        .foregroundStyle(Color.unbound.accent)
                        .lineLimit(2)
                        .minimumScaleFactor(0.62)
                } else {
                    Text("OPEN")
                        .font(Font.unbound.captionS.weight(.bold))
                        .tracking(0.7)
                        .foregroundStyle(Color.unbound.textTertiary.opacity(0.72))
                }
            }
            .padding(9)
            .frame(maxWidth: .infinity, minHeight: 74, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(title == nil ? Color.unbound.surface.opacity(0.72) : Color.unbound.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        title == nil
                            ? (isInitial ? Color.unbound.coachCyan.opacity(0.32) : Color.unbound.borderSubtle)
                            : Color.unbound.accent.opacity(0.34),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(selectedWorkout == nil)
    }

    private var dayColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
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

    private static func indexedTitles(
        from occurrences: [ProgramScheduleOccurrence],
        calendar: Calendar
    ) -> [Date: String] {
        occurrences.reduce(into: [:]) { result, occurrence in
            result[calendar.startOfDay(for: occurrence.date)] = occurrence.displayTitle
        }
    }
}
