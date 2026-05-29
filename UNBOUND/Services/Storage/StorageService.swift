import Foundation

// MARK: - StorageService (local-first)
//
// Replaces Firebase Storage with FileManager-backed local photo storage.
// Scan photos stay on-device — matches the "private by default" promise
// in Step30_ScanPrep.
//
// Layout:
//   .../Documents/ScanPhotos/<userId>/<scanId>/<angle>.jpg

final class StorageService: StorageServiceProtocol, @unchecked Sendable {
    static let shared = StorageService()
    private let logger = LoggingService.shared
    private let fm = FileManager.default

    private lazy var rootURL: URL = {
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("ScanPhotos", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private init() {}

    func uploadScanPhoto(userId: String, scanId: String, angle: ScanAngle, imageData: Data) async throws -> String {
        let scanDir = rootURL
            .appendingPathComponent(userId, isDirectory: true)
            .appendingPathComponent(scanId, isDirectory: true)

        do {
            try fm.createDirectory(at: scanDir, withIntermediateDirectories: true)
            let fileURL = scanDir.appendingPathComponent("\(angle.rawValue).jpg")
            try imageData.write(to: fileURL, options: [.atomic])
            logger.log("Photo stored locally: \(fileURL.path)", level: .info)
            return fileURL.absoluteString
        } catch {
            logger.log("Photo write failed: \(error)", level: .error)
            throw AppError.analysisPhotoUploadFailed(underlying: error)
        }
    }

    func deleteUserPhotos(userId: String) async throws {
        let dir = rootURL.appendingPathComponent(userId, isDirectory: true)
        guard fm.fileExists(atPath: dir.path) else { return }
        do {
            try fm.removeItem(at: dir)
            logger.log("User photos deleted", level: .info, context: ["userId": userId])
        } catch {
            logger.log("User photo deletion failed: \(error)", level: .error)
        }
    }

    func deleteScanPhotos(userId: String, scanId: String) async throws {
        let dir = rootURL
            .appendingPathComponent(userId, isDirectory: true)
            .appendingPathComponent(scanId, isDirectory: true)
        guard fm.fileExists(atPath: dir.path) else { return }
        do {
            try fm.removeItem(at: dir)
        } catch {
            logger.log("Scan photo deletion failed: \(error)", level: .error)
        }
    }

    // MARK: - Full photo-root teardown (account deletion)
    //
    // Account deletion must leave nothing on disk. `deleteUserPhotos` only
    // handles the current Supabase UID; a user migrated from a pre-auth local
    // UUID can also have an *old-UUID* photo directory left behind by the
    // local→cloud migration. This additive method removes the entire on-disk
    // photo root for every supplied UID (live + any legacy), skipping any that
    // don't exist. A failure on one UID is logged but does not block the rest —
    // best-effort teardown, mirroring `deleteUserPhotos`.

    /// Delete the entire on-disk photo root for each given user id (live and
    /// any legacy/old UUID). Missing directories are skipped silently.
    func deleteAllPhotoRoots(userIds: [String]) async throws {
        Self.deletePhotoRoots(userIds, under: rootURL, fileManager: fm, logger: logger)
    }

    /// Pure, injectable directory-teardown helper so the behavior is unit
    /// testable without the shared singleton's Documents-backed root.
    static func deletePhotoRoots(
        _ userIds: [String],
        under root: URL,
        fileManager fm: FileManager,
        logger: LoggingService? = nil
    ) {
        for userId in Set(userIds) where !userId.isEmpty {
            let dir = root.appendingPathComponent(userId, isDirectory: true)
            guard fm.fileExists(atPath: dir.path) else { continue }
            do {
                try fm.removeItem(at: dir)
                logger?.log("Photo root deleted", level: .info, context: ["userId": userId])
            } catch {
                logger?.log("Photo root deletion failed: \(error)", level: .error)
            }
        }
    }
}
