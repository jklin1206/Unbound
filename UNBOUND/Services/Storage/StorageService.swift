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
}

// MARK: - Photo directory re-key (sign-in migration)
//
// On Sign in with Apple an anonymous user's photo directory lives at
// ScanPhotos/<legacyUserId>/... and must move to ScanPhotos/<supabaseUserId>/...
// or the photos are orphaned (Bug #1). Additive-only: existing methods are
// untouched so this file merges cleanly with parallel work.
extension StorageService: UserDataMigrationPhotoMoving {
    /// Moves the entire on-disk photo directory from the legacy UID to the
    /// authenticated UID. Idempotent: a no-op when the legacy directory is
    /// absent (already moved or never existed). If a destination directory
    /// already holds files, the legacy scan subdirectories are merged in.
    func movePhotoDirectory(from legacyUserId: String, to supabaseUserId: String) async throws {
        guard legacyUserId != supabaseUserId else { return }

        let source = rootURL.appendingPathComponent(legacyUserId, isDirectory: true)
        let destination = rootURL.appendingPathComponent(supabaseUserId, isDirectory: true)

        guard fm.fileExists(atPath: source.path) else { return }

        if !fm.fileExists(atPath: destination.path) {
            // Fast path: no destination yet — move the whole directory.
            try fm.moveItem(at: source, to: destination)
            logger.log(
                "Scan photo directory re-keyed",
                level: .info,
                context: ["from": legacyUserId, "to": supabaseUserId]
            )
            return
        }

        // Destination exists — merge each scan subdirectory across, then remove
        // the now-empty legacy directory.
        let entries = try fm.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
        for entry in entries {
            let target = destination.appendingPathComponent(entry.lastPathComponent)
            if fm.fileExists(atPath: target.path) {
                try fm.removeItem(at: target)
            }
            try fm.moveItem(at: entry, to: target)
        }
        try fm.removeItem(at: source)
        logger.log(
            "Scan photo directory merged into authenticated uid",
            level: .info,
            context: ["from": legacyUserId, "to": supabaseUserId]
        )
    }
}
