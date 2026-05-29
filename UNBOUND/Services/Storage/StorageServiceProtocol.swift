import Foundation

protocol StorageServiceProtocol: Sendable {
    func uploadScanPhoto(userId: String, scanId: String, angle: ScanAngle, imageData: Data) async throws -> String
    func deleteUserPhotos(userId: String) async throws
    func deleteScanPhotos(userId: String, scanId: String) async throws
    /// Account-deletion teardown: remove the entire on-disk photo root for
    /// every supplied user id (live UID plus any legacy/old UUID).
    func deleteAllPhotoRoots(userIds: [String]) async throws
}
