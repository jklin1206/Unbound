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
