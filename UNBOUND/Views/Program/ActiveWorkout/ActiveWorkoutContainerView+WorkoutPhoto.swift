import SwiftUI
import UIKit

// MARK: - Post-workout photo save
//
// Persists an opt-in photo taken on the reward final beat, tagged with the
// session that was just finished. Mirrors PhotoCaptureFlow's local-first save
// (JPEG in Documents + a progressPhotos row). Local-only — progressPhotos is
// unmapped in SyncCollectionMap, so nothing leaves the device.

extension ActiveWorkoutContainerView {
    @MainActor
    func saveWorkoutPhoto(_ image: UIImage, context: WorkoutPhotoSummary?, services: ServiceContainer) async {
        guard let userId = services.auth.currentUserId else { return }
        let id = UUID().uuidString
        guard let jpeg = image.jpegData(compressionQuality: 0.85),
              let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let fileURL = docs.appendingPathComponent("progress_\(id).jpg")
        do {
            try jpeg.write(to: fileURL, options: [.atomic])
            let photo = ProgressPhoto(
                id: id,
                userId: userId,
                storageUrl: fileURL.path,
                capturedAt: Date(),
                source: .workout,
                workout: context
            )
            try await services.database.create(photo, collection: "progressPhotos", documentId: id)
            NotificationCenter.default.post(name: .photoCaptured, object: nil)
        } catch {
            try? FileManager.default.removeItem(at: fileURL)
            LoggingService.shared.log("Workout photo save failed: \(error)", level: .error)
        }
    }
}
