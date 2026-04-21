import UIKit

final class MockImageCaptureService: ImageCaptureServiceProtocol {
    var previewLayer: Any { CALayer() }
    var isSessionRunning = false

    func requestPermission() async -> Bool { true }
    func startSession() async throws { isSessionRunning = true }
    func stopSession() { isSessionRunning = false }
    func attachVideoSampleHandler(_ handler: VideoSampleHandling?) {}
    func capturePhoto() async throws -> UIImage {
        UIImage(systemName: "person.fill")!
    }
}
