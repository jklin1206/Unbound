import SwiftUI

extension FormPhaseLibrary {
    static func legPhases(skillId: String) -> [FormPhase] {
        let assetPrefix = skillId.replacingOccurrences(of: ".", with: "_")
        switch skillId {
        case "ld.goblet-20":
            return [
                phase("phase1", "Stance", "Set feet around shoulder width, hold the weight tight to the chest, and root heel, big toe, and little toe before descending.", "shoeprints.fill", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Half Depth", "Sit between the hips to the deepest clean target for this node. Knees track with toes and ribs stay stacked over the pelvis.", "arrow.down", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Drive Up", "Stand by pushing the floor away through the whole foot. Hips and chest rise together without the knees caving in.", "arrow.up", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Reset", "Finish tall, breathe, and reset foot pressure before the next rep. Do not bounce through sloppy volume.", "arrow.counterclockwise", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "ld.step-up":
            return [
                phase("phase1", "Plant", "Face a stable box and place the whole lead foot on top. Do not start from the toes or a half-foot plant.", "shoeprints.fill", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Drive", "Push mostly through the lead midfoot and heel while the trailing leg stays quiet. Knee tracks over the second toe.", "arrow.up.forward", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Stand Tall", "Finish with hip and knee fully extended on top before stepping down. The rep is not complete while folded forward.", "checkmark.seal.fill", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Control Down", "Step down slowly and quietly. If you drop off the box or wobble hard, lower the height or reps.", "arrow.down.forward", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "ld.deep-squat":
            return [
                phase("phase1", "Stance", "Set feet around shoulder width with a small toe turn-out. Keep heel, big toe, and little toe rooted.", "shoeprints.fill", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Sink", "Sit between the hips until hips pass below knees without heels lifting. Use a counterweight if balance blocks the range.", "arrow.down", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Open", "Keep chest open, knees tracking with toes, and breathe slowly in the bottom. This is active mobility, not a collapsed rest.", "wind", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Own Time", "Hold only while the position stays pain-free and foot-flat. Stand and reset before shape degrades.", "timer", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "ld.glute-bridge", "ld.single-leg-glute-bridge":
            let single = skillId == "ld.single-leg-glute-bridge"
            return [
                phase("phase1", "Set Ribs", "Lie back with ribs down and heel under knee. \(single ? "Extend the free leg and keep both hips level." : "Plant both feet evenly.")", "figure.core.training", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Drive Heels", "Push through the heel, not the toes, and lift by squeezing glutes instead of arching the low back.", "arrow.up", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Lock Hips", "Pause at full hip extension with glutes on and ribs still tucked. The top should not become a backbend.", "pause.circle.fill", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Lower Quietly", "Lower with control and keep the pelvis level. If hamstrings cramp or hips twist, shorten the range.", "arrow.down", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "ld.split-squat", "ld.weighted-split-squat", "ld.bulgarian-split-squat", "ld.weighted-bss":
            let rearElevated = skillId.contains("bulgarian") || skillId.contains("bss")
            return [
                phase("phase1", "Rails", "Set feet hip-width like train tracks. \(rearElevated ? "Rear foot rests on the bench as a balance point, not the engine." : "Back foot stays planted behind you.")", "lines.measurement.horizontal", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Descend", "Lower under control with front knee tracking over toes and torso organized. Match depth on both sides.", "arrow.down", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Front-Leg Drive", "Drive through the front foot to stand. The rear leg should not spring the rep into place.", "arrow.up.forward", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Symmetry", "Let the weaker side set load and reps. If weight shortens range, reduce it before progressing.", "equal.circle.fill", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "ld.shrimp-squat", "ld.pistol-squat", "ld.weighted-pistol":
            let shrimp = skillId == "ld.shrimp-squat"
            return [
                phase("phase1", "Balance Set", shrimp ? "Grab the rear ankle, free arm forward, and root the working foot." : "Reach arms forward, lift the free leg, and root the working heel before descending.", "scope", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Slow Lower", "Use a controlled eccentric. Knee follows toes; heel stays planted; hips stay square instead of twisting out.", "metronome", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", shrimp ? "Soft Knee Touch" : "Bottom Control", shrimp ? "Let the rear knee lightly touch the pad or floor. Do not crash into it or push from it." : "Reach the lowest controlled position with the free foot still off the floor. Pause instead of bouncing.", "pause.circle.fill", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Stand Clean", "Drive up without hand assist, free-foot touch, or heel lift. Use a box or counterweight if the full rep breaks.", "checkmark.seal.fill", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "ld.calf-raise", "ld.weighted-sl-calf":
            return [
                phase("phase1", "Stretch", "Start from a controlled bottom with ankle straight and pressure through the big toe mound. Use wall balance if needed.", "arrow.down.to.line", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Rise High", "Lift as high as the ankle allows without rolling outward or bending the knee to cheat.", "arrow.up", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Pause", "Hold the top briefly. This pause makes the rep full-range instead of a bounce.", "pause.circle.fill", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Slow Lower", "Lower for control back into the stretch. Add load only after range stays identical.", "metronome", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "ld.jumping-squat", "ld.box-jump":
            let box = skillId == "ld.box-jump"
            return [
                phase("phase1", "Load", box ? "Set a stable box and dip into an athletic quarter squat." : "Descend to a controlled squat depth with feet rooted.", "pause.circle.fill", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Triple Extend", "Extend hips, knees, and ankles together. Arms can swing, but knees still track toes.", "bolt.fill", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", box ? "Soft Box Landing" : "Soft Landing", box ? "Land with the whole foot on the box, knees soft, and chest organized. Stand tall after landing." : "Land quietly with knees soft and aligned, then absorb into the next rep.", "arrow.down.forward.circle.fill", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", box ? "Step Down" : "Stop On Fade", box ? "Step down instead of jumping down. Protect the ankle and keep the next rep crisp." : "End the set when height or landing quality drops. Power reps are not burnout reps.", "timer", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "ld.leg-extensions":
            return [
                phase("phase1", "Knee Set", "Kneel with ankles anchored or toes planted, hips open, ribs down, and glutes lightly on before the first lean.", "scope", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Lean Back", "Let the knees bend as the body leans backward in one line from knees to shoulders. Do not sit the hips back.", "arrow.down.forward", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Quad Tension", "Pause only as deep as the quads can control without sharp knee pain or lumbar arching.", "pause.circle.fill", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Extend", "Drive through the quads to return tall. Keep hips open instead of turning the rep into a hip hinge.", "arrow.up", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "ld.sissy-squat":
            return [
                phase("phase1", "Tall Line", "Stand tall with hips open, ribs down, and light support available if needed. This is a quad isolation pattern, not a normal squat.", "line.diagonal", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Knees Forward", "Let knees travel forward while the torso leans back and heels rise as needed. Keep hips extended.", "arrow.forward", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Deep Lean", "Reach the deepest controlled quad-loaded arc without dropping into pain or folding at the hips.", "scope", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Drive Tall", "Use the quads to return to a tall line. Reduce range if the hips hinge to escape the load.", "arrow.up", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "ld.fire-hydrant":
            return [
                phase("phase1", "Quadruped Set", "Set hands under shoulders, knees under hips, ribs down, and pelvis square before lifting the leg.", "square.grid.2x2", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Lift Side", "Lift the bent knee out to the side from the hip. The spine and pelvis should stay quiet.", "arrow.up.right", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Square Hips", "Pause where the glute owns the position. Do not roll the whole body open for extra height.", "scope", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Control Down", "Lower slowly to the same quadruped set. Match both sides and stop when the trunk starts twisting.", "arrow.down", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "ld.flying-kickback":
            return [
                phase("phase1", "Quadruped Set", "Set ribs down and hips square on hands and knees. The working leg starts from control, not a swing.", "square.grid.2x2", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Drive Back", "Drive the leg straight back from the glute while the low back stays quiet.", "arrow.backward", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Glute Squeeze", "Pause with the leg long and hips level. Do not arch the lumbar spine to fake height.", "pause.circle.fill", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Control Return", "Return under control to the start. The next rep begins only after the pelvis is square again.", "arrow.counterclockwise", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "ld.nordic-hip-hinge", "ld.advancing-nordic-curl", "ld.nordic-curl":
            if skillId == "ld.nordic-hip-hinge" {
                return [
                    phase("phase1", "Anchor", "Secure ankles under a stable anchor. If the feet shift, the rep is over before it starts.", "lock.fill", assetName: assetName(assetPrefix, "phase1")),
                    phase("phase2", "Brace Line", "Set ribs, glutes, and trunk before hinging. The hinge is deliberate, not a collapse.", "line.diagonal", assetName: assetName(assetPrefix, "phase2")),
                    phase("phase3", "Hip Hinge", "Move the hips back while the hamstrings load. Keep the spine organized and avoid rounding to escape tension.", "arrow.down.forward", assetName: assetName(assetPrefix, "phase3")),
                    phase("phase4", "Return", "Pull back to tall kneeling with control. Shorten the range if the anchor shifts or the back rounds.", "arrow.up", assetName: assetName(assetPrefix, "phase4"))
                ]
            }
            return [
                phase("phase1", "Anchor", "Secure ankles under a stable anchor. If the feet shift, the rep is over before it starts.", "lock.fill", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Brace Line", "Set ribs, glutes, and trunk. Keep a straight knee-to-head line unless you are deliberately using the hip-hinge regression.", "line.diagonal", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Slow Eccentric", "Lower under hamstring control. Use a band, shorter range, or hand catch before the last inches become a fall.", "metronome", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Return Or Catch", "Pull back up only if the line stays honest. Otherwise catch with hands, reset, and keep volume low.", "exclamationmark.triangle.fill", assetName: assetName(assetPrefix, "phase4"))
            ]
        case "ld.floor-to-ceiling-squat":
            return [
                phase("phase1", "Floor Set", "Start low with feet rooted and hands near the floor or target. Set knees over toes before standing.", "arrow.down.to.line", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Stand Up", "Rise from the squat without knee cave or heel lift. Finish tall before loading the jump.", "figure.stand", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Explode", "Jump vertically with full hip, knee, and ankle extension. Reach for the ceiling or measured target.", "bolt.fill", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Touch", "Touch the target and land softly with knees aligned. The rep is not clean if the landing falls apart.", "hand.point.up.left.fill", assetName: assetName(assetPrefix, "phase4"))
            ]
        default:
            return [
                phase("phase1", "Set", "Start with the working joints stacked and the foot or knee position stable. Do not rush the first rep.", "scope", assetName: assetName(assetPrefix, "phase1")),
                phase("phase2", "Control", "Move through the intended range slowly enough that knee, hip, and trunk alignment stay visible.", "metronome", assetName: assetName(assetPrefix, "phase2")),
                phase("phase3", "Target", "Reach the skill's target position without bouncing, twisting, or using hidden assistance.", "checkmark.seal.fill", assetName: assetName(assetPrefix, "phase3")),
                phase("phase4", "Reset", "Return under control and match the weaker side. Stop when form changes.", "arrow.counterclockwise", assetName: assetName(assetPrefix, "phase4"))
            ]
        }
    }
}
