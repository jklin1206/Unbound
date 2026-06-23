import SwiftUI

extension FormPhaseLibrary {
    static func hollowBodyPhases(assetPrefix: String? = nil) -> [FormPhase] {
        [
            phase("phase1", "Brace", "Lie on your back and lock the pelvis first: ribs down, tailbone slightly tucked, low back sealed to the floor. If the low back lifts, the set has already drifted.", "figure.core.training", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Short Hollow", "Lift shoulders and bent legs while keeping the spine glued down. Use this tucked shape until you can breathe normally without losing the brace.", "arrow.up.left.and.arrow.down.right", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Long Hollow", "Reach arms and legs longer only as far as the low back stays pressed down. Legs low with an arched back is not harder; it is just a broken hollow.", "rectangle.expand.vertical", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Transfer", "Use the same ribs-down body line in rocks, hangs, levers, and handstands. The point is not just ab burn; it is owning one clean trunk shape under motion.", "arrow.triangle.2.circlepath", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    static func forearmPlankPhases() -> [FormPhase] {
        let assetPrefix = "cal_plank-30"
        return [
            phase("phase1", "Stack", "Set forearms on the floor with elbows under shoulders. Root the forearms before lifting into the hold.", "rectangle.compress.vertical", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Brace", "Zip ribs toward hips, lightly squeeze glutes and quads, and keep the neck long.", "figure.core.training", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Hold", "Keep one long line from head to heels while breathing quietly. No sag, pike, or shoulder collapse.", "timer", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Lower", "Lower with the same line you held. Knees or hips touch down only after the ribs, shoulders, and pelvis stay organized.", "arrow.down.to.line", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    static func coreFlexionPhases(skillId: String) -> [FormPhase] {
        let assetPrefix = skillId.replacingOccurrences(of: ".", with: "_")
        switch skillId {
        case "cl.reverse-crunch":
            return [
                phase("phase1", "Tabletop", "Start on your back with knees bent, shins lifted, and shoulders grounded. The setup should be still before the curl.", "figure.core.training", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Brace", "Flatten ribs and steady the pelvis. Hands can press lightly into the floor for control.", "rectangle.compress.vertical", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Curl", "Peel the tailbone toward the ribs without throwing the knees. Keep the motion small and heavy.", "arrow.up.circle.fill", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Control", "Return slowly without leg swing or low-back arch. Reset before the next rep.", "metronome", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "cl.levitation-crunch":
            return [
                phase("phase1", "Hollow", "Hover shoulders and legs with the low back pressed down. Shorten the lever if the spine lifts.", "circle.hexagongrid.fill", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Gather", "Bring knees and ribs toward center together. The neck does not yank the rep.", "rectangle.compress.vertical", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Compress", "Pause briefly in the tight shape while the low back stays heavy.", "pause.circle.fill", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Reopen", "Extend back to a quiet hollow hover without dropping shoulders or heels.", "arrow.up.left.and.arrow.down.right", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "cl.inverted-situp":
            return [
                phase("phase1", "Anchor", "Secure the hook or grip before moving. The inverted setup must feel stable first.", "lock.fill", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Brace", "Lock ribs and pelvis while upside down. Stop if the anchor shifts.", "figure.core.training", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Curl", "Fold the trunk toward the legs or bar like a strict crunch, not a swing.", "arrow.up.circle.fill", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Lower", "Return slowly without whipping the spine or losing the hook.", "arrow.down.circle.fill", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "cl.decline-situp":
            return [
                phase("phase1", "Lock In", "Secure feet and choose a modest bench angle. More decline only counts if control stays clean.", "lock.fill", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Brace", "Set ribs down and pelvis controlled before the torso leaves the bench.", "rectangle.compress.vertical", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Rise", "Curl first, then sit tall. Do not yank the head or rely only on hip flexors.", "arrow.up", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Descend", "Lower slowly with ribs down. No flopping into a back arch.", "arrow.down", assetName: assetName(assetPrefix, "phase4"))
            ]
        default:
            return [
                phase("phase1", "Set", "Plant feet, support the head lightly if needed, and keep elbows wide. The hands do not pull.", "figure.core.training", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Exhale", "Exhale and soften ribs down before lifting. The low back stays controlled.", "wind", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Curl", "Lift shoulder blades by drawing ribs toward pelvis. Small and precise beats high and sloppy.", "rectangle.compress.vertical", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Uncurl", "Lower vertebra by vertebra until the shoulder blades touch down.", "arrow.down", assetName: assetName(assetPrefix, "phase4"))
            ]
        }
    }

    static func antiRotationPhases(skillId: String) -> [FormPhase] {
        let isBirdDog = skillId == "cl.bird-dog-plank"
        let prefix = isBirdDog ? "cl_bird-dog-plank" : "cl_superman-plank"
        return [
            phase("phase1", "Stack", "Start with ribs stacked over pelvis, glutes lightly on, and hands pressing the floor away. Do not begin the reach from a sagging plank.", "rectangle.compress.vertical", assetName: assetName(prefix, "phase1")),
            phase("phase2", "Brace", "Brace like someone is about to nudge your ribs sideways. The trunk should stay quiet before any limb leaves the floor.", "shield.lefthalf.filled", assetName: assetName(prefix, "phase2")),
            phase("phase3", isBirdDog ? "Reach" : "Long Lever", isBirdDog ? "Extend the opposite arm and leg without letting the hips roll open. Arm stays near shoulder height; leg stays near hip height." : "Reach the limbs long while the hips stay level. A higher leg or twisted torso makes the hold easier and less useful.", "arrow.up.left.and.arrow.down.right", assetName: assetName(prefix, "phase3")),
            phase("phase4", "Return", "Bring the limbs back slowly, then switch sides. The return should be as controlled as the hold, with no hip drop when the support changes.", "arrow.uturn.backward", assetName: assetName(prefix, "phase4"))
        ]
    }

    static func rolloutPlankPhases(skillId: String) -> [FormPhase] {
        let isRollout = skillId.contains("rollout")
        let prefix = skillId.replacingOccurrences(of: ".", with: "_")
        return [
            phase("phase1", isRollout ? "Start" : "Reach", isRollout ? "Set ribs down, glutes on, and shoulders active before the wheel moves. The spine position is the skill." : "Walk hands forward only as far as the ribs stay tucked and the hips stay level.", "figure.core.training", assetName: assetName(prefix, "phase1")),
            phase("phase2", "Extend", isRollout ? "Roll out slowly while keeping a hollow body. Stop before the low back sags; range is earned, not forced." : "Hold the longer lever with shoulders packed and neck neutral. Hands farther forward only counts if the body line survives.", "arrow.forward", assetName: assetName(prefix, "phase2")),
            phase("phase3", "End Range", "Pause at the hardest point without breath-holding or collapsing the shoulders. If the brace breaks, shorten the lever on the next set.", "pause.circle.fill", assetName: assetName(prefix, "phase3")),
            phase("phase4", "Return", isRollout ? "Pull back with lats and abs together. Do not pike the hips first to escape the hard range." : "Walk the hands back under control with ribs tucked and shoulders active. The return should not turn into a sudden hip pike or shoulder shrug.", "arrow.backward", assetName: assetName(prefix, "phase4"))
        ]
    }

    static func raisePhases(skillId: String) -> [FormPhase] {
        let hanging = skillId.contains("hanging") || skillId == "cl.toes-to-bar"
        let straight = skillId.contains("leg") || skillId == "cl.toes-to-bar"
        let prefix = skillId.replacingOccurrences(of: ".", with: "_")
        return [
            phase("phase1", hanging ? "Active Hang" : "Set", hanging ? "Hang with shoulders pulled down enough that the body is quiet. Start each rep from control, not from a pendulum." : "Press the low back down and set the pelvis before the legs move. The floor version trains the same anti-arch position as harder hanging raises.", hanging ? "figure.hanging" : "figure.core.training", assetName: assetName(prefix, "phase1")),
            phase("phase2", straight ? "Lift" : "Tuck", straight ? "Raise straight legs from the pelvis, not by throwing the feet. Keep knees locked only if the trunk can stay controlled." : "Drive knees toward the chest and curl the pelvis at the top. A waist-high knee lift is not the same as a tight knee raise.", "arrow.up", assetName: assetName(prefix, "phase2")),
            phase("phase3", skillId == "cl.toes-to-bar" ? "Touch" : "Curl", skillId == "cl.toes-to-bar" ? "Compress until the toes actually reach the bar between the hands. If the knees bend or the body swings, regress to strict leg raises." : "Finish with a small posterior pelvic curl so the abs do more than the hip flexors. Keep the bar or floor quiet.", "scope", assetName: assetName(prefix, "phase3")),
            phase("phase4", "Lower", "Lower slower than you lifted. Do not let gravity drop the legs and create the next rep's swing.", "arrow.down", assetName: assetName(prefix, "phase4"))
        ]
    }

    static func lSitFamilyPhases(skillId: String) -> [FormPhase] {
        let prefix = skillId.replacingOccurrences(of: ".", with: "_")
        let target = skillId == "cl.v-sit" ? "above horizontal" : "near horizontal"
        return [
            phase("phase1", "Support", "Press the floor, bars, or parallettes down until the shoulders move away from the ears. Elbows stay locked before the legs lift.", "arrow.down.to.line", assetName: assetName(prefix, "phase1")),
            phase("phase2", "Tuck", "Lift the hips and bring knees toward the chest. This teaches support strength and compression without forcing hamstrings to decide the skill.", "figure.core.training", assetName: assetName(prefix, "phase2")),
            phase("phase3", skillId.contains("straddle") ? "Open" : "Extend", skillId.contains("straddle") ? "Open the legs only as wide as you can keep them lifted. Both knees stay locked and both legs stay above the hands." : "Extend one or both legs while keeping the hips off the floor. Quads stay on; toes point; shoulders do not shrug.", "arrow.left.and.right", assetName: assetName(prefix, "phase3")),
            phase("phase4", "Hold", "Hold the final shape with legs \(target), arms locked, and breathing steady. End the set when the hips sink or knees soften.", "checkmark.seal.fill", assetName: assetName(prefix, "phase4"))
        ]
    }

    static func frontLeverPhases(skillId: String) -> [FormPhase] {
        let prefix = skillId.replacingOccurrences(of: ".", with: "_")
        let phase4Title: String
        let phase4Instruction: String
        switch skillId {
        case "cl.full-front-lever":
            phase4Title = "Full Lever"
            phase4Instruction = "Bring legs together only when the horizontal body line stays quiet. The final hold is face-up, straight-arm, and ribs-down from shoulders to toes."
        case "cl.straddle-front-lever":
            phase4Title = "Hip Line"
            phase4Instruction = "Hold the straddle with hips level to the shoulders, elbows locked, toes pointed, and ribs down. End the set when the hips sink or the arms bend."
        default:
            phase4Title = "Hold"
            phase4Instruction = "Own the tuck with shoulders depressed, elbows locked, ribs down, and no swing. Short clean holds beat longer sets that drift below the line."
        }
        return [
            phase("phase1", "Tuck", "Start from straight arms and a tight tuck. Depress the shoulders, pull the hands toward the hips, and bring hips to shoulder height before lengthening the lever.", "figure.hanging", assetName: assetName(prefix, "phase1")),
            phase("phase2", "Open Tuck", "Open the hips slightly while keeping ribs down and elbows locked. If the back arches or hips drop, return to the tighter tuck.", "rectangle.expand.vertical", assetName: assetName(prefix, "phase2")),
            phase("phase3", skillId == "cl.tuck-front-lever" ? "Line Check" : "Straddle", skillId == "cl.tuck-front-lever" ? "Hold the shortest lever perfectly: shoulders down, arms straight, and hips level. This is the shape that buys every later progression." : "Extend into a wide straddle with toes pointed and hips level. A wide clean straddle beats a narrow, sagging one.", "arrow.left.and.right", assetName: assetName(prefix, "phase3")),
            phase("phase4", phase4Title, phase4Instruction, "checkmark.seal.fill", assetName: assetName(prefix, "phase4"))
        ]
    }

    static func backLeverPhases(skillId: String) -> [FormPhase] {
        let prefix = skillId.replacingOccurrences(of: ".", with: "_")
        let isTuckBackLever = skillId == "cl.tuck-back-lever"
        let isStraddleBackLever = skillId == "cl.straddle-back-lever"
        let isFullBackLever = skillId == "cl.full-back-lever"
        if skillId == "cl.german-hang" {
            return [
                phase("phase1", "Invert", "Move through a skin-the-cat entry slowly. Use low rings or foot assistance if the shoulders cannot control the descent.", "figure.gymnastics", assetName: assetName(prefix, "phase1")),
                phase("phase2", "Pass", "Keep elbows straight as the body passes through. The rings stay quiet and the shoulders open gradually instead of dropping into the bottom.", "arrow.down.backward", assetName: assetName(prefix, "phase2")),
                phase("phase3", "German Hang", "Hold the deepest pain-free range with calm breathing. Arms stay behind the torso, elbows stay straight, and the shoulders do not get dumped into the joint.", "lungs.fill", assetName: assetName(prefix, "phase3")),
                phase("phase4", "Return", "Reverse the exact path back through inverted hang. The exit is part of the standard, not an optional escape.", "arrow.uturn.backward", assetName: assetName(prefix, "phase4"))
            ]
        }
        if skillId == "cl.skin-the-cat" {
            return [
                phase("phase1", "Hang", "Start from a quiet straight-arm ring hang. Set the shoulders and stop any swing before the pass-through begins.", "figure.hanging", assetName: assetName(prefix, "phase1")),
                phase("phase2", "Invert", "Tuck or pike the legs overhead with straight arms. Keep the rings still and the ribs controlled.", "arrow.up.forward", assetName: assetName(prefix, "phase2")),
                phase("phase3", "Pass", "Lower through the back side slowly into a pain-free German hang. Do not drop into the bottom.", "arrow.down.circle.fill", assetName: assetName(prefix, "phase3")),
                phase("phase4", "Return", "Reverse the motion back to inverted hang and then to a quiet hang. Count only reps you can bring home under control.", "arrow.triangle.2.circlepath", assetName: assetName(prefix, "phase4"))
            ]
        }

        let phase3Title: String
        let phase3Instruction: String
        if isTuckBackLever {
            phase3Title = "Line Check"
            phase3Instruction = "Keep the knees packed, elbows locked, and shoulders active as the hips approach shoulder height. The lever is still valid even though the body stays compact."
        } else if isFullBackLever || isStraddleBackLever {
            phase3Title = "Straddle"
            phase3Instruction = "Open into a wide straddle with glutes squeezed and ribs down. Widen the legs as needed to keep the body line honest."
        } else {
            phase3Title = "Control"
            phase3Instruction = "Move in and out of the bottom slowly. If the shoulders shock-load or elbows bend, regress the range."
        }

        let phase4Title: String
        let phase4Instruction: String
        if isFullBackLever {
            phase4Title = "Full Lever"
            phase4Instruction = "Bring legs together into a face-down horizontal line only when the shoulders, elbows, and trunk stay calm."
        } else if isTuckBackLever {
            phase4Title = "Tuck Hold"
            phase4Instruction = "Hold the compact face-down tuck with shoulders active, elbows locked, ribs controlled, and rings quiet. End the set before the hips sink or the tuck loosens."
        } else {
            phase4Title = "Hold Line"
            phase4Instruction = "Hold the straddle with shoulders active, elbows locked, glutes squeezed, and hips level. End the set before the rings drift or the body folds."
        }

        return [
            phase("phase1", "German Hang", "Enter shoulder extension slowly through a skin-the-cat path. Stop before pain; this position is mobility and connective-tissue prep, not a dare.", "figure.gymnastics", assetName: assetName(prefix, "phase1")),
            phase("phase2", "Tuck", "Keep elbows locked and tuck knees tight while lowering toward horizontal. Shoulders stay active; the body does not dump into the front of the joint.", "figure.core.training", assetName: assetName(prefix, "phase2")),
            phase("phase3", phase3Title, phase3Instruction, "arrow.left.and.right", assetName: assetName(prefix, "phase3")),
            phase("phase4", phase4Title, phase4Instruction, "checkmark.seal.fill", assetName: assetName(prefix, "phase4"))
        ]
    }

    static func threeSixtyPullPhases() -> [FormPhase] {
        let prefix = "cl_three-sixty-pulls"
        return [
            phase("phase1", "Active Hang", "Start from a quiet straight-arm ring hang. Set shoulders down, keep the ribs organized, and remove swing before the arc begins.", "figure.hanging", assetName: assetName(prefix, "phase1")),
            phase("phase2", "Front Lane", "Sweep through the front-lever lane with elbows locked, rings held continuously, and the body moving as one piece. This is a controlled shoulder circle, not a pull-up.", "arrow.up.forward.circle.fill", assetName: assetName(prefix, "phase2")),
            phase("phase3", "German Range", "Pass through the back side into a pain-free German-hang range: arms behind the torso, shoulders open, elbows straight, and rings quiet. Stop before the shoulders dump.", "figure.gymnastics", assetName: assetName(prefix, "phase3")),
            phase("phase4", "Reverse", "Reverse the exact path back through the rings without releasing or bending the arms. Count only the range you can bring home under control.", "arrow.triangle.2.circlepath", assetName: assetName(prefix, "phase4"))
        ]
    }

    static func dragonFlagPhases(skillId: String) -> [FormPhase] {
        let prefix = skillId.replacingOccurrences(of: ".", with: "_")
        return [
            phase("phase1", "Anchor", "Grip the bench, post, or pads hard enough that the shoulders stay pinned. The hands anchor the body; the neck should not strain.", "hand.raised.fill", assetName: assetName(prefix, "phase1")),
            phase("phase2", "Lift", "Raise hips until the body forms one rigid line from shoulders to toes. Do not pike just to get the feet higher.", "arrow.up", assetName: assetName(prefix, "phase2")),
            phase("phase3", skillId == "cl.dragon-flag" ? "Lower" : "Hip Line", skillId == "cl.dragon-flag" ? "Lower as one piece for several seconds. The rep ends when the hips fold, the back arches, or the shoulders lose the anchor." : "Own the straight-body top before chasing full negatives. The hip raise is the bridge between reverse crunches and the flag.", "line.diagonal", assetName: assetName(prefix, "phase3")),
            phase("phase4", "Reset", "Reset cleanly between reps instead of bouncing off the bottom. Dragon flag work should feel precise, not like a swinging sit-up.", "arrow.clockwise", assetName: assetName(prefix, "phase4"))
        ]
    }

}
