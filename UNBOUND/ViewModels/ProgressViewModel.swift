import SwiftUI

@MainActor
final class ProgressViewModel: ObservableObject {
    @Published var entries: [ProgressEntry] = []
    @Published var state: LoadingState<[ProgressEntry]> = .idle
    @Published var scans: [ScanSession] = []

    private let services: ServiceContainer

    init(services: ServiceContainer) {
        self.services = services
    }

    func loadProgress() async {
        guard let userId = services.auth.currentUserId else { return }
        state = .loading

        do {
            let entries: [ProgressEntry] = try await services.database.query(
                collection: "progress", field: "userId", isEqualTo: userId,
                orderBy: "createdAt", descending: true, limit: nil
            )
            self.entries = entries

            let scans: [ScanSession] = try await services.database.query(
                collection: "scans", field: "userId", isEqualTo: userId,
                orderBy: "createdAt", descending: true, limit: nil
            )
            self.scans = scans

            state = .loaded(entries)
        } catch {
            state = .error(.databaseReadFailed(underlying: error))
        }
    }

    var hasScans: Bool { !scans.isEmpty }

    func scoreDelta(for entry: ProgressEntry) -> Int? {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }),
              index + 1 < entries.count else { return nil }
        return entry.overallScore - entries[index + 1].overallScore
    }
}
