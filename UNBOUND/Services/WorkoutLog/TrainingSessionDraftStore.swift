import Foundation

final class TrainingSessionDraftStore {
    private let fileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.fileURL = fileURL ?? Self.defaultFileURL(fileManager: fileManager)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func loadRecent() -> [TrainingSessionDraft] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? decoder.decode([TrainingSessionDraft].self, from: data)) ?? []
    }

    func saveRecent(_ draft: TrainingSessionDraft, limit: Int = 10) {
        var recent = loadRecent().filter { $0.id != draft.id }
        recent.insert(draft, at: 0)
        if recent.count > limit {
            recent = Array(recent.prefix(limit))
        }

        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(recent)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            #if DEBUG
            print("TrainingSessionDraftStore save failed: \(error)")
            #endif
        }
    }

    private static func defaultFileURL(fileManager: FileManager) -> URL {
        let base = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fileManager.temporaryDirectory

        return base
            .appendingPathComponent("UNBOUND", isDirectory: true)
            .appendingPathComponent("recent-training-drafts.json")
    }
}
