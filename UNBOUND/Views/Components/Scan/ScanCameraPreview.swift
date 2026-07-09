import SwiftUI
import AVFoundation
import UIKit

/// SwiftUI bridge over the live `AVCaptureVideoPreviewLayer`. Mirrors the
/// preview horizontally so the user sees themselves naturally (selfie behavior).
/// The captured photo itself is NOT mirrored — `ImageCaptureService.capturePhoto`
/// returns the un-flipped frame for analysis.
struct ScanCameraPreview: UIViewRepresentable {
    let service: any ImageCaptureServiceProtocol

    func makeUIView(context: Context) -> ScanCameraPreviewHostView {
        let view = ScanCameraPreviewHostView()
        if let layer = service.previewLayer as? AVCaptureVideoPreviewLayer {
            view.attach(previewLayer: layer)
        }
        return view
    }

    func updateUIView(_ uiView: ScanCameraPreviewHostView, context: Context) {
        uiView.refreshLayout()
    }
}

/// UIView that owns the AVCaptureVideoPreviewLayer and keeps it sized to bounds.
/// Orientation + selfie mirroring are owned by `ImageCaptureService` (via its
/// RotationCoordinator); this view only keeps the layer filling its bounds so it
/// never fights the service for the connection's rotation angle.
final class ScanCameraPreviewHostView: UIView {
    private var previewLayer: AVCaptureVideoPreviewLayer?

    func attach(previewLayer: AVCaptureVideoPreviewLayer) {
        self.previewLayer?.removeFromSuperlayer()
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = bounds
        layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }

    func refreshLayout() {
        previewLayer?.frame = bounds
    }
}
