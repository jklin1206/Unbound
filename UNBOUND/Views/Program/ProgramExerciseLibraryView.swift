import SwiftUI

struct ProgramExerciseLibraryView: View {
    enum Mode {
        case add
        case swap
    }

    var mode: Mode = .swap
    let currentExerciseName: String
    let alternatives: [CatalogExercise]
    let onSelect: (CatalogExercise) -> Void
    var recentExerciseNames: Set<String> = []
    var preferenceStatusesByKey: [String: ExercisePreferenceStatus] = [:]
    var availableEquipment: [Equipment]? = nil
    var onCreateCustom: (() -> Void)? = nil
    var onDismiss: () -> Void = {}

    @State private var searchText = ""
    @State private var selectedSlot: MovementSlot?
    @State private var contextFilter: ExerciseLibraryContextFilter = .best

    private var filteredAlternatives: [CatalogExercise] {
        ExerciseLibrarySearch.filteredAlternatives(
            alternatives,
            searchText: searchText,
            selectedSlot: selectedSlot,
            contextFilter: contextFilter,
            recentExerciseNames: recentExerciseNames,
            preferenceStatusesByKey: preferenceStatusesByKey,
            availableEquipment: availableEquipment
        )
    }

    private var availableSlots: [MovementSlot] {
        ExerciseLibrarySearch.availableSlots(in: alternatives)
    }

    private var availableContextFilters: [ExerciseLibraryContextFilter] {
        ExerciseLibraryContextFilter.allCases.filter { filter in
            switch filter {
            case .best:
                return true
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
            case .available:
                return false
            }
        }
    }

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                searchAndFilters
                if alternatives.isEmpty {
                    emptyState
                    if onCreateCustom != nil {
                        createNewRow
                            .padding(.horizontal, 20)
                            .padding(.bottom, 28)
                    }
                } else if filteredAlternatives.isEmpty {
                    noSearchResults
                    if onCreateCustom != nil {
                        createNewRow
                            .padding(.horizontal, 20)
                            .padding(.bottom, 28)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(filteredAlternatives) { alt in
                                libraryRow(alt)
                            }
                            if onCreateCustom != nil {
                                createNewRow
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 28)
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: mode == .add ? "plus" : "arrow.triangle.2.circlepath")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.unbound.bg)
                .frame(width: 34, height: 34)
                .background(Circle().fill(mode == .add ? Color.unbound.coachCyan : Color.unbound.accent))

            VStack(alignment: .leading, spacing: 5) {
                Text(mode == .add ? "ADD EXERCISE" : "SWAP EXERCISE")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text(mode == .add ? "Pick the next movement" : currentExerciseName)
                    .font(Font.unbound.titleM)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(2)
                Text(mode == .add ? "Search, filter, or create a custom exercise." : "Choose a compatible replacement ranked by fit.")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                Text("\(filteredAlternatives.count) of \(alternatives.count) matches")
                    .font(Font.unbound.monoS)
                    .foregroundStyle(Color.unbound.textTertiary)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }

    private var searchAndFilters: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
                TextField("Search exercise, muscle, equipment", text: $searchText)
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
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

            if !availableSlots.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(availableContextFilters, id: \.self) { filter in
                            filterChip(title: filter.displayName, isSelected: contextFilter == filter) {
                                contextFilter = filter
                            }
                        }
                        filterChip(title: "All", isSelected: selectedSlot == nil) {
                            selectedSlot = nil
                        }
                        ForEach(availableSlots, id: \.self) { slot in
                            filterChip(title: slot.displayName, isSelected: selectedSlot == slot) {
                                selectedSlot = slot
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
            Text("Try a movement pattern, muscle, equipment, or clear the filter.")
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
            onDismiss()
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

    private func libraryRow(_ alt: CatalogExercise) -> some View {
        let metadata = MovementCatalog.canonicalExercise(named: alt.name).map { libraryMetadata(for: $0) }
        let signals = ExerciseLibrarySearch.signals(
            for: alt,
            recentExerciseNames: recentExerciseNames,
            preferenceStatusesByKey: preferenceStatusesByKey
        )
        let compatibility = ExerciseLibrarySearch.compatibilityState(
            for: alt,
            preferredSlot: selectedSlot,
            availableEquipment: availableEquipment,
            preferenceStatusesByKey: preferenceStatusesByKey
        )

        return Button(action: {
            guard compatibility.isSelectable else { return }
            UnboundHaptics.medium()
            onSelect(alt)
            onDismiss()
        }, label: {
            HStack(spacing: 12) {
                Image(systemName: mode == .add ? "plus" : "arrow.left.arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(compatibility.isSelectable ? compatibilityColor(compatibility) : Color.unbound.textTertiary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle().fill(compatibilityColor(compatibility).opacity(0.12))
                    )
                VStack(alignment: .leading, spacing: 3) {
                    Text(alt.displayName)
                        .font(Font.unbound.bodyLStrong)
                        .foregroundStyle(compatibility.isSelectable ? Color.unbound.textPrimary : Color.unbound.textTertiary)
                        .lineLimit(1)
                    Text(compatibility.detail.isEmpty ? (metadata ?? alt.muscleGroups.map(\.displayName).joined(separator: " · ")) : compatibility.detail)
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        contextBadge(compatibility.badgeTitle)
                        ForEach(signals.badges.filter { $0 != compatibility.badgeTitle }.prefix(2), id: \.self) { badge in
                            contextBadge(badge)
                        }
                    }
                    .padding(.top, 2)
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
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(13)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(compatibility.isSelectable ? Color.unbound.surface : Color.unbound.surface.opacity(0.72))
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
        case "Available", "Fits":
            return Color.unbound.success
        case "Avoid", "Unavailable":
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
        return [
            definition.movementSlot.displayName,
            definition.rankTemplate.displayName,
            definition.loggerMode.displayName,
            equipment
        ]
        .filter { !$0.isEmpty }
        .joined(separator: " · ")
    }
}
