import SwiftUI

// MARK: - SkillGuideLibrary


enum SkillGuideLibrary {
    static func guide(for skillId: String) -> SkillGuide? {
        switch skillId {
        case "pp.dead-hang":
            return SkillGuide(
                standard: "A clean dead hang starts from a secure overhand grip with arms straight, shoulders active enough to stay controlled, ribs down, legs quiet, and no twisting or swinging.",
                scoringNote: "Use this as the grip and shoulder-control root for the Pull branch. Passive hanging is useful, but skill progress should favor a controlled active hang.",
                assistance: [
                    SkillGuideAssistance(name: "Foot-Assisted Hang", detail: "Keep one or both feet lightly on a box so the shoulders and grip learn the position without taking full bodyweight immediately.", icon: "square.stack.3d.up"),
                    SkillGuideAssistance(name: "Scapular Pull", detail: "From straight arms, pull the shoulders down away from the ears without bending the elbows. This teaches the active shoulder used before every pull.", icon: "arrow.down.to.line"),
                    SkillGuideAssistance(name: "Towel or Ring Hang", detail: "Use towels or rings only after the standard bar hang is comfortable. The extra grip demand should not make the shoulder position sloppy.", icon: "circle.grid.cross")
                ],
                tips: [
                    SkillGuideTip(title: "Own the bottom", detail: "The bottom of every pull-up is a hang. If the grip, ribs, or shoulders collapse there, the rep starts behind before it starts moving.", icon: "hand.raised.fill"),
                    SkillGuideTip(title: "Shoulders are quiet, not shrugged", detail: "Let the arms reach long, but keep enough shoulder engagement that you are not hanging from irritated soft tissue.", icon: "arrow.down.circle.fill"),
                    SkillGuideTip(title: "Stop before the grip tears apart", detail: "For training, leave a little grip in reserve. White-knuckle max hangs can wreck the next pulling session.", icon: "timer")
                ],
                mistakes: [
                    SkillGuideMistake(mistake: "Shrugging into the ears.", fix: "Practice short scapular pulls and think shoulders down, neck long before adding longer hang time."),
                    SkillGuideMistake(mistake: "Swinging through the whole hold.", fix: "Start with a still body. Lightly squeeze glutes and keep legs together until the hang stops drifting."),
                    SkillGuideMistake(mistake: "Dropping suddenly at the end.", fix: "Step down or release under control. The finish should not be a fall.")
                ]
            )
        case "pp.pullup", "pp.strict-pullup", "pp.wide-pullup":
            return pullupGuide(
                title: skillId == "pp.wide-pullup" ? "wide pull-up" : (skillId == "pp.strict-pullup" ? "strict pull-up" : "pull-up"),
                grip: skillId == "pp.wide-pullup" ? "overhand grip set wider than shoulder width" : "overhand grip around shoulder width to slightly wider",
                standardDetail: skillId == "pp.wide-pullup" ? "The wider grip increases upper-back and lat demand, but the same rules apply: full extension, no kip, chin clearly over the bar, and controlled descent." : "Start from full arm extension, keep the body quiet, pull until the chin clearly clears the bar, then lower under control back to full extension.",
                extraTip: skillId == "pp.strict-pullup" ? "Strict means no hidden rhythm. If the legs or hips create the rep, it belongs in a different bucket." : nil
            )
        case "pp.chin-up", "pp.strict-chin-up":
            return pullupGuide(
                title: skillId == "pp.strict-chin-up" ? "strict chin-up" : "chin-up",
                grip: "supinated grip around shoulder width or slightly narrower",
                standardDetail: "Use the same full-extension bottom and chin-over-bar top as a pull-up. The supinated grip lets the biceps help more, but the rep still has to stay controlled.",
                extraTip: "If the wrists or elbows complain, narrow the grip or use neutral-grip work while you build tolerance."
            )
        case "pp.weighted-pullup", "pp.weighted-chin-up":
            return weightedPullGuide(isChin: skillId == "pp.weighted-chin-up")
        case "pp.explosive-pullup", "pp.clapping-pullup":
            return explosivePullGuide(isClapping: skillId == "pp.clapping-pullup")
        case "pp.archer-pullup":
            return archerPullGuide()
        case "pp.oap-negative", "pp.one-arm-pullup", "pp.heighted-chin-up", "pp.one-arm-chin-up":
            return soloArmGuide(skillId: skillId)
        case "pp.l-sit-chin-up":
            return lSitChinGuide()
        case "pp.incline-row", "pp.row", "pp.decline-row", "pp.one-arm-row", "pp.tuck-row", "pp.straddle-row", "pp.tuck-front-lever-pullup":
            return rowGuide(skillId: skillId)
        case "pp.muscle-up":
            return SkillGuide(
                standard: "A clean bar muscle-up starts from an active hang, passes through one smooth high pull and turnover, finishes with both elbows locked above the bar, and does not use a chicken-wing catch or uncontrolled bar crash.",
                scoringNote: "This regular muscle-up allows a controlled hollow-to-arch swing and hip drive. A zero-momentum false-grip rep belongs to the later strict muscle-up node.",
                assistance: [
                    SkillGuideAssistance(
                        name: "Banded Muscle-Up",
                        detail: "Loop the band on the bar and place one foot or knee in it. Use enough help to keep the rep smooth, then reduce band thickness over time. Do not rebound out of the bottom.",
                        icon: "point.3.connected.trianglepath.dotted"
                    ),
                    SkillGuideAssistance(
                        name: "Low-Bar Transition",
                        detail: "Use a low bar with feet on the floor. Pull, lean the chest over the bar, and press out while the legs supply only the minimum assistance needed.",
                        icon: "arrow.triangle.branch"
                    ),
                    SkillGuideAssistance(
                        name: "Jumping Negative",
                        detail: "Jump to the top support, lower through the dip and transition slowly, then return to the hang. This teaches the path in reverse without needing a full pull.",
                        icon: "arrow.down.forward"
                    ),
                    SkillGuideAssistance(
                        name: "Explosive Chest-to-Bar Pull-Up",
                        detail: "Build the pull height before full attempts. Aim the bar to the lower chest or upper stomach, not just chin-over-bar.",
                        icon: "arrow.up.forward"
                    ),
                    SkillGuideAssistance(
                        name: "Straight-Bar Dip",
                        detail: "Own the press-out position above a single bar. Muscle-ups often fail because the athlete can pull high but cannot press from the awkward bar-dip bottom.",
                        icon: "figure.strengthtraining.functional"
                    )
                ],
                tips: [
                    SkillGuideTip(
                        title: "False grip is a tool, not a religion",
                        detail: "A stronger false grip makes the turnover easier because the wrist starts partly above the bar. Explosive bar muscle-ups can be done with less false grip, but the more strict and slow the rep becomes, the more the false grip matters.",
                        icon: "hand.raised.fill"
                    ),
                    SkillGuideTip(
                        title: "Legs create timing, not chaos",
                        detail: "Use the legs as one connected lever. In the kip-style rep, the hollow-to-arch rhythm helps send the hips upward and the chest around the bar. Bent-knee kicking can get a rep, but it usually teaches a messy path.",
                        icon: "figure.run"
                    ),
                    SkillGuideTip(
                        title: "The pull is not a normal pull-up",
                        detail: "A pull-up goes mostly vertical. A muscle-up pull has to create height and then rotate the torso around the bar. Think pull the bar toward the lower ribs while the chest moves forward over the hands.",
                        icon: "arrow.up.and.forward"
                    ),
                    SkillGuideTip(
                        title: "Transition practice should be submaximal",
                        detail: "If every attempt is a grind, the nervous system keeps practicing panic. Use bands, a low bar, or jumping negatives so the elbows turn over together and the chest-over-hands timing stays clean.",
                        icon: "speedometer"
                    ),
                    SkillGuideTip(
                        title: "Strict muscle-up is a different standard",
                        detail: "The normal muscle-up can use controlled swing and hip drive. The strict muscle-up asks for a much quieter body, stronger false grip, higher pulling strength, and a slower transition.",
                        icon: "checkmark.seal.fill"
                    )
                ],
                mistakes: [
                    SkillGuideMistake(
                        mistake: "Pulling low and crashing into the bar.",
                        fix: "Build explosive chest-to-bar height and use a band until the bar reaches low chest or upper stomach before the turnover."
                    ),
                    SkillGuideMistake(
                        mistake: "One elbow turns over before the other.",
                        fix: "Stop max attempts. Drill low-bar transitions and banded reps where both elbows roll over together."
                    ),
                    SkillGuideMistake(
                        mistake: "Kicking the knees separately to force the rep.",
                        fix: "Return to hollow-to-arch swings and keep the legs long. If you need leg help, use one connected hip drive."
                    ),
                    SkillGuideMistake(
                        mistake: "Losing the wrist during the turnover.",
                        fix: "Practice false-grip hangs, false-grip rows, and low-bar turnovers so the hands do not need a desperate mid-air regrip."
                    ),
                    SkillGuideMistake(
                        mistake: "Pressing before the chest is over the bar.",
                        fix: "Delay the press until the torso has moved over the hands. Think pull first, lean through, then dip."
                    )
                ]
            )
        case "hs.wall-plank":
            return handstandGuide(
                standard: "A clean wall plank starts in a push-up position with the feet walked up the wall, hands shoulder-width, elbows locked, shoulders pushed tall, ribs tucked, and head between the arms. The angle can be partial, but the brace and shoulder shape must stay honest.",
                scoringNote: "Credit only controlled holds and exits. Bent elbows, collapsed shoulders, rushed wall steps, or a sagging low back stop the clock.",
                assistance: [
                    ("Box Pike Hold", "Put feet on a box and walk the hands back until the hips stack higher. This teaches shoulder loading before the wall adds fear.", "rectangle.3.group.fill"),
                    ("Partial Wall Walk", "Walk only as high as the user can keep elbows locked and ribs down. Height comes after control.", "arrow.up.right"),
                    ("Bear Hold Shoulder Shift", "Hold a bear crawl position and shift weight from hand to hand so the wrists and shoulders learn palm pressure.", "figure.strengthtraining.functional")
                ],
                tips: [
                    ("Push the floor away", "The wall plank is already handstand practice if the shoulders stay elevated and the body gets longer.", "arrow.up.circle.fill"),
                    ("Small wall steps win", "Rushing up the wall usually creates panic and a soft line. Move one foot at a time and keep breathing.", "shoeprints.fill"),
                    ("Exit is part of the rep", "Walk down with the same control used to walk up. Falling out teaches the wrong finish.", "checkmark.seal.fill")
                ],
                mistakes: [
                    ("Elbows bend as the feet climb.", "Lower the feet and shorten the hold until the arms can stay locked."),
                    ("The low back sags.", "Cue ribs in and glutes tight; use a box pike hold if the wall angle is too demanding."),
                    ("Head looks forward.", "Look between the hands so the shoulders can open and the neck stays long.")
                ]
            )
        case "hs.wall-handstand-30":
            return SkillGuide(
                standard: "A clean wall handstand is chest-to-wall, hands roughly shoulder-width, elbows locked, shoulders elevated by the ears, ribs tucked, glutes tight, legs together, and only light toe contact with the wall. The hold should keep its shape while the athlete breathes.",
                scoringNote: "Count only time spent in the stacked shape. If the low back arches hard, elbows soften, shoulders collapse, or the athlete has to hold their breath to survive, stop the clock there.",
                assistance: [
                    SkillGuideAssistance(
                        name: "Box Pike Hold",
                        detail: "Place feet on a box and walk hands back until hips stack over shoulders. This loads the wrists and shoulders without asking for a full vertical wall walk yet.",
                        icon: "rectangle.3.group.fill"
                    ),
                    SkillGuideAssistance(
                        name: "Partial Wall Walk",
                        detail: "Walk the feet only as high as you can keep ribs tucked and elbows locked. Add height before adding duration.",
                        icon: "arrow.up.right"
                    ),
                    SkillGuideAssistance(
                        name: "Back-to-Wall Hold",
                        detail: "Use it for entry confidence, not line practice. Keep ribs down and avoid learning the big banana shape that chest-to-wall work is meant to fix.",
                        icon: "square.dashed"
                    ),
                    SkillGuideAssistance(
                        name: "Wrist Prep Circuit",
                        detail: "Use wrist rocks, palm lifts, fingertip pulses, and gentle extension loading before holds so the hands can actually balance and tolerate pressure.",
                        icon: "hand.raised.fill"
                    )
                ],
                tips: [
                    SkillGuideTip(
                        title: "The wall should feel light",
                        detail: "If the toes are smashed into the wall, the body is leaning on support instead of learning a line. Walk closer, push taller, and make the wall a reference point.",
                        icon: "scope"
                    ),
                    SkillGuideTip(
                        title: "Shoulders go up, not down",
                        detail: "In a handstand, active shoulders mean pushing the floor away until the body gets longer. Collapsed shoulders make the hold feel heavier and shorten the line.",
                        icon: "arrow.up.circle.fill"
                    ),
                    SkillGuideTip(
                        title: "Breathing is the audit",
                        detail: "A position that only exists while holding air is not owned yet. Shorter holds with calm breaths beat longer holds that turn into a survival brace.",
                        icon: "lungs.fill"
                    ),
                    SkillGuideTip(
                        title: "Exit before the shape breaks",
                        detail: "Wall handstands are practice, not punishment. Step down while you still control the arms and wrists so the last rep teaches the right finish.",
                        icon: "checkmark.seal.fill"
                    )
                ],
                mistakes: [
                    SkillGuideMistake(
                        mistake: "Hands too far from the wall, body arched hard.",
                        fix: "Walk hands closer only as far as you can keep ribs down, glutes tight, and shoulders open."
                    ),
                    SkillGuideMistake(
                        mistake: "Soft elbows under fatigue.",
                        fix: "End the set when elbows start bending. Add shorter clusters instead of forcing one long hold."
                    ),
                    SkillGuideMistake(
                        mistake: "Head pokes forward to stare at the floor.",
                        fix: "Look between the hands and keep the ears framed by the arms so the shoulders can open."
                    ),
                    SkillGuideMistake(
                        mistake: "The wall walk becomes a frantic scramble.",
                        fix: "Use partial wall walks and controlled step-downs until each hand step is deliberate."
                    )
                ]
            )
        case "hs.headstand":
            return handstandGuide(
                standard: "A clean headstand uses a stable tripod: hands and head form a triangle, palms press the floor, neck stays long, elbows stay controlled, and the legs rise slowly from tuck to vertical without kicking.",
                scoringNote: "Count only quiet holds with weight shared through the hands. No credit for neck compression, rolling, elbow flare, or a jump into the wall.",
                assistance: [
                    ("Tripod Knee Shelf", "Place knees on the upper arms and practice lifting one foot at a time before extending the legs.", "triangle.fill"),
                    ("Tuck Headstand", "Hold a compact tuck with hips over the base before trying full vertical legs.", "arrow.up.and.down"),
                    ("Wall-Supported Headstand", "Use the wall as a safety target while keeping most balance through the hands and shoulders.", "rectangle.portrait")
                ],
                tips: [
                    ("Hands protect the neck", "Press the palms down and keep the shoulders active so the head is not carrying the whole hold.", "hand.raised.fill"),
                    ("Lift slowly", "A headstand should float up from a tuck. Kicking turns it into a roll waiting to happen.", "tortoise.fill"),
                    ("Triangle first", "If the base is too narrow or too wide, balance gets noisy before the legs even move.", "triangle")
                ],
                mistakes: [
                    ("Too much weight dumps into the head.", "Return to tripod knee shelves and push harder through the palms."),
                    ("Legs kick up fast.", "Use tuck progressions and extend one leg at a time."),
                    ("Elbows flare out.", "Reset hand width and grip the floor before lifting.")
                ]
            )
        case "hs.freestanding-hs-30":
            return SkillGuide(
                standard: "A clean freestanding handstand starts from a controlled entry, stacks hands, shoulders, hips, and ankles, keeps elbows locked and shoulders active, balances mainly through finger and palm pressure, breathes normally, and exits intentionally instead of falling out.",
                scoringNote: "For the 30-second node, do not count walking saves, big banana-back holds, repeated leg scissoring, or time spent collapsing into a bailout. The standard is a repeatable balance, not a lucky fight.",
                assistance: [
                    SkillGuideAssistance(
                        name: "Chest-to-Wall Line Hold",
                        detail: "Use the wall to rehearse the exact body line: hands close enough to stack, shoulders tall, ribs down, glutes on, toes light.",
                        icon: "rectangle.portrait"
                    ),
                    SkillGuideAssistance(
                        name: "Heel Pull",
                        detail: "Start chest-to-wall, gently pull one heel then both heels off the wall, and let the fingers catch overbalance before returning lightly to the wall.",
                        icon: "arrow.left.and.right"
                    ),
                    SkillGuideAssistance(
                        name: "Toe Pull",
                        detail: "From back-to-wall, peel the toes away and find the balance point without kicking through it. This teaches underbalance recovery.",
                        icon: "arrow.up.backward"
                    ),
                    SkillGuideAssistance(
                        name: "Controlled Kick-Up",
                        detail: "Kick with one long lever and stop at the balance point. If every attempt slams past vertical, reduce kick height and use the wall as a quiet target.",
                        icon: "figure.run"
                    ),
                    SkillGuideAssistance(
                        name: "Cartwheel Bail",
                        detail: "Practice turning one hand out and stepping down sideways before max attempts. Confidence with the exit keeps the entry from becoming timid.",
                        icon: "arrow.uturn.down"
                    )
                ],
                tips: [
                    SkillGuideTip(
                        title: "Fingers are the brakes",
                        detail: "When the body tips past vertical, press the fingertips into the floor. When it falls short, shift pressure toward the heel of the hand and reach taller through the shoulders.",
                        icon: "hand.tap.fill"
                    ),
                    SkillGuideTip(
                        title: "Stack first, then hold",
                        detail: "A handstand that begins bent usually stays bent. Spend attempts arriving in the line before worrying about how many seconds you can wrestle out of it.",
                        icon: "line.diagonal"
                    ),
                    SkillGuideTip(
                        title: "The ribs decide the shape",
                        detail: "Ribs down and glutes on put the pelvis under you. If the ribs flare, the legs drift behind and the handstand becomes a heavy banana.",
                        icon: "shield.lefthalf.filled"
                    ),
                    SkillGuideTip(
                        title: "Train quality before fatigue",
                        detail: "Freestanding balance is nervous-system practice. Stop before the shoulders are so tired that every attempt becomes a different skill.",
                        icon: "speedometer"
                    ),
                    SkillGuideTip(
                        title: "Use the wall as a lab",
                        detail: "Heel pulls and toe pulls teach the same hand-pressure corrections you need away from the wall, but with fewer dramatic exits.",
                        icon: "testtube.2"
                    )
                ],
                mistakes: [
                    SkillGuideMistake(
                        mistake: "Kicking past vertical and hoping to save it.",
                        fix: "Lower the kick, aim for a quieter arrival, and use back-to-wall toe pulls to learn the balance point."
                    ),
                    SkillGuideMistake(
                        mistake: "Balancing with big shoulder waves.",
                        fix: "Return to wall heel pulls and practice fingertip pressure as the first correction."
                    ),
                    SkillGuideMistake(
                        mistake: "Banana back becomes the default hold.",
                        fix: "Rebuild chest-to-wall line holds with ribs down, glutes on, and shoulders elevated before free attempts."
                    ),
                    SkillGuideMistake(
                        mistake: "Legs split and bicycle to keep the hold alive.",
                        fix: "Use shorter holds with legs together. Count only the seconds where the lower body stays quiet."
                    ),
                    SkillGuideMistake(
                        mistake: "Fear of falling blocks commitment.",
                        fix: "Practice cartwheel bails separately until stepping out is automatic, then bring that confidence back to kick-ups."
                    )
                ]
            )
        case "hs.tuck-handstand":
            return handstandGuide(
                standard: "A clean tuck handstand keeps hands, locked elbows, and elevated shoulders stacked while the knees draw toward the chest. The hips stay over the hands and the tuck shape is balanced, not collapsed behind the wrists.",
                scoringNote: "Credit only holds where the shoulder stack survives the leg change. Bent elbows, hips dropping behind the hands, or wall collapse do not count as clean tuck time.",
                assistance: [
                    ("Wall Tuck Hold", "From a wall handstand, bend the knees and pull them in only as far as the shoulders stay tall.", "rectangle.portrait"),
                    ("Box Tuck Handstand", "Use a box to support the feet while practicing hips high over hands.", "rectangle.3.group.fill"),
                    ("Tuck Negative", "Lower from a wall line into tuck slowly, then re-extend or step down.", "arrow.down.forward")
                ],
                tips: [
                    ("Press before you tuck", "Set the shoulder push first. Moving the legs before the shoulders are tall makes the hips drop.", "arrow.up.circle.fill"),
                    ("Hips stay high", "Think knees light, hips over hands. The tuck is still a handstand, not a squat on the arms.", "scope"),
                    ("Use it as press prep", "Tuck handstand teaches the compression and hip path needed for tuck press work.", "link")
                ],
                mistakes: [
                    ("Knees pull in and shoulders sink.", "Use a smaller tuck range and rebuild shoulder elevation."),
                    ("Elbows bend to save balance.", "Return to wall tuck negatives and straight-arm support drills."),
                    ("Head pokes forward.", "Look between the hands and keep ears framed by the arms.")
                ]
            )
        case "hs.tuck-press", "hs.straddle-press", "hs.press-to-handstand":
            return pressHandstandGuide(skillId: skillId)
        case "hs.wall-supported-oah":
            return oneArmHandstandGuide(wallSupported: true, full: false)
        case "oah.one-arm-handstand-5s":
            return oneArmHandstandGuide(wallSupported: false, full: false)
        case "oah.full-one-arm-handstand":
            return oneArmHandstandGuide(wallSupported: false, full: true)
        case "pp.ring-muscle-up":
            return ringMuscleUpGuide()
        case "pp.strict-muscle-up":
            return strictMuscleUpGuide()
        case "cal.plank-30":
            return forearmPlankGuide()
        case "cl.hollow-body-30":
            return hollowBodyGuide()
        case "cl.crunch", "cl.reverse-crunch", "cl.levitation-crunch", "cl.inverted-situp", "cl.decline-situp":
            return coreFlexionGuide(skillId: skillId)
        case "cl.bird-dog-plank", "cl.superman-plank", "cl.extended-plank":
            return plankControlGuide(skillId: skillId)
        case "cl.knee-ab-rollout", "cl.standing-ab-rollout":
            return rolloutGuide(skillId: skillId)
        case "cl.knee-raise", "cl.leg-raise", "cl.hanging-knee-raise", "cl.hanging-leg-raise", "cl.toes-to-bar":
            return coreRaiseGuide(skillId: skillId)
        case "cal.l-sit-10", "cl.semi-straddle-l-sit", "cl.straddle-l-sit", "cl.v-sit", "cl.vertical-l-sit":
            return lSitFamilyGuide(skillId: skillId)
        case "cl.tuck-front-lever", "cl.straddle-front-lever", "cl.full-front-lever":
            return frontLeverGuide(skillId: skillId)
        case "cl.german-hang", "cl.skin-the-cat", "cl.tuck-back-lever", "cl.straddle-back-lever", "cl.full-back-lever":
            return backLeverGuide(skillId: skillId)
        case "cl.three-sixty-pulls":
            return threeSixtyPullGuide()
        case "cl.dragon-flag-hip-raise", "cl.dragon-flag":
            return dragonFlagGuide(skillId: skillId)
        case "hs.crow-pose", "hs.crane-pose", "hs.flying-crow":
            return crowFamilyGuide(skillId: skillId)
        case "hs.elbow-lever", "hs.one-arm-elbow-lever":
            return elbowLeverGuide(isOneArm: skillId == "hs.one-arm-elbow-lever")
        case "cal.incline-pushup", "cal.pushup", "cal.decline-pushup":
            return pushupGuide(skillId: skillId)
        case "cal.diamond-pushup", "cal.sphinx-pushup":
            return closePushGuide(skillId: skillId)
        case "cal.5-dips", "cal.bench-dip":
            return dipGuide(skillId: skillId)
        case "cal.ring-dip":
            return ringDipGuide()
        case "cal.pike-pushup", "cal.elevated-pike-pushup", "cal.floating-pike-pushup":
            return pikePushGuide(skillId: skillId)
        case "cal.handstand-pushup":
            return handstandPushGuide()
        case "cal.ninety-degree-pushup":
            return ninetyDegreePushGuide()
        case "cal.clapping-handstand-pushup":
            return clappingHandstandPushGuide()
        case "cal.pseudo-planche-pushup", "cal.tuck-planche-pushup":
            return planchePushGuide(skillId: skillId)
        case "pl.tuck-planche", "pl.straddle-planche", "pl.half-lay-planche", "pl.full-planche", "pl.bent-arm-planche":
            return plancheHoldGuide(skillId: skillId)
        case "cal.archer-pushup", "cal.one-arm-pushup":
            return unilateralPushGuide(skillId: skillId)
        case "cal.explosive-pushup", "cal.clapping-pushup", "cal.triple-clap-pushup":
            return explosivePushGuide(skillId: skillId)
        case "cal.bent-arm-press":
            return bentArmPressGuide()
        case let id where id.hasPrefix("ld."):
            return legGuide(skillId: id)
        default:
            return nil
        }
    }



}
