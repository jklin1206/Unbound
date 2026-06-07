import SwiftUI

extension SkillGuideLibrary {
    static func handstandGuide(
        standard: String,
        scoringNote: String,
        assistance: [(String, String, String)],
        tips: [(String, String, String)],
        mistakes: [(String, String)]
    ) -> SkillGuide {
        SkillGuide(
            standard: standard,
            scoringNote: scoringNote,
            assistance: assistance.map { SkillGuideAssistance(name: $0.0, detail: $0.1, icon: $0.2) },
            tips: tips.map { SkillGuideTip(title: $0.0, detail: $0.1, icon: $0.2) },
            mistakes: mistakes.map { SkillGuideMistake(mistake: $0.0, fix: $0.1) }
        )
    }

    static func pressHandstandGuide(skillId: String) -> SkillGuide {
        let isTuck = skillId == "hs.tuck-press"
        let isStraddle = skillId == "hs.straddle-press"
        let standard = isTuck
            ? "A clean tuck press shifts shoulders past wrists, keeps arms straight, compresses knees tightly, floats the feet without a jump, then lifts hips over hands into a controlled tuck handstand or full handstand finish."
            : (isStraddle
                ? "A clean straddle press starts from a folded straddle shape, leans shoulders over the hands, lifts the feet without momentum, keeps legs wide while the hips rise, then closes the legs only after the handstand is stacked."
                : "A clean press to handstand is a momentum-free straight-arm entry. Hands root into the floor, shoulders elevate, legs compress toward the torso, hips travel over the wrists, and the rep finishes in a stable handstand.")

        return handstandGuide(
            standard: standard,
            scoringNote: "Count only presses with no hop or kick. Bent elbows, shoulder collapse, feet leaving from momentum, or an uncontrolled top position move the work back to regressions.",
            assistance: [
                ("Elevated Hands", "Use blocks or parallettes to reduce compression demand while keeping the same straight-arm press path.", "square.stack.3d.up.fill"),
                ("Wall Negative", "Lower from a wall handstand through the press shape slowly. Negatives teach the path without needing the full lift yet.", "arrow.down.forward"),
                (isTuck ? "Crow to Tuck Float" : "Compression Lift", isTuck ? "Float from crow-style compression into a small tuck so the feet learn to leave quietly." : "Lift the heels from a pike or straddle fold to build active compression.", "arrow.up.circle.fill")
            ],
            tips: [
                ("Press down to go up", "The floor push and shoulder elevation are what let the hips rise. Do not think about yanking the legs first.", "hand.raised.fill"),
                ("Lean is required", "The shoulders must move forward enough for the hips to pass over the wrists. Fear of lean usually turns into a hop.", "arrow.forward.circle.fill"),
                ("Shape decides difficulty", isStraddle ? "Keep the legs wide until the hips are stacked; closing early makes the lever heavier." : "The tighter the compression, the less brute strength the press demands.", "scope")
            ],
            mistakes: [
                ("The feet jump off the floor.", "Use slow negatives and elevated hands until the feet can float quietly."),
                ("Elbows bend during the lift.", "Regress to straight-arm lean holds and shorten the range."),
                ("The top handstand is unstable.", "Finish toward a wall target and pause before counting the rep.")
            ]
        )
    }

    static func oneArmHandstandGuide(wallSupported: Bool, full: Bool) -> SkillGuide {
        let standard = wallSupported
            ? "A clean wall-supported one-arm handstand starts from a tight wall handstand, opens the legs enough to manage balance, shifts weight into one straight working arm, keeps that shoulder elevated by the ear, and reduces the free hand to light fingertips or a brief hover."
            : (full
                ? "A clean full one-arm handstand is a freestanding one-hand balance with straight support arm, elevated shoulder, active hand, controlled straddle or full line, hips centered over the support hand, steady breath, and an intentional exit."
                : "A clean one-arm handstand starts from a stable freestanding straddle handstand, shifts weight into one straight support arm, keeps the support shoulder tall, lifts the free hand, and balances with active fingers, wrist, shoulder, and small hip corrections.")
        return handstandGuide(
            standard: standard,
            scoringNote: wallSupported
                ? "For the assisted standard, count only time where the working arm carries the load and the free hand is visibly light. Heavy leaning into the wall or a sinking shoulder does not count."
                : "Count only quiet holds. Bent support arm, shoulder collapse, major walking, leg chaos, or an uncontrolled fall means the attempt is not clean.",
            assistance: [
                ("Two-Hand Wall Line", "Own a tall two-hand handstand first: ribs controlled, shoulders elevated, and hands active.", "rectangle.portrait"),
                ("Close-Hand Straddle", "Bring the hands closer than normal and open the legs so the body can shift without turning into a walk.", "figure.flexibility"),
                ("Weight Shifts", "Move weight side to side before lifting the hand. The working shoulder stays tall rather than dumping sideways.", "arrow.left.and.right"),
                ("Two-Finger Tent", "Keep only two fingertips from the free hand on the floor. The support should be light enough that the working hand has to steer.", "hand.point.up.left.fill"),
                ("One-Finger Tent", "Reduce to one fingertip only after the two-finger tent can stay calm. This is a balance stage, not a strength stunt.", "hand.point.up.left.fill"),
                ("Off-Hand Float", "Let the free hand hover briefly, then return it before the shoulder sinks or the hips dump sideways.", "hand.raised.fill")
            ],
            tips: [
                ("Push tall before lifting", "The free hand comes off only after the working shoulder has already taken the stack.", "arrow.up.circle.fill"),
                ("Straddle gives time", "Opening the legs gives more balance options while the hand and shoulder learn the new center.", "figure.flexibility"),
                ("Progress the support hand", "Full palm, fingertips, two-finger tent, one-finger tent, float. Each step should feel boring before the next one gets tested.", "slider.horizontal.3"),
                ("The hand is still steering", "Finger pressure and heel-of-hand pressure stay active. One-arm balance is not passive stacking.", "hand.tap.fill")
            ],
            mistakes: [
                ("The working shoulder sinks.", "Return to wall shifts and one-arm shoulder-elevation holds."),
                ("The free hand is secretly heavy.", "Use fewer fingers and shorter holds instead of pretending the shift is complete."),
                ("Skipping from wall support straight to free attempts.", "Spend time on tenting and off-hand floats so the body learns pressure transfer instead of panic exits."),
                ("The hips dump sideways.", "Think shoulder tall first, then move the hips only enough to center over the hand.")
            ]
        )
    }

    static func hollowBodyGuide() -> SkillGuide {
        SkillGuide(
            standard: "A clean hollow body hold keeps the low back sealed to the floor, ribs pulled down toward the pelvis, shoulders lifted, arms and legs long, and breathing controlled without losing posterior pelvic tilt.",
            scoringNote: "The set ends the moment the low back arches. Shorter clean holds beat longer holds that turn into hip-flexor leg lifts.",
            assistance: [
                SkillGuideAssistance(name: "Bent-Knee Hollow", detail: "Keep knees bent and arms by the sides until the pelvis can stay tucked with normal breathing.", icon: "figure.core.training"),
                SkillGuideAssistance(name: "Dead Bug", detail: "Alternate arm and leg reaches while the low back stays down. This teaches the same brace with less lever length.", icon: "arrow.up.left.and.arrow.down.right"),
                SkillGuideAssistance(name: "One-Leg Lower", detail: "Lower one leg at a time only as far as the spine stays glued to the floor.", icon: "arrow.down")
            ],
            tips: [
                SkillGuideTip(title: "Ribs meet hips", detail: "Think of shortening the front of the torso before lifting the limbs. The hollow is a trunk shape first, not a leg height contest.", icon: "rectangle.compress.vertical"),
                SkillGuideTip(title: "Reach long after you brace", detail: "Arms overhead and low legs are progressions. Earn them by keeping the same pelvis position.", icon: "arrow.up.left.and.arrow.down.right"),
                SkillGuideTip(title: "Use it everywhere", detail: "Front lever, toes-to-bar, dragon flag, handstand work, and muscle-up swing all borrow this ribs-down body line.", icon: "link")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Low back lifts off the floor.", fix: "Bend knees, bring arms forward, or shorten the set until lumbar contact stays unbroken."),
                SkillGuideMistake(mistake: "Holding the breath.", fix: "Use easier leverage and breathe behind the brace. If breathing breaks the shape, the shape is too hard."),
                SkillGuideMistake(mistake: "Chasing low legs too early.", fix: "Keep legs higher or tucked until the pelvis stays posteriorly tilted.")
            ]
        )
    }

    static func forearmPlankGuide() -> SkillGuide {
        SkillGuide(
            standard: "A clean forearm plank holds a straight line from head to heels with elbows under shoulders, forearms rooted, ribs down, glutes and quads lightly squeezed, and steady breathing for the full target time.",
            scoringNote: "The timer stops when the low back sags, hips pike, shoulders collapse, elbows drift forward, or the athlete has to hold breath to survive.",
            assistance: [
                SkillGuideAssistance(name: "Knee Plank", detail: "Drop to the knees while keeping the same ribs-down trunk line. Build clean time before returning to full legs.", icon: "figure.core.training"),
                SkillGuideAssistance(name: "Incline Forearm Plank", detail: "Raise the forearms on a bench or box to reduce the anti-extension load while preserving the plank shape.", icon: "arrow.up.to.line"),
                SkillGuideAssistance(name: "Short Hold Clusters", detail: "Use repeated 5-15 second holds with clean exits instead of one long sagging hold.", icon: "timer")
            ],
            tips: [
                SkillGuideTip(title: "Push the floor away", detail: "Root the forearms and gently spread the shoulder blades so the upper back does not sink.", icon: "arrow.down.to.line"),
                SkillGuideTip(title: "Zip ribs to hips", detail: "A slight posterior pelvic tuck keeps the low back from arching. The plank should feel like a hollow body turned face down.", icon: "rectangle.compress.vertical"),
                SkillGuideTip(title: "Breathe behind the brace", detail: "Quiet nasal or controlled mouth breaths prove the position is owned, not just tolerated.", icon: "lungs.fill")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Low back sags.", fix: "Squeeze glutes, tuck ribs down, widen feet, or regress to knees."),
                SkillGuideMistake(mistake: "Hips pike too high.", fix: "Lower hips until shoulders, ribs, and pelvis form one line."),
                SkillGuideMistake(mistake: "Neck cranes forward.", fix: "Look slightly ahead of the hands and keep the back of the neck long.")
            ]
        )
    }

    static func coreFlexionGuide(skillId: String) -> SkillGuide {
        switch skillId {
        case "cl.reverse-crunch":
            return SkillGuide(
                standard: "A clean reverse crunch starts with knees bent around tabletop, ribs down, and shoulders grounded. The pelvis curls toward the rib cage so the tailbone peels up, then returns slowly without leg swing.",
                scoringNote: "The rep is small by design. Throwing knees toward the face, rocking onto the shoulders, or arching on the return turns it into momentum.",
                assistance: [
                    SkillGuideAssistance(name: "Hands Pressed Down", detail: "Press the floor lightly for stability while learning the pelvic curl.", icon: "hand.raised.fill"),
                    SkillGuideAssistance(name: "Smaller Curl", detail: "Lift only the tailbone at first. Add range after the pelvis moves without a swing.", icon: "slider.horizontal.3"),
                    SkillGuideAssistance(name: "Foot Tap Reset", detail: "Tap feet down between reps to remove momentum before the next curl.", icon: "shoeprints.fill")
                ],
                tips: [
                    SkillGuideTip(title: "Curl the pelvis", detail: "Think tailbone toward ribs, not knees to face. The pelvis movement is what makes it abdominal work.", icon: "arrow.up.circle.fill"),
                    SkillGuideTip(title: "Make it small and heavy", detail: "A controlled inch of pelvic curl beats a big swing that rolls the whole body.", icon: "scope"),
                    SkillGuideTip(title: "Lower without reload", detail: "Return slowly enough that the legs do not swing into the next rep.", icon: "metronome")
                ],
                mistakes: [
                    SkillGuideMistake(mistake: "Legs kick for momentum.", fix: "Bend knees tighter, use smaller range, and pause between reps."),
                    SkillGuideMistake(mistake: "Rocking onto shoulders.", fix: "Keep mid-back grounded and stop at a small tailbone lift."),
                    SkillGuideMistake(mistake: "Low back arches on the return.", fix: "Reset ribs down before lowering the feet or knees.")
                ]
            )
        case "cl.levitation-crunch":
            return SkillGuide(
                standard: "A clean levitation crunch starts in a hollow hover with low back pressed down, shoulders and legs off the floor, folds ribs and knees toward center, then reopens to a quiet hover without touching down.",
                scoringNote: "Count only reps where the hollow survives both directions. If the low back pops off the floor, shorten the lever or rest between reps.",
                assistance: [
                    SkillGuideAssistance(name: "Bent-Knee Hollow", detail: "Hold a short hollow with knees bent before adding the crunch motion.", icon: "figure.core.training"),
                    SkillGuideAssistance(name: "Arms Forward", detail: "Reach arms toward the feet instead of overhead to reduce lever length.", icon: "arrow.forward"),
                    SkillGuideAssistance(name: "One-Leg Extension", detail: "Extend one leg at a time while the spine stays sealed down.", icon: "arrow.left.and.right")
                ],
                tips: [
                    SkillGuideTip(title: "Own hollow first", detail: "The crunch starts from a stable hollow. If the setup leaks, the rep has nowhere clean to go.", icon: "circle.hexagongrid.fill"),
                    SkillGuideTip(title: "Fold from both ends", detail: "Ribs and knees travel toward each other; do not yank only with the neck or only with the legs.", icon: "rectangle.compress.vertical"),
                    SkillGuideTip(title: "Return to a hover", detail: "The last inch matters. Reopen quietly instead of dropping shoulders or heels.", icon: "pause.circle.fill")
                ],
                mistakes: [
                    SkillGuideMistake(mistake: "Low back leaves the floor.", fix: "Bend knees, raise legs higher, or bring arms forward."),
                    SkillGuideMistake(mistake: "Neck strains forward.", fix: "Keep chin softly tucked and lift from the ribs."),
                    SkillGuideMistake(mistake: "Turns into a loose V-up.", fix: "Slow down and finish each rep in a controlled hollow hover.")
                ]
            )
        case "cl.inverted-situp":
            return SkillGuide(
                standard: "A clean inverted sit-up starts from a secure inverted hook or hang, braces first, curls the trunk toward the legs or bar without swing, then lowers under control while the anchor stays locked.",
                scoringNote: "Safety owns the standard. Do not count reps where the hook slips, the body swings, or the athlete overextends at the bottom.",
                assistance: [
                    SkillGuideAssistance(name: "Decline Sit-Up", detail: "Build the same trunk flexion on a stable bench before going inverted.", icon: "rectangle.inset.filled"),
                    SkillGuideAssistance(name: "Inverted Hold", detail: "Practice only the secure upside-down anchor and calm breathing before adding reps.", icon: "figure.gymnastics"),
                    SkillGuideAssistance(name: "Partial Curl", detail: "Use a small range or spotter support until the anchor and descent are reliable.", icon: "slider.horizontal.3")
                ],
                tips: [
                    SkillGuideTip(title: "Secure first", detail: "The hook, grip, or leg anchor must feel boring before the first rep starts.", icon: "lock.fill"),
                    SkillGuideTip(title: "Curl, do not swing", detail: "Move like a strict crunch upside down. Momentum makes the setup less safe and less useful.", icon: "metronome"),
                    SkillGuideTip(title: "Lower with brakes", detail: "The descent should not whip the spine or shift the anchor.", icon: "arrow.down.circle.fill")
                ],
                mistakes: [
                    SkillGuideMistake(mistake: "Swinging for height.", fix: "Return to decline work or partial inverted curls."),
                    SkillGuideMistake(mistake: "Anchor shifts mid-rep.", fix: "Stop immediately and rebuild the setup before loading reps."),
                    SkillGuideMistake(mistake: "Overextending at the bottom.", fix: "Stop the descent where ribs and pelvis can stay controlled.")
                ]
            )
        case "cl.decline-situp":
            return SkillGuide(
                standard: "A clean decline sit-up uses a modest bench angle, secured feet, bent knees, and controlled spinal flexion. Curl up before sitting tall, then lower slowly without flopping or arching.",
                scoringNote: "Steeper is not better if control vanishes. Add decline, range, and load only after flat sit-ups and crunches stay clean.",
                assistance: [
                    SkillGuideAssistance(name: "Flat Crunch", detail: "Use small rib-to-pelvis curls until neck and hip-flexor cheating disappear.", icon: "figure.core.training"),
                    SkillGuideAssistance(name: "Low Decline", detail: "Start at the lowest useful angle and increase only when the lower stays controlled.", icon: "slider.horizontal.3"),
                    SkillGuideAssistance(name: "Arms Forward", detail: "Reach arms forward to reduce leverage before using hands behind head or added load.", icon: "arrow.forward")
                ],
                tips: [
                    SkillGuideTip(title: "Curl before sit", detail: "Start by rolling ribs toward pelvis. Sitting up without the curl shifts the work into hip flexors.", icon: "rectangle.compress.vertical"),
                    SkillGuideTip(title: "Ribs down on the way back", detail: "The lower should stay braced instead of turning into a backward flop.", icon: "arrow.down"),
                    SkillGuideTip(title: "Earn load last", detail: "Weight belongs after angle, range, and tempo are all repeatable.", icon: "scalemass.fill")
                ],
                mistakes: [
                    SkillGuideMistake(mistake: "Bench angle too steep.", fix: "Lower the decline until the whole rep can be controlled."),
                    SkillGuideMistake(mistake: "Yanking the head.", fix: "Move hands across chest or support the head lightly without pulling."),
                    SkillGuideMistake(mistake: "Flopping into lumbar extension.", fix: "Slow the eccentric and stop before the brace disappears.")
                ]
            )
        default:
            return SkillGuide(
                standard: "A clean crunch starts supine with knees bent and feet planted, then curls the upper back off the floor by drawing ribs toward pelvis. The neck stays relaxed, low back controlled, and the lower is slow.",
                scoringNote: "This is a small spinal-flexion rep. Pulling the head, throwing the arms, or turning it into a hip-flexor sit-up does not count.",
                assistance: [
                    SkillGuideAssistance(name: "Hands Across Chest", detail: "Remove the temptation to pull the neck while learning the rib curl.", icon: "xmark"),
                    SkillGuideAssistance(name: "Small Curl", detail: "Lift only the shoulder blades at first. Range grows after the neck stays quiet.", icon: "slider.horizontal.3"),
                    SkillGuideAssistance(name: "Feet Supported", detail: "Place feet on a bench if it helps keep the pelvis and low back quiet.", icon: "rectangle.inset.filled")
                ],
                tips: [
                    SkillGuideTip(title: "Ribs to pelvis", detail: "Do not chase head to knees. The useful motion is the ribs shortening toward the hips.", icon: "rectangle.compress.vertical"),
                    SkillGuideTip(title: "Exhale to lift", detail: "A smooth exhale helps the ribs soften down before the curl.", icon: "wind"),
                    SkillGuideTip(title: "Hands only support", detail: "If hands are behind the head, they cradle. They do not pull.", icon: "hand.raised.fill")
                ],
                mistakes: [
                    SkillGuideMistake(mistake: "Pulling on the neck.", fix: "Move hands to chest and keep chin softly tucked."),
                    SkillGuideMistake(mistake: "Feet lift or hips rock.", fix: "Use a smaller curl and slow the tempo."),
                    SkillGuideMistake(mistake: "Rushing the lower.", fix: "Uncurl slowly until shoulder blades touch down.")
                ]
            )
        }
    }

    static func plankControlGuide(skillId: String) -> SkillGuide {
        let name = skillId == "cl.bird-dog-plank" ? "bird dog plank" : (skillId == "cl.superman-plank" ? "superman plank" : "extended plank")
        return SkillGuide(
            standard: "A clean \(name) keeps ribs stacked over pelvis, glutes lightly squeezed, shoulders active, and the spine quiet while the lever changes. The body should not sag, pike, twist, or shrug.",
            scoringNote: "Anti-rotation is the point. If the hips roll or the shoulder line opens, shorten the hold or use an easier plank variation.",
            assistance: [
                SkillGuideAssistance(name: "Incline Plank", detail: "Raise the hands until the trunk can stay stacked without low-back sag.", icon: "arrow.up.to.line"),
                SkillGuideAssistance(name: "Quadruped Reach", detail: "Practice opposite arm and leg reaches from hands and knees before loading the full plank.", icon: "figure.core.training"),
                SkillGuideAssistance(name: "Short Holds", detail: "Use 5-10 second perfect holds per side instead of one long collapse.", icon: "timer")
            ],
            tips: [
                SkillGuideTip(title: "Move limbs without moving spine", detail: "The best rep looks boring from the trunk. Only the arm or leg changes.", icon: "scope"),
                SkillGuideTip(title: "Push the floor away", detail: "Active shoulders keep the upper back from sinking and make the brace easier to keep.", icon: "arrow.down.to.line"),
                SkillGuideTip(title: "Hips tell the truth", detail: "A small hip hike usually means the anti-rotation demand is winning. Regress before adding time.", icon: "line.diagonal")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Hips sag under fatigue.", fix: "Shorten the lever, raise the hands, or stop the set earlier."),
                SkillGuideMistake(mistake: "Free leg lifts too high.", fix: "Keep the leg near hip height so the trunk does not arch and rotate."),
                SkillGuideMistake(mistake: "Shoulders rotate open.", fix: "Press evenly through the support hand and reduce reach distance.")
            ]
        )
    }

    static func rolloutGuide(skillId: String) -> SkillGuide {
        let standing = skillId == "cl.standing-ab-rollout"
        return SkillGuide(
            standard: standing
                ? "A clean standing ab rollout starts from standing with a braced hinge to the wheel, rolls forward through a hollow body line, reaches only the range the spine can control, then returns without hip snapping or lumbar sag."
                : "A clean knee ab rollout starts kneeling with the wheel under shoulders, ribs down, glutes on, and arms long. Roll forward only as far as the hollow shape survives, then pull back without bending the elbows to escape.",
            scoringNote: "Rollouts are anti-extension. The rep ends when the low back arches, shoulders collapse, elbows bend to shorten the lever, or the return becomes a hip pike.",
            assistance: [
                SkillGuideAssistance(name: standing ? "Wall-Stop Standing Rollout" : "Wall-Stop Rollout", detail: "Use a wall as a hard range limit so the body learns a clean endpoint before max range.", icon: "rectangle.portrait"),
                SkillGuideAssistance(name: standing ? "Knee Rollout" : "Short Range Rollout", detail: standing ? "Own strict knee rollouts before standing range." : "Use a shorter rollout and gradually move the wall farther away.", icon: "slider.horizontal.3"),
                SkillGuideAssistance(name: "Elevated Rollout", detail: "Roll to a bench, barbell, or box to reduce the lever while keeping the same brace.", icon: "arrow.up.to.line")
            ],
            tips: [
                SkillGuideTip(title: "Hollow before motion", detail: "Set ribs down and glutes on before the wheel moves. The spine position is the skill.", icon: "circle.hexagongrid.fill"),
                SkillGuideTip(title: "Stop before the arch", detail: "The clean endpoint is one inch before the low back wants to sag.", icon: "exclamationmark.triangle.fill"),
                SkillGuideTip(title: "Pull back with abs and lats", detail: "Return by keeping the body long and drawing the wheel back, not by folding the hips first.", icon: "arrow.backward")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Low back arches near end range.", fix: "Shorten the range with a wall stop and squeeze glutes harder."),
                SkillGuideMistake(mistake: "Elbows bend to return.", fix: "Regress range or elevation until arms can stay long."),
                SkillGuideMistake(mistake: "Hips snap back first.", fix: "Slow the return and think ribs pull the wheel home.")
            ]
        )
    }

    static func coreRaiseGuide(skillId: String) -> SkillGuide {
        let hanging = skillId.contains("hanging") || skillId == "cl.toes-to-bar"
        let name = skillId.replacingOccurrences(of: "cl.", with: "").replacingOccurrences(of: "-", with: " ")
        return SkillGuide(
            standard: hanging
                ? "A clean \(name) starts from an active hang, uses a quiet shoulder position, curls the pelvis instead of swinging the legs, reaches the required height, and lowers under control without building momentum."
                : "A clean \(name) starts with the low back controlled, raises from the pelvis with no bounce, reaches the target range, then lowers slower than it lifted.",
            scoringNote: "Count strict reps only. If the descent creates the next rep's swing or the knees bend to steal leverage, use an easier raise.",
            assistance: [
                SkillGuideAssistance(name: "Bent-Knee Raise", detail: "Shorten the lever so the pelvis can curl and the shoulders stay quiet.", icon: "figure.core.training"),
                SkillGuideAssistance(name: "Eccentric Lower", detail: "Start near the top and lower for 2-4 seconds. This builds control without needing a perfect concentric yet.", icon: "arrow.down.forward"),
                SkillGuideAssistance(name: "Captain's Chair", detail: "Use supported elbows or dip bars when grip or swing control blocks clean abdominal work.", icon: "rectangle.on.rectangle")
            ],
            tips: [
                SkillGuideTip(title: "Start with the pelvis", detail: "The rep becomes an ab skill when the tailbone curls up. Throwing the feet mostly trains momentum.", icon: "arrow.up.circle.fill"),
                SkillGuideTip(title: "Quiet bar, quiet body", detail: "A strict raise should not turn the hang into a pendulum. Reset between reps if needed.", icon: "pause.circle.fill"),
                SkillGuideTip(title: "Lower like brakes", detail: "The eccentric should be slower than the lift. Dropping the legs reloads the next cheat.", icon: "metronome")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Swinging through reps.", fix: "Pause at the bottom, reduce reps, or regress to bent-knee raises until the body stays still."),
                SkillGuideMistake(mistake: "Only lifting to waist height.", fix: "Use knee raises and finish by curling knees toward chest before extending the lever."),
                SkillGuideMistake(mistake: "Loose shoulders in the hang.", fix: "Practice active hangs and scapular depression before adding higher raises.")
            ]
        )
    }

    static func lSitFamilyGuide(skillId: String) -> SkillGuide {
        let name = skillId == "cal.l-sit-10" ? "L-sit" : skillId.replacingOccurrences(of: "cl.", with: "").replacingOccurrences(of: "-", with: " ")
        return SkillGuide(
            standard: "A clean \(name) has hands pressing down, elbows locked, shoulders depressed, hips lifted, legs held in the target shape, knees straight, and toes pointed without shrugging or dragging the heels.",
            scoringNote: "Use parallettes, blocks, or tucked variations if mobility limits the floor version. The hold only counts while hips and legs stay lifted.",
            assistance: [
                SkillGuideAssistance(name: "Tuck L-Sit", detail: "Keep knees bent and lift the hips first. This builds support strength before hamstring mobility becomes the bottleneck.", icon: "figure.core.training"),
                SkillGuideAssistance(name: "One-Leg L-Sit", detail: "Alternate one straight leg and one tucked leg to bridge between tuck and full L.", icon: "arrow.left.and.right"),
                SkillGuideAssistance(name: "Compression Lifts", detail: "Sit tall and lift straight legs or heels from the floor for short reps to train active hip compression.", icon: "arrow.up.to.line")
            ],
            tips: [
                SkillGuideTip(title: "Push before you lift", detail: "Shoulders down and elbows locked create space for the hips. Without the press, the legs have nowhere to go.", icon: "arrow.down.to.line"),
                SkillGuideTip(title: "Quads stay on", detail: "Locked knees are active. Pointed toes and squeezed quads make the lever cleaner and easier to judge.", icon: "checkmark.seal.fill"),
                SkillGuideTip(title: "Blocks are not cheating", detail: "Extra hand height lets more athletes train the correct shape while compression and hamstrings catch up.", icon: "square.stack.3d.up")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Shoulders shrug toward ears.", fix: "Return to support holds and think push the floor away."),
                SkillGuideMistake(mistake: "Knees bend as fatigue hits.", fix: "Use shorter holds, one-leg variations, or a tuck until legs can stay locked."),
                SkillGuideMistake(mistake: "Hips stay on the floor.", fix: "Raise the hands on parallettes or blocks and prioritize lifting the hips before extending legs.")
            ]
        )
    }

    static func frontLeverGuide(skillId: String) -> SkillGuide {
        let name = skillId.replacingOccurrences(of: "cl.", with: "").replacingOccurrences(of: "-", with: " ")
        return SkillGuide(
            standard: "A clean \(name) hangs face-up under the bar or rings with elbows locked, shoulders depressed, ribs down, pelvis tucked, and hips level with shoulders. The chosen lever shape must stay still for the full hold.",
            scoringNote: "Front lever is straight-arm lat strength plus trunk position. Bent elbows, shrugging, piking, or a banana back move the set back to an easier progression.",
            assistance: [
                SkillGuideAssistance(name: "Tuck Lever Hold", detail: "Shorten the lever aggressively. Own 10-15 second clean tucks before opening the hips.", icon: "figure.core.training"),
                SkillGuideAssistance(name: "Band-Assisted Lever", detail: "Use a band at the hips or feet so the horizontal line can be practiced without collapse.", icon: "point.3.connected.trianglepath.dotted"),
                SkillGuideAssistance(name: "Lever Row or Negative", detail: "Rows and slow lowers build the same shoulder extension strength while exposing hip drop.", icon: "arrow.down.forward")
            ],
            tips: [
                SkillGuideTip(title: "Hands toward hips", detail: "Think straight-arm pulldown: drive the bar toward your hips while the shoulders stay down.", icon: "arrow.down.backward"),
                SkillGuideTip(title: "Lengthen one lever at a time", detail: "Tuck, open tuck, one-leg, straddle, and full are not ego labels. Pick the shape you can keep horizontal.", icon: "slider.horizontal.3"),
                SkillGuideTip(title: "Accumulate clean seconds", detail: "Several crisp 6-10 second holds beat one max attempt that changes shape halfway through.", icon: "timer")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Bending the elbows.", fix: "Regress the lever or use a band until the arms can stay locked."),
                SkillGuideMistake(mistake: "Hips drop below shoulder line.", fix: "Return to tuck or open tuck and squeeze glutes with ribs closed."),
                SkillGuideMistake(mistake: "Shrugging toward the ears.", fix: "Add active hangs, scapular pulls, and shorter lever holds with shoulders depressed.")
            ]
        )
    }

    static func backLeverGuide(skillId: String) -> SkillGuide {
        if skillId == "cl.german-hang" {
            return SkillGuide(
                standard: "A clean German hang is entered slowly through a skin-the-cat path, held pain-free with straight arms behind the body, quiet rings, calm breathing, and an exit through the same route.",
                scoringNote: "This is shoulder-extension capacity, not a courage test. Sharp anterior shoulder pain, bent arms, panic breathing, or dropping into range ends the attempt.",
                assistance: [
                    SkillGuideAssistance(name: "Feet-Assisted German Hang", detail: "Set the rings low and keep toes on the floor so you can dose the stretch and practice the exit before full bodyweight.", icon: "shoeprints.fill"),
                    SkillGuideAssistance(name: "Box-Assisted Skin the Cat", detail: "Use a box to guide the pass-through instead of free-falling into the bottom position.", icon: "square.stack.3d.up"),
                    SkillGuideAssistance(name: "Ring Support and Reverse Plank", detail: "Prepare shoulder extension with supports, reverse planks, and short assisted holds before full hangs.", icon: "figure.strengthtraining.functional")
                ],
                tips: [
                    SkillGuideTip(title: "Depth is earned", detail: "Start shallow and add range only when the shoulders stay warm, quiet, and pain-free.", icon: "slider.horizontal.3"),
                    SkillGuideTip(title: "Straight arms, soft intent", detail: "The elbows stay locked, but the shoulders should not be jammed. Think long arms and controlled chest opening.", icon: "checkmark.seal.fill"),
                    SkillGuideTip(title: "Exit proves ownership", detail: "If you cannot reverse the path, the hang was too deep or too heavy for today.", icon: "arrow.uturn.backward")
                ],
                mistakes: [
                    SkillGuideMistake(mistake: "Dropping into the bottom.", fix: "Lower the rings, use foot assistance, and slow the pass-through before adding depth."),
                    SkillGuideMistake(mistake: "Holding through sharp pain.", fix: "Stop immediately and rebuild shoulder extension with assisted range."),
                    SkillGuideMistake(mistake: "Bending elbows to survive.", fix: "Regress the load. Bent elbows hide the shoulder position and change the stress.")
                ]
            )
        }

        if skillId == "cl.skin-the-cat" {
            return SkillGuide(
                standard: "A clean skin-the-cat starts from a quiet ring hang, moves through tuck or pike to inverted hang, passes under control into German hang, then reverses back to the starting hang without dropping or bending the elbows.",
                scoringNote: "Count only reps with a controlled bottom and a controlled return. If the athlete can enter but cannot reverse out, it is a partial progression.",
                assistance: [
                    SkillGuideAssistance(name: "Tuck Pass-Through", detail: "Keep the knees tight to shorten the lever while learning the shoulder route.", icon: "figure.core.training"),
                    SkillGuideAssistance(name: "Low-Ring Foot Assist", detail: "Use toes on the floor at the bottom so the shoulders never absorb a sudden drop.", icon: "shoeprints.fill"),
                    SkillGuideAssistance(name: "German Hang Holds", detail: "Build short, calm holds at the bottom before asking for full repeated reps.", icon: "figure.gymnastics")
                ],
                tips: [
                    SkillGuideTip(title: "The bottom is not a fall", detail: "Lower into shoulder extension slowly enough that you could stop at any point.", icon: "arrow.down.circle.fill"),
                    SkillGuideTip(title: "Reverse the movie", detail: "Come out by retracing the same path: German hang, inverted tuck, then quiet hang.", icon: "arrow.triangle.2.circlepath"),
                    SkillGuideTip(title: "Rings should stay boring", detail: "Swinging rings usually mean the hips kicked instead of the shoulders and core controlling the rotation.", icon: "circle.grid.cross")
                ],
                mistakes: [
                    SkillGuideMistake(mistake: "Dropping into German hang.", fix: "Use low rings and feet assistance until the descent is slow."),
                    SkillGuideMistake(mistake: "Bending arms during the pass-through.", fix: "Return to tighter tuck reps and straight-arm active hangs."),
                    SkillGuideMistake(mistake: "Going deeper than can be reversed.", fix: "Limit range to the deepest point you can exit cleanly.")
                ]
            )
        }

        let name = skillId.replacingOccurrences(of: "cl.", with: "").replacingOccurrences(of: "-", with: " ")
        return SkillGuide(
            standard: "A clean \(name) uses straight arms, controlled shoulder extension, a rigid ribs-down body line, and a slow entry and exit. Full back lever standards require a face-down horizontal line with legs straight and together.",
            scoringNote: "Back lever loads shoulders and elbow tendons hard. No hold counts through pain, bent arms, or a rushed drop into German hang.",
            assistance: [
                SkillGuideAssistance(name: "German Hang", detail: "Build pain-free shoulder extension tolerance first. Enter and exit slowly every time.", icon: "figure.gymnastics"),
                SkillGuideAssistance(name: "Skin the Cat", detail: "Use controlled pass-throughs to learn the route before pausing in harder lever shapes.", icon: "arrow.triangle.2.circlepath"),
                SkillGuideAssistance(name: "Tuck Back Lever", detail: "Keep knees tight and elbows locked. This is the safest first horizontal pause.", icon: "figure.core.training")
            ],
            tips: [
                SkillGuideTip(title: "Mobility before intensity", detail: "If German hang feels sharp or panicked, the back lever is not ready yet.", icon: "exclamationmark.triangle.fill"),
                SkillGuideTip(title: "Elbows stay honest", detail: "Bent arms make the hold easier and put ugly load into the wrong tissues.", icon: "checkmark.seal.fill"),
                SkillGuideTip(title: "Exit the same path", detail: "A controlled return protects the shoulders and proves the position was owned.", icon: "arrow.uturn.backward")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Dropping into shoulder extension.", fix: "Use feet assistance, lower rings, or smaller range until entry speed is controlled."),
                SkillGuideMistake(mistake: "Ignoring anterior shoulder pain.", fix: "Stop the set and rebuild German hang tolerance. Pain is not a progression."),
                SkillGuideMistake(mistake: "Arching the low back to fake horizontal.", fix: "Squeeze glutes, close ribs, and use a wider straddle or tuck.")
            ]
        )
    }

    static func threeSixtyPullGuide() -> SkillGuide {
        SkillGuide(
            standard: "A clean 360-degree pull is a controlled straight-arm ring arc: active hang, front-lever lane, inverted hang, back-lever lane, German hang, then the same path reversed without release, panic, or shoulder dumping.",
            scoringNote: "This is an elite ring control skill, not a bar release trick. Count only reps with straight arms, quiet rings, pain-free shoulder extension, and a reverse path the athlete can actually bring home.",
            assistance: [
                SkillGuideAssistance(name: "Skin the Cat", detail: "Own slow pass-throughs and controlled returns before linking the full arc.", icon: "figure.gymnastics"),
                SkillGuideAssistance(name: "Front Lever Pull", detail: "Train the front-side straight-arm pull toward inverted hang without bending the elbows.", icon: "arrow.up.forward"),
                SkillGuideAssistance(name: "Assisted Ring Arc", detail: "Set rings low and use toe assistance so both the descent and reverse path stay calm.", icon: "shoeprints.fill")
            ],
            tips: [
                SkillGuideTip(title: "Do not release", detail: "The name refers to the ring path around the shoulders, not letting go of a bar.", icon: "hand.raised.fill"),
                SkillGuideTip(title: "Switch shoulder intent", detail: "Use the front-lever side to pull toward the hips, then keep slight protraction and depression through the back-lever side.", icon: "arrow.triangle.branch"),
                SkillGuideTip(title: "Reverse proves ownership", detail: "If you can descend into German hang but cannot reverse the path, the range is too deep for the set.", icon: "arrow.uturn.backward")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Training it as a release-and-recatch move.", fix: "Reset the standard to rings and straight-arm arc control."),
                SkillGuideMistake(mistake: "Bending elbows to muscle through the hard sections.", fix: "Use toe assistance, partial arcs, or front/back lever negatives until the elbows stay locked."),
                SkillGuideMistake(mistake: "Dropping into shoulder extension.", fix: "Lower the rings, use foot support, and stop before sharp anterior shoulder pain.")
            ]
        )
    }

    static func dragonFlagGuide(skillId: String) -> SkillGuide {
        let full = skillId == "cl.dragon-flag"
        return SkillGuide(
            standard: full
                ? "A clean dragon flag anchors the shoulders, lifts the body as one rigid unit, lowers under control without hip pike or lumbar arch, and avoids bouncing between reps."
                : "A clean dragon flag hip raise anchors the shoulders and drives the hips up into one straight line without kipping the legs or folding at the waist.",
            scoringNote: "This is a long-lever anti-extension skill. Stop when the body line breaks; do not grind through back extension.",
            assistance: [
                SkillGuideAssistance(name: "Reverse Crunch", detail: "Curl the pelvis first so the hip raise is abdominal, not just leg momentum.", icon: "arrow.up.circle.fill"),
                SkillGuideAssistance(name: "Tuck Dragon Flag", detail: "Shorten the lever by bending knees while keeping shoulders anchored and hips extended.", icon: "figure.core.training"),
                SkillGuideAssistance(name: "Negative Only", detail: "Start high and lower for 3-5 seconds. Reset at the top instead of bouncing from the bottom.", icon: "arrow.down.forward")
            ],
            tips: [
                SkillGuideTip(title: "Anchor hard", detail: "Hands and lats pin the upper body so the trunk can move as one piece.", icon: "hand.raised.fill"),
                SkillGuideTip(title: "One line, not a pike", detail: "The harder the lever gets, the more tempting it is to fold at the hips. That changes the skill.", icon: "line.diagonal"),
                SkillGuideTip(title: "Own the negative", detail: "Controlled lowers build the dragon flag faster than sloppy full reps.", icon: "metronome")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Piking at the hips.", fix: "Use tuck or one-leg flags until the body can stay rigid."),
                SkillGuideMistake(mistake: "Swinging from the bottom.", fix: "Reset each rep and slow the eccentric."),
                SkillGuideMistake(mistake: "Shrugging or neck strain.", fix: "Re-anchor the shoulders and reduce range if the upper body cannot stay pinned.")
            ]
        )
    }

    static func crowFamilyGuide(skillId: String) -> SkillGuide {
        switch skillId {
        case "hs.crane-pose":
            return SkillGuide(
                standard: "A clean crane pose is a straight-arm arm balance: hands planted shoulder-width, knees high on the upper arms, elbows locked or very close to locked, upper back rounded, hips lifted, and feet floating without a hop.",
                scoringNote: "Crow does not count as crane. Count only holds where the elbows stay straight and the knees remain high on the arms instead of sliding down toward the elbows.",
                assistance: [
                    SkillGuideAssistance(name: "Crow Hold", detail: "Own 15-30 seconds of calm crow first so balance is not the limiter when the elbows begin to straighten.", icon: "timer"),
                    SkillGuideAssistance(name: "Block Under Feet", detail: "Start with toes on a yoga block or low step while practicing the press into straighter arms.", icon: "square.stack.3d.up"),
                    SkillGuideAssistance(name: "Crane Toe Taps", detail: "Press tall, lightly tap one toe down, then float again without rebending the elbows.", icon: "shoeprints.fill")
                ],
                tips: [
                    SkillGuideTip(title: "Hips rise as arms straighten", detail: "Crane is not just crow with strained elbows. Press the floor away and let the hips climb so the balance point stays over the hands.", icon: "arrow.up.circle.fill"),
                    SkillGuideTip(title: "Knees stay high", detail: "Keep the knee contact near the triceps or upper arm. Sliding toward the elbows usually forces a collapse back into crow.", icon: "scope"),
                    SkillGuideTip(title: "Fingers are the brakes", detail: "Use fingertip pressure to stop tipping forward. Do not fix every wobble by bending the arms.", icon: "hand.tap.fill")
                ],
                mistakes: [
                    SkillGuideMistake(mistake: "Calling bent elbows crane.", fix: "Regress to crow-to-crane presses and count only the seconds where elbows stay straight."),
                    SkillGuideMistake(mistake: "Knees slide down the arms.", fix: "Reset the knees higher before the press and keep the upper back rounded."),
                    SkillGuideMistake(mistake: "Hopping into the hold.", fix: "Lean and press until the feet float. Hops hide the balance point.")
                ]
            )
        case "hs.flying-crow":
            return SkillGuide(
                standard: "A clean flying crow holds one knee high on the upper arm while the opposite leg extends long behind the body, toe pointed, shoulders active, fingers steering, and the pelvis controlled instead of twisting open.",
                scoringNote: "Count holds only when the support knee stays connected and the back leg extends from balance, not from a fast kick that throws the body forward.",
                assistance: [
                    SkillGuideAssistance(name: "Crow Knee Anchor", detail: "Practice one-knee crow holds where one knee carries more contact before the opposite leg leaves.", icon: "1.circle.fill"),
                    SkillGuideAssistance(name: "Back-Leg Slides", detail: "From crow, slide one toe back on the floor until the body learns the longer lever.", icon: "arrow.right"),
                    SkillGuideAssistance(name: "Wall Toe Reach", detail: "Reach the back toe toward a wall or block so the extension has a target and does not swing sideways.", icon: "scope")
                ],
                tips: [
                    SkillGuideTip(title: "Shift before extending", detail: "The long leg changes the balance. Move the shoulders and hand pressure first, then lengthen the leg.", icon: "arrow.up.forward"),
                    SkillGuideTip(title: "Anchor knee, long opposite leg", detail: "The support knee is the shelf. The back leg is a lever. If either disappears, the pose turns into a fall.", icon: "line.diagonal"),
                    SkillGuideTip(title: "Keep the kick quiet", detail: "Point the toe and extend smoothly. A whip-like kick usually pulls the hands past their braking power.", icon: "metronome")
                ],
                mistakes: [
                    SkillGuideMistake(mistake: "Back leg swings sideways.", fix: "Use a wall target and extend straight behind the hip before trying longer holds."),
                    SkillGuideMistake(mistake: "Support knee slips off the arm.", fix: "Return to crow and keep the knee higher before shifting."),
                    SkillGuideMistake(mistake: "Dumping into wrists.", fix: "Warm wrists, spread fingers, and reduce hold time until pressure corrections stay small.")
                ]
            )
        default:
            return SkillGuide(
                standard: "A clean crow pose balances on the hands with elbows bent, knees high on the upper arms, hips lifted, upper back rounded, feet off the floor, and gaze slightly forward without collapsing into the wrists.",
                scoringNote: "The feet must float from a controlled forward lean. Do not count knee-resting squats, toe drags, or hops that land in a panic balance.",
                assistance: [
                    SkillGuideAssistance(name: "Tripod Toe Taps", detail: "Keep toes light on the floor while shifting shoulders forward and learning finger pressure.", icon: "shoeprints.fill"),
                    SkillGuideAssistance(name: "Block Under Feet", detail: "Start from a block so the hips are already high and the knees can land higher on the arms.", icon: "square.stack.3d.up"),
                    SkillGuideAssistance(name: "One-Foot Float", detail: "Lift one foot at a time until both feet can float without a jump.", icon: "1.circle.fill")
                ],
                tips: [
                    SkillGuideTip(title: "Build the shelf first", detail: "Elbows bend and knees press high into the arms. Without that shelf, the pose becomes wrist strength and hope.", icon: "scope"),
                    SkillGuideTip(title: "Lean until feet get light", detail: "Shift shoulders forward of the wrists slowly. The feet should peel up because the center of mass moved.", icon: "arrow.forward.circle.fill"),
                    SkillGuideTip(title: "Round the upper back", detail: "Push the floor away and keep the chest from dropping between the shoulders.", icon: "rectangle.compress.vertical")
                ],
                mistakes: [
                    SkillGuideMistake(mistake: "Jumping both feet up.", fix: "Practice one-foot floats and stop once fingertip pressure can control the lean."),
                    SkillGuideMistake(mistake: "Knees too low on the arms.", fix: "Squat deeper, lift hips higher, and place knees closer to the triceps."),
                    SkillGuideMistake(mistake: "Looking straight down.", fix: "Look slightly ahead of the hands so the body can counterbalance instead of tipping forward.")
                ]
            )
        }
    }

    static func elbowLeverGuide(isOneArm: Bool) -> SkillGuide {
        SkillGuide(
            standard: isOneArm
                ? "A clean one-arm elbow lever balances the body horizontal on one anchored elbow with the free arm controlled, wrists stable, glutes tight, and no collapsing through the shoulder."
                : "A clean elbow lever balances the body horizontal with elbows anchored into the lower abdomen or hip crease, hands close enough to support the lean, wrists active, and legs squeezed into one rigid line.",
            scoringNote: "Elbow lever is placement and balance as much as strength. Count holds only when the body floats instead of being kicked up and caught.",
            assistance: [
                SkillGuideAssistance(name: "Frog Stand", detail: "Use a compact balance to learn finger pressure and forward lean before extending the body.", icon: "hand.raised.fill"),
                SkillGuideAssistance(name: "Tuck Elbow Lever", detail: "Keep knees tucked and find the elbow shelf before lengthening the legs.", icon: "figure.core.training"),
                SkillGuideAssistance(name: "Parallette Lever", detail: "Use parallettes if wrist extension on the floor blocks clean practice.", icon: "rectangle.on.rectangle")
            ],
            tips: [
                SkillGuideTip(title: "Elbows are kickstands", detail: "Place them low enough on the abdomen or hip crease that the torso can rest on the shelf.", icon: "scope"),
                SkillGuideTip(title: "Lean until feet float", detail: "Do not jump the legs up. Shift forward and let the balance point lift them.", icon: "arrow.up.forward"),
                SkillGuideTip(title: "Fingers steer", detail: "Press fingertips into the floor to stop tipping forward and heel of hand to shift back.", icon: "hand.tap.fill")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Elbows slide wide or too high.", fix: "Reset hand width and wedge elbows into the lower abdomen before leaning."),
                SkillGuideMistake(mistake: "Trying to lift legs before balance point.", fix: "Lean forward gradually until the feet become light."),
                SkillGuideMistake(mistake: "Wrists collapse.", fix: "Warm up wrists, use parallettes, or reduce hold duration.")
            ]
        )
    }
}
