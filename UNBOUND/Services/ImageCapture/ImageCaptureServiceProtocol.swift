import UIKit
import AVFoundation
import Combine

protocol ImageCaptureServiceProtocol: AnyObject {
    var previewLayer: Any { get }
    var isSessionRunning: Bool { get }

    func requestPermission() async -> Bool
    func startSession() async throws
    func stopSession()
    func capturePhoto() async throws -> UIImage

    /// Attach a per-frame video sample delegate for live alignment detection.
    /// Implementations should hand back raw `CVPixelBuffer` frames at ≥15fps
    /// on a serial queue. No-op for mock.
    func attachVideoSampleHandler(_ handler: VideoSampleHandling?)
}

/// Sink for live preview frames. Conformers can be `AVCaptureVideoDataOutputSampleBufferDelegate`
/// (real camera) or call `process(pixelBuffer:)` directly from a test.
protocol VideoSampleHandling: AnyObject {
    func process(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation)
}
