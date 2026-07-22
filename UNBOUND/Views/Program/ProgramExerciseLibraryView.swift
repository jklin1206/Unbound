import SwiftUI

struct ProgramExerciseLibraryView: View {
    enum Mode {
        case addMulti    // SessionEditor add, ActiveWorkout quick-log add
        case addSingle   // ProgramOverview starter — pick one, dismiss, route onward
        case swap

        var dismissesOnSelect: Bool { self != .addMulti }
        var showsDoneBar: Bool { self == .addMulti }
        var showsTrailingChevron: Bool { self != .addMulti }
    }

    /// The canonical, stable per-exercise key — the same normalization
    /// `preferenceStatusesByKey` is keyed by. Using it for `addedKeys` means a
    /// toggle repaints the one matching row in place instead of reshuffling.
    static func canonicalKey(for exercise: CatalogExercise) -> String {
        ExercisePreferenceLookup.normalizedKey(exercise.name)
    }

    var mode: Mode = .swap
    let currentExerciseName: String
    let alternatives: [CatalogExercise]
    let onRowTap: (CatalogExercise) -> Void
    var recentExerciseNames: Set<String> = []
    var preferenceStatusesByKey: [String: ExercisePreferenceStatus] = [:]
    var availableEquipment: [Equipment]? = nil
    var onCreateCustom: (() -> Void)? = nil
    /// Rendering only — which rows the shell has toggled on in `.addMulti`.
    /// Must never influence search, ranking, or filtering (see
    /// `ExerciseLibrarySearch`), or a tap would reshuffle the list under itself.
    var addedKeys: Set<String> = []

    @State private var searchText = ""
    @State private var selectedMuscle: MuscleGroup?
    @State private var contextFilter: ExerciseLibraryContextFilter = .best
    @FocusState private var searchIsFocused: Bool

    private var filteredResults: [ExerciseLibrarySearchResult] {
        ExerciseLibrarySearch.filteredResults(
            alternatives,
            searchText: searchText,
            selectedMuscle: selectedMuscle,
            contextFilter: contextFilter,
            recentExerciseNames: recentExerciseNames,
            preferenceStatusesByKey: preferenceStatusesByKey,
            availableEquipment: availableEquipment
        )
    }

    /// Filter by body part, not by movement pattern. "Horizontal Push" is how the
    /// program generator thinks; "Chest" is how the person holding the phone at
    /// the rack thinks.
    private var availableMuscles: [MuscleGroup] {
        ExerciseLibrarySearch.availableMuscleGroups(in: alternatives)
    }

    /// Optional context chips — shown only when they'd match something.
    /// There is no "Best" chip: with no filter active, the list is already
    /// ranked by fit, and labeling that state "Best" read as a claim about
    /// every row. Tapping a selected chip deselects it.
    private var availableContextFilters: [ExerciseLibraryContextFilter] {
        ExerciseLibraryContextFilter.allCases.filter { filter in
            switch filter {
            case .best, .available:
                return false
            case .recent:
                return alternatives.contains {
                    ExerciseLibrarySearch.signals(
                        for: $0,
                        recentExerciseNames: recentExerciseNames,
                        preferenceStatusesByKey: preferenceStatusesByKey
                    ).isRecent
                }
            case .favorites:
                return alternatives.contains {
                    ExerciseLibrarySearch.signals(
                        for: $0,
                        recentExerciseNames: recentExerciseNames,
                        preferenceStatusesByKey: preferenceStatusesByKey
                    ).preferenceStatus == .available
                }
            }
        }
    }

    var body: some View {
        let matches = filteredResults

        return ZStack {
            Color.unbound.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                header(matchCount: matches.count)
                searchAndFilters
                libraryContent(matches: matches)
            }
        }
    }

    /// One compact row — the old icon + headline + subtitle header pushed the
    /// search field halfway down the sheet, and with the keyboard up almost no
    /// results survived. Search now sits directly under this line.
    private func header(matchCount: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: mode != .swap ? "plus" : "arrow.triangle.2.circlepath")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(mode != .swap ? Color.unbound.coachCyan : Color.unbound.accent)

            Text(mode != .swap ? "ADD EXERCISE" : "SWAP")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textTertiary)

            if mode == .swap {
                Text(currentExerciseName)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 8)

            Text("\(matchCount) of \(alternatives.count)")
                .font(Font.unbound.monoS)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    private var searchAndFilters: some View {
        let muscles = availableMuscles
        let filters = availableContextFilters

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
                TextField("Search exercise, muscle, equipment", text: $searchText)
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($searchIsFocused)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.unbound.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.unbound.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
            )

            if !muscles.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterChip(title: "All", isSelected: selectedMuscle == nil && contextFilter == .best) {
                            selectedMuscle = nil
                            contextFilter = .best
                        }
                        ForEach(filters, id: \.self) { filter in
                            filterChip(title: filter.displayName, isSelected: contextFilter == filter) {
                                contextFilter = contextFilter == filter ? .best : filter
                            }
                        }
                        ForEach(muscles, id: \.self) { muscle in
                            filterChip(title: muscle.displayName, isSelected: selectedMuscle == muscle) {
                                selectedMuscle = selectedMuscle == muscle ? nil : muscle
                            }
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private func libraryContent(matches: [ExerciseLibrarySearchResult]) -> some View {
        if alternatives.isEmpty {
            emptyState
            if onCreateCustom != nil {
                createNewRow
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
            }
        } else if matches.isEmpty {
            noSearchResults
            if onCreateCustom != nil {
                createNewRow
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(matches) { result in
                        libraryRow(result)
                    }
                    if onCreateCustom != nil {
                        createNewRow
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            UnboundHaptics.soft()
            withAnimation(.easeInOut(duration: 0.16)) {
                action()
            }
        } label: {
            Text(title.uppercased())
                .font(Font.unbound.captionS.weight(.bold))
                .tracking(1.0)
                .foregroundStyle(isSelected ? Color.unbound.textPrimary : Color.unbound.textSecondary)
                .lineLimit(1)
                .padding(.horizontal, 11)
                .frame(height: 30)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.unbound.accent.opacity(0.22) : Color.unbound.surface)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            isSelected ? Color.unbound.accent.opacity(0.5) : Color.unbound.borderSubtle,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 40)
            Image(systemName: "rectangle.on.rectangle.slash")
                .font(.system(size: 32, weight: .regular))
                .foregroundStyle(Color.unbound.textTertiary)
            Text("No alternatives available")
                .font(Font.unbound.titleS)
                .foregroundStyle(Color.unbound.textPrimary)
            Text("Add more to your available exercise library, or relax your avoid list.")
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    private var noSearchResults: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 34)
            Image(systemName: "magnifyingglass")
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(Color.unbound.textTertiary)
            Text("No matches")
                .font(Font.unbound.titleS)
                .foregroundStyle(Color.unbound.textPrimary)
            Text("Try a body part, exercise name, or equipment — or clear the filter.")
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    private var createNewRow: some View {
        Button {
            UnboundHaptics.medium()
            onCreateCustom?()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.unbound.accent)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.unbound.accent.opacity(0.14)))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Create new")
                        .font(Font.unbound.bodyLStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text("Build a custom exercise")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.unbound.accent.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func libraryRow(_ result: ExerciseLibrarySearchResult) -> some View {
        let alt = result.exercise
        let metadata = result.definition.map { libraryMetadata(for: $0) }
        let signals = result.signals
        let compatibility = result.compatibility
        let isAdded = mode == .addMulti && addedKeys.contains(Self.canonicalKey(for: alt))

        return Button(action: {
            guard compatibility.isSelectable else { return }
            onRowTap(alt)
        }, label: {
            HStack(spacing: 12) {
                libraryRowVisual(result, compatibility: compatibility, isAdded: isAdded)
                VStack(alignment: .leading, spacing: 3) {
                    Text(alt.displayName)
                        .font(Font.unbound.bodyLStrong)
                        .foregroundStyle(compatibility.isSelectable ? Color.unbound.textPrimary : Color.unbound.textTertiary)
                        .lineLimit(1)
                    Text(compatibility.detail.isEmpty ? (metadata ?? alt.muscleGroups.map(\.displayName).joined(separator: " · ")) : compatibility.detail)
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(2)
                    // Only badges that say something this row doesn't already:
                    // Recent / Favorite / Substitute. A "Fits" badge on every
                    // compatible row was noise; incompatibility gets its own
                    // warning line below.
                    if !signals.badges.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(signals.badges.prefix(2), id: \.self) { badge in
                                contextBadge(badge)
                            }
                        }
                        .padding(.top, 2)
                    }
                    if !compatibility.isSelectable {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(compatibilityColor(compatibility))
                            Text(compatibility.title)
                                .font(Font.unbound.captionS.weight(.semibold))
                                .foregroundStyle(compatibilityColor(compatibility))
                        }
                        .padding(.top, 2)
                    }
                }
                Spacer()
                if mode.showsTrailingChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.unbound.textTertiary)
                }
            }
            .padding(13)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isAdded ? Color.unbound.surfaceElevated : (compatibility.isSelectable ? Color.unbound.surface : Color.unbound.surface.opacity(0.72)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(compatibility.isSelectable ? compatibilityColor(compatibility).opacity(0.20) : compatibilityColor(compatibility).opacity(0.42), lineWidth: 1)
            )
        })
        .buttonStyle(.plain)
        .disabled(!compatibility.isSelectable)
        .opacity(compatibility.isSelectable ? 1 : 0.72)
    }

    @ViewBuilder
    private func libraryRowVisual(
        _ result: ExerciseLibrarySearchResult,
        compatibility: ExerciseLibraryCompatibilityState,
        isAdded: Bool
    ) -> some View {
        let tint = compatibility.isSelectable ? compatibilityColor(compatibility) : Color.unbound.textTertiary
        let badgeIcon = isAdded ? "checkmark.circle.fill" : (mode != .swap ? "plus" : "arrow.left.arrow.right")
        let badgeTint = isAdded ? Color.unbound.success : tint
        ZStack(alignment: .bottomTrailing) {
            if let definition = result.definition {
                ExerciseVisualView(definition: definition, size: .thumbnail)
                    .frame(width: 62, height: 62)
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.unbound.surfaceElevated)
                    .frame(width: 62, height: 62)
                    .overlay(
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(tint)
                    )
            }

            Image(systemName: badgeIcon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.unbound.bg)
                .frame(width: 22, height: 22)
                .background(Circle().fill(badgeTint))
                .overlay(Circle().strokeBorder(Color.unbound.bg.opacity(0.78), lineWidth: 1))
                .offset(x: 4, y: 4)
        }
        .accessibilityHidden(true)
    }

    private func contextBadge(_ title: String) -> some View {
        Text(title.uppercased())
            .font(Font.unbound.monoS.weight(.bold))
            .foregroundStyle(badgeColor(title))
            .lineLimit(1)
            .padding(.horizontal, 7)
            .frame(height: 20)
            .background(
                Capsule()
                    .fill(badgeColor(title).opacity(0.12))
            )
            .overlay(
                Capsule()
                    .strokeBorder(badgeColor(title).opacity(0.22), lineWidth: 1)
            )
    }

    private func badgeColor(_ title: String) -> Color {
        switch title {
        case "Favorite":
            return Color.unbound.success
        case "Avoid":
            return Color.unbound.alert
        case "Substitute":
            return Color.unbound.warnOrange
        default:
            return Color.unbound.accent
        }
    }

    private func compatibilityColor(_ state: ExerciseLibraryCompatibilityState) -> Color {
        switch state.level {
        case .compatible:
            return Color.unbound.success
        case .unavailable, .avoided:
            return Color.unbound.alert
        }
    }

    private func libraryMetadata(for definition: MovementDefinition) -> String {
        let equipment = ExerciseLibrary.equipmentLabels(for: definition).prefix(2).joined(separator: " · ")
        return [ExerciseLibrarySearch.muscleSummary(for: definition.muscleGroups), equipment]
            .filter { !$0.isEmpty }
            .joined(separator: "  •  ")
    }
}
