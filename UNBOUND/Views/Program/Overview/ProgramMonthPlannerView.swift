import SwiftUI

/// What one calendar day shows in the Plan sheet: the resolved program day
/// (generated split + user overrides + travel), collapsed to a paintable cell.
struct ProgramPlannerDayInfo {
    let label: String?
    let accent: Color
    let isRest: Bool
    let isPlannedByUser: Bool
    let isCompleted: Bool
}

/// Optimistic marker for a day the user just planned inside this sheet —
/// only consulted when `dayInfo` can't resolve the date (no active program).
private struct ProgramMonthPlanMarker: Hashable {
    let title: String
    let kind: ProgramScheduleOccurrenceKind

    var isRest: Bool { kind == .rest }
}

/// The Plan calendar: a month where every day wears its resolved session —
/// the generated split, your placed loadouts, rest days, and completions —
/// so the whole training rhythm reads without tapping a single cell.
struct ProgramMonthPlannerView: View {
    private struct DaySelection: Identifiable {
        let date: Date

        var id: TimeInterval { date.timeIntervalSinceReferenceDate }
    }

    let workouts: [SavedWorkout]
    let initialDate: Date
    let occurrences: [ProgramScheduleOccurrence]
    let splitSummary: String?
    let dayInfo: (Date) -> ProgramPlannerDayInfo?
    let onPlace: (SavedWorkout, Date) -> Void
    let onMarkRest: (Date) -> Void
    let onClearPlan: (Date) -> Void
    let onCreateWorkout: () -> Void
    let onDismiss: () -> Void

    @State private var visibleMonth: Date
    @State private var planMarkers: [Date: ProgramMonthPlanMarker]
    @State private var activeDaySelection: DaySelection?

    private let calendar: Calendar
    private let dayCellHeight: CGFloat = 58
    private let weekdaySymbols = ["M", "T", "W", "T", "F", "S", "S"]

    init(
        workouts: [SavedWorkout],
        initialDate: Date,
        occurrences: [ProgramScheduleOccurrence],
        splitSummary: String? = nil,
        dayInfo: @escaping (Date) -> ProgramPlannerDayInfo? = { _ in nil },
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
        self.splitSummary = splitSummary
        self.dayInfo = dayInfo
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
                    plannerLegend
                    Spacer(minLength: 0)
                }
                .padding(20)
            }
            .navigationTitle("Plan")
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
                    plannedTitle: plannedTitle(for: selection.date),
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
                Text(splitSummary ?? monthSummary)
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

    /// The live cell content: the resolver-backed `dayInfo` wins (it already
    /// merges generated days, user placements, and travel); the optimistic
    /// local marker only paints dates the resolver can't (no program).
    private func resolvedInfo(for date: Date) -> ProgramPlannerDayInfo? {
        if let info = dayInfo(date) { return info }
        guard let marker = planMarkers[date] else { return nil }
        if marker.isRest {
            return ProgramPlannerDayInfo(
                label: nil,
                accent: Color.unbound.textSecondary,
                isRest: true,
                isPlannedByUser: true,
                isCompleted: false
            )
        }
        return ProgramPlannerDayInfo(
            label: String(marker.title.prefix(6)).uppercased(),
            accent: Color.unbound.accent,
            isRest: false,
            isPlannedByUser: true,
            isCompleted: false
        )
    }

    /// Title shown in the day picker header — only for days the USER planned;
    /// a generated split day still reads "Choose Loadout" and offers no
    /// "clear override" action.
    private func plannedTitle(for date: Date) -> String? {
        let normalized = calendar.startOfDay(for: date)
        if let marker = planMarkers[normalized] { return marker.title }
        guard let info = resolvedInfo(for: normalized), info.isPlannedByUser else { return nil }
        if info.isRest { return "Rest" }
        return info.label.map { $0.capitalized }
    }

    private func dayCell(_ date: Date) -> some View {
        let normalized = calendar.startOfDay(for: date)
        let info = resolvedInfo(for: normalized)
        let isToday = calendar.isDateInToday(date)
        let isSelected = calendar.isDate(date, inSameDayAs: initialDate)
        let isPast = normalized < calendar.startOfDay(for: Date())

        return Button {
            UnboundHaptics.medium()
            activeDaySelection = DaySelection(date: normalized)
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    if isToday {
                        Circle()
                            .fill(Color.unbound.accent)
                            .frame(width: 30, height: 30)
                    } else if isSelected {
                        Circle()
                            .strokeBorder(Color.unbound.accent.opacity(0.55), lineWidth: 1.5)
                            .frame(width: 30, height: 30)
                    }
                    Text("\(calendar.component(.day, from: date))")
                        .font(Font.unbound.monoS.weight(.bold))
                        .foregroundStyle(dayNumberColor(isToday: isToday, isPast: isPast))
                }
                .frame(height: 30)

                dayStatusLine(info, isPast: isPast)
            }
            .frame(maxWidth: .infinity, minHeight: dayCellHeight)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(info?.isPlannedByUser == true ? Color.unbound.surface : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(plannedBorderColor(info), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isPast && info == nil ? 0.5 : 1)
        .accessibilityLabel(accessibilityLabel(for: date, info: info))
    }

    /// Border for a user-planned cell. Rest days keep the moon's neutral
    /// tone — the rest role's green accent would read as "completed" here.
    private func plannedBorderColor(_ info: ProgramPlannerDayInfo?) -> Color {
        guard let info, info.isPlannedByUser else { return .clear }
        return (info.isRest ? Color.unbound.textSecondary : info.accent).opacity(0.45)
    }

    /// The second line of a cell: ✓ for a completed day, a moon for rest,
    /// the split tag (PUSH / PULL / LEGS …) for a planned training day.
    @ViewBuilder
    private func dayStatusLine(_ info: ProgramPlannerDayInfo?, isPast: Bool) -> some View {
        if let info {
            if info.isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(Color.unbound.success)
                    .frame(height: 12)
            } else if info.isRest {
                Image(systemName: "moon.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.unbound.textSecondary.opacity(isPast ? 0.5 : 1))
                    .frame(height: 12)
            } else if let label = info.label {
                Text(label)
                    .font(.system(size: 8, weight: .heavy))
                    .tracking(0.5)
                    .foregroundStyle(info.accent.opacity(isPast ? 0.45 : 1))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(height: 12)
            } else {
                Color.clear.frame(height: 12)
            }
        } else {
            Color.clear.frame(height: 12)
        }
    }

    private var plannerLegend: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.unbound.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .strokeBorder(Color.unbound.accent.opacity(0.45), lineWidth: 1)
                    )
                    .frame(width: 12, height: 12)
                Text("Planned by you")
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

    private func accessibilityLabel(for date: Date, info: ProgramPlannerDayInfo?) -> String {
        let day = accessibilityDayTitle(date)
        guard let info else { return "\(day), no plan. Tap to plan." }
        if info.isCompleted { return "\(day), completed" }
        if info.isRest { return "\(day), rest day" }
        let planned = info.isPlannedByUser ? ", planned by you" : ""
        return "\(day), \(info.label?.capitalized ?? "training") day\(planned)"
    }

    private var monthSummary: String {
        let monthMarkers = planMarkers.filter {
            calendar.isDate($0.key, equalTo: visibleMonth, toGranularity: .month)
        }
        let workouts = monthMarkers.values.filter { !$0.isRest }.count
        let rests = monthMarkers.values.filter { $0.isRest }.count
        if workouts == 0 && rests == 0 { return "Nothing planned yet" }
        var parts: [String] = []
        if workouts > 0 { parts.append("\(workouts) loadout\(workouts == 1 ? "" : "s")") }
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
    let plannedTitle: String?
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

    private var isRestPlanned: Bool {
        plannedTitle?.lowercased() == "rest"
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
                Text(plannedTitle ?? "Choose Loadout")
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                Text(isRestPlanned ? "Recovery day" : "\(workouts.count) saved")
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
                subtitle: "No loadout",
                icon: "moon.fill",
                tint: Color.unbound.textSecondary,
                action: onMarkRest
            )

            if plannedTitle != nil {
                Divider()
                    .padding(.leading, 46)
                    .overlay(Color.unbound.borderSubtle.opacity(0.52))

                actionRow(
                    title: "Use Arc Plan",
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
        if isRestPlanned { return "moon.fill" }
        return plannedTitle == nil ? "calendar.badge.plus" : "calendar.badge.checkmark"
    }

    private var headerTint: Color {
        if isRestPlanned { return Color.unbound.textSecondary }
        return plannedTitle == nil ? Color.unbound.coachCyan : Color.unbound.accent
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
                    Text("Build Loadout")
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
                    Text(workout.title.isEmpty ? "Loadout" : workout.title)
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
        SessionRole.fromStorageValue(workout.sessionRole)?.accentColor
            ?? Color.unbound.textSecondary
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
