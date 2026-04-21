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
    var minBoxWidthFraction: Double = 0.32
    var maxBoxWidthFraction: Double = 0.85
    var horizontalCenterTolerance: Double = 0.18    // ±18% of screen width
    var headBandFraction: Double = 0.22             // top 22% of frame must contain head
    var feetBandFraction: Double = 0.22             // bottom 22% must contain ankles
    var sustainedFramesForAligned: Int = 24          // ~0.8s at 30fps
    var minLandmarkConfidence: Float = 0.35

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
    private var thresholds: BodyAlignmentThresholds

    /// Number of consecutive frames the body has been in alignment range.
    /// Once it reaches `thresholds.sustainedFramesForAligned`, alignment
    /// flips to `.aligned`.
    private var sustainedAlignedFrames = 0
    private var lastFrameAt: Date = .distantPast

    private nonisolated let request: VNDetectHumanBodyPoseRequest

    init(thresholds: BodyAlignmentThresholds = .default) {
        self.thresholds = thresholds
        self.request = VNDetectHumanBodyPoseRequest()
    }

    /// Reset between sessions (e.g. retake) so a stale aligned state doesn't
    /// auto-snap as soon as the detector spins back up.
    func reset() {
        sustainedAlignedFrames = 0
        alignment = .noBody
    }

    // MARK: - VideoSampleHandling

    nonisolated func process(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) {
        // Throttle to ~15fps — we don't need 30fps body pose for a coarse UX
        // signal and Vision is heavy on the CPU.
        let now = Date()
        let throttled: Bool
        let last = lastFrameAtUnsafe
        if now.timeIntervalSince(last) < (1.0 / 15.0) {
            throttled = true
        } else {
            throttled = false
            lastFrameAtUnsafe = now
        }
        if throttled { return }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return
        }

        let observation = request.results?.first
        let computed = computeAlignment(from: observation)

        Task { @MainActor [computed] in
            self.applyAlignment(computed)
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

    private nonisolated func computeAlignment(from observation: VNHumanBodyPoseObservation?) -> BodyAlignment {
        guard let observation else { return .noBody }

        let minConfidence = thresholdsSnapshot.minLandmarkConfidence
        let recognizedPoints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint] = {
            var out: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint] = [:]
            for joint in [VNHumanBodyPoseObservation.JointName.nose,
                          .neck,
                          .leftShoulder, .rightShoulder,
                          .leftHip, .rightHip,
                          .leftAnkle, .rightAnkle,
                          .leftKnee, .rightKnee] {
                if let p = try? observation.recognizedPoint(joint), p.confidence >= minConfidence {
                    out[joint] = p
                }
            }
            return out
        }()

        // Need at least a head reference + one ankle to call this a body.
        guard !recognizedPoints.isEmpty else { return .noBody }

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
            return .outOfFrame(reason: .tooClose)
        }
        if bboxWidth < t.minBoxWidthFraction {
            return .outOfFrame(reason: .tooFar)
        }

        // Centering check
        if abs(bboxCenterX - 0.5) > t.horizontalCenterTolerance {
            return .outOfFrame(reason: .offCenterX)
        }

        // Head visibility — top of bbox must sit inside top headBandFraction
        // OR the nose must exist in that band.
        let headInBand: Bool = {
            if let nose = recognizedPoints[.nose] {
                return (1.0 - Double(nose.location.y)) <= t.headBandFraction * 1.4
            }
            return minY <= t.headBandFraction
        }()
        if !headInBand {
            return .outOfFrame(reason: .headNotVisible)
        }

        // Feet visibility — at least one ankle in the bottom band, OR bbox
        // bottom inside the bottom band.
        let feetInBand: Bool = {
            if let leftAnkle = recognizedPoints[.leftAnkle] {
                if (1.0 - Double(leftAnkle.location.y)) >= (1.0 - t.feetBandFraction * 1.4) {
                    return true
                }
            }
            if let rightAnkle = recognizedPoints[.rightAnkle] {
                if (1.0 - Double(rightAnkle.location.y)) >= (1.0 - t.feetBandFraction * 1.4) {
                    return true
                }
            }
            return maxY >= (1.0 - t.feetBandFraction)
        }()
        if !feetInBand {
            return .outOfFrame(reason: .feetNotVisible)
        }

        return .closeToAligned
    }

    /// Snapshot of thresholds — taken on init and immutable for the lifetime
    /// of the detector. Avoids actor-isolation issues reading them from the
    /// nonisolated process(pixelBuffer:) path.
    private nonisolated var thresholdsSnapshot: BodyAlignmentThresholds {
        BodyAlignmentThresholds.default
    }

    private func applyAlignment(_ next: BodyAlignment) {
        switch next {
        case .closeToAligned:
            sustainedAlignedFrames += 1
            if sustainedAlignedFrames >= thresholds.sustainedFramesForAligned {
                if alignment != .aligned {
                    alignment = .aligned
                }
            } else {
                if alignment != .closeToAligned {
                    alignment = .closeToAligned
                }
            }
        default:
            sustainedAlignedFrames = 0
            if alignment != next {
                alignment = next
            }
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
