import SwiftUI

extension FormPhaseLibrary {
    static func hangPhases(assetPrefix: String? = nil) -> [FormPhase] {
        [
            phase("phase1", "Grip", "Set both hands just outside shoulder width, wrap the bar securely, and let the body settle before loading the hang. If grip is the limiter, use shorter clean holds instead of twisting on the bar.", "hand.raised.fill", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Shoulders", "Reach long through straight arms, then keep the shoulders active enough that the neck stays long and the ears do not swallow the shoulders. This active bottom becomes the start of every pull.", "arrow.down.circle.fill", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Body Line", "Keep ribs down, glutes lightly squeezed, and legs together. The hold should look still from the side, not like a swing building momentum.", "figure.core.training", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Finish", "End by stepping down or releasing under control. Do not turn the last second into a sudden drop from loose shoulders.", "checkmark.seal.fill", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    static func verticalPullPhases(title: String, grip: String, top: String, assetPrefix: String? = nil) -> [FormPhase] {
        [
            phase("phase1", "Set", "\(grip) Start from straight arms with ribs down, glutes lightly on, and legs quiet. Pause long enough that the body is not swinging before the pull begins.", "figure.climbing", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Initiate", "Begin by pulling the shoulder blades down and slightly back. The elbows have not done the whole job yet; this sets the lats and keeps the neck from shrugging.", "arrow.down.backward", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Pull", "\(top) Keep the path smooth and vertical. If the chin reaches forward or the knees kick, use assistance or fewer reps.", "arrow.up", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Lower", "Lower under control until the arms are straight again. The rep is not finished at the top; the controlled return proves you own the full range.", "arrow.down", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    static func chinUpPhases(assetPrefix: String? = nil) -> [FormPhase] {
        [
            phase("phase1", "Chin Grip", "Set both hands shoulder-width or slightly narrower. From your perspective, the knuckles wrap over the far side of the bar; from a front camera, the knuckle side of both hands is visible. Keep thumbs underneath and wrists stacked.", "hand.raised.fill", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Pull", "Begin the pull without letting the hands roll. The camera should still see knuckles, not open palms, while elbows drive down and slightly forward under the bar.", "arrow.up", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Top", "Clear the chin with the same hand shape: knuckle side visible from the front, thumbs underneath, wrists not folded over, elbows close to the ribs, and shoulders down.", "scope", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Lower", "Lower to straight arms while the grip stays unchanged. If a front view no longer shows the knuckle side clearly, reset before the next rep.", "arrow.down", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    static func weightedPullPhases(isChin: Bool, assetPrefix: String? = nil) -> [FormPhase] {
        let name = isChin ? "weighted chin-up" : "weighted pull-up"
        let grip = isChin ? "supinated chin-up grip" : "overhand pull-up grip"
        if isChin {
            return [
                phase("phase1", "Load", "Set the load, then take a true chin grip: from your perspective, knuckles wrap over the far side of the bar; from a front camera, the knuckle side is visible. Keep thumbs underneath and start from straight arms.", "scalemass.fill", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Brace", "Brace before pulling while the grip stays visibly underhand. A front view should show knuckles on both hands, wrists stacked, elbows ready to travel down and slightly forward, and the load quiet.", "figure.core.training", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Pull", "Pull with the same hand orientation the whole way. The camera should still see knuckles, thumbs stay wrapped underneath, elbows drive down and forward, and the wrists do not roll into overhand.", "arrow.up", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Control", "Lower until the arms are straight while the grip stays unchanged. If the load makes the visible knuckles disappear or the grip flip, reduce weight before adding reps.", "arrow.down", assetName: assetName(assetPrefix, "phase4"))
            ]
        }
        return [
            phase("phase1", "Load", "Attach the load so it hangs still. Step or jump carefully to the bar and wait for the plate, vest, or dumbbell to stop swinging before starting the \(name).", "scalemass.fill", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Brace", "Set a \(grip), straighten the arms, brace the trunk, and keep the legs quiet. The added weight should not pull the body into an arch or swing.", "figure.core.training", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Pull", "Pull with the same standard as the bodyweight version: shoulder blades set, elbows drive down, and chin clears the bar without shortening the range.", "arrow.up", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Control", "Lower until the arms are straight while the load stays quiet. If the plate swings or range disappears, reduce weight before adding reps.", "arrow.down", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    static func explosivePullPhases(isClapping: Bool, assetPrefix: String? = nil) -> [FormPhase] {
        [
            phase("phase1", "Dead Stop", "Start from a still active hang. Explosive work begins from control; do not preload the rep with a hidden swing or knee kick.", "pause.circle.fill", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Snap", "Pull as hard and fast as possible while staying hollow. Think bar toward lower chest, not chin barely over bar.", "bolt.fill", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", isClapping ? "Release" : "Height", isClapping ? "Only release when the pull is high enough that both hands can leave the bar, clap once, and return to the bar without panic." : "Measure the rep by height. Stop the set when the body no longer reaches the same target.", "arrow.up.forward", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Absorb", "Re-grip or finish the high pull with active shoulders, then lower under control. Power reps still need a clean landing.", "arrow.down.forward", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    static func archerPullPhases(assetPrefix: String? = nil) -> [FormPhase] {
        [
            phase("phase1", "Wide Set", "Take a wide overhand grip and start from a full, still hang. Pick a width that allows one arm to straighten without shoulder pain.", "arrow.left.and.right", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Shift", "Pull toward one hand while the opposite arm stays long. The straight arm guides the path; the working arm does most of the pull.", "arrow.up.left", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Finish", "Bring the chest toward the working hand without spinning the torso open. If both elbows bend equally, regress to banded archers or archer rows.", "scope", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Return", "Lower back to a full hang under control before switching sides or repeating. Match the weaker side instead of letting the stronger side define the set.", "arrow.down", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    static func soloArmPhases(skillId: String, assetPrefix: String? = nil) -> [FormPhase] {
        let isNegative = skillId == "pp.oap-negative"
        let isChin = skillId == "pp.one-arm-chin-up"
        let hangTitle = isChin ? "Chin Hang" : (isNegative ? "Top Set" : "One-Arm Hang")
        let hangInstruction = isNegative ? "Start at the top with one hand on the bar, shoulder packed, and torso quiet. Use a box or assist hand to arrive cleanly instead of jumping into chaos." : (isChin ? "Start from an active one-arm hang with the working hand supinated: from your perspective, knuckles wrap over the far side of the bar; from a front camera, knuckles are visible. Thumb stays underneath and free arm stays off the bar." : "Start from an active one-arm hang. Pull the shoulder down away from the ear before bending the elbow.")
        let pullInstruction = isNegative ? "Lower slowly through the full range without dropping, shrugging, or spinning out. Use assistance if any part becomes a fall." : (isChin ? "Pull the elbow down and slightly forward while the hand stays underhand. The camera should still see the knuckle side of the working hand, and the body resists twisting into the bar." : "Pull the elbow toward the ribs or hip while resisting rotation. Some body turn is normal; wild twisting means the assist level is too low.")
        return [
            phase("phase1", hangTitle, hangInstruction, "hand.raised.fill", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Scap First", isChin ? "Keep the working hand underhand while the shoulder blade depresses. From the front, the knuckle side stays visible; the palm does not open toward the camera." : "Depress and slightly retract the shoulder blade. This tiny first movement protects the shoulder and gives the elbow a stronger path.", "arrow.down.circle.fill", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", isNegative ? "Lower" : "Pull", pullInstruction, "arrow.up", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Control", isChin ? "Lower without letting the working wrist roll over the bar. A front view should still show knuckles, and any grip flip means the rep should be reset." : "Finish with a controlled lower or controlled top. Keep volume low and stop if elbow tendon pain rises during the session.", "exclamationmark.triangle.fill", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    static func heightedChinPhases(assetPrefix: String? = nil) -> [FormPhase] {
        [
            phase("phase1", "Chin Grip", "Set a true chin grip: from your perspective, knuckles wrap over the far side of the bar; from a front camera, the knuckle side is visible. Thumbs wrap underneath and hands stay shoulder-width or slightly narrower.", "hand.raised.fill", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "High Pull", "Keep the grip readable as the elbows drive down and slightly forward. The camera should still see knuckles, and the chest rises close without the wrists rolling over.", "arrow.up", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Chest To Bar", "Pull until the upper chest or collarbone reaches the bar with the underhand grip still intact: visible knuckles from the front, thumbs underneath, forearms under the hands. A grip-flipped pull-up does not count.", "scope", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Control", "Lower under control back to straight arms while preserving the same visible-knuckle chin grip. Stop the set once height, range, or grip orientation starts fading.", "arrow.down", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    static func lSitChinPhases(assetPrefix: String? = nil) -> [FormPhase] {
        [
            phase("phase1", "L Set", "Take a chin-up grip first: from your perspective, knuckles wrap over the far side of the bar; from a front camera, the knuckle side is visible. Then raise the legs toward horizontal and lock in the hollow trunk.", "figure.core.training", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Pull", "Keep the L shape while driving elbows down and slightly forward. The hands stay underhand with visible knuckles from the front; do not let the wrist roll into a pull-up grip.", "arrow.up", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Top", "Pause briefly with the chin over the bar, legs still lifted, and knuckles still visible from the front. Do not let the knees bend or the grip flip to steal the finish.", "pause.circle.fill", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Lower", "Return to straight arms while maintaining the L and the same hand orientation. If the front view no longer shows the knuckle side, reset before the next rep.", "arrow.down", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    static func rowPhases(skillId: String) -> [FormPhase] {
        if skillId == "pp.tuck-row" || skillId == "pp.straddle-row" || skillId == "pp.tuck-front-lever-pullup" {
            let shape = skillId == "pp.straddle-row" ? "straddle front-lever shape" : "tucked front-lever shape"
            let assetPrefix = "pp_tuck-row"
            return [
                phase("phase1", "Lever Set", "Set a \(shape) before bending the arms. Shoulders stay depressed, ribs stay down, and hips stay high enough to match the chosen lever.", "figure.core.training", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Pull", "Row from the lever without opening the tuck, dropping the hips, or turning it into a normal pull-up. Use band assistance or a shorter range if the shape changes.", "arrow.up", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Top", "Pause at the top while keeping the same lever. The row only counts if the body line survives the hardest point.", "pause.circle.fill", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Return", "Lower back into the same lever shape under control. If the eccentric collapses, regress the lever or reduce reps.", "arrow.down", assetName: assetName(assetPrefix, "phase4"))
            ]
        }

        let oneArm = skillId == "pp.one-arm-row"
        let decline = skillId == "pp.decline-row"
        let standardRow = skillId == "pp.row"
        let assetPrefix = oneArm ? "pp_one-arm-row" : (standardRow ? "pp_row" : "pp_incline-row")
        return [
            phase("phase1", "Set Angle", decline ? "Set the bar or rings so the body is near horizontal, often with feet elevated. Keep a straight line from head to heels." : (standardRow ? "Set a low bar or rings so the body is close to horizontal, heels grounded, and the chest can reach the hands without neck reaching." : "Set the bar or rings high enough that every rep can reach the same top. Walk the feet forward to make it harder, back to make it easier."), "slider.horizontal.3", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Brace", oneArm ? "Brace hard and keep the torso square. The free hand may assist lightly at easier levels, but it cannot twist the body into the finish." : "Squeeze glutes, keep ribs down, and start with straight arms. The body should feel like a plank before the elbows bend.", "rectangle.compress.vertical", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Row", oneArm ? "Pull with one arm while resisting rotation. The working elbow travels back; the torso stays quiet." : "Pull the lower chest or ribs toward the bar. Lead with shoulder blades and elbows, not the chin.", "arrow.up", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Lower", "Pause briefly at the top, then lower to straight arms without hips sagging. Progress only when every rep keeps the same body line.", "arrow.down", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

}
