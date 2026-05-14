import Foundation
import Vision
import CoreVideo
import CoreGraphics
import Observation

/// Live alignment state — drives the silhouette overlay color and the
/// auto-snap countdown trigger.
enum BodyAlignment: Equatable {
    case noBody
    case outOfFrame(reason: OutOfFrameReason)
    case closeToAligned
    case aligned

    enum OutOfFrameReason: String, Equatable {
        case tooClose       // body bbox > maxWidth fraction
        case tooFar         // body bbox < minWidth fraction
        case offCenterX     // horizontal centering miss
        case headNotVisible // top of head not in upper band
        case feetNotVisible // ankles not in lower band
    }

    var statusLabel: String {
        switch self {
        case .noBody:                      return "STEP INTO FRAME"
        case .outOfFrame(.tooClose):       return "STEP BACK"
        case .outOfFrame(.tooFar):         return "STEP IN"
        case .outOfFrame(.offCenterX):     return "CENTER YOURSELF"
        case .outOfFrame(.headNotVisible): return "RAISE THE PHONE"
        case .outOfFrame(.feetNotVisible): return "LOWER THE PHONE"
        case .closeToAligned:              return "HOLD STILL"
        case .aligned:                     return "ALIGNED"
        }
    }
}

/// Tunables for the alignment detector. Centralized so jlin can tweak from
/// one place without spelunking the request pipeline.
struct BodyAlignmentThresholds {
    var minBoxWidthFraction: Double = 0.22          // lowered from 0.32 — allows standing further back
    var maxBoxWidthFraction: Double = 0.85
    var horizontalCenterTolerance: Double = 0.18    // ±18% of screen width
    var headBandFraction: Double = 0.22             // top 22% of frame must contain head
    var feetBandFraction: Double = 0.22             // bottom 22% must contain ankles
    var sustainedFramesForAligned: Int = 24          // ~0.8s at 30fps
    var minLandmarkConfidence: Float = 0.35
    var wristRaiseOffset: Double = 0.10             // wrist must be 10% above shoulder in Vision y
    var wristSustainFrames: Int = 10                // ~0.7s at 15fps before gesture fires

    static let `default` = BodyAlignmentThresholds()
}

/// Wraps Vision's body pose detection to publish a coarse `BodyAlignment`
/// state to SwiftUI. Frames flow in via `VideoSampleHandling.process(pixelBuffer:)`.
///
/// This is purely a UI-feedback signal; the captured photo is what gets
/// analyzed downstream. No PHI / pose data is persisted.
@Observable
@MainActor
final class BodyAlignmentDetector: VideoSampleHandling {

    private(set) var alignment: BodyAlignment = .noBody

    /// Set true when the user holds a wrist above shoulder level for
    /// `thresholds.wristSustainFrames` consecutive frames. Consumed by
    /// `Step_ScanLive` to start the capture countdown. Reset via `resetGesture()`.
    private(set) var gestureDetected: Bool = false

    private var thresholds: BodyAlignmentThresholds
    private var sustainedAlignedFrames = 0
    private var sustainedWristFrames = 0
    private var lastFrameAt: Date = .distantPast

    private nonisolated let request: VNDetectHumanBodyPoseRequest

    init(thresholds: BodyAlignmentThresholds = .default) {
        self.thresholds = thresholds
        self.request = VNDetectHumanBodyPoseRequest()
    }

    func reset() {
        sustainedAlignedFrames = 0
        alignment = .noBody
        resetGesture()
    }

    func resetGesture() {
        gestureDetected = false
        sustainedWristFrames = 0
    }

    // MARK: - VideoSampleHandling

    nonisolated func process(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) {
        let now = Date()
        let last = lastFrameAtUnsafe
        guard now.timeIntervalSince(last) >= (1.0 / 15.0) else { return }
        lastFrameAtUnsafe = now

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return
        }

        let observation = request.results?.first
        let (computed, wristRaised) = computeAlignment(from: observation)

        Task { @MainActor [computed, wristRaised] in
            self.applyAlignment(computed, wristRaised: wristRaised)
        }
    }

    // MARK: - Private (nonisolated state, only touched from the video queue)
    //
    // `lastFrameAt` is read/written off the MainActor by the capture queue.
    // We accept the data race risk on a single Date — at worst we drop a
    // frame that the throttle should have allowed, or process one we should
    // have dropped. No correctness issue for the alignment heuristic.
    nonisolated private var lastFrameAtUnsafe: Date {
        get { _lastFrameAtBox.get() }
        set { _lastFrameAtBox.set(newValue) }
    }
    private let _lastFrameAtBox = ThrottleBox()

    private nonisolated func computeAlignment(from observation: VNHumanBodyPoseObservation?) -> (BodyAlignment, Bool) {
        guard let observation else { return (.noBody, false) }

        let minConfidence = thresholdsSnapshot.minLandmarkConfidence
        let recognizedPoints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint] = {
            var out: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint] = [:]
            for joint in [VNHumanBodyPoseObservation.JointName.nose,
                          .neck,
                          .leftShoulder, .rightShoulder,
                          .leftHip, .rightHip,
                          .leftAnkle, .rightAnkle,
                          .leftKnee, .rightKnee,
                          .leftWrist, .rightWrist] {
                if let p = try? observation.recognizedPoint(joint), p.confidence >= minConfidence {
                    out[joint] = p
                }
            }
            return out
        }()

        guard !recognizedPoints.isEmpty else { return (.noBody, false) }

        // Vision points are in 0...1 normalized coordinates with origin at
        // bottom-left for the source image. After our `.leftMirrored`
        // orientation hint, x is along screen width and y is along screen
        // height with origin still bottom-left. Convert y to top-left for the
        // overlay's mental model.
        let xs = recognizedPoints.values.map { Double($0.location.x) }
        let ys = recognizedPoints.values.map { 1.0 - Double($0.location.y) } // flip to top-origin

        let minX = xs.min() ?? 0
        let maxX = xs.max() ?? 0
        let minY = ys.min() ?? 0
        let maxY = ys.max() ?? 0
        let bboxWidth = maxX - minX
        let bboxCenterX = (minX + maxX) / 2.0

        let t = thresholdsSnapshot

        // Distance check
        if bboxWidth > t.maxBoxWidthFraction {
            return (.outOfFrame(reason: .tooClose), false)
        }
        if bboxWidth < t.minBoxWidthFraction {
            return (.outOfFrame(reason: .tooFar), false)
        }

        // Centering check
        if abs(bboxCenterX - 0.5) > t.horizontalCenterTolerance {
            return (.outOfFrame(reason: .offCenterX), false)
        }

        // Head visibility
        let headInBand: Bool = {
            if let nose = recognizedPoints[.nose] {
                return (1.0 - Double(nose.location.y)) <= t.headBandFraction * 1.4
            }
            return minY <= t.headBandFraction
        }()
        if !headInBand {
            return (.outOfFrame(reason: .headNotVisible), false)
        }

        // Feet visibility
        let feetInBand: Bool = {
            if let leftAnkle = recognizedPoints[.leftAnkle] {
                if (1.0 - Double(leftAnkle.location.y)) >= (1.0 - t.feetBandFraction * 1.4) { return true }
            }
            if let rightAnkle = recognizedPoints[.rightAnkle] {
                if (1.0 - Double(rightAnkle.location.y)) >= (1.0 - t.feetBandFraction * 1.4) { return true }
            }
            return maxY >= (1.0 - t.feetBandFraction)
        }()
        if !feetInBand {
            return (.outOfFrame(reason: .feetNotVisible), false)
        }

        // Wrist-raise gesture — any wrist above any shoulder by ≥ wristRaiseOffset.
        // Vision coords: y=0 bottom, y=1 top. Higher y = physically higher.
        let wristRaised: Bool = {
            let wrists = [recognizedPoints[.leftWrist], recognizedPoints[.rightWrist]].compactMap { $0 }
            let shoulders = [recognizedPoints[.leftShoulder], recognizedPoints[.rightShoulder]].compactMap { $0 }
            guard !wrists.isEmpty, !shoulders.isEmpty else { return false }
            let maxWristY = wrists.map { Double($0.location.y) }.max() ?? 0
            let maxShoulderY = shoulders.map { Double($0.location.y) }.max() ?? 0
            return maxWristY > maxShoulderY + t.wristRaiseOffset
        }()

        return (.closeToAligned, wristRaised)
    }

    /// Snapshot of thresholds — taken on init and immutable for the lifetime
    /// of the detector. Avoids actor-isolation issues reading them from the
    /// nonisolated process(pixelBuffer:) path.
    private nonisolated var thresholdsSnapshot: BodyAlignmentThresholds {
        BodyAlignmentThresholds.default
    }

    private func applyAlignment(_ next: BodyAlignment, wristRaised: Bool) {
        switch next {
        case .closeToAligned:
            sustainedAlignedFrames += 1
            if sustainedAlignedFrames >= thresholds.sustainedFramesForAligned {
                if alignment != .aligned { alignment = .aligned }
            } else {
                if alignment != .closeToAligned { alignment = .closeToAligned }
            }
        default:
            sustainedAlignedFrames = 0
            if alignment != next { alignment = next }
        }

        // Gesture: sustain wrist raise while body is in frame
        if wristRaised && !gestureDetected && next != .noBody {
            sustainedWristFrames += 1
            if sustainedWristFrames >= thresholds.wristSustainFrames {
                gestureDetected = true
            }
        } else if !wristRaised {
            sustainedWristFrames = 0
        }
    }
}

/// Sendable ref-cell for the throttle timestamp, safe for nonisolated access
/// from the capture queue without tripping Swift 6 data-race diagnostics.
private final class ThrottleBox: @unchecked Sendable {
    private var value: Date = .distantPast
    private let lock = NSLock()

    func get() -> Date {
        lock.lock(); defer { lock.unlock() }
        return value
    }

    func set(_ newValue: Date) {
        lock.lock(); defer { lock.unlock() }
        value = newValue
    }
}
