import SwiftUI

// MARK: - WeeklyScheduleEditorSheet (V4)
//
// V4 changes vs V3:
//   1. Drag-to-reorder via SwiftUI `List` + `.onMove`. Day labels stay
//      pinned (Mon-Sun); the user reorders the CATEGORIES, so dragging
//      Pull from Mon to Sun swaps the categories on those rows. Drag
//      handles stay visible via `.environment(\.editMode, .active)`.
//   2. OPTIMIZE SPLIT — deterministic 7-day split from Program Focuses;
//      populates the draft (no auto-save).
//   3. WEEK PHASE picker — chip + bottom sheet (heavy/moderate/light/
//      deload). Persists immediately via setWeekPhase.
//   4. Tap-a-chip per row still works for picking the category.

struct WeeklyScheduleEditorSheet: View {
    @EnvironmentObject var services: ServiceContainer
    @Environment(\.dismiss) private var dismiss
    @Bindable private var skillProgress = SkillProgressService.shared

    /// Local working copy — committed to service on Save.
    @State private var draft: [DayCategory] = []

    /// V4 — deterministic optimize in-flight + error state.
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
            UnboundButton(
                title: isSuggesting ? "OPTIMIZING…" : "OPTIMIZE SPLIT",
                variant: .secondary,
                icon: "wand.and.stars.inverse",
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
                Text("Couldn't optimize. Try again?")
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
        let programFocusIds = skillProgress.programFocusIds
        withAnimation(.easeInOut(duration: 0.15)) {
            isSuggesting = true
            suggestErrorVisible = false
        }
        let suggested = ProgramScheduler.shared.optimizedWeeklySchedule(programFocusIds: programFocusIds)
        if suggested.count == 7 {
            draft = suggested
            UnboundHaptics.medium()
        } else {
            LoggingService.shared.log(
                "optimizedWeeklySchedule returned invalid count",
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
