import SwiftUI

// MARK: - ExercisePreferencesView
//
// Hawks-style YES/SUB/NO exercise library picker. User taps a row to cycle
// through states: unset → available → substitute → avoid → unset.
//
// Grouped by movement pattern. Top shows a compact summary ("42 / 70
// categorized · 10 avoided"). Each row shows the pill state inline.
//
// Persists via ExercisePreferenceService. Consumed by LocalProgramGenerator
// when building sessions (next chunk).

struct ExercisePreferencesView: View {
    @EnvironmentObject var services: ServiceContainer
    @State private var preferences: [String: ExercisePreferenceStatus] = [:]  // key: exercise name
    @State private var preferenceRecords: [String: ExercisePreference] = [:]
    @State private var customExercises: [CustomExercise] = []
    @State private var showingBuilder = false
    @State private var isLoading = true

    private var userId: String {
        services.auth.currentUserId ?? "anonymous"
    }

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .tint(Color.unbound.accent)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        legend
                        addCustomRow
                        if !customExercises.isEmpty {
                            customExercisesSection
                        }
                        ForEach(MovementPattern.allCases) { pattern in
                            patternSection(pattern)
                        }
                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
            }
        }
        .navigationTitle("Exercise Library")
        .navigationBarTitleDisplayMode(.large)
        .task { await load() }
        .sheet(isPresented: $showingBuilder) {
            CustomExerciseBuilderView { saved in
                customExercises.insert(saved, at: 0)
            }
            .environmentObject(services)
        }
    }

    private var addCustomRow: some View {
        Button {
            UnboundHaptics.medium()
            showingBuilder = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.unbound.accent)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.unbound.accent.opacity(0.14)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add custom exercise")
                        .font(Font.unbound.bodyLStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text("Build one that isn't in the library")
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

    private var customExercisesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.unbound.accent)
                Text("YOUR CUSTOM EXERCISES")
                    .font(Font.unbound.captionS)
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            VStack(spacing: 8) {
                ForEach(customExercises) { custom in
                    HStack(spacing: 12) {
                        Text(custom.displayName)
                            .font(Font.unbound.bodyM)
                            .foregroundStyle(Color.unbound.textPrimary)
                        Spacer()
                        Text(custom.pattern.title)
                            .font(Font.unbound.captionS)
                            .foregroundStyle(Color.unbound.textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.unbound.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.unbound.border, lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: Load + save

    @MainActor
    private func load() async {
        do {
            let prefs = try await services.exercisePreference.fetchPreferences(userId: userId)
            preferenceRecords = ExercisePreferenceLookup.index(prefs)
            preferences = preferenceRecords.mapValues { $0.status }
        } catch {
            preferences = [:]
            preferenceRecords = [:]
        }
        customExercises = await services.customExercise.all(userId: userId)
        isLoading = false
    }

    private func setStatus(_ status: ExercisePreferenceStatus?, for exercise: CatalogExercise) {
        UnboundHaptics.medium()
        let definition = MovementCatalog.canonicalExercise(named: exercise.name)
        let key = definition?.canonicalExerciseName ?? exercise.name
        let displayName = definition?.displayName ?? exercise.displayName
        let muscleGroups = definition?.muscleGroups ?? exercise.muscleGroups
        let lookupKeys = ExercisePreferenceLookup.keys(for: exercise)

        if let status {
            for lookupKey in lookupKeys {
                preferences[lookupKey] = status
            }
            let pref = ExercisePreference(
                id: "\(userId):\(key)",
                userId: userId,
                exerciseName: key,
                displayName: displayName,
                status: status,
                muscleGroups: muscleGroups,
                substitutePreference: status == .substitute
                    ? MovementCatalog.catalogAlternatives(to: displayName).first?.name ?? exercise.defaultSubstitute
                    : nil,
                notes: nil,
                updatedAt: Date()
            )
            for lookupKey in lookupKeys {
                preferenceRecords[lookupKey] = pref
            }
            Task {
                try? await services.exercisePreference.setPreference(pref)
            }
        } else {
            let ids = Set(lookupKeys.compactMap { preferenceRecords[$0]?.id } + ["\(userId):\(key)"])
            for lookupKey in lookupKeys {
                preferences[lookupKey] = nil
                preferenceRecords[lookupKey] = nil
            }
            Task {
                for id in ids {
                    try? await services.exercisePreference.deletePreference(id: id)
                }
            }
        }
    }

    /// Cycle order: nil → available → substitute → avoid → nil
    private func cycle(_ exercise: CatalogExercise) {
        let current = preferenceStatus(for: exercise)
        let next: ExercisePreferenceStatus?
        switch current {
        case nil:           next = .available
        case .available:    next = .substitute
        case .substitute:   next = .avoid
        case .avoid:        next = nil
        }
        setStatus(next, for: exercise)
    }

    private func preferenceStatus(for exercise: CatalogExercise) -> ExercisePreferenceStatus? {
        ExercisePreferenceLookup.keys(for: exercise).compactMap { preferences[$0] }.first
    }

    private func preferenceStatus(for definition: MovementDefinition) -> ExercisePreferenceStatus? {
        ExercisePreferenceLookup.keys(for: definition).compactMap { preferences[$0] }.first
    }

    // MARK: Header + legend

    private var header: some View {
        let total = MovementCatalog.legacyExercises.count
        let categorized = MovementCatalog.legacyExercises.filter { preferenceStatus(for: $0) != nil }.count
        let avoided = MovementCatalog.legacyExercises.filter { preferenceStatus(for: $0) == .avoid }.count

        return VStack(alignment: .leading, spacing: 8) {
            Text("Tell us what you like.")
                .font(Font.unbound.titleM)
                .foregroundStyle(Color.unbound.textPrimary)
            Text("Tap to cycle: **available** · **substitute** · **avoid**. Your program only draws from exercises you're good with.")
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                statChip(icon: "checkmark.circle.fill", count: categorized, of: total, label: "set")
                statChip(icon: "minus.circle", count: avoided, of: nil, label: "avoided", tint: Color.unbound.alert)
            }
            .padding(.top, 4)
        }
    }

    private func statChip(icon: String, count: Int, of total: Int?, label: String, tint: Color = Color.unbound.accent) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            if let total {
                Text("\(count) / \(total)")
                    .font(Font.unbound.monoS)
            } else {
                Text("\(count)")
                    .font(Font.unbound.monoS)
            }
            Text(label)
                .font(Font.unbound.captionS)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .overlay(
            Capsule().strokeBorder(tint.opacity(0.5), lineWidth: 1)
        )
    }

    private var legend: some View {
        HStack(spacing: 8) {
            legendPill(status: .available)
            legendPill(status: .substitute)
            legendPill(status: .avoid)
            Spacer()
        }
    }

    private func legendPill(status: ExercisePreferenceStatus) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color(for: status)).frame(width: 6, height: 6)
            Text(labelShort(for: status))
                .font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textSecondary)
        }
    }

    // MARK: Section per pattern

    private func patternSection(_ pattern: MovementPattern) -> some View {
        let exercises = MovementCatalog.catalogExercises(for: pattern)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: pattern.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.unbound.accent)
                Text(pattern.title.uppercased())
                    .font(Font.unbound.captionS)
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(.top, 8)

            VStack(spacing: 8) {
                ForEach(exercises) { ex in
                    exerciseRow(ex)
                }
            }
        }
    }

    private func exerciseRow(_ exercise: CatalogExercise) -> some View {
        let status = preferenceStatus(for: exercise)
        let metadata = exerciseMetadata(for: exercise)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.displayName)
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textPrimary)

                if let metadata {
                    Text(metadata)
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            statusPill(status: status)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    status == nil ? Color.unbound.border : color(for: status!).opacity(0.6),
                    lineWidth: 1
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture { cycle(exercise) }
    }

    private func exerciseMetadata(for exercise: CatalogExercise) -> String? {
        guard let definition = MovementCatalog.canonicalExercise(named: exercise.name) else { return nil }
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

    private func statusPill(status: ExercisePreferenceStatus?) -> some View {
        Group {
            if let status {
                HStack(spacing: 4) {
                    Image(systemName: iconShort(for: status))
                        .font(.system(size: 10, weight: .bold))
                    Text(labelShort(for: status))
                        .font(Font.unbound.captionS)
                        .tracking(0.4)
                }
                .foregroundStyle(color(for: status))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .overlay(
                    Capsule().strokeBorder(color(for: status), lineWidth: 1)
                )
            } else {
                Text("tap")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .overlay(
                        Capsule().strokeBorder(Color.unbound.border, lineWidth: 1)
                    )
            }
        }
    }

    // MARK: Status display helpers

    private func color(for status: ExercisePreferenceStatus) -> Color {
        switch status {
        case .available:  return Color.unbound.accent
        case .substitute: return Color.unbound.impact
        case .avoid:      return Color.unbound.alert
        }
    }

    private func labelShort(for status: ExercisePreferenceStatus) -> String {
        switch status {
        case .available:  return "YES"
        case .substitute: return "SUB"
        case .avoid:      return "NO"
        }
    }

    private func iconShort(for status: ExercisePreferenceStatus) -> String {
        switch status {
        case .available:  return "checkmark"
        case .substitute: return "arrow.triangle.2.circlepath"
        case .avoid:      return "xmark"
        }
    }
}
