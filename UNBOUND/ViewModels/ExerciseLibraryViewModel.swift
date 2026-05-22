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
                let searchSource = [
                    item.name,
                    item.canonicalName,
                    item.metadataSummary,
                    item.equipmentSummary
                ].joined(separator: " ")
                let matchesSearch = searchText.isEmpty || searchSource.localizedCaseInsensitiveContains(searchText)
                let matchesCategory = selectedCategory == nil || item.category == selectedCategory
                return matchesSearch && matchesCategory
            }
            return filtered.isEmpty ? nil : (title, filtered)
        }
    }

    var availableCount: Int { uniquePreferences.filter { $0.status == .available }.count }
    var substituteCount: Int { uniquePreferences.filter { $0.status == .substitute }.count }
    var avoidCount: Int { uniquePreferences.filter { $0.status == .avoid }.count }

    private var uniquePreferences: [ExercisePreference] {
        Dictionary(grouping: preferences.values, by: \.id).compactMap { $0.value.first }
    }

    func loadPreferences() async {
        guard let userId = services.auth.currentUserId else { return }
        state = .loading
        do {
            let prefs = try await services.exercisePreference.fetchPreferences(userId: userId)
            preferences = ExercisePreferenceLookup.index(prefs)
            state = .loaded(())
        } catch {
            state = .error(.databaseReadFailed(underlying: error))
        }
        services.analytics.track(.exerciseLibraryViewed)
    }

    func setPreference(for item: ExerciseLibraryItem, status: ExercisePreferenceStatus?) async {
        guard let userId = services.auth.currentUserId else { return }
        let key = item.preferenceKey

        if let status {
            let pref = ExercisePreference(
                id: "\(userId):\(key)",
                userId: userId,
                exerciseName: key,
                displayName: item.name,
                status: status,
                muscleGroups: item.muscleGroups,
                substitutePreference: status == .substitute
                    ? MovementCatalog.catalogAlternatives(to: item.name).first?.name
                    : nil,
                notes: nil,
                updatedAt: Date()
            )
            try? await services.exercisePreference.setPreference(pref)
            for lookupKey in item.preferenceLookupKeys {
                preferences[lookupKey] = pref
            }
            services.analytics.track(.exercisePreferenceSet(exerciseName: item.name, status: status.rawValue))
        } else {
            let ids = Set(
                item.preferenceLookupKeys.compactMap { preferences[$0]?.id } + ["\(userId):\(item.preferenceKey)"]
            )
            for id in ids {
                try? await services.exercisePreference.deletePreference(id: id)
            }
            for lookupKey in item.preferenceLookupKeys {
                preferences.removeValue(forKey: lookupKey)
            }
        }
    }

    func statusFor(_ item: ExerciseLibraryItem) -> ExercisePreferenceStatus? {
        preferenceFor(item)?.status
    }

    private func preferenceFor(_ item: ExerciseLibraryItem) -> ExercisePreference? {
        item.preferenceLookupKeys.compactMap { preferences[$0] }.first
    }
}
