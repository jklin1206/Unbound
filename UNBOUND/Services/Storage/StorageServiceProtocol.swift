import Foundation

protocol StorageServiceProtocol: Sendable {
    func uploadScanPhoto(userId: String, scanId: String, angle: ScanAngle, imageData: Data) async throws -> String
    func deleteUserPhotos(userId: String) async throws
    func deleteScanPhotos(userId: String, scanId: String) async throws
}
