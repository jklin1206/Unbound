// UNBOUND/Services/Scan/ScanCheckpointStore.swift
import Foundation

/// Filesystem-backed persistence for ScanCheckpoint. JSON files on disk,
/// one per checkpoint. History queries scan and filter by userId.
final class ScanCheckpointStore {

    static let shared = ScanCheckpointStore()

    private let directory: URL
    private let fileManager: FileManager
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(directory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
        if let directory {
            self.directory = directory
        } else {
            let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            self.directory = docs.appendingPathComponent("scan-checkpoints", isDirectory: true)
        }
        try? fileManager.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    private func url(for id: String) -> URL {
        directory.appendingPathComponent("\(id).json")
    }

    func save(_ checkpoint: ScanCheckpoint) throws {
        let data = try encoder.encode(checkpoint)
        try data.write(to: url(for: checkpoint.id), options: .atomic)
    }

    func load(id: String) throws -> ScanCheckpoint {
        let data = try Data(contentsOf: url(for: id))
        return try decoder.decode(ScanCheckpoint.self, from: data)
    }

    func history(userId: String) throws -> [ScanCheckpoint] {
        let files = try fileManager.contentsOfDirectory(at: directory,
                                                       includingPropertiesForKeys: nil)
        var checkpoints: [ScanCheckpoint] = []
        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let cp = try? decoder.decode(ScanCheckpoint.self, from: data),
               cp.userId == userId {
                checkpoints.append(cp)
            }
        }
        return checkpoints.sorted { $0.createdAt < $1.createdAt }
    }

    func mostRecent(userId: String) throws -> ScanCheckpoint? {
        try history(userId: userId).last
    }
}
