import SwiftUI

extension SkillGuideLibrary {
    static func legGuide(skillId: String) -> SkillGuide {
        switch skillId {
        case "ld.step-up":
            return stepUpGuide()
        case "ld.deep-squat":
            return deepSquatGuide()
        case "ld.glute-bridge", "ld.single-leg-glute-bridge":
            return gluteBridgeGuide(singleLeg: skillId == "ld.single-leg-glute-bridge")
        case "ld.split-squat", "ld.weighted-split-squat", "ld.bulgarian-split-squat", "ld.weighted-bss":
            return splitSquatGuide(skillId: skillId)
        case "ld.shrimp-squat", "ld.pistol-squat", "ld.weighted-pistol":
            return pistolPathGuide(skillId: skillId)
        case "ld.calf-raise", "ld.weighted-sl-calf":
            return calfGuide(weighted: skillId == "ld.weighted-sl-calf")
        case "ld.jumping-squat", "ld.box-jump":
            return legPowerGuide(boxJump: skillId == "ld.box-jump")
        case "ld.leg-extensions", "ld.sissy-squat":
            return quadIsolationGuide(sissy: skillId == "ld.sissy-squat")
        case "ld.flying-kickback", "ld.fire-hydrant":
            return hipAccessoryGuide(abduction: skillId == "ld.fire-hydrant")
        case "ld.nordic-hip-hinge", "ld.advancing-nordic-curl", "ld.nordic-curl":
            return nordicGuide(skillId: skillId)
        case "ld.floor-to-ceiling-squat":
            return floorToCeilingGuide()
        default:
            return squatBaseGuide()
        }
    }

    static func squatBaseGuide() -> SkillGuide {
        SkillGuide(
            standard: "A clean squat base rep keeps the whole foot rooted, knees tracking with the toes, ribs stacked over the pelvis, and a controlled descent to the target depth before standing without knee cave or bounce.",
            scoringNote: "Depth only counts if foot pressure, knee tracking, and trunk control stay together. Use a box, counterweight, or smaller range before forcing ugly reps.",
            assistance: [
                SkillGuideAssistance(name: "Box Squat", detail: "Sit to a box or bench, pause, then stand without rocking. Lower the box over time as control improves.", icon: "square.fill"),
                SkillGuideAssistance(name: "Counterbalance Squat", detail: "Hold a light plate or kettlebell forward so the torso can stay upright while ankles and hips learn the bottom.", icon: "scalemass.fill"),
                SkillGuideAssistance(name: "Tempo Squat", detail: "Use a 3-second descent and 1-second pause. Tempo exposes heel lift and knee cave fast.", icon: "metronome")
            ],
            tips: [
                SkillGuideTip(title: "Tripod foot", detail: "Keep pressure through heel, big toe, and little toe. If one edge peels off the floor, the knee usually follows.", icon: "scope"),
                SkillGuideTip(title: "Knees follow toes", detail: "Let the knees travel in the same direction the toes point. Caving inward is a strength and control leak.", icon: "arrow.up.left.and.arrow.down.right"),
                SkillGuideTip(title: "Depth is earned", detail: "Use the deepest range you can control without heel lift, pelvic tuck, or pain, then expand it gradually.", icon: "slider.horizontal.3")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Heels lift at the bottom.", fix: "Widen or slightly turn out the stance, use counterbalance work, and add ankle dorsiflexion drills."),
                SkillGuideMistake(mistake: "Knees collapse inward.", fix: "Slow the eccentric and push knees over the second or third toe."),
                SkillGuideMistake(mistake: "Bouncing out of range.", fix: "Pause in the bottom and use fewer reps until the position is owned.")
            ]
        )
    }

    static func stepUpGuide() -> SkillGuide {
        SkillGuide(
            standard: "A clean step-up plants the whole lead foot on a stable box, drives mostly through that lead leg, stands fully tall on top, then steps down under control without dropping or pushing hard from the floor leg.",
            scoringNote: "Start with a lower box if form changes. The box is useful only when the lead leg, knee line, and controlled descent stay honest.",
            assistance: [
                SkillGuideAssistance(name: "Low Step", detail: "Use a low stair or box and make every rep smooth before raising the height.", icon: "arrow.down.to.line"),
                SkillGuideAssistance(name: "Hand-Supported Step-Up", detail: "Lightly touch a wall or rack for balance while the lead leg still supplies the strength.", icon: "hand.raised.fill"),
                SkillGuideAssistance(name: "Eccentric Step-Down", detail: "Stand on the box and lower the free foot slowly to the floor. This builds the control side of the rep.", icon: "arrow.down.forward")
            ],
            tips: [
                SkillGuideTip(title: "Whole foot on the box", detail: "A half-foot plant turns the rep into a calf and balance scramble. Set the foot first, then drive.", icon: "shoeprints.fill"),
                SkillGuideTip(title: "Stand tall before stepping down", detail: "Finish the hip and knee extension on top. Do not rush the descent while still folded over.", icon: "checkmark.seal.fill"),
                SkillGuideTip(title: "Height follows control", detail: "A knee-height box is enough for most training. Higher is not better if the pelvis twists or the trail leg kicks.", icon: "slider.horizontal.3")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Springing off the floor leg.", fix: "Lift the trailing toes or slow the start so the lead leg has to do the work."),
                SkillGuideMistake(mistake: "Knee dives inward on the box.", fix: "Lower the height and track the knee over the second toe."),
                SkillGuideMistake(mistake: "Dropping off the box.", fix: "Step down quietly. If you cannot control the descent, the height or fatigue is too high.")
            ]
        )
    }

    static func deepSquatGuide() -> SkillGuide {
        SkillGuide(
            standard: "A clean deep squat hold keeps both feet flat, hips below knees, knees tracking with toes, spine long enough to breathe, and balance centered without grabbing the floor or collapsing into the joints.",
            scoringNote: "This is active mobility. Count the hold only while the position stays pain-free, foot-flat, and breathable.",
            assistance: [
                SkillGuideAssistance(name: "Heel-Elevated Hold", detail: "Use a small wedge or plate under the heels while ankle mobility catches up. Reduce elevation over time.", icon: "triangle.fill"),
                SkillGuideAssistance(name: "Counterbalance Hold", detail: "Hold a light weight in front to keep the torso upright and explore depth without falling backward.", icon: "scalemass.fill"),
                SkillGuideAssistance(name: "Squat Pry", detail: "At the bottom, gently shift side to side and use elbows inside knees to open hips without forcing pain.", icon: "arrow.left.and.right")
            ],
            tips: [
                SkillGuideTip(title: "Breathe in the bottom", detail: "If you cannot take slow breaths, the body sees the position as a threat instead of a usable range.", icon: "wind"),
                SkillGuideTip(title: "Feet tell the story", detail: "Heels, big toes, and little toes stay grounded. Rocking to one edge shows the missing mobility or balance line.", icon: "scope"),
                SkillGuideTip(title: "Use short daily doses", detail: "Frequent 30-60 second quality holds usually beat rare max-duration suffering.", icon: "calendar")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Forcing depth with heels up.", fix: "Elevate the heels temporarily and work ankle mobility instead of pretending the range is clean."),
                SkillGuideMistake(mistake: "Relaxing into a rounded slump.", fix: "Stay active: chest open, knees out, feet rooted, slow breathing."),
                SkillGuideMistake(mistake: "Holding through knee or hip pain.", fix: "Adjust stance, reduce depth, or use support. Mobility work should feel loaded, not sharp.")
            ]
        )
    }

    static func gluteBridgeGuide(singleLeg: Bool) -> SkillGuide {
        let name = singleLeg ? "single-leg glute bridge" : "glute bridge"
        return SkillGuide(
            standard: "A clean \(name) drives through the heel, reaches full hip extension with ribs down, pauses in a glute squeeze, then lowers without arching the lumbar spine.",
            scoringNote: singleLeg ? "Both hips must rise level. If the pelvis twists or the hamstring cramps instantly, return to two-leg bridges and shorter holds." : "Do not count reps where the lower back creates the height instead of the glutes.",
            assistance: [
                SkillGuideAssistance(name: "Short-Lever Bridge", detail: "Bring heels closer to the hips and use a smaller range while learning the glute squeeze.", icon: "arrow.left.and.right"),
                SkillGuideAssistance(name: "Top-Hold Bridge", detail: "Hold the top for 3-5 seconds with ribs down. This teaches lockout without lumbar extension.", icon: "pause.circle.fill"),
                SkillGuideAssistance(name: "Marching Bridge", detail: "Alternate lifting one foot briefly while hips stay level before committing to full single-leg reps.", icon: "figure.walk")
            ],
            tips: [
                SkillGuideTip(title: "Ribs down, hips up", detail: "The top position should feel like glutes closing the hip, not the spine bending backward.", icon: "figure.core.training"),
                SkillGuideTip(title: "Heel pressure matters", detail: "Driving through toes usually shifts work away from the glutes. Keep the foot planted and heel heavy.", icon: "shoeprints.fill"),
                SkillGuideTip(title: "Pause every rep", detail: "A one-second top squeeze makes the bridge honest and keeps it from becoming a momentum drill.", icon: "metronome")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Lower back arches at the top.", fix: "Tuck ribs down, squeeze glutes, and stop the rep at true hip extension."),
                SkillGuideMistake(mistake: "Hamstrings cramp immediately.", fix: "Move the foot slightly closer, reduce range, and practice top holds."),
                SkillGuideMistake(mistake: "Hips rotate in single-leg reps.", fix: "Use marching bridges or shorter single-leg holds until the pelvis stays level.")
            ]
        )
    }

    static func splitSquatGuide(skillId: String) -> SkillGuide {
        let isBulgarian = skillId.contains("bss") || skillId.contains("bulgarian")
        let isWeighted = skillId.contains("weighted")
        let name = isBulgarian ? "Bulgarian split squat" : "split squat"
        return SkillGuide(
            standard: "A clean \(isWeighted ? "weighted " : "")\(name) uses a stable hip-width stance, front foot rooted, knee tracking over toes, controlled descent, and a front-leg drive to stand without bouncing off the rear leg.",
            scoringNote: "Single-leg work is only useful when both sides match depth and control. Let the weaker side set the load, height, and reps.",
            assistance: [
                SkillGuideAssistance(name: "Supported Split Squat", detail: "Use a wall, rack, or pole lightly for balance so strength work is not limited by wobble.", icon: "hand.raised.fill"),
                SkillGuideAssistance(name: "Short Range Split Squat", detail: "Start with a smaller depth and add range as the knee and hip tolerate it.", icon: "slider.horizontal.3"),
                SkillGuideAssistance(name: "Front-Foot Elevated", detail: "Elevate the front foot slightly when you need more clean depth without folding forward.", icon: "arrow.up.to.line")
            ],
            tips: [
                SkillGuideTip(title: "Train-track stance", detail: "Feet should be hip-width apart, not on one tight line. The wider rail gives the pelvis somewhere stable to work from.", icon: "lines.measurement.horizontal"),
                SkillGuideTip(title: "Rear leg balances", detail: "The back leg is a kickstand, not the engine. If it pushes hard, lower load or use support.", icon: "scope"),
                SkillGuideTip(title: "Load after symmetry", detail: "Add dumbbells only after left and right reps have the same depth, tempo, and knee path.", icon: "scalemass.fill")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Stance too narrow, balance all over the place.", fix: "Set feet on parallel rails and widen before adding reps."),
                SkillGuideMistake(mistake: "Rear foot drives the rep.", fix: "Slow down and think front heel through the floor."),
                SkillGuideMistake(mistake: "Load shortens depth.", fix: "Reduce weight until the bottom position matches the bodyweight version.")
            ]
        )
    }

    static func pistolPathGuide(skillId: String) -> SkillGuide {
        let isShrimp = skillId == "ld.shrimp-squat"
        let isWeighted = skillId == "ld.weighted-pistol"
        let name = isShrimp ? "shrimp squat" : (isWeighted ? "weighted pistol squat" : "pistol squat")
        return SkillGuide(
            standard: isShrimp
                ? "A clean shrimp squat lowers on one leg until the rear knee lightly touches the floor, keeps the working heel planted, then stands without bouncing, twisting, or pushing from the rear leg."
                : "A clean \(name) lowers on one leg to full depth with the free leg off the floor, working foot flat, knee tracking over toes, then stands without bounce or hand assist.",
            scoringNote: "Do not chase the full variation before strength, ankle mobility, and balance are present. Box and assisted reps count as training, not as the full node.",
            assistance: [
                SkillGuideAssistance(name: "Box Pistol", detail: "Sit to a box, pause fully, then stand on one leg. Lower the box over weeks as control improves.", icon: "square.fill"),
                SkillGuideAssistance(name: "Counterweight", detail: "Hold a light plate or kettlebell forward to balance the torso while the leg builds range.", icon: "scalemass.fill"),
                SkillGuideAssistance(name: "Assisted Rail Rep", detail: "Use a strap, rack, or doorframe with minimal arm help. The arms guide balance; the leg still works.", icon: "hand.raised.fill")
            ],
            tips: [
                SkillGuideTip(title: "Control beats depth theater", detail: "A slightly higher controlled rep is more useful than collapsing into a low position you cannot leave.", icon: "checkmark.seal.fill"),
                SkillGuideTip(title: "The ankle is part of the skill", detail: "If the heel lifts, train ankle range and use box pistols instead of forcing reps.", icon: "scope"),
                SkillGuideTip(title: "Use the free leg deliberately", detail: "Keep the free leg active and off the floor. If it drops, regress the range or use assistance.", icon: "figure.walk")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Bouncing out of the bottom.", fix: "Use paused box pistols and 3-second eccentrics until the bottom has strength."),
                SkillGuideMistake(mistake: "Heel rises or foot collapses.", fix: "Regress to assisted work and add ankle mobility before full-depth reps."),
                SkillGuideMistake(mistake: "Twisting to escape the hard point.", fix: "Use a higher box or counterweight and keep hips square.")
            ]
        )
    }

    static func calfGuide(weighted: Bool) -> SkillGuide {
        SkillGuide(
            standard: weighted
                ? "A clean weighted single-leg calf raise starts from a controlled stretch, rises to the highest plantar-flexed position, pauses, and lowers slowly without the free leg assisting."
                : "A clean calf raise uses full range: heels lower under control, ankles rise as high as possible, top pauses briefly, and knees stay steady instead of bouncing.",
            scoringNote: "Calf reps are easy to fake. Count only full-range reps with a pause at the top and a controlled lower.",
            assistance: [
                SkillGuideAssistance(name: "Wall Balance", detail: "Lightly touch a wall so balance does not steal range from the ankle.", icon: "hand.raised.fill"),
                SkillGuideAssistance(name: "Tempo Calf Raise", detail: "Use a 2-second rise, 1-second top pause, and 3-second lower.", icon: "metronome"),
                SkillGuideAssistance(name: "Two-Up One-Down", detail: "Rise with both feet, shift to one foot, then lower slowly on one side.", icon: "arrow.down.forward")
            ],
            tips: [
                SkillGuideTip(title: "Own both ends", detail: "The stretched bottom and high top both matter. Middle-range bouncing is mostly noise.", icon: "arrow.up.and.down"),
                SkillGuideTip(title: "Keep the ankle vertical", detail: "Avoid rolling toward the big toe or little toe as fatigue climbs.", icon: "scope"),
                SkillGuideTip(title: "Load slowly", detail: "Achilles and calf tissue like gradual jumps. Add load only after range stays full.", icon: "plus.circle.fill")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Bouncing short reps.", fix: "Add a top pause and slow lower. Reduce reps if range disappears."),
                SkillGuideMistake(mistake: "Rolling the ankle outward.", fix: "Use wall balance and keep pressure through the big toe mound."),
                SkillGuideMistake(mistake: "Adding load before single-leg control.", fix: "Build bodyweight single-leg reps first, then load in small steps.")
            ]
        )
    }

    static func legPowerGuide(boxJump: Bool) -> SkillGuide {
        SkillGuide(
            standard: boxJump
                ? "A clean box jump starts from a balanced dip, extends hips, knees, and ankles together, lands softly on the box with full foot contact, stands tall, then steps down."
                : "A clean jumping squat hits a controlled squat depth, explodes straight up, lands softly with knees tracking toes, and absorbs into the next rep without collapsing.",
            scoringNote: "Power work ends when height, landing, or alignment drops. Do not turn sloppy jumps into conditioning reps.",
            assistance: [
                SkillGuideAssistance(name: "Snap-Down Landing", detail: "Practice landing in a soft quarter squat with knees tracking toes before adding height.", icon: "arrow.down.forward"),
                SkillGuideAssistance(name: "Low Box Jump", detail: "Use a box you can land on quietly without tucking knees desperately high.", icon: "square.fill"),
                SkillGuideAssistance(name: "Paused Squat Jump", detail: "Pause in the squat for one second, then jump. This removes bounce and builds true concentric power.", icon: "pause.circle.fill")
            ],
            tips: [
                SkillGuideTip(title: "Land like a loaded spring", detail: "Soft knees, full foot, quiet contact. Loud landings usually mean the joints absorbed what the muscles missed.", icon: "waveform.path.ecg"),
                SkillGuideTip(title: "Step down from boxes", detail: "Jumping down adds avoidable ankle and knee impact. Save elastic landings for drills that need them.", icon: "arrow.down.to.line"),
                SkillGuideTip(title: "Full rest keeps power honest", detail: "Use short sets and enough rest. If the next jump is lower, the set is done.", icon: "timer")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Choosing a box too high.", fix: "Use a lower box and land tall instead of winning height by folding into a deep tuck."),
                SkillGuideMistake(mistake: "Knees cave on landing.", fix: "Reduce height or reps and practice snap-downs with knees over toes."),
                SkillGuideMistake(mistake: "Turning jumps into fatigue work.", fix: "Keep sets small and stop when speed changes.")
            ]
        )
    }

    static func quadIsolationGuide(sissy: Bool) -> SkillGuide {
        SkillGuide(
            standard: sissy
                ? "A clean sissy squat keeps hips extended, body long from knees to shoulders, heels lifted, knees traveling forward, and quads controlling the descent and return."
                : "A clean bodyweight leg extension uses a reverse-Nordic-style kneeling line: hips stay open, ribs down, knees bend as the body leans back, then the quads extend the body tall again through a pain-free arc.",
            scoringNote: "Quad-isolation work should feel controlled at the knee. Sharp pain, hip hinging, or bouncing means the range is too aggressive.",
            assistance: [
                SkillGuideAssistance(name: "Support Pole", detail: "Hold a rack or pole for balance so the quads, not fear, limit the set.", icon: "hand.raised.fill"),
                SkillGuideAssistance(name: "Short Range Reps", detail: "Use the pain-free arc first, then extend range over time.", icon: "slider.horizontal.3"),
                SkillGuideAssistance(name: "Slow Eccentric", detail: "Lower for 3-5 seconds and return with control. Tendons adapt better to gradual loading.", icon: "metronome")
            ],
            tips: [
                SkillGuideTip(title: "Hips stay open", detail: "For sissy squats, do not sit back. The whole point is knee extension demand with the hip extended.", icon: "line.diagonal"),
                SkillGuideTip(title: "Earn knee travel", detail: "Forward knee travel is not the enemy, but it has to be progressed and controlled.", icon: "arrow.forward"),
                SkillGuideTip(title: "Use this as accessory work", detail: "Place hard quad isolation after main squats or single-leg work so it does not wreck skill quality.", icon: "list.bullet.clipboard")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Hinging at the hips.", fix: "Use support and shorter range. Keep shoulders, hips, and knees in one long line."),
                SkillGuideMistake(mistake: "Dropping into the bottom.", fix: "Slow the eccentric and stop before control disappears."),
                SkillGuideMistake(mistake: "Training through sharp knee pain.", fix: "Reduce range, load, and volume. Quad burn is fine; joint pain is not the target.")
            ]
        )
    }

    static func hipAccessoryGuide(abduction: Bool) -> SkillGuide {
        SkillGuide(
            standard: abduction
                ? "A clean fire hydrant keeps hands and knees stable, spine quiet, hips mostly square, and lifts the bent leg out to the side from the glute rather than rotating the whole trunk."
                : "A clean kickback keeps the trunk braced, extends the hip from the glute, reaches the leg back without lumbar arch, then returns under control.",
            scoringNote: "These are control accessories. Count reps only while the pelvis stays quiet and the target glute is doing the work.",
            assistance: [
                SkillGuideAssistance(name: "Quadruped Hold", detail: "Hold the top position for 2-3 seconds to learn the glute line before adding reps.", icon: "pause.circle.fill"),
                SkillGuideAssistance(name: "Mini-Band Rep", detail: "Add a light band only after the pelvis stays square without it.", icon: "point.3.connected.trianglepath.dotted"),
                SkillGuideAssistance(name: "Wall-Supported Standing Rep", detail: "Use standing hip abduction or extension when wrists dislike the quadruped setup.", icon: "figure.walk")
            ],
            tips: [
                SkillGuideTip(title: "Small range can be enough", detail: "Chasing height often turns into spine motion. Stop where the glute can still own it.", icon: "scope"),
                SkillGuideTip(title: "Brace before lifting", detail: "Set ribs and pelvis first, then move the leg. The torso should not get dragged around.", icon: "figure.core.training"),
                SkillGuideTip(title: "Use it to clean bigger lifts", detail: "These drills help knee tracking and hip control for step-ups, split squats, and pistols.", icon: "link")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Rotating the body for more height.", fix: "Lower the leg and pause where the pelvis stays still."),
                SkillGuideMistake(mistake: "Arching the lower back.", fix: "Brace ribs down and think glute squeeze, not foot to ceiling."),
                SkillGuideMistake(mistake: "Rushing activation work.", fix: "Use slow reps and top pauses. Speed hides whether the right muscle is working.")
            ]
        )
    }

    static func nordicGuide(skillId: String) -> SkillGuide {
        let isFull = skillId == "ld.nordic-curl"
        let isAdvanced = skillId == "ld.advancing-nordic-curl"
        return SkillGuide(
            standard: isFull
                ? "A clean Nordic curl anchors the ankles, keeps a rigid line from knees to head, lowers under hamstring control, and returns without pushing off the hands."
                : "A clean \(isAdvanced ? "advanced " : "")Nordic hip hinge anchors the ankles, keeps the trunk braced, hinges forward under control, and returns without falling or using the hands as a crutch.",
            scoringNote: "Nordics create high eccentric hamstring load. Use low volume, long rest, and regress before the last inches turn into a fall.",
            assistance: [
                SkillGuideAssistance(name: "Band-Assisted Nordic", detail: "Anchor a band in front or overhead so it helps through the hardest range while you keep the same body line.", icon: "point.3.connected.trianglepath.dotted"),
                SkillGuideAssistance(name: "Eccentric Only", detail: "Lower slowly, catch with the hands, then push back to start. Over time, reduce the hand catch.", icon: "arrow.down.forward"),
                SkillGuideAssistance(name: "Hip-Hinge Regression", detail: "Break at the hips slightly to shorten the lever before returning to a straighter body line.", icon: "slider.horizontal.3")
            ],
            tips: [
                SkillGuideTip(title: "Anchor must be boring", detail: "If the feet shift, the nervous system will protect you by cutting power. Secure the ankles first.", icon: "lock.fill"),
                SkillGuideTip(title: "Hamstrings like gradual exposure", detail: "Start with a few quality reps. Soreness can be intense when volume jumps too fast.", icon: "exclamationmark.triangle.fill"),
                SkillGuideTip(title: "Keep the hips honest", detail: "A tiny hinge can be a planned regression. A sudden pike is the body escaping the load.", icon: "scope")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Falling through the bottom range.", fix: "Use a band, shorter range, or eccentric-only reps until every inch is controlled."),
                SkillGuideMistake(mistake: "Piking hard at the hips.", fix: "Choose a regression deliberately instead of letting the hips bail out mid-rep."),
                SkillGuideMistake(mistake: "Doing high volume too soon.", fix: "Keep early work to low-rep sets with recovery. This is potent eccentric work.")
            ]
        )
    }

    static func floorToCeilingGuide() -> SkillGuide {
        SkillGuide(
            standard: "A clean floor-to-ceiling squat starts lying flat, rises to the feet without hand push-off, finds a squat base, then jumps vertically to touch a true overhead target before landing under control.",
            scoringNote: "This is a mythic power-and-coordination node. Count only reps with no side roll, no hand assist, clear jump target, and safe landing.",
            assistance: [
                SkillGuideAssistance(name: "No-Hands Stand-Up", detail: "Cross-legged or squat stand-ups build the transition without the ceiling-touch demand.", icon: "figure.stand"),
                SkillGuideAssistance(name: "Deck Squat", detail: "Roll to the upper back, return to the feet, and stand before trying the no-hands version.", icon: "arrow.triangle.2.circlepath"),
                SkillGuideAssistance(name: "Vertical Jump", detail: "Train separate high-quality jumps so the final touch is power, not panic.", icon: "arrow.up")
            ],
            tips: [
                SkillGuideTip(title: "Separate the pieces first", detail: "Floor rise, squat catch, jump, and landing all need ownership before linking them.", icon: "square.stack.3d.up"),
                SkillGuideTip(title: "Use a real target", detail: "Touching a measured mark keeps the rep honest and avoids vague almost-jumps.", icon: "scope"),
                SkillGuideTip(title: "Land before celebrating", detail: "The rep finishes when the landing is controlled. Wild landings do not count.", icon: "checkmark.seal.fill")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Rolling sideways to stand.", fix: "Regress to no-hands stand-ups until the rise is symmetrical."),
                SkillGuideMistake(mistake: "Using hands on the floor.", fix: "Slow the transition and build mobility instead of turning it into a burpee."),
                SkillGuideMistake(mistake: "Jumping to an unmeasured target.", fix: "Set a clear mark and count only clean touches with controlled landings.")
            ]
        )
    }
}
