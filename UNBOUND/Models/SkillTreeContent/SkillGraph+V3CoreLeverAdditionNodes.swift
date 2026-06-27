import Foundation

extension SkillGraph {
    static let v3CoreLeverAdditionNodes: [SkillNode] = [
        // ────────────────────────────────────────────────────────────────
        // CORE & LEVERS ADDITIONS — crunch variants, plank variants, rings
        // ────────────────────────────────────────────────────────────────

        .simple(
            id: "cl.crunch",
            title: "Crunch",
            cluster: .coreLever, tier: 2, type: .skill,
            target: .reps(exercise: "crunch", count: 20),
            prereqs: [PrerequisiteGroup("cal.plank-30")],
            primary: [.core],
            subtitle: "Starting point for ab-specific work.",
            description: "20 strict crunches — lying on your back, knees bent, curl shoulder blades off the floor, touch fingertips toward knees. Short-range, ab-isolated.",
            formCues: [
                "Lower back pressed to floor throughout",
                "Chin tucked, eyes on the ceiling",
                "Lift shoulder blades off the floor — no more",
                "Hands light on head, don't pull neck"
            ],
            commonMistakes: [
                "Yanking on the neck to sit up",
                "Sitting all the way up — that's a sit-up, not a crunch",
                "Feet lifting off the floor"
            ],
            timeline: "Immediate."
        ),
        .simple(
            id: "cl.reverse-crunch",
            title: "Reverse Crunch",
            cluster: .coreLever, tier: 2, type: .skill,
            target: .reps(exercise: "reverse crunch", count: 15),
            prereqs: [PrerequisiteGroup("cl.crunch")],
            primary: [.core], secondary: [.legs],
            subtitle: "Lower abs emphasis.",
            description: "15 reverse crunches — lie on back, curl hips off the floor by pulling knees toward chest. Targets lower ab engagement the standard crunch misses.",
            formCues: [
                "Start with knees stacked over hips",
                "Curl hips off the floor, don't just swing legs",
                "Lower slowly, no momentum",
                "Shoulders stay down, don't shrug"
            ],
            commonMistakes: [
                "Swinging the legs instead of curling the hips",
                "Using momentum from the eccentric",
                "Lumbar arching at the bottom"
            ],
            timeline: "1-2 weeks from crunches."
        ),
        .simple(
            id: "cl.superman-plank",
            title: "Superman Plank",
            cluster: .coreLever, tier: 5, type: .hold,
            target: .hold(exercise: "superman plank", seconds: 15),
            prereqs: [PrerequisiteGroup("cl.extended-plank")],
            primary: [.core, .shoulders], secondary: [.back, .glutes],
            subtitle: "Plank with limbs extended.",
            description: "15-second plank with one arm extended forward and the opposite leg extended back. Hold, switch. Anti-rotation challenge.",
            formCues: [
                "Start in a rigid plank",
                "Extend opposite arm and leg without hips twisting",
                "Hold — don't lose the plank line",
                "Return slowly, switch sides"
            ],
            commonMistakes: [
                "Hips rotating as the limbs extend",
                "Arm and leg on the same side — cancels the anti-rotation",
                "Dropping the extended limb to the floor"
            ],
            timeline: "1-4 weeks from 30s plank."
        ),
        .simple(
            id: "cl.extended-plank",
            title: "Extended Plank",
            cluster: .coreLever, tier: 3, type: .hold,
            target: .hold(exercise: "extended plank", seconds: 15),
            prereqs: [PrerequisiteGroup("cl.bird-dog-plank")],
            primary: [.core, .shoulders], secondary: [.arms],
            subtitle: "Hands way out front of the shoulders.",
            description: "15-second plank with hands reached forward past the shoulders — long lever demands more core tension than a standard plank.",
            formCues: [
                "Hands reach 6-12 inches past shoulders",
                "Body rigid as plank — no sag, no pike",
                "Shoulders stay packed down",
                "Gaze at the floor, neck neutral"
            ],
            commonMistakes: [
                "Reaching hands too far too soon",
                "Hip sag as the lever gets long",
                "Shrugged shoulders under the load"
            ],
            timeline: "2-4 weeks from plank 30s."
        ),
        .simple(
            id: "cl.knee-ab-rollout",
            title: "Kneeling Ab Rollout",
            cluster: .coreLever, tier: 4, type: .skill,
            target: .reps(exercise: "ab wheel kneeling", count: 8),
            prereqs: [PrerequisiteGroup("cl.extended-plank")],
            primary: [.core, .shoulders], secondary: [.lats],
            subtitle: "Ab wheel on ramp.",
            description: "8 kneeling ab wheel rollouts. Roll out as far as core can control, roll back. Gateway to the standing rollout.",
            formCues: [
                "Kneel with hands on the wheel under shoulders",
                "Roll out keeping a hollow body",
                "Pause at the end range before rolling back",
                "Control both directions"
            ],
            commonMistakes: [
                "Lumbar sag at the end range",
                "Rolling too far too soon (injury risk)",
                "Holding breath instead of breathing"
            ],
            timeline: "1-4 weeks from solid plank."
        ),
        .simple(
            id: "cl.levitation-crunch",
            title: "Levitation Crunch",
            cluster: .coreLever, tier: 3, type: .skill,
            target: .reps(exercise: "levitation crunch", count: 8),
            prereqs: [PrerequisiteGroup("cl.crunch")],
            primary: [.core], secondary: [.glutes],
            subtitle: "Lift the whole body off the floor.",
            description: "8 reps — lying on back, knees bent, curl hips and upper back off the floor simultaneously, only the mid-back stays in contact. Brutal on the rectus abdominis.",
            formCues: [
                "Curl both ends of the body toward the ceiling",
                "Only mid-back stays in contact",
                "Arms reach toward the knees",
                "Slow descent — no crashing down"
            ],
            commonMistakes: [
                "Yanking with the neck",
                "Using the arms to swing up",
                "Not fully levitating — partial ROM"
            ],
            timeline: "1-3 months from reverse crunch."
        ),
        .simple(
            id: "cl.inverted-situp",
            title: "Inverted Sit-Up",
            cluster: .coreLever, tier: 5, type: .skill,
            target: .reps(exercise: "inverted sit-up", count: 5),
            prereqs: [PrerequisiteGroup("cl.decline-situp")],
            equipment: [.pullupBar],
            primary: [.core, .lats], secondary: [.arms],
            subtitle: "Sit-up while hanging upside down.",
            description: "5 hanging sit-ups — hook legs over a pullup bar so you hang inverted, curl the torso toward the knees, return slowly. Demands real core strength.",
            formCues: [
                "Secure the legs over the bar before the first rep",
                "Curl the torso up, don't swing",
                "Touch knees or elbows",
                "Slow descent to avoid whipping the spine"
            ],
            commonMistakes: [
                "Swinging for momentum",
                "Legs slipping off the bar",
                "Partial ROM"
            ],
            timeline: "2-6 months from hanging leg raise."
        ),
        .simple(
            id: "cl.skin-the-cat",
            title: "Skin the Cat",
            cluster: .pullingPower, tier: 4, type: .skill,
            target: .reps(exercise: "skin the cat", count: 3),
            prereqs: [PrerequisiteGroup("cl.german-hang")],
            equipment: [.gymnasticRings],
            primary: [.shoulders, .core, .lats], secondary: [.arms],
            subtitle: "Rings pass-through. Shoulder opener.",
            description: "Controlled ring pass-through from hang to inverted hang to German hang and back. The rep proves shoulder extension tolerance, straight-arm control, and a calm reverse path.",
            formCues: [
                "Start from a quiet hang with straight arms and rings still",
                "Tuck or pike the legs overhead without yanking the elbows",
                "Pass through slowly until the shoulders open into German hang",
                "Pause only in a pain-free range, then reverse the same path",
                "Keep ribs tucked so the pass-through is controlled by shoulders and core"
            ],
            commonMistakes: [
                "Dropping into the german hang — shoulder shock",
                "Bent arms during the pass-through",
                "Skipping warm-up — shoulders need prep",
                "Going deeper than can be reversed under control"
            ],
            timeline: "2-6 months from german hang."
        ),
        .simple(
            id: "cl.german-hang",
            title: "German Hang",
            cluster: .pullingPower, tier: 3, type: .hold,
            target: .hold(exercise: "german hang", seconds: 10),
            prereqs: [PrerequisiteGroup("pp.dead-hang")],
            equipment: [.gymnasticRings],
            primary: [.shoulders, .chest], secondary: [.core, .arms],
            subtitle: "The rings position only mobile shoulders own.",
            description: "Pain-free hold at the bottom of a skin-the-cat path. The arms are behind the body, shoulders are open, rings stay quiet, and the athlete can exit without panic.",
            formCues: [
                "Enter slowly through an assisted or controlled skin-the-cat path",
                "Keep arms straight while the shoulders open behind the torso",
                "Let the chest open without dumping into sharp anterior shoulder pain",
                "Breathe calmly; the position should feel loaded, not panicked",
                "Exit the same way you entered before the shoulders lose control"
            ],
            commonMistakes: [
                "Attempting without shoulder warm-up",
                "Bent arms — wrong skill, injury risk",
                "Holding through shoulder pain",
                "Dropping too deep because the rings are set too high"
            ],
            timeline: "2-6 months from a calm dead hang.",
            isParallelToParent: true
        ),
        .simple(
            id: "cl.three-sixty-pulls",
            title: "360-Degree Pulls",
            cluster: .pullingPower, tier: 6, type: .skill,
            target: .reps(exercise: "360 ring pull", count: 1),
            prereqs: [PrerequisiteGroup(["cl.skin-the-cat", "cl.german-hang"])],
            equipment: [.gymnasticRings, .pullupBar],
            primary: [.lats, .arms, .core], secondary: [.back, .shoulders],
            subtitle: "A full ring arc through front and back lever lanes.",
            description: "Controlled straight-arm ring pull through a 360-degree arc: active hang, front-lever lane, inverted hang, back-lever lane, German hang, then reverse under control. No release or re-catch.",
            formCues: [
                "Use rings set low enough to bail or toe-assist safely",
                "Start from active hang with elbows locked",
                "Pull through the front-lever side toward inverted hang",
                "Move into the back-lever/German-hang side without dumping shoulders",
                "Reverse the same path; only count range you can bring home"
            ],
            commonMistakes: [
                "Treating it like a bar release/re-catch trick",
                "Bending elbows to muscle through the arc",
                "Dropping into German hang or holding through shoulder pain",
                "Owning the descent but not the reverse path"
            ],
            timeline: "5+ years of dedicated explosive pulling. Very rare."
        ),
    ]
}
