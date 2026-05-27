import SwiftUI

// MARK: - CoachActionsRow
//
// Structured action chips for program adjustments.
// Each chip opens a tight, purpose-built flow that
// feeds `CoachActionExecutor` (or sets a session flag for SHORT).
//
//   DELOAD — confirm, executor applies a planned deload
//   TRAVEL — deterministic bodyweight travel plan based on duration
//   SHORT  — today's session gets trimmed to compound lifts only
//
// Exercise swaps live in SessionEditorView so the main Program surface does
// not expose two competing edit entry points.

struct CoachActionsRow: View {
    let program: TrainingProgram?
    let todayDay: ProgramDay?
    @EnvironmentObject var services: ServiceContainer

    @State private var sheet: Sheet?

    enum Sheet: Identifiable {
        case deload
        case travel
        case shortSession

        var id: String {
            switch self {
            case .deload:       return "deload"
            case .travel:       return "travel"
            case .shortSession: return "short"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.unbound.accent)
                Text("PLAN ADJUSTMENTS")
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.textTertiary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip(
                        title: "DELOAD",
                        subtitle: "next week",
                        icon: "arrow.down.circle",
                        tint: Color.unbound.accent,
                        action: { sheet = .deload }
                    )
                    chip(
                        title: "TRAVEL",
                        subtitle: "adjust plan",
                        icon: "airplane",
                        tint: Color.unbound.accent,
                        action: { sheet = .travel }
                    )
                    chip(
                        title: "SHORT",
                        subtitle: "~30 min",
                        icon: "timer",
                        tint: Color.unbound.coachCyan,
                        action: { sheet = .shortSession }
                    )
                }
            }
        }
        .sheet(item: $sheet) { kind in
            switch kind {
            case .deload:
                DeloadConfirmSheet(services: services) { sheet = nil }
            case .travel:
                TravelAdjustSheet(program: program, services: services) { sheet = nil }
            case .shortSession:
                ShortSessionConfirmSheet(todayDay: todayDay) { sheet = nil }
            }
        }
    }

    private func chip(
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
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(tint)
                    Text(title)
                        .font(Font.unbound.captionS.weight(.bold))
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textPrimary)
                }
                Text(subtitle.uppercased())
                    .font(.system(size: 9, weight: .medium))
                    .tracking(1.0)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(tint.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func unavailableSheet(title: String, subtitle: String) -> some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 26))
                    .foregroundStyle(Color.unbound.textTertiary)
                Text(title)
                    .font(Font.unbound.titleS)
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text(subtitle)
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Swap Exercise Picker Sheet
//
// Step 1: user picks WHICH exercise in today's session to swap.
// Step 2: hands off to the existing `ExerciseSwapSheet` with alternatives.

private struct SwapExercisePickerSheet: View {
    let day: ProgramDay
    let services: ServiceContainer
    let onDismiss: () -> Void

    @State private var picked: Exercise?
    @State private var alternatives: [CatalogExercise] = []
    @State private var preferences: [ExercisePreference] = []

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                header

                if let workout = day.workout {
                    if let target = picked {
                        ExerciseSwapSheet(
                            currentExerciseName: target.name,
                            alternatives: alternatives,
                            onSelect: { alt in
                                Task { await applySwap(from: target.name, to: alt.name) }
                            },
                            onCreateCustom: {
                                // Custom exercise creation is handled elsewhere;
                                // dismiss and let the user navigate there.
                                onDismiss()
                            }
                        )
                    } else {
                        exerciseList(workout: workout)
                    }
                } else {
                    Spacer()
                    Text("No workout scheduled today.")
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textSecondary)
                    Spacer()
                }
            }
            .padding(20)
        }
        .task {
            if let userId = services.auth.currentUserId {
                preferences = (try? await services.exercisePreference.fetchPreferences(userId: userId)) ?? []
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("SWAP EXERCISE")
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.8)
                    .foregroundStyle(Color.unbound.accent)
                Text(picked == nil ? "Pick what to swap" : "Pick a replacement")
                    .font(Font.unbound.titleS)
                    .tracking(0.4)
                    .foregroundStyle(Color.unbound.textPrimary)
            }
            Spacer()
            Button("Done", action: onDismiss)
                .foregroundStyle(Color.unbound.textSecondary)
        }
    }

    private func exerciseList(workout: Workout) -> some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(Array(workout.mainExercises.enumerated()), id: \.offset) { _, ex in
                    Button {
                        UnboundHaptics.soft()
                        picked = ex
                        alternatives = alternativesFor(name: ex.name)
                    } label: {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ex.name.uppercased())
                                    .font(Font.unbound.bodyMStrong)
                                    .tracking(0.4)
                                    .foregroundStyle(Color.unbound.textPrimary)
                                Text("\(ex.sets) × \(ex.reps)")
                                    .font(Font.unbound.monoS)
                                    .foregroundStyle(Color.unbound.textTertiary)
                            }
                            Spacer()
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.unbound.accent)
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
            }
        }
    }

    private func alternativesFor(name: String) -> [CatalogExercise] {
        // Return movement-catalog substitutions in the same slot, filtered
        // by any AVOID preferences the user has set.
        guard MovementCatalog.canonicalExercise(named: name) != nil else { return [] }
        let avoided = Set(preferences.filter { $0.status == .avoid }.map(\.exerciseName))
        return MovementCatalog.catalogAlternatives(to: name)
            .filter { !avoided.contains($0.name) }
    }

    @MainActor
    private func applySwap(from: String, to: String) async {
        let userId = services.auth.currentUserId ?? "anonymous"
        let action = CoachAction.swapExercise(
            from: from,
            to: to,
            scope: .session
        )
        try? await CoachActionExecutor.shared.apply(action, userId: userId)
        UnboundHaptics.success()
        onDismiss()
    }
}

// MARK: - Deload Confirm Sheet

private struct DeloadConfirmSheet: View {
    let services: ServiceContainer
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("DELOAD")
                        .font(Font.unbound.captionS.weight(.bold))
                        .tracking(1.8)
                        .foregroundStyle(Color.unbound.accent)
                    Spacer()
                    Button("Cancel", action: onDismiss)
                        .foregroundStyle(Color.unbound.textSecondary)
                }

                Text("Take a recovery week?")
                    .font(Font.unbound.titleL)
                    .tracking(0.3)
                    .foregroundStyle(Color.unbound.textPrimary)

                Text("Your next block's loads drop ~10% and volume drops a set per lift. Rank progression pauses. Rebuild momentum for the following block.")
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                Button {
                    UnboundHaptics.medium()
                    Task { await applyDeload() }
                } label: {
                    HStack(spacing: 10) {
                        Text("APPLY DELOAD")
                            .font(Font.unbound.bodyMStrong)
                            .tracking(1.6)
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(Color.unbound.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.unbound.accent)
                    )
                    .shadow(color: Color.unbound.accent.opacity(0.45), radius: 14, y: 2)
                }
                .buttonStyle(.plain)
            }
            .padding(24)
        }
        .presentationDetents([.medium])
    }

    @MainActor
    private func applyDeload() async {
        let userId = services.auth.currentUserId ?? "anonymous"
        let action = CoachAction.insertDeload(week: 1)
        try? await CoachActionExecutor.shared.apply(action, userId: userId)
        UnboundHaptics.success()
        onDismiss()
    }
}

// MARK: - Travel Adjust Sheet

private struct TravelAdjustSheet: View {
    let program: TrainingProgram?
    let services: ServiceContainer
    let onDismiss: () -> Void

    @State private var days: Int = 7
    @State private var equipment: Set<TravelEquipment> = [.bodyweight]
    @State private var generating = false
    @State private var generatedPlan: TravelPlan?
    @State private var errorMsg: String?

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("TRAVEL ADJUST")
                        .font(Font.unbound.captionS.weight(.bold))
                        .tracking(1.8)
                        .foregroundStyle(Color.unbound.accent)
                    Spacer()
                    Button("Cancel", action: onDismiss)
                        .foregroundStyle(Color.unbound.textSecondary)
                }

                if let plan = generatedPlan {
                    planPreview(plan)
                } else {
                    inputForm
                }
            }
            .padding(20)
        }
        .presentationDetents([.large])
    }

    private var inputForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Generate a minimal-equipment plan while you're away.")
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Text("DURATION")
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)
                HStack(spacing: 8) {
                    ForEach([3, 5, 7, 10, 14], id: \.self) { d in
                        dayChip(d)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("EQUIPMENT ACCESS")
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)
                VStack(spacing: 6) {
                    ForEach(TravelEquipment.allCases) { eq in
                        equipmentToggle(eq)
                    }
                }
            }

            if let errorMsg {
                Text(errorMsg)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.alert)
            }

            Spacer()

            Button {
                UnboundHaptics.medium()
                Task { await generate() }
            } label: {
                HStack(spacing: 10) {
                    if generating {
                        ProgressView().tint(Color.unbound.textPrimary)
                    } else {
                        Text("GENERATE PLAN")
                            .font(Font.unbound.bodyMStrong)
                            .tracking(1.6)
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .bold))
                    }
                }
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.unbound.accent)
                )
                .shadow(color: Color.unbound.accent.opacity(0.45), radius: 14, y: 2)
            }
            .buttonStyle(.plain)
            .disabled(generating || equipment.isEmpty)
        }
    }

    private func dayChip(_ d: Int) -> some View {
        Button {
            UnboundHaptics.soft()
            days = d
        } label: {
            Text("\(d)d")
                .font(Font.unbound.monoS.weight(.semibold))
                .foregroundStyle(days == d ? Color.unbound.textPrimary : Color.unbound.textTertiary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(days == d ? Color.unbound.accent.opacity(0.3) : Color.unbound.surface)
                )
                .overlay(
                    Capsule().strokeBorder(
                        days == d ? Color.unbound.accent : Color.unbound.borderSubtle,
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
    }

    private func equipmentToggle(_ eq: TravelEquipment) -> some View {
        let isOn = equipment.contains(eq)
        return Button {
            UnboundHaptics.soft()
            if isOn { equipment.remove(eq) } else { equipment.insert(eq) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isOn ? Color.unbound.accent : Color.unbound.textTertiary)
                Text(eq.displayName)
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textPrimary)
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.unbound.surface)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func planPreview(_ plan: TravelPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(plan.summary)
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(plan.days.enumerated()), id: \.offset) { idx, day in
                        travelDayRow(index: idx + 1, day: day)
                    }
                }
            }

            Button {
                UnboundHaptics.success()
                Task { await persistPlan(plan) }
            } label: {
                Text("ACCEPT PLAN")
                    .font(Font.unbound.bodyMStrong)
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.unbound.accent)
                    )
                    .shadow(color: Color.unbound.accent.opacity(0.45), radius: 14, y: 2)
            }
            .buttonStyle(.plain)
        }
    }

    private func travelDayRow(index: Int, day: TravelPlanDay) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("DAY \(index)")
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.accent)
                Spacer()
                Text(day.duration.uppercased())
                    .font(Font.unbound.monoS)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            Text(day.title.uppercased())
                .font(Font.unbound.bodyMStrong)
                .tracking(0.4)
                .foregroundStyle(Color.unbound.textPrimary)
            if !day.exercises.isEmpty {
                Text(day.exercises.joined(separator: "  ·  "))
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.unbound.surface)
        )
    }

    @MainActor
    private func persistPlan(_ plan: TravelPlan) async {
        let userId = services.auth.currentUserId ?? "anonymous"
        let startDate = Calendar.current.startOfDay(for: Date())
        guard let endDate = Calendar.current.date(byAdding: .day, value: max(0, days - 1), to: startDate) else {
            onDismiss()
            return
        }
        let overrideDays = plan.days.enumerated().map { idx, d in
            TravelDay(
                dayOffset: idx,
                title: d.title,
                duration: d.duration,
                exercises: d.exercises,
                isRest: d.title.lowercased().contains("rest") || d.exercises.isEmpty
            )
        }
        let override = TravelOverride(
            userId: userId,
            startDate: startDate,
            endDate: endDate,
            summary: plan.summary,
            days: overrideDays
        )
        await TravelOverrideStore.shared.save(override)
        onDismiss()
    }

    @MainActor
    private func generate() async {
        generating = true
        defer { generating = false }
        errorMsg = nil

        generatedPlan = deterministicTravelPlan(days: days, equipment: equipment)
    }

    private func deterministicTravelPlan(days: Int, equipment: Set<TravelEquipment>) -> TravelPlan {
        let selected = equipment.isEmpty ? Set([TravelEquipment.bodyweight]) : equipment
        let templates = travelTemplates(equipment: selected)
        let planDays = (0..<max(1, days)).map { index -> TravelPlanDay in
            if (index + 1).isMultiple(of: 4) {
                return TravelPlanDay(
                    title: "REST / WALK",
                    duration: "REST",
                    exercises: ["Walk 20 minutes", "Couch Stretch", "Thread the Needle"]
                )
            }
            return templates[index % templates.count]
        }
        let equipmentLabel = selected.map(\.displayName).sorted().joined(separator: " + ")
        return TravelPlan(
            summary: "\(days)-day travel block loaded for \(equipmentLabel). Normal arc resumes when the window ends.",
            days: planDays
        )
    }

    private func travelTemplates(equipment: Set<TravelEquipment>) -> [TravelPlanDay] {
        let pull = pullSlot(equipment: equipment)
        let hinge = equipment.contains(.dumbbells) || equipment.contains(.hotelGym)
            ? "Dumbbell Romanian Deadlift"
            : "Single-Leg Glute Bridge"
        return [
            TravelPlanDay(
                title: "PUSH",
                duration: "~30 MIN",
                exercises: ["Push-ups", "Pike Push-ups", "Chair Dips", "Plank Shoulder Taps"]
            ),
            TravelPlanDay(
                title: "LOWER",
                duration: "~35 MIN",
                exercises: ["Split Squats", "Reverse Lunges", hinge, "Wall Sit"]
            ),
            TravelPlanDay(
                title: "FULL BODY",
                duration: "~30 MIN",
                exercises: ["Tempo Squats", "Push-ups", pull, "Mountain Climbers", "Side Plank"]
            )
        ]
    }

    private func pullSlot(equipment: Set<TravelEquipment>) -> String {
        if equipment.contains(.hotelGym) { return "Lat Pulldown" }
        if equipment.contains(.dumbbells) { return "One-Arm Dumbbell Row" }
        if equipment.contains(.resistanceBands) { return "Band Row" }
        return "Prone Swimmers"
    }
}

private enum TravelEquipment: String, Identifiable, CaseIterable {
    case bodyweight
    case dumbbells
    case resistanceBands = "resistance bands"
    case hotelGym = "hotel gym"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .bodyweight:       return "Bodyweight only"
        case .dumbbells:        return "Dumbbells"
        case .resistanceBands:  return "Resistance bands"
        case .hotelGym:         return "Hotel gym"
        }
    }
}

private struct TravelPlan {
    let summary: String
    let days: [TravelPlanDay]
}

private struct TravelPlanDay {
    let title: String
    let duration: String
    let exercises: [String]
}

// MARK: - Short Session Confirm Sheet

private struct ShortSessionConfirmSheet: View {
    let todayDay: ProgramDay?
    let onDismiss: () -> Void

    @AppStorage("unbound.shortSessionDate") private var shortSessionDate: Double = 0

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("SHORT SESSION")
                        .font(Font.unbound.captionS.weight(.bold))
                        .tracking(1.8)
                        .foregroundStyle(Color.unbound.coachCyan)
                    Spacer()
                    Button("Cancel", action: onDismiss)
                        .foregroundStyle(Color.unbound.textSecondary)
                }

                Text("Today's session in ~30 minutes?")
                    .font(Font.unbound.titleL)
                    .tracking(0.3)
                    .foregroundStyle(Color.unbound.textPrimary)

                if let workout = todayDay?.workout {
                    Text("Keep the compounds, cut the accessories. \(workout.mainExercises.prefix(3).map(\.name).joined(separator: ", ")). Rest the rest for tomorrow.")
                        .font(Font.unbound.bodyM)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("No session scheduled today — short mode applies when one exists.")
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textTertiary)
                }

                Spacer()

                Button {
                    UnboundHaptics.medium()
                    shortSessionDate = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
                    onDismiss()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "timer")
                            .font(.system(size: 13, weight: .bold))
                        Text("ACTIVATE SHORT MODE")
                            .font(Font.unbound.bodyMStrong)
                            .tracking(1.6)
                    }
                    .foregroundStyle(Color.unbound.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.unbound.coachCyan)
                    )
                    .shadow(color: Color.unbound.coachCyan.opacity(0.45), radius: 14, y: 2)
                }
                .buttonStyle(.plain)
                .disabled(todayDay?.workout == nil)
            }
            .padding(24)
        }
        .presentationDetents([.medium])
    }
}
