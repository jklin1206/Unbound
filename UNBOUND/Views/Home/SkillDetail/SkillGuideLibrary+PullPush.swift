import SwiftUI

extension SkillGuideLibrary {
    static func pullupGuide(title: String, grip: String, standardDetail: String, extraTip: String?) -> SkillGuide {
        var tips = [
            SkillGuideTip(title: "Start from an honest bottom", detail: "Arms reach full extension before each rep. Brace ribs and glutes before pulling so the body does not turn into a swing.", icon: "arrow.down.to.line"),
            SkillGuideTip(title: "Pull elbows toward the ribs", detail: "Think shoulder blades down and back, then elbows driving to the sides. The chin clears because the body rises, not because the neck reaches.", icon: "arrow.down.backward"),
            SkillGuideTip(title: "Stop sets before reps slow badly", detail: "For skill progress, crisp submaximal sets usually beat grinding until every rep changes shape.", icon: "speedometer")
        ]
        if let extraTip {
            tips.append(SkillGuideTip(title: "Respect the variation", detail: extraTip, icon: "checkmark.seal.fill"))
        }

        return SkillGuide(
            standard: "A clean \(title) uses a \(grip). \(standardDetail)",
            scoringNote: "Count only reps with a still lower body, clear top position, and controlled return to full extension.",
            assistance: [
                SkillGuideAssistance(name: "Band-Assisted Pull-Up", detail: "Use a band that lets every rep finish cleanly. Reduce band help only when the top and bottom positions stay identical.", icon: "point.3.connected.trianglepath.dotted"),
                SkillGuideAssistance(name: "Negative Pull-Up", detail: "Jump or step to the top, then lower for 3-5 seconds through the full range. Keep shoulders down instead of dropping loose.", icon: "arrow.down.forward"),
                SkillGuideAssistance(name: "Inverted Row", detail: "Build pulling volume with rows when full vertical reps are not ready. Keep the body rigid and pull the chest to the bar or rings.", icon: "figure.strengthtraining.functional")
            ],
            tips: tips,
            mistakes: [
                SkillGuideMistake(mistake: "Craning the chin to fake the finish.", fix: "Keep the neck neutral and pull the chest up. The chin clears after the torso rises."),
                SkillGuideMistake(mistake: "Kicking or swinging into the rep.", fix: "Reset to a still hang between reps. Use band assistance if stillness makes the rep disappear."),
                SkillGuideMistake(mistake: "Dropping out of the eccentric.", fix: "Lower under control until the arms are straight. Own the descent before adding reps.")
            ]
        )
    }

    static func weightedPullGuide(isChin: Bool) -> SkillGuide {
        let name = isChin ? "weighted chin-up" : "weighted pull-up"
        let grip = isChin ? "supinated chin-up grip" : "overhand pull-up grip"
        let chinGripDetail = " For the chin-up version, think in two viewpoints: from the athlete's perspective, the knuckles wrap over the far side of the bar; from a front camera, the knuckle side of both hands is visible. Thumbs stay underneath and the wrist never rolls into an overhand pull-up shape."
        return SkillGuide(
            standard: "A clean \(name) is the same strict rep with external load added by belt, vest, or dumbbell. Use a \(grip), brace before the first pull, clear the bar, and control the plate through the descent.\(isChin ? chinGripDetail : "")",
            scoringNote: "Do not count loaded reps that shorten the bottom, swing the weight, or trade range of motion for heavier numbers.",
            assistance: [
                SkillGuideAssistance(name: "Tempo Bodyweight Reps", detail: "Use slow 3-second lowers and pauses at the top before adding load. The weighted rep should inherit this control.", icon: "metronome"),
                SkillGuideAssistance(name: "Light Vest Loading", detail: "Start with a vest or tiny belt load so the rep pattern stays quiet before using heavier hanging plates.", icon: "shippingbox.fill"),
                SkillGuideAssistance(name: "Weighted Negative", detail: "Use very small load and a controlled lower when full weighted reps are not ready. Keep volume low to protect elbows.", icon: "arrow.down.forward")
            ],
            tips: [
                SkillGuideTip(title: "Step into the first rep", detail: "Do not jump into a swinging plate. Set the load still, brace, then pull.", icon: "pause.circle.fill"),
                isChin
                    ? SkillGuideTip(title: "Run the knuckle check", detail: "Before every set, confirm a front view would see the knuckle side of both hands. From your perspective, those knuckles wrap over the far side of the bar.", icon: "hand.raised.fill")
                    : SkillGuideTip(title: "Keep the overhand shape", detail: "The loaded pull-up should keep the same pronated hand position from bottom to top instead of drifting into a mixed or half-chin grip.", icon: "hand.raised.fill"),
                SkillGuideTip(title: "Small jumps win", detail: "Add load in small increments. A clean 2.5-5 lb jump beats a bigger jump that changes the rep.", icon: "plus.circle.fill"),
                SkillGuideTip(title: "Keep bodyweight reps alive", detail: "Weighted work builds strength, but clean unweighted volume keeps the pattern and elbows happier.", icon: "repeat")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Adding weight before clean bodyweight reps.", fix: "Build several strict reps with full range first. Load should amplify the pattern, not replace it."),
                isChin
                    ? SkillGuideMistake(mistake: "Hands flip into a pull-up.", fix: "Reset the grip so a front camera sees knuckles, thumbs stay underneath, and the wrists stay stacked. Reduce load if the wrist cannot hold that orientation.")
                    : SkillGuideMistake(mistake: "Grip changes under load.", fix: "Lower the weight and keep both hands in the same overhand position for the full rep."),
                SkillGuideMistake(mistake: "Letting the plate swing.", fix: "Start still, keep legs quiet, and pause between reps if the load drifts."),
                SkillGuideMistake(mistake: "Cutting range to lift more.", fix: "Use less load until the chin-over-bar top and full-extension bottom both return.")
            ]
        )
    }

    static func explosivePullGuide(isClapping: Bool) -> SkillGuide {
        SkillGuide(
            standard: isClapping
                ? "A clean clapping pull-up starts from a controlled hang, pulls explosively high enough for both hands to leave the bar, claps once, then re-grips and absorbs under control."
                : "A clean explosive pull-up starts from a dead stop, keeps hollow tension, and pulls as high as possible without kipping. The set ends when height or speed drops.",
            scoringNote: "Power reps are quality reps. Count low, crisp attempts; do not turn the set into sloppy conditioning.",
            assistance: [
                SkillGuideAssistance(name: "Fast Assisted Pull-Up", detail: "Use a light band to practice speed while keeping the same strict start and controlled lower.", icon: "bolt.fill"),
                SkillGuideAssistance(name: "Chest-to-Bar Pull-Up", detail: "Build height before release skills. Aim the bar to upper chest, then lower under control.", icon: "arrow.up.forward"),
                SkillGuideAssistance(name: "Jumping Pull + Negative", detail: "Jump to the high position, then own the descent. This trains the landing side of power work without needing max pull height yet.", icon: "arrow.down.forward")
            ],
            tips: [
                SkillGuideTip(title: "Power comes early", detail: "Do explosive work near the start of training after warm-up, before fatigue turns speed into grinding.", icon: "flame.fill"),
                SkillGuideTip(title: "Stop when height drops", detail: "If the bar no longer reaches the same target, the nervous system is practicing slower reps.", icon: "chart.line.downtrend.xyaxis"),
                SkillGuideTip(title: "Strict first, speed second", detail: "Explosive pulling should sit on top of strict control, not replace it.", icon: "checkmark.seal.fill")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Kipping to fake height.", fix: "Return to strict explosive singles or use assistance until the body stays tight."),
                SkillGuideMistake(mistake: "Doing too many reps per set.", fix: "Use short sets of 1-3 reps with full rest. Power fades quickly."),
                SkillGuideMistake(mistake: "Catching loose after release.", fix: "Re-grip with bent elbows and active shoulders, then lower under control.")
            ]
        )
    }

    static func archerPullGuide() -> SkillGuide {
        SkillGuide(
            standard: "A clean archer pull-up uses a wide grip, pulls the chest toward one hand, keeps the opposite arm long, then lowers under control to a full hang before switching or repeating sides.",
            scoringNote: "The working side must clearly do the pull. If both elbows bend equally, it is a wide pull-up, not an archer rep.",
            assistance: [
                SkillGuideAssistance(name: "Archer Ring Row", detail: "Practice the same side-to-side pull on rings with feet on the floor before taking it vertical.", icon: "circle.grid.cross"),
                SkillGuideAssistance(name: "Band-Assisted Archer", detail: "Use a band so the working arm can finish while the assisting arm stays long.", icon: "point.3.connected.trianglepath.dotted"),
                SkillGuideAssistance(name: "Typewriter Hold", detail: "Pull to the top, shift slightly toward one side, then lower. Build control before full side travel.", icon: "arrow.left.and.right")
            ],
            tips: [
                SkillGuideTip(title: "One arm works, one arm guides", detail: "The straight arm is a support rail. The bent arm should feel like the main pull.", icon: "arrow.left.arrow.right"),
                SkillGuideTip(title: "Keep the chest square-ish", detail: "Some rotation is natural, but spinning open to finish hides missing unilateral strength.", icon: "scope"),
                SkillGuideTip(title: "Train both sides honestly", detail: "Start each set with the weaker side or match its reps so asymmetry does not quietly grow.", icon: "equal.circle.fill")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Both arms bend the same amount.", fix: "Widen the grip, use assistance, and keep the non-working arm longer."),
                SkillGuideMistake(mistake: "Cutting the bottom short.", fix: "Return to a full hang each rep so the shoulder learns the whole range."),
                SkillGuideMistake(mistake: "Yanking sideways with no control.", fix: "Slow the eccentric and use ring-row archers until the path is smooth.")
            ]
        )
    }

    static func soloArmGuide(skillId: String) -> SkillGuide {
        let isChin = skillId.contains("chin")
        let isNegative = skillId == "pp.oap-negative"
        let isHeighted = skillId == "pp.heighted-chin-up"
        let name = isHeighted ? "heighted chin-up" : (isNegative ? "one-arm pull-up negative" : (isChin ? "one-arm chin-up" : "one-arm pull-up"))
        let chinStandard = " For chin-up variants, the working hand must stay supinated: from the athlete's perspective, knuckles wrap over the far side of the bar; from a front camera, the knuckle side is visible. Thumb stays underneath and the elbow tracks down and slightly forward."
        return SkillGuide(
            standard: isNegative
                ? "A clean one-arm negative starts at the top with one hand, shoulder packed, torso quiet, and lowers slowly through the full range without dropping or twisting out."
                : "A clean \(name) starts from an active one-arm hang, initiates with scapular depression, pulls the elbow toward the ribs or hip, clears the bar, and lowers under control.\(isChin || isHeighted ? chinStandard : "")",
            scoringNote: "This is tendon-heavy work. Low volume, long rest, and perfect control matter more than chasing daily max attempts.",
            assistance: [
                SkillGuideAssistance(name: "Assisted One-Arm Pull", detail: "Hold a towel, band, ring, or lower strap with the free hand. Move the assist lower over time so it contributes less.", icon: "hand.raised.fill"),
                SkillGuideAssistance(name: "Archer Pull-Up", detail: "Use archers to shift more load to one arm while the other arm stays as a guide.", icon: "arrow.left.and.right"),
                SkillGuideAssistance(name: "One-Arm Isometric", detail: "Hold top, middle, or lower positions for short clean efforts before trying full reps.", icon: "pause.circle.fill")
            ],
            tips: [
                SkillGuideTip(title: "Scap first", detail: "Begin by pulling the shoulder down away from the ear. Bending the elbow before the shoulder is set makes the rep weaker and rougher.", icon: "arrow.down.circle.fill"),
                isChin || isHeighted
                    ? SkillGuideTip(title: "Keep knuckles visible", detail: "On the working hand, a front view should see knuckles through the whole rep. If the palm opens toward the camera, the wrist has flipped out of the chin-up position.", icon: "hand.raised.fill")
                    : SkillGuideTip(title: "Own the working hand", detail: "The working hand stays fixed on the bar while the shoulder and torso organize around it. Do not let the wrist twist to escape the hard range.", icon: "hand.raised.fill"),
                SkillGuideTip(title: "Fight rotation quietly", detail: "Some rotation is unavoidable, but the torso should not spin wildly to manufacture height.", icon: "rotate.3d"),
                SkillGuideTip(title: "Protect the elbows", detail: "Hard negatives and assisted singles need recovery. Stop if tendon pain rises during the session.", icon: "cross.case.fill")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Jumping straight to max attempts.", fix: "Use assisted reps, isometrics, and negatives so the shoulder and elbow adapt gradually."),
                isChin || isHeighted
                    ? SkillGuideMistake(mistake: "Working hand turns overhand.", fix: "Reset before continuing: visible knuckles from the front, thumb under, elbow slightly forward. Add assistance if that position cannot stay.")
                    : SkillGuideMistake(mistake: "Wrist twists to find leverage.", fix: "Use more assistance and keep the working hand stable through the whole range."),
                SkillGuideMistake(mistake: "Dropping through the negative.", fix: "Shorten the range or add assistance until every inch is controlled."),
                SkillGuideMistake(mistake: "Shrugging at the bottom.", fix: "Rebuild active one-arm hangs and scapular depression before full attempts.")
            ]
        )
    }

    static func lSitChinGuide() -> SkillGuide {
        SkillGuide(
            standard: "A clean L-sit chin-up holds a true supinated grip, keeps legs straight near horizontal, pulls from full extension until the chin clears the bar, and lowers without letting the legs drop or swing. From the athlete's perspective, knuckles wrap over the far side of the bar; from a front camera, the knuckle side is visible. Thumbs wrap underneath and the wrists do not roll into overhand.",
            scoringNote: "The pull and the compression both count. If the legs fold or drop, regress the L position before adding reps.",
            assistance: [
                SkillGuideAssistance(name: "Tuck Chin-Up", detail: "Pull with knees tucked high. Keep the same hollow trunk before extending one or both legs.", icon: "figure.core.training"),
                SkillGuideAssistance(name: "Hanging Knee Raise", detail: "Build the compression and hip-flexor endurance needed to keep the legs up during the pull.", icon: "arrow.up.to.line"),
                SkillGuideAssistance(name: "One-Leg L Pull", detail: "Hold one leg straight and one leg tucked to bridge from tuck work to the full L shape.", icon: "figure.strengthtraining.functional")
            ],
            tips: [
                SkillGuideTip(title: "Ribs down before the pull", detail: "Set the hollow/compressed shape first. If the trunk opens, the legs will drop as soon as the pull gets hard.", icon: "circle.hexagongrid.fill"),
                SkillGuideTip(title: "Grip can help", detail: "The chin-up grip lets the biceps help, but only if it stays readable: visible knuckles from the front, thumb underneath, wrist stacked. Use that help to keep the L position cleaner, not to rush reps.", icon: "hand.raised.fill"),
                SkillGuideTip(title: "Own the bottom", detail: "Return to full arm extension while the legs stay lifted. That bottom position is where most reps leak.", icon: "arrow.down.to.line")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Legs drop during the pull.", fix: "Use tuck or one-leg variations until the trunk can hold position through the full rep."),
                SkillGuideMistake(mistake: "Grip turns into a pull-up.", fix: "Reset the hands before the next rep. A front view should see the knuckle side, with thumbs underneath and wrists stacked."),
                SkillGuideMistake(mistake: "Swinging into the first rep.", fix: "Pause in a still L hang before pulling."),
                SkillGuideMistake(mistake: "Partial pull range.", fix: "Lower the leg difficulty so the chin-up can still reach a clear top.")
            ]
        )
    }

    static func rowGuide(skillId: String) -> SkillGuide {
        switch skillId {
        case "pp.incline-row":
            return baseRowGuide(
                name: "incline row",
                standard: "Set the bar or rings high enough that the body is angled, start with arms straight, keep a plank line, and pull lower chest or ribs to the hands without reaching the neck.",
                assistance: "Raise the bar or rings, bend the knees, or walk the feet back until every rep reaches the same top position.",
                progression: "Lower the handles, walk the feet forward, straighten the legs, then progress toward decline rows."
            )
        case "pp.row":
            return baseRowGuide(
                name: "inverted row",
                standard: "Set a low bar or rings so the body is close to horizontal with heels grounded. Start from straight arms, keep ribs down and glutes on, pull lower chest or ribs to the hands, then return to the same straight-arm bottom.",
                assistance: "Raise the bar or rings, bend the knees, or step the feet back until the torso reaches the implement without hips sagging.",
                progression: "Lower the handles, straighten the legs fully, add a top pause, then elevate the feet for decline rows."
            )
        case "pp.decline-row":
            return baseRowGuide(
                name: "decline row",
                standard: "Use a near-horizontal body with feet elevated or handles low, keep head-to-heel tension, pull middle or lower chest to the bar, then lower to straight arms.",
                assistance: "Remove foot elevation, bend the knees, or raise the handles until the hips stop sagging.",
                progression: "Add foot height, rings, pauses, wider grips, or load only after each rep reaches the same top."
            )
        case "pp.one-arm-row":
            return baseRowGuide(
                name: "one-arm row",
                standard: "Pull with one arm while the torso stays square and quiet. The free hand may hover or lightly assist at easier levels, but it cannot twist the rep into place.",
                assistance: "Use a higher ring, wider feet, band help, or an assisted one-arm row with the free hand lightly on the strap.",
                progression: "Lower the rings, narrow the feet, elevate the feet, add pauses, then reduce free-hand assistance."
            )
        case "pp.tuck-row":
            return leverRowGuide(name: "tuck row", shape: "tucked front-lever shape", assistance: "Use tuck front-lever holds, feet-supported arc rows, band assistance, or shorter partial reps.")
        case "pp.straddle-row":
            return leverRowGuide(name: "straddle row", shape: "straddle front-lever shape with hips level and legs open", assistance: "Use advanced tuck rows, one-leg rows, half-straddle rows, band assistance, or controlled negatives.")
        default:
            return leverRowGuide(name: "tuck front lever pull-up", shape: "controlled tuck front lever", assistance: "Use tuck front-lever holds, partial-ROM reps, eccentric-only reps, band assistance, and front-lever rows.")
        }
    }

    static func baseRowGuide(name: String, standard: String, assistance: String, progression: String) -> SkillGuide {
        SkillGuide(
            standard: "A clean \(name) keeps the body as one rigid line. \(standard)",
            scoringNote: "Progress by changing one variable at a time: body angle, foot support, range, tempo, unilateral load, or external load.",
            assistance: [
                SkillGuideAssistance(name: "Raise the Handles", detail: assistance, icon: "arrow.up.to.line"),
                SkillGuideAssistance(name: "Scapular Row", detail: "With straight arms, squeeze and release the shoulder blades before bending the elbows. This teaches the start of the pull.", icon: "arrow.left.and.right"),
                SkillGuideAssistance(name: "Tempo Row", detail: "Use a 2-1-2 rhythm: pull, pause at the top, lower under control. Tempo exposes hips and neck cheating fast.", icon: "metronome")
            ],
            tips: [
                SkillGuideTip(title: "Make the body a plank", detail: "Ribs down, glutes on, and hips level. The row gets harder because the body angle changes, not because the shape falls apart.", icon: "rectangle.compress.vertical"),
                SkillGuideTip(title: "Chest moves, chin does not", detail: "Reach the target with the torso. Neck reaching is usually a sign the rep is too hard.", icon: "scope"),
                SkillGuideTip(title: "Progress one lever at a time", detail: progression, icon: "slider.horizontal.3")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Hips sag or pike mid-rep.", fix: "Raise the handles or bend the knees until the body line stays consistent."),
                SkillGuideMistake(mistake: "Pulling to the throat with a forward head.", fix: "Aim lower chest or ribs to the bar and keep the neck neutral."),
                SkillGuideMistake(mistake: "Bouncing through the top.", fix: "Pause briefly at the top before lowering.")
            ]
        )
    }

    static func leverRowGuide(name: String, shape: String, assistance: String) -> SkillGuide {
        SkillGuide(
            standard: "A clean \(name) begins in a \(shape), keeps shoulders depressed, rows without changing the lever, and lowers back to the same shape under control.",
            scoringNote: "The lever counts as much as the row. Do not progress if the hips drop, knees open unintentionally, or the rep turns into a regular pull-up.",
            assistance: [
                SkillGuideAssistance(name: "Static Lever Hold", detail: "Own the lever shape for short clean holds before adding bent-arm pulling.", icon: "pause.circle.fill"),
                SkillGuideAssistance(name: "Band-Assisted Lever Row", detail: assistance, icon: "point.3.connected.trianglepath.dotted"),
                SkillGuideAssistance(name: "Eccentric Lever Row", detail: "Start near the top and lower slowly while keeping the same lever shape.", icon: "arrow.down.forward")
            ],
            tips: [
                SkillGuideTip(title: "Set the lever first", detail: "Do not start rowing from a loose hang. Depress the shoulders, set the trunk, then bend the arms.", icon: "checkmark.seal.fill"),
                SkillGuideTip(title: "Hips tell the truth", detail: "If the hips fall below the line, the lever is too long for the current strength.", icon: "line.diagonal"),
                SkillGuideTip(title: "Use leverage, not panic", detail: "Tuck, advanced tuck, one-leg, straddle, and full are leverage steps. Pick the shape you can keep.", icon: "slider.horizontal.3")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Opening the tuck to gain momentum.", fix: "Use a shorter set, more assistance, or a simpler lever shape."),
                SkillGuideMistake(mistake: "Shrugging during the pull.", fix: "Return to scapular pulls and static lever holds with shoulders depressed."),
                SkillGuideMistake(mistake: "No controlled eccentric.", fix: "Lower back into the same lever. If you cannot, reduce range or assistance.")
            ]
        )
    }

    static func ringMuscleUpGuide() -> SkillGuide {
        SkillGuide(
            standard: "A clean ring muscle-up starts in a secure false grip, pulls rings close toward the lower chest, rolls the chest over the rings with elbows close, then presses to a stable ring support.",
            scoringNote: "Ring muscle-ups demand false grip, transition control, and ring dip strength. Do not count reps where the rings drift wide or the false grip disappears before transition.",
            assistance: [
                SkillGuideAssistance(name: "False-Grip Ring Row", detail: "Row with the wrist already over the ring. This builds the grip and wrist path used in the transition.", icon: "hand.raised.fill"),
                SkillGuideAssistance(name: "Low-Ring Transition", detail: "Keep feet on the floor, pull rings to the chest, then roll forward into the bottom of a ring dip.", icon: "arrow.triangle.branch"),
                SkillGuideAssistance(name: "Ring Dip Negative", detail: "Build the press-out and bottom support so the transition has somewhere stable to land.", icon: "arrow.down.forward")
            ],
            tips: [
                SkillGuideTip(title: "False grip buys the turnover", detail: "The wrist starts above the ring so you do not need a desperate regrip in the hardest part.", icon: "hand.raised.fill"),
                SkillGuideTip(title: "Rings stay close", detail: "Pull the rings down the body. If they drift away, the transition becomes a shoulder fight.", icon: "arrow.down.to.line"),
                SkillGuideTip(title: "Transition low and forward", detail: "Move the chest over the rings, elbows back, then press. It is not a normal pull-up followed by a pause.", icon: "arrow.up.and.forward")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Losing false grip mid-rep.", fix: "Spend more time on false-grip hangs, rows, and low-ring transitions."),
                SkillGuideMistake(mistake: "Rings flare away from the body.", fix: "Use feet assistance and keep the rings brushing close through the pull."),
                SkillGuideMistake(mistake: "Trying to transition too low.", fix: "Build stricter high pulls and use assistance until the rings reach lower chest.")
            ]
        )
    }

    static func strictMuscleUpGuide() -> SkillGuide {
        SkillGuide(
            standard: "A clean strict muscle-up starts from a dead or active hang, uses no kip or hip drive, pulls high enough to transition smoothly, keeps elbows close, then presses to full support.",
            scoringNote: "This is stricter than the regular muscle-up node. If swing or hip drive creates the turnover, log it under regular muscle-up work.",
            assistance: [
                SkillGuideAssistance(name: "High Strict Pull", detail: "Train strict pulls toward lower chest or upper stomach so the transition has enough height.", icon: "arrow.up.forward"),
                SkillGuideAssistance(name: "Slow Transition Negative", detail: "Start in top support and lower through the transition slowly, keeping wrists and elbows close.", icon: "arrow.down.forward"),
                SkillGuideAssistance(name: "Straight-Bar or Ring Dip", detail: "Own the press-out position so the turnover does not collapse once the chest gets over the hands.", icon: "figure.strengthtraining.functional")
            ],
            tips: [
                SkillGuideTip(title: "It is one continuous skill", detail: "Strict muscle-up is not pull-up, pause, then dip. The pull must feed the transition before momentum dies.", icon: "link"),
                SkillGuideTip(title: "False grip can help", detail: "A higher wrist shortens the turnover, especially on rings or slower strict reps.", icon: "hand.raised.fill"),
                SkillGuideTip(title: "Negatives are potent", detail: "Use low volume and clean control. Hard transition negatives can beat up elbows if stacked too often.", icon: "exclamationmark.triangle.fill")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Pulling only to chin height.", fix: "Build high-pull strength before expecting a strict turnover."),
                SkillGuideMistake(mistake: "Flaring elbows wide in transition.", fix: "Use assisted transitions and keep elbows close as the chest comes over."),
                SkillGuideMistake(mistake: "Calling a quiet kip strict.", fix: "Reset the standard: no swing, no hip pop, no leg kick.")
            ]
        )
    }

    static func pushupGuide(skillId: String) -> SkillGuide {
        let isIncline = skillId == "cal.incline-pushup"
        let isDecline = skillId == "cal.decline-pushup"
        let name = isIncline ? "incline push-up" : (isDecline ? "decline push-up" : "push-up")
        let surface = isIncline ? "hands elevated on a stable bench or box" : (isDecline ? "feet elevated on a stable bench or box" : "hands on the floor")
        let depth = isIncline ? "chest touches the bench" : "chest reaches the floor or a fist-width above it"
        return SkillGuide(
            standard: "A clean \(name) starts in a rigid plank with \(surface), hands around shoulder width, ribs tucked, glutes squeezed, and legs quiet. Lower until \(depth), keep elbows about 30-45 degrees from the ribs, then press to a full elbow lockout without losing the body line.",
            scoringNote: "Count only full-range reps with one straight head-to-heel line. If the hips sag, the head dives first, or the elbows flare wide, regress the angle before chasing more reps.",
            assistance: [
                SkillGuideAssistance(name: "Wall Push-Up", detail: "Use a wall when floor strength is not there yet. Keep the same plank line and elbow path instead of treating it like a casual lean.", icon: "rectangle.portrait"),
                SkillGuideAssistance(name: "Higher Incline", detail: "Raise the hands until every rep reaches honest depth. Lower the surface over time: wall, counter, bench, low box, floor.", icon: "arrow.up.to.line"),
                SkillGuideAssistance(name: "Negative Push-Up", detail: "Lower for 3-5 seconds, then reset from knees or a high plank. Slow eccentrics teach depth without turning the press into a grind.", icon: "arrow.down.forward"),
                SkillGuideAssistance(name: "Knee Push-Up", detail: "Use knees only if the trunk stays straight from head to knees. It is a strength step, not permission to fold at the hips.", icon: "figure.strengthtraining.functional")
            ],
            tips: [
                SkillGuideTip(title: "Make it a moving plank", detail: "Set ribs down, glutes on, and quads tight before the first rep. The chest and hips should travel together.", icon: "rectangle.compress.vertical"),
                SkillGuideTip(title: "Hands under the chest, not the face", detail: "At the bottom, forearms should look roughly vertical from the side. Hands too high turn the rep into a shoulder-crank.", icon: "hand.raised.fill"),
                SkillGuideTip(title: "Use the right angle", detail: "Incline builds the first strict rep. Decline increases shoulder and upper-chest load after regular push-ups are clean.", icon: "slider.horizontal.3")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Sagging hips or piking up.", fix: "Regress to a higher incline and add hollow holds until the body line stays locked."),
                SkillGuideMistake(mistake: "Elbows flare to 90 degrees.", fix: "Turn the elbow pits slightly forward, screw the hands into the floor, and aim elbows diagonally back."),
                SkillGuideMistake(mistake: "Partial reps that never reach depth.", fix: "Use a target at chest height or raise the hands until full range is repeatable."),
                SkillGuideMistake(mistake: "Head reaches the floor first.", fix: "Keep the neck neutral and lower the whole torso as one piece.")
            ]
        )
    }

    static func closePushGuide(skillId: String) -> SkillGuide {
        let isSphinx = skillId == "cal.sphinx-pushup"
        return SkillGuide(
            standard: isSphinx
                ? "A clean sphinx push-up starts in a forearm plank, presses through the forearms until the elbows fully extend, then returns under control without the hips rising or sagging."
                : "A clean diamond push-up uses close hands under the sternum, elbows tracking back near the ribs, chest reaching the hands, and a full lockout while the trunk stays in one plank line.",
            scoringNote: "This is close-grip pressing. Count it only if the elbow path and lockout stay strict; if the hands drift wide or the hips pike, it is no longer the intended skill.",
            assistance: [
                SkillGuideAssistance(name: "Close-Grip Incline Push-Up", detail: "Raise the hands and keep the same close elbow path. Lower the surface as the triceps catch up.", icon: "arrow.up.to.line"),
                SkillGuideAssistance(name: "Eccentric Close-Grip Rep", detail: "Use a slow 3-5 second lower through the close-grip path, then reset from knees if needed.", icon: "metronome"),
                SkillGuideAssistance(name: "Triceps Extension", detail: "Band or dumbbell extensions add direct elbow-extension volume without more wrist-loaded push-ups.", icon: "figure.strengthtraining.functional")
            ],
            tips: [
                SkillGuideTip(title: "Elbows go back", detail: "Think triceps brushing the ribs. Flaring turns the movement into an awkward regular push-up.", icon: "arrow.down.backward"),
                SkillGuideTip(title: "Lockout matters", detail: "Finish with elbows straight and shoulders active. The last inch is the point of close-grip work.", icon: "checkmark.seal.fill"),
                SkillGuideTip(title: "Protect the wrists", detail: "Use push-up handles, parallettes, or a slightly wider hand shape if the classic diamond bothers the wrists.", icon: "cross.case.fill")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Hands too far forward.", fix: "Set the hands under the lower chest or sternum so the forearms can stack."),
                SkillGuideMistake(mistake: "Hips shoot up to finish.", fix: "Regress the angle and keep glutes squeezed through the press."),
                SkillGuideMistake(mistake: "Half lockout.", fix: "End every rep with straight elbows before starting the next descent.")
            ]
        )
    }

    static func dipGuide(skillId: String) -> SkillGuide {
        let isBench = skillId == "cal.bench-dip"
        return SkillGuide(
            standard: isBench
                ? "A clean bench dip keeps hands on a stable bench behind the hips, elbows tracking back, shoulders controlled, hips close to the bench, and presses to full elbow lockout without bouncing."
                : "A clean parallel-bar dip starts in a locked support, shoulders depressed, torso controlled, lowers until the shoulders are at least level with or slightly below the elbows if mobility allows, then presses to a full stable lockout.",
            scoringNote: "Shoulder comfort sets the depth ceiling. Deeper is not better if the shoulder rolls forward or pinches; use the deepest controlled pain-free range.",
            assistance: [
                SkillGuideAssistance(name: "Support Hold", detail: "Hold the top position with elbows locked, shoulders down, and body still. This teaches the support you must return to after every rep.", icon: "pause.circle.fill"),
                SkillGuideAssistance(name: "Negative Dip", detail: "Lower for 3-5 seconds, step down, and reset. Keep shoulders packed instead of collapsing into the bottom.", icon: "arrow.down.forward"),
                SkillGuideAssistance(name: "Band-Assisted Dip", detail: "Use a band between the bars under the knees or feet so the range stays full and the shoulder position stays clean.", icon: "point.3.connected.trianglepath.dotted")
            ],
            tips: [
                SkillGuideTip(title: "Own support first", detail: "If the top support shakes or shoulders shrug, full dips will leak power and irritate joints.", icon: "checkmark.seal.fill"),
                SkillGuideTip(title: "Lean is a dial", detail: "A slight forward lean biases chest. A more upright torso biases triceps. Both still need controlled shoulders.", icon: "slider.horizontal.3"),
                SkillGuideTip(title: "Press the bars down", detail: "Think of pushing the bars toward the floor rather than lifting the body. It keeps shoulders active at lockout.", icon: "arrow.down.to.line")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Shrugging or sinking at the bottom.", fix: "Shorten range and practice support holds plus slow negatives until shoulders stay packed."),
                SkillGuideMistake(mistake: "Swinging the legs to escape the bottom.", fix: "Use band assistance and reset still between reps."),
                SkillGuideMistake(mistake: "Soft top position.", fix: "Pause one second at lockout on every rep.")
            ]
        )
    }

    static func ringDipGuide() -> SkillGuide {
        SkillGuide(
            standard: "A clean ring dip starts in a still support with elbows locked, rings close to the body, and rings turned out at the top. Lower under control with rings tracking close, reach a controlled dip bottom, then press to a stable turned-out support without swinging or letting the rings flare wide.",
            scoringNote: "Ring dips are not just harder bar dips. The support position counts. If the rings drift wide, the top is unstable, or the turn-out disappears entirely, regress to support work.",
            assistance: [
                SkillGuideAssistance(name: "RTO Support Hold", detail: "Build 15-30 second rings-turned-out support holds before full reps. Palms rotate forward while elbows stay locked.", icon: "pause.circle.fill"),
                SkillGuideAssistance(name: "Foot-Assisted Ring Dip", detail: "Set rings low and keep toes lightly on the floor. Use the legs only enough to keep the rings close and the rep smooth.", icon: "figure.strengthtraining.functional"),
                SkillGuideAssistance(name: "Ring Dip Negative", detail: "Start in support, lower slowly, step down, and reset. Do not grind out ugly presses from a flared bottom.", icon: "arrow.down.forward"),
                SkillGuideAssistance(name: "Strict Bar Dip", detail: "Own stable bar dips first. Rings add instability; they should not be the first place you learn pressing depth.", icon: "rectangle.split.2x1")
            ],
            tips: [
                SkillGuideTip(title: "Rings brush the body", detail: "Keep rings close to the ribs through the descent and press. Wide rings turn the rep into a shoulder fight.", icon: "arrow.left.and.right"),
                SkillGuideTip(title: "Turn out at the top", detail: "The top support should finish with the rings turned out and elbows locked. That is the ring-specific standard.", icon: "rotate.right.fill"),
                SkillGuideTip(title: "Low reps, high quality", detail: "Ring dips degrade fast. Use small sets and longer rest so every rep teaches stability.", icon: "speedometer")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Rings flare away from the torso.", fix: "Return to RTO support holds, foot-assisted reps, and slower negatives."),
                SkillGuideMistake(mistake: "Skipping the turn-out.", fix: "Pause at the top and rotate palms forward before each descent."),
                SkillGuideMistake(mistake: "Swinging through the set.", fix: "Reset to a dead-still support between reps or lower the rings for foot assistance.")
            ]
        )
    }

    static func pikePushGuide(skillId: String) -> SkillGuide {
        let isElevated = skillId == "cal.elevated-pike-pushup"
        let isFloating = skillId == "cal.floating-pike-pushup"
        let name = isFloating ? "floating pike push-up" : (isElevated ? "elevated pike push-up" : "pike push-up")
        return SkillGuide(
            standard: "A clean \(name) stacks the hips high, keeps shoulders active, lowers the head between the hands into a tripod-like path, then presses back up by driving the floor away. The rep should feel like vertical pressing, not a regular push-up with hips slightly raised.",
            scoringNote: "Count reps only while the hips stay high and the head travels between the hands. If the body drifts backward or the elbows flare wide, the handstand-push-up pattern is not being trained.",
            assistance: [
                SkillGuideAssistance(name: "Box Pike Hold", detail: "Hold the pike shape with hips high and shoulders stacked before adding reps.", icon: "pause.circle.fill"),
                SkillGuideAssistance(name: "Partial Pike Push-Up", detail: "Use a shallow range first, then increase depth as the head path and elbow angle stay clean.", icon: "arrow.down.forward"),
                SkillGuideAssistance(name: "Elevated Pike", detail: "Raise the feet only after floor pike reps are clean. More height adds shoulder load fast.", icon: "arrow.up.to.line"),
                SkillGuideAssistance(name: "Wall HSPU Negative", detail: "For advanced athletes, slow wall negatives teach the next vertical press without requiring a full press yet.", icon: "metronome")
            ],
            tips: [
                SkillGuideTip(title: "Push up, not back", detail: "Imagine pressing toward a handstand. If the hips shoot backward, the shoulders are escaping the load.", icon: "arrow.up"),
                SkillGuideTip(title: "Tripod bottom", detail: "Hands and head form a triangle at the bottom. Head landing in line with the hands usually means the path is too cramped.", icon: "triangle.fill"),
                SkillGuideTip(title: "Elevate slowly", detail: "Small increases in foot height can be a large jump in shoulder demand. Keep reps clean before chasing height.", icon: "slider.horizontal.3")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Hips too low.", fix: "Walk the feet closer or use an elevated surface that lets the hips stack."),
                SkillGuideMistake(mistake: "Head drops in front of the hands.", fix: "Aim the crown between the hands and slightly forward into a tripod."),
                SkillGuideMistake(mistake: "Elbows flare wide.", fix: "Turn the elbow pits forward and track elbows diagonally back.")
            ]
        )
    }

    static func handstandPushGuide() -> SkillGuide {
        SkillGuide(
            standard: "A clean handstand push-up starts from a stable handstand or wall handstand, hands around shoulder width, ribs tucked, lowers under control until the head lightly contacts the floor or pad, then presses to full lockout with the shoulders elevated and body line controlled.",
            scoringNote: "Wall-supported reps count for early progress. Freestanding reps are a separate mastery standard. Do not count kipping, crashing to the head, banana-back lockouts, or partial-range presses.",
            assistance: [
                SkillGuideAssistance(name: "Pike Push-Up", detail: "Build the vertical pressing path on the floor before taking the body upside down.", icon: "figure.strengthtraining.functional"),
                SkillGuideAssistance(name: "Elevated Pike Push-Up", detail: "Feet elevated increases shoulder load and bridges toward wall HSPU strength.", icon: "arrow.up.to.line"),
                SkillGuideAssistance(name: "Wall Negative", detail: "Kick or wall-walk up, lower for 3-5 seconds to the head target, then come down safely.", icon: "arrow.down.forward"),
                SkillGuideAssistance(name: "Partial ROM HSPU", detail: "Use pads or ab mats to shorten range, then remove height gradually as full-range strength appears.", icon: "rectangle.stack.fill")
            ],
            tips: [
                SkillGuideTip(title: "Tripod, then press", detail: "At the bottom, hands and head form a triangle. This gives the shoulders room to press instead of folding straight down.", icon: "triangle.fill"),
                SkillGuideTip(title: "Toes point to the wall", detail: "In chest-to-wall work, the toes point toward the wall as a light line reference. Do not plant the heels or turn the feet away to prop up the rep.", icon: "shoeprints.fill"),
                SkillGuideTip(title: "Ribs stay tucked", detail: "The wall makes arching tempting. Keep glutes tight and ribs down so the lockout is a handstand, not a backbend.", icon: "rectangle.compress.vertical"),
                SkillGuideTip(title: "Use strict volume carefully", detail: "HSPU overloads wrists, neck, and shoulders. Use low crisp sets and stop before reps become head-bounces.", icon: "cross.case.fill")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Kipping off the wall.", fix: "Log it separately. For strict progress, use partial range or negatives until the press is honest."),
                SkillGuideMistake(mistake: "Crashing onto the head.", fix: "Add a pad, lower slower, and reduce range until the bottom is controlled."),
                SkillGuideMistake(mistake: "Banana-back lockout.", fix: "Practice chest-to-wall holds, hollow body work, and glute squeeze at the top.")
            ]
        )
    }

    static func ninetyDegreePushGuide() -> SkillGuide {
        SkillGuide(
            standard: "A clean 90-degree push-up starts from a controlled handstand, leans forward into a bent-arm horizontal body line with elbows around 90 degrees, then presses back to handstand without kicking, piking, or losing shoulder control.",
            scoringNote: "This is not a deep handstand push-up. Count it only when the body reaches a clear horizontal bent-arm line and returns by pressing, not by throwing the legs.",
            assistance: [
                SkillGuideAssistance(name: "Deep HSPU Negative", detail: "Lower slowly past the normal head-touch range toward a bent-arm planche angle, then step down before collapse.", icon: "arrow.down.forward"),
                SkillGuideAssistance(name: "Bent-Arm Planche Hold", detail: "Build the horizontal bottom shape separately so the press has somewhere real to pass through.", icon: "pause.circle.fill"),
                SkillGuideAssistance(name: "Wall-Assisted 90-Degree Negative", detail: "Use a wall or spotter to control the line while learning the forward lean and shoulder load.", icon: "rectangle.portrait")
            ],
            tips: [
                SkillGuideTip(title: "Lean before you bend", detail: "The shoulders must travel forward past the wrists before the elbows bend. That shift moves the center of mass over the hands instead of turning the rep into a deep handstand push-up.", icon: "arrow.forward.circle.fill"),
                SkillGuideTip(title: "Hands under the balance point", detail: "At the 90-degree point, the hands sit near the body's center of mass with shoulders far forward. Feet, knees, hips, chest, and head stay off the floor.", icon: "arrow.up.forward"),
                SkillGuideTip(title: "Keep the body one piece", detail: "Ribs down, glutes on, legs together. Piking the hips turns the skill into a different press.", icon: "rectangle.compress.vertical"),
                SkillGuideTip(title: "Use tiny volume", detail: "This is high-load wrist, elbow, and shoulder work. A few pristine attempts beat fatigued grinding.", icon: "speedometer")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Only doing a deeper HSPU.", fix: "Add the forward shoulder lean and move the balance point over the hands before counting it as 90-degree work."),
                SkillGuideMistake(mistake: "Feet touch the floor in the bottom.", fix: "Regress to bent-arm planche holds or negatives until the legs can hover without piking."),
                SkillGuideMistake(mistake: "Kicking back to handstand.", fix: "Regress to negatives, bent-arm holds, or wall assistance until the press does the work."),
                SkillGuideMistake(mistake: "Hips fold in the bottom.", fix: "Shorten range and rebuild hollow tension through bent-arm planche progressions.")
            ]
        )
    }

    static func clappingHandstandPushGuide() -> SkillGuide {
        SkillGuide(
            standard: "A clean clapping handstand push-up starts from a stable strict handstand push-up, presses explosively enough for both hands to leave the floor, claps once, catches under control, and returns to a tall handstand line.",
            scoringNote: "Release work only counts when the catch is safe and controlled. Do not count wall kicks, head bounces, partial claps, or catches that collapse the elbows or neck.",
            assistance: [
                SkillGuideAssistance(name: "Explosive Pike Push-Up", detail: "Practice fast pressing with the feet on the floor before taking release work upside down.", icon: "bolt.fill"),
                SkillGuideAssistance(name: "Partial ROM Power HSPU", detail: "Use pads to reduce range and train speed while keeping the same handstand line.", icon: "rectangle.stack.fill"),
                SkillGuideAssistance(name: "Handstand Pop-Off", detail: "From a short range, pop both hands lightly off the floor without clapping, then absorb cleanly.", icon: "arrow.up.forward")
            ],
            tips: [
                SkillGuideTip(title: "Strict strength first", detail: "A clap is a speed expression of strict HSPU strength. If strict reps are unstable, release reps are not ready.", icon: "checkmark.seal.fill"),
                SkillGuideTip(title: "Use the HSPU line", detail: "Practice from the same chest-to-wall position as the strict handstand push-up. Toes stay light on the wall, but the wall is only a line reference.", icon: "shoeprints.fill"),
                SkillGuideTip(title: "Clap near the support line", detail: "The hands pop just off the floor and meet close under the head and shoulders. Reaching forward turns the catch into a dive instead of a press.", icon: "hands.clap.fill"),
                SkillGuideTip(title: "Catch soft, then tall", detail: "Land with enough elbow bend to absorb, then push tall through the shoulders before the next attempt.", icon: "arrow.down.forward.circle.fill"),
                SkillGuideTip(title: "Singles are enough", detail: "Use crisp singles with long rest. Fatigue makes upside-down catches ugly fast.", icon: "timer")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Using the wall as a launch kick.", fix: "Reduce range and keep the same chest-to-wall HSPU line. The clap comes from the press, not from flipping or kicking off the wall."),
                SkillGuideMistake(mistake: "Reaching the clap forward.", fix: "Keep the clap close to the original hand path, under the head and shoulders, so the catch lands back under the body."),
                SkillGuideMistake(mistake: "Catching stiff-armed.", fix: "Practice pop-offs and absorb with active shoulders before adding the clap."),
                SkillGuideMistake(mistake: "Clapping too low.", fix: "Train more launch height first. The hands need time to return safely.")
            ]
        )
    }

    static func bentArmPressGuide() -> SkillGuide {
        SkillGuide(
            standard: "A clean bent-arm press starts from a controlled tripod, tuck, or straddle setup, shifts shoulders forward, floats the hips, then presses smoothly to handstand without jumping the legs or collapsing onto the head.",
            scoringNote: "Count only presses that move through shoulder strength and balance. A kick-up, headstand jump, or uncontrolled roll-through is not the same skill.",
            assistance: [
                SkillGuideAssistance(name: "Tripod Press Negative", detail: "Start in handstand, lower slowly through a bent-arm path to tripod or tuck, and step down cleanly.", icon: "arrow.down.forward"),
                SkillGuideAssistance(name: "Wall-Assisted Press", detail: "Use the wall as a light line guide while practicing the hip lift and shoulder press.", icon: "rectangle.portrait"),
                SkillGuideAssistance(name: "Tuck Press Drill", detail: "Float the knees tight to the chest before opening into handstand. A shorter lever makes the press teachable.", icon: "figure.core.training")
            ],
            tips: [
                SkillGuideTip(title: "Hips rise before legs", detail: "If the feet kick first, the press becomes a disguised kick-up. Lift the hips over the shoulders first.", icon: "arrow.up"),
                SkillGuideTip(title: "Head is light", detail: "The head can guide the tripod, but the arms and shoulders must carry the press.", icon: "scope"),
                SkillGuideTip(title: "Open late", detail: "Keep the tuck or straddle compact until the hips stack, then extend into the final handstand.", icon: "arrow.up.forward")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Jumping off the feet.", fix: "Use a higher start, wall assistance, or negatives until the hips can float without a kick."),
                SkillGuideMistake(mistake: "Dumping weight into the head.", fix: "Push harder through the hands and reduce range until the neck stays unloaded."),
                SkillGuideMistake(mistake: "Arching into the finish.", fix: "Keep ribs tucked and arrive in a real handstand line before counting the rep.")
            ]
        )
    }

    static func planchePushGuide(skillId: String) -> SkillGuide {
        let isTuck = skillId == "cal.tuck-planche-pushup"
        return SkillGuide(
            standard: isTuck
                ? "A clean tuck planche push-up starts from a real tuck planche, lowers without the feet touching, then presses back to locked elbows while the tuck, protraction, and forward shoulder lean stay intact."
                : "A clean pseudo-planche push-up keeps the body in one rigid hollow line while the hands sit near the hips, shoulders stay clearly forward of the wrists, elbows track back, and the shoulder blades stay pushed apart through the whole rep.",
            scoringNote: isTuck
                ? "Do not count reps that begin from a bent-arm planche, tap the feet on the floor, or press into a different top shape than the start."
                : "This is not a hard push-up with the hands a little low. Count reps only when the forward lean stays present at the bottom and top.",
            assistance: [
                SkillGuideAssistance(name: isTuck ? "Tuck Planche Negative" : "Planche Lean", detail: isTuck ? "Start in the hold and lower slowly to a bent-arm tuck position. Step down before form collapses, then rebuild the press separately." : "Hold locked elbows, protracted shoulders, posterior pelvic tilt, and a measurable forward lean before adding a push-up.", icon: "pause.circle.fill"),
                SkillGuideAssistance(name: isTuck ? "Band-Assisted Reps" : "Feet-Elevated Lean", detail: isTuck ? "Use hip assistance to keep the feet floating and elbows tracking back through the press." : "Elevating feet can make the shoulder angle more planche-specific, but only if protraction and hollow shape stay clean.", icon: isTuck ? "point.3.connected.trianglepath.dotted" : "arrow.up.to.line"),
                SkillGuideAssistance(name: "Partial ROM Lean Push-Up", detail: "Use a shallow range and keep the same shoulder lean. Increase depth only when lean survives the whole rep.", icon: "slider.horizontal.3")
            ],
            tips: [
                SkillGuideTip(title: "Protraction is non-negotiable", detail: "Spread the shoulder blades and push the floor away. Planche pressing collapses when the upper back relaxes.", icon: "arrow.left.and.right"),
                SkillGuideTip(title: "Lean is progressive load", detail: "Mark hand or shoulder position and move the shoulders farther forward over months, not random max attempts.", icon: "ruler.fill"),
                SkillGuideTip(title: "Wrists need prep", detail: "Turn fingers slightly out or back, warm wrists before heavy lean work, and use parallettes if flat palms become the limiter.", icon: "hand.raised.fill")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Losing forward lean during the press.", fix: "Shorten the range or reduce lean until the shoulder position stays fixed."),
                SkillGuideMistake(mistake: isTuck ? "Feet brush the floor at the bottom." : "Piking hips to reduce load.", fix: isTuck ? "Use a band, parallettes, or less depth until the whole rep floats." : "Squeeze glutes, tuck ribs down, and return to a plank or hollow body line."),
                SkillGuideMistake(mistake: "Elbows flare wide.", fix: "Turn the elbow pits forward, bend elbows back, and reduce lean until the shoulders can control the path.")
            ]
        )
    }

    static func plancheHoldGuide(skillId: String) -> SkillGuide {
        switch skillId {
        case "pl.tuck-planche":
            return SkillGuide(
                standard: "A clean tuck planche is held on locked elbows with shoulders forward of the hands, scapulae protracted and depressed, hips near shoulder height, knees tight to the chest, heels close to the glutes, and no knee support on the arms.",
                scoringNote: "Crow, crane, and frog stand do not count. The knees must float free, the elbows stay straight, and the hips cannot sink into a tucked L-sit.",
                assistance: [
                    SkillGuideAssistance(name: "Raised Planche Lean", detail: "Use a box or bench under the feet, lean forward with locked arms, and practice the exact shoulder and scapular position before trying to float.", icon: "arrow.up.right"),
                    SkillGuideAssistance(name: "One-Knee Float", detail: "From crane or supported tuck, lift one knee off the arm at a time. This teaches the no-knee-support standard without jumping straight to both legs.", icon: "1.circle.fill"),
                    SkillGuideAssistance(name: "Band-Assisted Tuck", detail: "Loop a band around the hips so you can hold the right shape longer without dumping into bent arms or low hips.", icon: "point.3.connected.trianglepath.dotted")
                ],
                tips: [
                    SkillGuideTip(title: "Push the bars away", detail: "Round the upper back by protracting hard. If the shoulder blades collapse together, the hold usually drops immediately.", icon: "arrow.left.and.right.circle.fill"),
                    SkillGuideTip(title: "Shoulders pass the hands", detail: "If the shoulders stack directly over the wrists, the feet cannot float without cheating somewhere else.", icon: "arrow.forward.circle.fill"),
                    SkillGuideTip(title: "Tuck tight before opening", detail: "A compact tuck shortens the lever. Open the knees only after the basic tuck is repeatable with the same shoulder position.", icon: "lock.fill")
                ],
                mistakes: [
                    SkillGuideMistake(mistake: "Bent elbows turn it into a bent-arm balance.", fix: "Regress to planche leans or one-knee floats. Straight-arm strength is the point of this node."),
                    SkillGuideMistake(mistake: "Hips hang below the shoulders.", fix: "Pull knees closer, posteriorly tilt the pelvis, and push harder through the shoulders before counting the hold."),
                    SkillGuideMistake(mistake: "Neck cranes up to find balance.", fix: "Look slightly ahead or between the hands and keep the head neutral so the trunk can stay rounded.")
                ]
            )
        case "pl.straddle-planche":
            return advancedPlancheGuide(
                name: "straddle planche",
                standard: "A clean straddle planche holds locked elbows, protracted shoulders, hips level with the shoulders, legs straight and wide, toes pointed, and a slightly hollow body line parallel to the floor.",
                scoring: "A wide straddle can be a valid bridge, but the body still has to stay horizontal. Do not count holds where the legs droop or the back arches to fake length.",
                bridge: "Advanced Tuck Planche",
                bridgeDetail: "Open the knees away from the chest while keeping the back controlled. This is the main bridge between tuck and straddle."
            )
        case "pl.half-lay-planche":
            return advancedPlancheGuide(
                name: "half-lay planche",
                standard: "A clean half-lay planche keeps the same locked-arm, protracted, horizontal planche line as the straddle while the legs move partway toward parallel, narrowing the lever without letting the hips drop.",
                scoring: "This is a bridge from straddle to full planche. Count it only when the legs narrow intentionally and the torso line remains unchanged.",
                bridge: "Narrow-Straddle Holds",
                bridgeDetail: "Start from a wide straddle and close the legs a few inches while preserving height and protraction."
            )
        case "pl.full-planche":
            return SkillGuide(
                standard: "A clean full planche is a straight-arm horizontal hold with hands as the only contact point, shoulders forward of the hands, scapulae strongly protracted and depressed, ribs down, pelvis tucked, glutes and quads squeezed, legs together, toes pointed, and the body roughly parallel to the floor.",
                scoringNote: "This node is the strict standard. Bent elbows, dropped hips, a banana back, or a brief uncontrolled float should not be counted as a full planche hold.",
                assistance: [
                    SkillGuideAssistance(name: "Band-Assisted Full Planche", detail: "Set the band at hip height and use only enough help to keep the real full-planche line. The band should teach shape, not hide collapse.", icon: "point.3.connected.trianglepath.dotted"),
                    SkillGuideAssistance(name: "Box-Supported Full Line", detail: "Place feet on a box at body-line height, lean shoulders forward, and press down as if trying to lift the feet.", icon: "shippingbox.fill"),
                    SkillGuideAssistance(name: "Straddle or Half-Lay Holds", detail: "Use the hardest prior lever you can hold cleanly for volume, then test the full line in short fresh attempts.", icon: "slider.horizontal.3")
                ],
                tips: [
                    SkillGuideTip(title: "The shoulders carry the skill", detail: "Full planche is not just core tension. The shoulders must stay forward, depressed, and protracted while the elbows remain locked.", icon: "arrow.forward.circle.fill"),
                    SkillGuideTip(title: "Hollow beats banana", detail: "Posterior pelvic tilt, ribs down, glutes tight, and quads locked keep the body from folding into a low-back arch.", icon: "circle.hexagongrid.fill"),
                    SkillGuideTip(title: "Train it fresh", detail: "High-skill straight-arm work belongs early in the session with long rests. Once the line changes, stop or regress.", icon: "speedometer")
                ],
                mistakes: [
                    SkillGuideMistake(mistake: "Hips drop while the chest stays high.", fix: "Return to half-lay, straddle, or band assistance and rebuild the hollow line."),
                    SkillGuideMistake(mistake: "Elbows soften under load.", fix: "Reduce lever length and add straight-arm planche lean volume. Do not practice bent elbows as full planche."),
                    SkillGuideMistake(mistake: "Maxing the same hold every day.", fix: "Use two or three focused sessions per week with wrist prep, long rest, and lower-intensity support work between.")
                ]
            )
        default:
            return SkillGuide(
                standard: "A clean bent-arm planche keeps the body horizontal with legs extended, elbows bent around a strong dip angle, shoulders protracted, chest forward, and no elbow shelf wedged into the hips.",
                scoringNote: "This is a useful planche-adjacent strength skill, but it is not a substitute for straight-arm tuck, straddle, or full planche progress.",
                assistance: [
                    SkillGuideAssistance(name: "Elbow Lever", detail: "Use elbow lever work only as a body-line and balance bridge. The bent-arm planche gradually removes the hip shelf.", icon: "figure.core.training"),
                    SkillGuideAssistance(name: "Planche Lean Push-Up", detail: "Build the forward shoulder pressure and bent-arm pressing strength before trying to float the legs.", icon: "arrow.forward.circle.fill"),
                    SkillGuideAssistance(name: "Band-Assisted Bent-Arm Hold", detail: "Use assistance at the hips so the body can stay horizontal while the shoulders learn the position.", icon: "point.3.connected.trianglepath.dotted")
                ],
                tips: [
                    SkillGuideTip(title: "Keep the line horizontal", detail: "The rep should look like a low flying plank, not a deep push-up with the legs dragging behind.", icon: "line.diagonal"),
                    SkillGuideTip(title: "Do not confuse paths", detail: "Bent-arm work builds pressing power, but straight-arm planche still needs locked-elbow leans and holds.", icon: "arrow.triangle.branch"),
                    SkillGuideTip(title: "Exit before collapse", detail: "Step down when hips start falling. A clean short hold teaches more than a long wrestle.", icon: "checkmark.seal.fill")
                ],
                mistakes: [
                    SkillGuideMistake(mistake: "Elbows wedge into the hips like an elbow lever.", fix: "Shift shoulders forward and let the arms support the body instead of using the hip shelf."),
                    SkillGuideMistake(mistake: "Bending so deep it becomes a paused push-up.", fix: "Use a stronger elbow angle and band assistance until the body floats."),
                    SkillGuideMistake(mistake: "Calling bent-arm progress full-planche progress.", fix: "Keep it as accessory strength while the straight-arm planche ladder remains the main measure.")
                ]
            )
        }
    }

    static func advancedPlancheGuide(name: String, standard: String, scoring: String, bridge: String, bridgeDetail: String) -> SkillGuide {
        SkillGuide(
            standard: standard,
            scoringNote: scoring,
            assistance: [
                SkillGuideAssistance(name: bridge, detail: bridgeDetail, icon: "slider.horizontal.3"),
                SkillGuideAssistance(name: "Tuck Push-Back", detail: "From tuck planche, push the knees back toward open tuck, half straddle, or one-leg planche for short controlled pulses.", icon: "arrow.backward.circle.fill"),
                SkillGuideAssistance(name: "Band-Assisted \(name.capitalized)", detail: "Use hip assistance to practice the real line without losing scapular protraction.", icon: "point.3.connected.trianglepath.dotted")
            ],
            tips: [
                SkillGuideTip(title: "Open gradually", detail: "Use intermediate lever steps rather than gambling on max holds. The jump between planche shapes is larger than it looks.", icon: "slider.horizontal.3"),
                SkillGuideTip(title: "Same shoulders, harder legs", detail: "The shoulder position should stay depressed, protracted, and forward while the legs make the lever harder.", icon: "checkmark.seal.fill"),
                SkillGuideTip(title: "Hips tell the truth", detail: "If hips drop below shoulder level, the lever is too long for today. Regress before the body learns a banana line.", icon: "line.diagonal")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Arching the lower back.", fix: "Posteriorly tilt the pelvis, squeeze glutes, and return to an easier lever if the hollow line disappears."),
                SkillGuideMistake(mistake: "Scapulae retract as the lever lengthens.", fix: "Add protraction holds and banded practice before unassisted attempts."),
                SkillGuideMistake(mistake: "Chasing long holds with a broken line.", fix: "Use two to five clean seconds, then accumulate volume at the prior progression.")
            ]
        )
    }

    static func unilateralPushGuide(skillId: String) -> SkillGuide {
        let isOneArm = skillId == "cal.one-arm-pushup"
        return SkillGuide(
            standard: isOneArm
                ? "A clean one-arm push-up uses one hand under the shoulder or slightly inside, feet wide enough for balance, free hand off the floor, body controlled as one unit, chest reaches full depth, then the working arm presses to lockout without wild hip rotation."
                : "A clean archer push-up starts with wide hands, shifts bodyweight over one working arm, keeps the opposite arm long as a guide, reaches full depth on the working side, and presses back without both arms sharing the load equally.",
            scoringNote: "Unilateral pressing is about load shift plus anti-rotation. If the assisting arm does half the work or the torso spins open, regress the variation.",
            assistance: [
                SkillGuideAssistance(name: "Incline One-Arm Push-Up", detail: "Raise the working hand to reduce load while keeping the one-arm line honest.", icon: "arrow.up.to.line"),
                SkillGuideAssistance(name: "Archer Push-Up", detail: "Use archers to bridge from bilateral reps to one-arm reps. The straight arm should guide, not press hard.", icon: "arrow.left.and.right"),
                SkillGuideAssistance(name: "Eccentric One-Arm Rep", detail: "Lower slowly with one arm, then use both arms or knees to return. Keep rotation quiet.", icon: "arrow.down.forward"),
                SkillGuideAssistance(name: "Wide-Stance Plank Shift", detail: "Shift weight from side to side in a plank to build wrist, shoulder, and trunk tolerance.", icon: "figure.core.training")
            ],
            tips: [
                SkillGuideTip(title: "Wide feet are allowed", detail: "A wider base lets strength be the limiter instead of balance noise. Narrow later for mastery.", icon: "arrow.left.and.right"),
                SkillGuideTip(title: "Press through the floor", detail: "Drive the working palm down and slightly inward so the shoulder stays centered instead of dumping forward.", icon: "hand.raised.fill"),
                SkillGuideTip(title: "Train the weaker side first", detail: "Match the strong side to the weak side's clean reps. This skill exposes asymmetry fast.", icon: "equal.circle.fill")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Hips twist open to escape the bottom.", fix: "Raise the hand, widen the feet, and add slow eccentrics until rotation quiets down."),
                SkillGuideMistake(mistake: "Assisting arm secretly presses.", fix: "Use fingertips or a slider for the guide arm, or regress to incline archers."),
                SkillGuideMistake(mistake: "Partial depth.", fix: "Use an incline and a clear chest target until full range returns.")
            ]
        )
    }

    static func explosivePushGuide(skillId: String) -> SkillGuide {
        let isClap = skillId == "cal.clapping-pushup"
        let isTriple = skillId == "cal.triple-clap-pushup"
        let name = isTriple ? "triple-clap push-up" : (isClap ? "clapping push-up" : "explosive push-up")
        return SkillGuide(
            standard: "A clean \(name) starts as a strict push-up, descends under control, then presses explosively enough for the hands to leave the floor. Land with soft elbows, return to the same plank line, and reset if the rhythm breaks.",
            scoringNote: "Power reps are neurological quality work. Count only reps with clear airtime, safe landing, and no hip-snap cheat.",
            assistance: [
                SkillGuideAssistance(name: "Incline Plyo Push-Up", detail: "Use hands on a box so you can learn fast intent and soft landing before floor-level power.", icon: "arrow.up.to.line"),
                SkillGuideAssistance(name: "Explosive Push-Up", detail: "Hands leave the floor without a clap. Build consistent airtime before adding clap demands.", icon: "bolt.fill"),
                SkillGuideAssistance(name: "Eccentric + Fast Press", detail: "Lower for 2-3 seconds, pause, then press fast without leaving the floor. This builds the launch pattern.", icon: "metronome")
            ],
            tips: [
                SkillGuideTip(title: "Do power fresh", detail: "Train explosive reps early after warm-up. Fatigue turns power into slow sloppy pressing.", icon: "flame.fill"),
                SkillGuideTip(title: "Catch like a spring", detail: "Land with elbows slightly bent and shoulders active. Locked-arm catches are not worth the risk.", icon: "arrow.down.forward.circle.fill"),
                SkillGuideTip(title: "Small sets only", detail: "Use sets of 1-5. Stop when airtime, clap height, or landing quality drops.", icon: "speedometer")
            ],
            mistakes: [
                SkillGuideMistake(mistake: "Hip buck for fake airtime.", fix: "Return to incline plyo reps and keep the body as one plank."),
                SkillGuideMistake(mistake: "Stiff locked-elbow landing.", fix: "Practice lower-intensity releases and absorb with soft elbows."),
                SkillGuideMistake(mistake: "Too many reps after power fades.", fix: "End the set when the hands barely leave the floor.")
            ]
        )
    }
}
