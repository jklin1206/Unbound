import SwiftUI

@MainActor
final class ExerciseLibraryViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var selectedCategory: ExerciseCategory?
    @Published var preferences: [String: ExercisePreference] = [:]
    @Published var state: LoadingState<Void> = .idle

    private let services: ServiceContainer

    init(services: ServiceContainer) {
        self.services = services
    }

    var filteredGroups: [(String, [ExerciseLibraryItem])] {
        let groups = ExerciseLibrary.grouped()
        return groups.compactMap { (title, items) in
            let filtered = items.filter { item in
                let matchesSearch = searchText.isEmpty || item.name.localizedCaseInsensitiveContains(searchText)
                let matchesCategory = selectedCategory == nil || item.category == selectedCategory
                return matchesSearch && matchesCategory
            }
            return filtered.isEmpty ? nil : (title, filtered)
        }
    }

    var availableCount: Int { preferences.values.filter { $0.status == .available }.count }
    var substituteCount: Int { preferences.values.filter { $0.status == .substitute }.count }
    var avoidCount: Int { preferences.values.filter { $0.status == .avoid }.count }

    func loadPreferences() async {
        guard let userId = services.auth.currentUserId else { return }
        state = .loading
        do {
            let prefs = try await services.exercisePreference.fetchPreferences(userId: userId)
            preferences = Dictionary(uniqueKeysWithValues: prefs.map { ($0.exerciseName, $0) })
            state = .loaded(())
        } catch {
            state = .error(.databaseReadFailed(underlying: error))
        }
        services.analytics.track(.exerciseLibraryViewed)
    }

    func setPreference(for item: ExerciseLibraryItem, status: ExercisePreferenceStatus?) async {
        guard let userId = services.auth.currentUserId else { return }

        if let status {
            let pref = ExercisePreference(
                id: item.normalizedName,
                userId: userId,
                exerciseName: item.normalizedName,
                displayName: item.name,
                status: status,
                muscleGroups: item.muscleGroups,
                substitutePreference: nil,
                notes: nil,
                updatedAt: Date()
            )
            try? await services.exercisePreference.setPreference(pref)
            preferences[item.normalizedName] = pref
            services.analytics.track(.exercisePreferenceSet(exerciseName: item.name, status: status.rawValue))
        } else {
            if let existing = preferences[item.normalizedName] {
                try? await services.exercisePreference.deletePreference(id: existing.id)
                preferences.removeValue(forKey: item.normalizedName)
            }
        }
    }

    func statusFor(_ item: ExerciseLibraryItem) -> ExercisePreferenceStatus? {
        preferences[item.normalizedName]?.status
    }
}
