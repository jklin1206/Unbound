import SwiftUI

extension FormPhaseLibrary {
    static func pushupPhases(skillId: String) -> [FormPhase] {
        let isIncline = skillId == "cal.incline-pushup"
        let isDecline = skillId == "cal.decline-pushup"
        let assetPrefix = skillId.replacingOccurrences(of: ".", with: "_")
        return [
            phase("phase1", "Plank Set", isIncline ? "Set hands on a stable elevated surface and walk feet back until the body forms one straight line. Brace ribs, glutes, and quads before bending the elbows." : (isDecline ? "Set feet on a stable box and hands on the floor under the chest. Keep ribs down so the elevated feet do not turn the rep into a banana-back press." : "Start in a strong plank with hands under the chest, ribs tucked, glutes squeezed, and legs quiet. The push-up is a moving plank before it is a chest exercise."), "rectangle.compress.vertical", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Descend", "Lower the chest and hips together. Elbows travel diagonally back around 30-45 degrees instead of flaring straight out to the sides.", "arrow.down", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Depth", isIncline ? "Touch the chest to the bench or box without losing the plank line. If you cannot reach the surface, raise the hands higher." : "Reach full depth with chest near the floor while the neck stays neutral. The head should not dive ahead of the torso.", "scope", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Lockout", "Press the floor away until elbows lock and shoulders stay active. Finish in the same body line you started with before the next rep.", "checkmark.seal.fill", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    static func closePushPhases(skillId: String) -> [FormPhase] {
        let isSphinx = skillId == "cal.sphinx-pushup"
        let assetPrefix = skillId.replacingOccurrences(of: ".", with: "_")
        return [
            phase("phase1", "Narrow Set", isSphinx ? "Start in a forearm plank with elbows under shoulders, ribs down, and glutes tight. The trunk stays one piece before the triceps press begins." : "Set hands close under the sternum. A true diamond is optional; use a pain-free close grip if wrists or elbows complain.", "hand.raised.fill", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Elbows Back", isSphinx ? "Press through the forearms and begin extending the elbows while the hips stay level. Do not pike up to escape the triceps load." : "Lower with elbows tracking back near the ribs. The close grip should load triceps, not force the shoulders into a flare.", "arrow.down.backward", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Full Range", isSphinx ? "Reach the hardest middle range with forearms still controlling the floor. Keep the neck long and shoulders away from the ears." : "Bring the chest toward the hands without cutting depth. If range vanishes, use an incline close-grip variation.", "scope", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Triceps Lock", "Finish with a clear elbow lockout and active shoulders. The last inch of extension is the point of the close-grip path.", "checkmark.seal.fill", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    static func dipPhases(skillId: String) -> [FormPhase] {
        let isBench = skillId == "cal.bench-dip"
        let assetPrefix = skillId.replacingOccurrences(of: ".", with: "_")
        return [
            phase("phase1", "Support", isBench ? "Set hands on a stable bench behind the hips and keep the hips close to the edge. Shoulders stay controlled before the first descent." : "Start in a locked parallel-bar support with shoulders depressed, elbows straight, and body still. If support shakes, train holds first.", "pause.circle.fill", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Lower", "Bend the elbows under control and keep them tracking back. Do not dive-bomb into the bottom or let the shoulders shrug toward the ears.", "arrow.down", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Bottom", isBench ? "Stop at the deepest pain-free range with shoulders still organized. Bench dips are a regression, not a reason to crank the shoulder forward." : "Reach shoulders level with or slightly below elbows only if mobility allows. The bottom should feel loaded, not collapsed.", "scope", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Press Out", "Press the bars or bench down until elbows lock and shoulders stay active. Pause briefly at support before the next rep.", "checkmark.seal.fill", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    static func ringDipPhases() -> [FormPhase] {
        let assetPrefix = "cal_ring-dip"
        return [
            phase("phase1", "RTO Support", "Begin in a still ring support with elbows locked and rings turned out if possible. The top support is part of the rep, not a place to rush through.", "pause.circle.fill", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Rings Close", "Lower slowly while the rings stay close to the ribs. If they drift wide, use foot assistance or support holds.", "arrow.down", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Controlled Bottom", "Reach the deepest stable bottom without shoulder collapse. Rings should not wobble wildly or flare away from the body.", "scope", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Turn Out", "Press back to a locked support and turn the rings out at the top. Pause until the rings are still before the next rep.", "rotate.right.fill", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    static func pikePushPhases(skillId: String) -> [FormPhase] {
        let assetPrefix = skillId.replacingOccurrences(of: ".", with: "_")
        let isElevated = skillId == "cal.elevated-pike-pushup"
        let isFloating = skillId == "cal.floating-pike-pushup"
        return [
            phase("phase1", "Pike Stack", isFloating ? "Start from a tuck or straddle support on parallettes with feet off the floor. Hips stack high and shoulders stay active before the press." : (isElevated ? "Place feet on a box and walk hands in until hips stack high. Increase box height only when the line stays controlled." : "Walk feet in and lift hips high so the body resembles an inverted V. This is vertical pressing practice, not a regular push-up."), "triangle.fill", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Tripod Path", "Lower the head between the hands into a tripod-like path. Elbows bend diagonally back instead of flaring straight sideways.", "arrow.down.forward", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Head Target", "Touch the top of the head lightly or reach a controlled target. Do not crash into the floor or let the hips drift backward.", "scope", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Press Tall", "Press the floor away and return hips over shoulders. Think up toward handstand, not back into an easier push-up angle.", "arrow.up", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    static func handstandPushPhases() -> [FormPhase] {
        let assetPrefix = "cal_handstand-pushup"
        return [
            phase("phase1", "Handstand Line", "Start in a stable wall or freestanding handstand. Hands are around shoulder width, ribs tucked, glutes on, and shoulders pushed tall.", "figure.handball", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Toes To Wall", "Lower under control so the head moves slightly in front of the hands. In a chest-to-wall rep, keep the toes pointed toward the wall instead of turning the feet away or planting the heels.", "triangle.fill", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Soft Touch", "Lightly touch the head or pad without collapsing onto the neck. Use partial range if the descent becomes a crash.", "scope", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Tall Lockout", "Press to full elbow lockout and push tall through the shoulders. Keep ribs tucked so the finish is a handstand, not a backbend.", "checkmark.seal.fill", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    static func ninetyDegreePushPhases() -> [FormPhase] {
        let assetPrefix = "cal_ninety-degree-pushup"
        return [
            phase("phase1", "Handstand Set", "Start from a stacked handstand with elbows locked, shoulders tall, ribs tucked, and eyes between the hands. The line has to be quiet before the descent begins.", "figure.handball", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Shoulders Forward", "Lean the shoulders far past the wrists before the elbows bend. The hands stay near the balance point under the body mass instead of sitting back like a regular push-up.", "arrow.down.forward", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Floating 90", "Reach a true bent-arm planche shape: elbows near 90 degrees, shoulders forward of the wrists, hands under the center of mass, and feet completely off the floor.", "angle", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Press Back", "Press through the same path back toward handstand. Keep shoulders protracted and elbows tracking back; do not kick the legs to escape the press.", "arrow.up.forward", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    static func clappingHandstandPushPhases() -> [FormPhase] {
        let assetPrefix = "cal_clapping-handstand-pushup"
        return [
            phase("phase1", "Strict Base", "Begin from a stable handstand push-up setup with a predictable bottom target. Do not train release work until strict reps are controlled.", "pause.circle.fill", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Controlled Lower", "Lower like a normal chest-to-wall handstand push-up with the same wall-side direction every rep. Toes stay light on the wall, but the press comes from shoulders and triceps.", "bolt.fill", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Pop Clap", "Clap only if the launch is high enough for a small near-floor release. The hands meet close under the head and shoulders; do not reach forward or let the body line flip away from the wall.", "hands.clap.fill", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Catch Tall", "Return the hands under the shoulders with elbows soft enough to absorb, then press tall. Stop the set when the catch gets noisy or the line arches.", "arrow.down.forward.circle.fill", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    static func bentArmPressPhases() -> [FormPhase] {
        let assetPrefix = "cal_bent-arm-press"
        return [
            phase("phase1", "Tripod Base", "Set hands shoulder-width and place the head lightly ahead of the hands. Hips lift high before the press so the shoulders are already loaded.", "triangle.fill", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Float Hips", "Shift shoulders forward and float the feet or tuck the knees. Keep elbows strong and ribs tucked instead of jumping the legs upward.", "arrow.up.forward", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Press Through", "Press the floor away while the hips rise over the shoulders. The movement should feel like unfolding into handstand, not kicking past the balance point.", "arrow.up", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Handstand Finish", "Arrive in a tall handstand with elbows locked, shoulders elevated, and a controlled exit. If the finish arches hard, regress the entry or use wall assistance.", "checkmark.seal.fill", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    static func planchePushPhases(skillId: String) -> [FormPhase] {
        let assetPrefix = skillId.replacingOccurrences(of: ".", with: "_")
        let isTuck = skillId == "cal.tuck-planche-pushup"
        return [
            phase("phase1", "Lean Set", isTuck ? "Enter a stable tuck planche with feet off the floor, shoulders protracted, and elbows locked. Do not begin the push-up from a collapsing tuck." : "Set hands low near the hips or lower ribs, then lean shoulders clearly forward past the wrists. Mark the lean so it is repeatable.", "ruler.fill", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Protract", "Push the floor away and spread the shoulder blades. Protraction and hollow shape keep the planche line alive.", "arrow.left.and.right", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Bend Without Losing Lean", isTuck ? "Bend the elbows while feet stay off the floor and knees remain tucked tight. If the feet touch, regress." : "Lower through the push-up while shoulders remain forward. If the body drifts back over the hands, the rep lost its planche load.", "arrow.down", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Press To Same Shape", "Press back to the exact setup position: same lean, same protraction, same hollow line. Do not finish by shifting backward into a normal push-up.", "checkmark.seal.fill", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    static func crowFamilyPhases(skillId: String) -> [FormPhase] {
        let assetPrefix = skillId.replacingOccurrences(of: ".", with: "_")
        switch skillId {
        case "hs.crane-pose":
            return [
                phase("phase1", "Crow Base", "Begin from a stable crow with knees high on the upper arms. The feet should float because the hands control pressure, not because you hopped into balance.", "figure.core.training", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Press Tall", "Press the floor away and let the hips climb. Keep the knees glued high on the triceps while the elbows begin to straighten.", "arrow.up.circle.fill", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Lock Arms", "Reach toward straight elbows without dumping weight into the wrists. Fingers stay active and the upper back stays rounded.", "lock.fill", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Hold Crane", "Hold with straight arms, knees still high, and a calm gaze slightly forward. If elbows rebend or knees slide, return to crow work.", "timer", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "hs.flying-crow":
            return [
                phase("phase1", "Base", "Start from a quiet crow or crane. One knee stays high on the arm before the back leg starts to leave the compact shape.", "pause.circle.fill", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Shift", "Shift weight forward and into the support-side hand. Move slowly enough that the fingers can correct balance before the long leg pulls you over.", "arrow.up.forward", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Extend", "Reach the free leg straight back with the toe pointed. Keep the support knee connected to the triceps instead of letting the pose turn into a kick.", "arrow.right", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Hold", "Hold with one knee anchored, one leg long, hips as level as the shape allows, and shoulders still pushing the floor away.", "timer", assetName: assetName(assetPrefix, "phase4"))
            ]
        default:
            return [
                phase("phase1", "Setup", "Plant hands shoulder-width with fingers spread, then set knees high on the upper arms. The elbows bend to make a shelf.", "hand.raised.fill", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Shelf", "Lean shoulders forward and squeeze knees into the arms. Keep the hips high so the feet can get light.", "arrow.forward.circle.fill", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Float", "Lift one foot, then the other, without jumping. Use fingertip pressure to stop tipping forward.", "arrow.up.forward", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Hold", "Hold with bent elbows, knees high, rounded upper back, and steady breathing. Step down before the wrists collapse.", "timer", assetName: assetName(assetPrefix, "phase4"))
            ]
        }
    }

    static func elbowLeverPhases(skillId: String) -> [FormPhase] {
        let assetPrefix = skillId.replacingOccurrences(of: ".", with: "_")
        if skillId == "hs.one-arm-elbow-lever" {
            return [
                phase("phase1", "Two Arm", "Enter a clean two-arm elbow lever first. Both elbows should be anchored before you try to remove support.", "pause.circle.fill", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Shift", "Move weight toward the working elbow while keeping the torso square. The free hand becomes light before it leaves.", "arrow.left.and.right", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Release", "Reach the free arm off the floor as a counterbalance. Do not let that side twist open or drop.", "hand.raised.fill", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Hold", "Hold one-arm support with the working elbow locked into the hip crease, legs straight, and body horizontal.", "timer", assetName: assetName(assetPrefix, "phase4"))
            ]
        }
        return [
            phase("phase1", "Plant", "Set hands shoulder-width with fingers spread. Bend elbows inward toward the lower abdomen or hip crease before leaning.", "hand.raised.fill", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Anchor", "Wedge both elbows into the body and lean forward gradually. The shelf should support the torso before the feet lift.", "scope", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Float", "Let the feet float as the balance point moves forward. Extend the legs only as far as the elbow shelf stays fixed.", "arrow.up.forward", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Hold", "Hold a horizontal body line with glutes tight, legs together, and wrists active. Step out before the elbows slide.", "timer", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    static func plancheHoldPhases(skillId: String) -> [FormPhase] {
        let assetPrefix = skillId.replacingOccurrences(of: ".", with: "_")
        switch skillId {
        case "pl.tuck-planche":
            return [
                phase("phase1", "Support", "Grip floor or parallettes, lock elbows, depress shoulders, and push hard into protraction. The shoulders must be active before the feet float.", "hand.raised.fill", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Lean", "Lean shoulders forward of the hands. If shoulders stay stacked over wrists, the hold cannot balance without another cheat.", "arrow.forward.circle.fill", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Tuck", "Pull knees tight to the chest, heels close to glutes, and lift hips toward shoulder height. Knees do not rest on the arms.", "figure.core.training", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Hold", "Hold with straight elbows, rounded upper back, and quiet head position. Stop when hips drop or elbows soften.", "timer", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "pl.straddle-planche":
            return [
                phase("phase1", "Tuck Base", "Begin from a tuck or advanced tuck planche you can control with the same protracted shoulder position.", "pause.circle.fill", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Open", "Extend the legs wide into straddle, not straight back. A wider split is the bridge; narrow it only after control appears.", "arrow.left.and.right", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Line", "Lock knees, point toes, posteriorly tilt the pelvis, and keep hips level with shoulders instead of letting the legs droop.", "line.diagonal", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Hold Line", "Hold the straddle with shoulders forward, elbows locked, hips level, and toes pointed. End the set when the scapula collapses or the low back starts to banana.", "checkmark.seal.fill", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "pl.half-lay-planche":
            return [
                phase("phase1", "Straddle Set", "Start from a clean straddle planche with shoulders forward, elbows locked, and hips already level.", "pause.circle.fill", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Narrow", "Close the legs partway toward parallel in small increments. The torso and shoulder shape should not change.", "arrow.left.and.right", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Brace", "Squeeze glutes, quads, and toes while keeping ribs down. Narrower legs make every small leak louder.", "figure.core.training", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Proof Hold", "Use short two-to-five-second holds. If hips drop, widen the straddle or use band assistance.", "timer", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "pl.full-planche":
            return [
                phase("phase1", "Shoulder Lean", "Hands press down, shoulders travel forward of the hands, elbows stay locked, and scapulae stay protracted and depressed.", "arrow.forward.circle.fill", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Hollow Line", "Ribs down, pelvis tucked, glutes squeezed, quads locked, legs together, toes pointed. Hollow beats banana.", "circle.hexagongrid.fill", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Float", "Lift into the hold without bending the elbows. Use band or box assistance if the full line appears only for a split second.", "arrow.up.forward", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Standard", "Hold the body roughly parallel to the floor with hands as the only contact. End the set as soon as elbows soften or hips drop.", "checkmark.seal.fill", assetName: assetName(assetPrefix, "phase4"))
            ]
        default:
            return [
                phase("phase1", "Lean", "Shift shoulders forward and protract before the legs float. This is still a planche-family shape, not a normal push-up pause.", "arrow.forward.circle.fill", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Bend", "Use a strong bent-arm angle while keeping the body horizontal. Do not wedge elbows into the hips like an elbow lever.", "arrow.down.forward", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Hold", "Chest stays forward, legs extended, and hips level. Step down before the line turns into a sag.", "timer", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Separate", "Treat this as pressing accessory work. Straight-arm planche progress still needs locked-elbow leans and holds.", "arrow.triangle.branch", assetName: assetName(assetPrefix, "phase4"))
            ]
        }
    }

    static func unilateralPushPhases(skillId: String) -> [FormPhase] {
        let assetPrefix = skillId.replacingOccurrences(of: ".", with: "_")
        let isOneArm = skillId == "cal.one-arm-pushup"
        return [
            phase("phase1", "Base", isOneArm ? "Set one hand under the shoulder or slightly inside and widen the feet enough to balance. The free hand stays off the floor." : "Set hands wide and brace before shifting. Use a moderate width first; very wide hands can irritate shoulders.", "arrow.left.and.right", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Shift Load", isOneArm ? "Shift weight over the working hand and resist twisting. The torso should stay mostly square instead of spinning open." : "Move the chest toward the working hand while the opposite arm stays long and light. The straight arm guides more than it presses.", "arrow.up.left", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Full Depth", "Lower to honest depth with control. If range shrinks or hips rotate hard, raise the working hand and rebuild the full path.", "scope", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Lockout", "Press back to lockout without dumping the shoulder forward. Train the weaker side first and match clean reps.", "checkmark.seal.fill", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    static func explosivePushPhases(skillId: String) -> [FormPhase] {
        let assetPrefix = skillId.replacingOccurrences(of: ".", with: "_")
        let isClap = skillId == "cal.clapping-pushup"
        let isTriple = skillId == "cal.triple-clap-pushup"
        return [
            phase("phase1", "Strict Load", "Start as a strict push-up and lower with control. Power comes from a strong plank line, not a hip buck.", "pause.circle.fill", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Explode", "Punch the floor away hard enough that both hands leave the ground. Stop the set when height drops.", "bolt.fill", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", isTriple ? "Triple Clap" : (isClap ? "Clap" : "Airtime"), isTriple ? "Fit three quick claps only if the launch is massive and controlled. This is an elite power skill, not conditioning." : (isClap ? "Clap once at chest level and return the hands before the landing. A low hip-level clap means airtime is not ready yet." : "Show clear airtime without changing the body line. The hands leave because the press is fast, not because the hips snap."), "hands.clap.fill", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Soft Catch", "Land with elbows slightly bent and shoulders active, then regain the plank before the next rep. Never catch stiff-armed.", "arrow.down.forward.circle.fill", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    static func ringMuscleUpPhases(assetPrefix: String? = nil) -> [FormPhase] {
        [
            phase("phase1", "False Grip", "Set the wrist high over each ring before the pull. The false grip keeps the hand ready for transition instead of forcing a desperate regrip.", "hand.raised.fill", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "Pull Close", "Pull the rings down the body toward lower chest. Keep rings close; if they drift away, the transition becomes a shoulder fight.", "arrow.down.to.line", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Transition", "Roll the chest over the rings with elbows close and moving back. Use feet or bands until the turnover is smooth rather than a grind.", "arrow.triangle.branch", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Support", "Land in the bottom of a ring dip, then press to stable support with rings controlled near the body.", "checkmark.seal.fill", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

    static func strictMuscleUpPhases(assetPrefix: String? = nil) -> [FormPhase] {
        [
            phase("phase1", "Strict Hang", "Start from a dead or active hang with no swing, hip pop, or leg kick. False grip can help, but the body must stay quiet.", "pause.circle.fill", assetName: assetName(assetPrefix, "phase1")),
            phase("phase2", "High Pull", "Pull higher than a normal pull-up, aiming toward lower chest or upper stomach. Chin height is usually too low for a strict turnover.", "arrow.up.forward", assetName: assetName(assetPrefix, "phase2")),
            phase("phase3", "Turnover", "Keep elbows close and lean the chest over the hands before momentum dies. The transition should be continuous, not pull-up, pause, panic.", "arrow.triangle.branch", assetName: assetName(assetPrefix, "phase3")),
            phase("phase4", "Press Out", "Press to full support under control. If swing created the transition, log it as regular muscle-up work instead.", "checkmark.seal.fill", assetName: assetName(assetPrefix, "phase4"))
        ]
    }

}
