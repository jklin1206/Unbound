import Foundation

// MARK: - TravelOverrideStore
//
// Tiny async cache + persistence for `TravelOverride`s. Saves to
// `travel_overrides` via `DatabaseService`. Exposes `activeOverride(for:)`
// which is read by `UnboundHomeView.todayProgramDay` and
// `ProgramOverviewView.programDay(for:in:)` to substitute the travel
// workout when today falls inside the window.

@MainActor
final class TravelOverrideStore {
    static let shared = TravelOverrideStore()

    private let database: DatabaseServiceProtocol

    private convenience init() {
        self.init(database: DatabaseService.shared)
    }

    init(database: DatabaseServiceProtocol) {
        self.database = database
    }

    /// Persist a new override. Any previous overrides stay in the
    /// collection — we pick the most recently-created active one on read.
    func save(_ override: TravelOverride) async {
        try? await database.create(override, collection: "travel_overrides", documentId: override.id)
    }

    /// The currently-active override for `userId`, or nil. "Active" means
    /// today falls within `[startDate, endDate]`. If multiple overrides
    /// overlap today (user re-scheduled), the one created most recently wins.
    /// "Today" is the program clock — real time in release, the dev-simulated
    /// day in DEBUG — so simulated day-jumps see the same window a user would.
    func activeOverride(for userId: String, on date: Date = ProgramClock.now) async -> TravelOverride? {
        let all = await fetchAll(userId: userId)
        let active = all.filter { $0.isActive(on: date) }
        return active.sorted(by: { $0.createdAt > $1.createdAt }).first
    }

    func fetchAll(userId: String) async -> [TravelOverride] {
        do {
            let overrides: [TravelOverride] = try await database.query(
                collection: "travel_overrides",
                field: "userId",
                isEqualTo: userId,
                orderBy: "createdAt",
                descending: true,
                limit: 10
            )
            return overrides
        } catch {
            return []
        }
    }
}
