import UIKit
import AVFoundation

final class ImageCaptureService: NSObject, ImageCaptureServiceProtocol {
    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var photoContinuation: CheckedContinuation<UIImage, Error>?
    private weak var sampleHandler: VideoSampleHandling?
    private let videoQueue = DispatchQueue(label: "com.unbound.camera.video", qos: .userInitiated)
    private let logger = LoggingService.shared

    private(set) var isSessionRunning = false

    /// Cached preview layer — recreating per access broke the scan view because
    /// each `previewLayer` access returned a fresh layer disconnected from the
    /// running session. Lazy + memoized keeps it bound to the live session.
    private var cachedPreviewLayer: AVCaptureVideoPreviewLayer?

    // Orientation is owned here, not by the SwiftUI preview view: a hardcoded
    // 90° guess left a portrait subject lying sideways on some devices. The
    // RotationCoordinator computes the exact horizon-level preview angle for THIS
    // device + camera and republishes it via KVO, so the preview always stands up.
    private var captureDevice: AVCaptureDevice?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var previewRotationObservation: NSKeyValueObservation?

    var previewLayer: Any {
        if let cached = cachedPreviewLayer { return cached }
        let layer = AVCaptureVideoPreviewLayer(session: captureSession ?? AVCaptureSession())
        layer.videoGravity = .resizeAspectFill
        // Front camera mirroring so the user reads themselves naturally.
        if let connection = layer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
        cachedPreviewLayer = layer
        // In the scan flow the layer is first accessed AFTER startSession, so the
        // device already exists — wire up rotation immediately.
        setupRotationCoordinatorIfPossible()
        return layer
    }

    /// Binds a RotationCoordinator to the live device + preview layer and locks
    /// the preview connection to the returned horizon-level angle, updating it
    /// whenever the device reports a new one. No-op until both exist.
    private func setupRotationCoordinatorIfPossible() {
        guard let device = captureDevice, let previewLayer = cachedPreviewLayer else { return }
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
        rotationCoordinator = coordinator
        applyPreviewRotation()
        previewRotationObservation = coordinator.observe(
            \.videoRotationAngleForHorizonLevelPreview,
            options: [.new]
        ) { [weak self] _, _ in
            DispatchQueue.main.async { self?.applyPreviewRotation() }
        }
    }

    private func applyPreviewRotation() {
        guard let coordinator = rotationCoordinator,
              let connection = cachedPreviewLayer?.connection else { return }
        let angle = coordinator.videoRotationAngleForHorizonLevelPreview
        if connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
        logger.log("Camera preview rotation set to \(Int(angle))°", level: .info)
    }

    func requestPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    func startSession() async throws {
        guard !isSessionRunning else { return }

        let session = AVCaptureSession()
        session.sessionPreset = .photo

        // Prefer front ultra-wide (iPads with Center Stage) for a wider FOV.
        // Falls back to standard wide-angle on iPhones and older iPads.
        let frontCamera = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInUltraWideCamera, .builtInWideAngleCamera],
            mediaType: .video,
            position: .front
        ).devices.first
        guard let camera = frontCamera else {
            throw AppError.cameraUnavailable
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
            }
        } catch {
            throw AppError.cameraUnavailable
        }

        let output = AVCapturePhotoOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        self.captureSession = session
        self.photoOutput = output
        self.videoDataOutput = videoOutput
        self.captureDevice = camera

        // Rebind preview layer to the new session if it was created earlier.
        cachedPreviewLayer?.session = session
        if let connection = cachedPreviewLayer?.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
        // Re-anchor rotation to the now-live device (no-op if the preview layer
        // hasn't been created yet; the getter wires it up when it is).
        setupRotationCoordinatorIfPossible()

        // startRunning blocks; off the main actor.
        await Task.detached(priority: .userInitiated) {
            session.startRunning()
        }.value

        isSessionRunning = true
        logger.log("Camera session started (front)", level: .info)
    }

    func stopSession() {
        captureSession?.stopRunning()
        isSessionRunning = false
        logger.log("Camera session stopped", level: .info)
    }

    func attachVideoSampleHandler(_ handler: VideoSampleHandling?) {
        self.sampleHandler = handler
    }

    func capturePhoto() async throws -> UIImage {
        guard let photoOutput else {
            throw AppError.cameraUnavailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.photoContinuation = continuation
            let settings = AVCapturePhotoSettings()
            settings.flashMode = .off
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension ImageCaptureService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            photoContinuation?.resume(throwing: AppError.cameraCaptureFailed)
            photoContinuation = nil
            logger.log("Photo capture failed: \(error)", level: .error)
            return
        }

        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            photoContinuation?.resume(throwing: AppError.cameraCaptureFailed)
            photoContinuation = nil
            return
        }

        // The front-camera preview is mirrored for the user's benefit; the
        // captured photo from the photoOutput is NOT mirrored, which is what
        // we want for analysis + display. No transform needed.
        photoContinuation?.resume(returning: image)
        photoContinuation = nil
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension ImageCaptureService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let handler = sampleHandler,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        // Front camera + portrait → leftMirrored is the canonical orientation
        // Vision expects.
        handler.process(pixelBuffer: pixelBuffer, orientation: .leftMirrored)
    }
}
