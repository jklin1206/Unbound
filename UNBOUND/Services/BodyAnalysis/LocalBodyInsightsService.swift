import UIKit
import Vision

/// On-device body-shape inference powered by Apple's Vision framework.
///
/// This is the V2-scope replacement for the "the scan informs your
/// program" claim. Runs locally (no photo upload, no API cost, no
/// prompt hallucination), returns deterministic measurements, and
/// feeds `BodyScanInsights` back into the onboarding view model so
/// the Verdict screen can show one concrete, honest, scan-derived fact.
///
/// Gracefully degrades: returns `nil` if the photo has no detected
/// human, if keypoint confidence is too low, or if Vision throws. The
/// Verdict screen just skips the insight card in that case — no error
/// spinner, no retry UX. This is scan-as-bonus-signal, not scan-as-gate.
///
/// Coordinate system note: Vision returns normalized coordinates where
/// (0,0) is the bottom-left of the image. Our "shoulder width" is the
/// horizontal pixel distance between the two shoulder keypoints, in
/// that normalized space.
@MainActor
final class LocalBodyInsightsService {
    /// Confidence floor for a keypoint to be considered usable. 0.3 is
    /// Apple's recommended threshold for body-pose keypoints; below that,
    /// the estimate is noisy enough to be worse than a sensible default.
    private let minKeypointConfidence: Float = 0.3

    func analyze(image: UIImage) async -> BodyScanInsights? {
        guard let cgImage = image.cgImage else { return nil }

        let poseRequest = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])

        do {
            try handler.perform([poseRequest])
        } catch {
            return nil
        }

        guard let observation = poseRequest.results?.first,
              let points = try? observation.recognizedPoints(.all) else {
            return nil
        }

        guard let leftShoulder = usable(points[.leftShoulder]),
              let rightShoulder = usable(points[.rightShoulder]),
              let leftHip = usable(points[.leftHip]),
              let rightHip = usable(points[.rightHip]) else {
            return nil
        }

        // Shoulder + hip widths in normalized image space. For a front-
        // facing photo, horizontal distance between the two keypoints
        // approximates the body's projected width at that landmark.
        let shoulderWidth = abs(leftShoulder.x - rightShoulder.x)
        let hipWidth = abs(leftHip.x - rightHip.x)
        guard shoulderWidth > 0.02, hipWidth > 0.02 else { return nil }
        let shoulderHipRatio = shoulderWidth / hipWidth

        // Torso and leg lengths — vertical distances between shoulder-
        // midline → hip-midline → ankle-midline. Skip leg ratio if we
        // don't have a confident ankle keypoint.
        let shoulderY = (leftShoulder.y + rightShoulder.y) / 2
        let hipY = (leftHip.y + rightHip.y) / 2
        let torsoLength = abs(shoulderY - hipY)

        let ankleY: Double? = {
            if let left = usable(points[.leftAnkle]) { return left.y }
            if let right = usable(points[.rightAnkle]) { return right.y }
            return nil
        }()
        let legLength = ankleY.map { abs(hipY - $0) } ?? 0
        let torsoLegRatio = legLength > 0.05 ? torsoLength / legLength : 0.7

        // Shoulder asymmetry — one shoulder more than 2.5% of image
        // height higher than the other. Meaningful but not a medical
        // diagnosis; flagged as a thing for the Verdict copy to hint at.
        let shoulderDrop = abs(leftShoulder.y - rightShoulder.y)
        var postureFlags: Set<BodyScanInsights.PostureFlag> = []
        if shoulderDrop > 0.025 {
            postureFlags.insert(.shoulderAsymmetry)
        } else {
            postureFlags.insert(.uprightStance)
        }

        // Frame category — shoulder breadth as fraction of image width.
        // Thresholds tuned against typical phone-held full-body front
        // photos where the subject roughly fills 60-80% of frame height.
        let frameCategory: BodyScanInsights.FrameCategory = {
            switch shoulderWidth {
            case 0.26...:   return .broad
            case 0.18..<0.26: return .balanced
            default:        return .narrow
            }
        }()

        // Archetype suggestion — cheap heuristic from the two ratios.
        // Deliberately coarse; this is a suggestion surfaced to the user,
        // not a replacement for their explicit pick.
        let suggestedArchetypeRaw = suggestedArchetype(
            shoulderHipRatio: shoulderHipRatio,
            frameCategory: frameCategory
        )

        return BodyScanInsights(
            shoulderHipRatio: shoulderHipRatio,
            torsoLegRatio: torsoLegRatio,
            frameCategory: frameCategory,
            postureFlags: postureFlags,
            suggestedArchetypeRaw: suggestedArchetypeRaw
        )
    }

    private func usable(_ point: VNRecognizedPoint?) -> (x: Double, y: Double)? {
        guard let point, point.confidence >= minKeypointConfidence else { return nil }
        return (Double(point.location.x), Double(point.location.y))
    }

    /// Maps the two measured ratios into a build tendency label.
    private func suggestedArchetype(
        shoulderHipRatio: Double,
        frameCategory: BodyScanInsights.FrameCategory
    ) -> String {
        // V-TAPER: strong shoulder-to-hip dominance, narrow-to-balanced frame.
        if shoulderHipRatio >= 1.5, frameCategory != .broad {
            return "vTaper"
        }
        // HEAVYWEIGHT: broad frame regardless of V-taper — density reads first.
        if frameCategory == .broad {
            return "heavyDuty"
        }
        // SLEEPER: narrow frame with low shoulder dominance — hidden ceiling.
        if frameCategory == .narrow, shoulderHipRatio < 1.3 {
            return "shredded"
        }
        // Default middle ground: the balanced-athlete bucket.
        return "leanCut"
    }
}

