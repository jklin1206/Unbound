import Foundation

extension SkillGraph {
    static let v3HandbalanceAdditionNodes: [SkillNode] = [
        // ────────────────────────────────────────────────────────────────
        // HANDBALANCE ADDITIONS — poses, elbow lever, press progressions
        // ────────────────────────────────────────────────────────────────

        .simple(
            id: "hs.headstand",
            title: "Headstand",
            cluster: .handstand, tier: 2, type: .hold,
            target: .hold(exercise: "headstand", seconds: 30),
            prereqs: [PrerequisiteGroup("hs.wall-plank")],
            primary: [.shoulders, .core], secondary: [.arms],
            subtitle: "The inversion that still respects your neck.",
            description: "30-second tripod or supported headstand with active hands, light head contact, long neck, and body stacked vertical. First real taste of inverted balance without treating the neck like the base.",
            formCues: [
                "Tripod: hands and crown form a stable triangle",
                "Press through the palms so the head stays light",
                "Neck long, shoulders active, ribs controlled",
                "Enter from a tuck or controlled wall setup — no hard kick"
            ],
            commonMistakes: [
                "All weight on the head — neck strain",
                "Arching the spine to stay up",
                "Kicking up too hard against the wall",
                "Staying in the hold with neck compression, tingling, or headache"
            ],
            timeline: "1-4 weeks from wall plank."
        ),
        .simple(
            id: "hs.tuck-handstand",
            title: "Tuck Handstand",
            cluster: .handstand, tier: 3, type: .hold,
            target: .hold(exercise: "tuck handstand", seconds: 5),
            prereqs: [PrerequisiteGroup("hs.wall-handstand-30")],
            primary: [.shoulders, .core], secondary: [.arms],
            subtitle: "Freestanding on-ramp.",
            description: "5-second freestanding tuck handstand — balance on hands with knees pulled tight to chest. Easier lever than full handstand, teaches the balance.",
            formCues: [
                "Press into the floor through straight arms",
                "Knees tucked tight to chest, heels near glutes",
                "Balance with the fingers, not the shoulders",
                "Micro-adjust — don't try to stand statue still"
            ],
            commonMistakes: [
                "Losing the tuck to try to balance",
                "Bent arms when balance shifts",
                "Over-kicking into the position"
            ],
            timeline: "1-3 months from wall handstand."
        ),
        .simple(
            id: "hs.crow-pose",
            title: "Crow Pose",
            cluster: .planche, tier: 2, type: .hold,
            target: .hold(exercise: "crow pose", seconds: 15),
            prereqs: [PrerequisiteGroup("hs.wall-plank")],
            primary: [.shoulders, .arms, .core],
            subtitle: "Knees on the triceps. Balance on the hands.",
            description: "15-second crow pose — squat, plant hands, rest knees on the backs of the triceps, shift weight forward until feet leave the floor.",
            formCues: [
                "Hands shoulder-width, fingers spread wide",
                "Knees pin onto the triceps, not just touching",
                "Shift weight forward until feet float",
                "Gaze slightly ahead, not straight down"
            ],
            commonMistakes: [
                "Knees slipping off the triceps",
                "Keeping weight over the feet — won't float",
                "Tipping forward onto the head — yes, put a pillow down"
            ],
            timeline: "1-4 weeks from wall plank."
        ),
        .simple(
            id: "hs.crane-pose",
            title: "Crane Pose",
            cluster: .planche, tier: 3, type: .hold,
            target: .hold(exercise: "crane pose", seconds: 10),
            prereqs: [PrerequisiteGroup("hs.crow-pose")],
            primary: [.shoulders, .arms, .core],
            subtitle: "Crow, but arms straight.",
            description: "10-second crane pose — same knees-on-triceps position as crow, but arms are fully locked out. Harder balance and a real strength challenge.",
            formCues: [
                "Enter from crow, slowly press arms straight",
                "Knees stay on triceps as the arms straighten",
                "Hips climb higher as arms lock",
                "Balance shifts — fingers press into the floor"
            ],
            commonMistakes: [
                "Losing the knee-tricep contact as arms straighten",
                "Bending arms as soon as balance shifts",
                "Hips dropping — arms not vertical"
            ],
            timeline: "1-3 months from crow pose."
        ),
        .simple(
            id: "hs.flying-crow",
            title: "Flying Crow Pose",
            cluster: .planche, tier: 3, type: .hold,
            target: .hold(exercise: "flying crow", seconds: 5),
            prereqs: [PrerequisiteGroup(["hs.crow-pose", "hs.crane-pose"])],
            primary: [.shoulders, .arms, .core],
            subtitle: "One leg extended straight back.",
            description: "5-second flying crow — from crane or crow, extend one leg straight back into the air. Full body engagement with a long lever fighting the balance.",
            formCues: [
                "Enter stable crane first",
                "Extend one leg straight back, toe pointed",
                "Press through fingers to counter the lever shift",
                "Keep the knee on the tricep of the bent leg"
            ],
            commonMistakes: [
                "Extending too fast — tips forward",
                "Leg drifting out to the side",
                "Losing knee-tricep contact on the bent leg"
            ],
            timeline: "3-9 months from crow."
        ),
        .simple(
            id: "hs.elbow-lever",
            title: "Elbow Lever",
            cluster: .planche, tier: 3, type: .hold,
            target: .hold(exercise: "elbow lever", seconds: 10),
            prereqs: [PrerequisiteGroup("hs.crow-pose")],
            primary: [.shoulders, .core, .arms],
            subtitle: "Body horizontal, elbows into the hips.",
            description: "10-second elbow lever — hands plant on the floor, elbows drive into the ribs or hip crease, body extends horizontal. Parlor trick that builds serious core.",
            formCues: [
                "Hands shoulder-width, fingers spread wide",
                "Elbows dig into the iliac crest / hip bones",
                "Lean weight forward until legs lift",
                "Body rigid and horizontal"
            ],
            commonMistakes: [
                "Elbows not tucked into the hips — no support",
                "Legs sagging below horizontal",
                "Bent knees to cheat the lever"
            ],
            timeline: "2-8 weeks from crow pose."
        ),
        .simple(
            id: "hs.one-arm-elbow-lever",
            title: "One-Arm Elbow Lever",
            cluster: .planche, tier: 4, type: .hold,
            target: .hold(exercise: "one-arm elbow lever", seconds: 5),
            prereqs: [PrerequisiteGroup(["hs.elbow-lever", "hs.crane-pose"])],
            primary: [.shoulders, .core, .arms],
            subtitle: "Same lever. Half the supports.",
            description: "5-second one-arm elbow lever. Same position as the two-arm version but supported by a single arm — the elbow of the working side presses into the hip crease.",
            formCues: [
                "Enter from a two-arm elbow lever, shift weight to one side",
                "Free arm extends straight out for balance",
                "Working elbow stays locked into the hip",
                "Shoulders stay square to the floor"
            ],
            commonMistakes: [
                "Free arm bracing on the floor",
                "Body rotating open as weight shifts",
                "Working arm collapsing"
            ],
            timeline: "6-18 months from elbow lever."
        ),
        .simple(
            id: "hs.tuck-press",
            title: "Tuck Press to Handstand",
            cluster: .handstand, tier: 5, type: .skill,
            target: .reps(exercise: "tuck press", count: 3),
            prereqs: [PrerequisiteGroup(["hs.tuck-handstand", "hs.freestanding-hs-30", "cl.hollow-body-30"])],
            primary: [.shoulders, .core], secondary: [.arms],
            subtitle: "Press up from tuck to handstand.",
            description: "3 tuck presses — from an L-sit or compressed tuck on the floor, press through straight arms to a tuck handstand without kipping.",
            formCues: [
                "Start compressed — chest close to thighs",
                "Arms straight throughout, no bending to cheat",
                "Hips climb through the straight arms",
                "Tuck stays tight until the handstand is achieved"
            ],
            commonMistakes: [
                "Kipping the legs for momentum",
                "Bent arms once weight shifts",
                "Losing the tuck as hips rise"
            ],
            timeline: "6-18 months from tuck handstand."
        ),
        .simple(
            id: "hs.straddle-press",
            title: "Straddle Press to Handstand",
            cluster: .handstand, tier: 6, type: .skill,
            target: .reps(exercise: "straddle press", count: 3),
            prereqs: [PrerequisiteGroup(["hs.tuck-press", "hs.freestanding-hs-30", "cal.pike-pushup"])],
            primary: [.shoulders, .core], secondary: [.arms],
            subtitle: "Legs split. Straight arms all the way.",
            description: "3 straddle presses to handstand — from a straddle pike compression on the floor, press through straight arms and a split-leg shape up to handstand. Hamstring flexibility + pressing strength.",
            formCues: [
                "Start pike compressed, chest on thighs",
                "Arms straight throughout",
                "Legs stay wide in the straddle as hips rise",
                "Close the straddle only once handstand is held"
            ],
            commonMistakes: [
                "Bent arms as fatigue sets in",
                "Closing the straddle too early",
                "Hamstring flexibility limits not addressed in warm-up"
            ],
            timeline: "1-3 years from tuck press."
        ),
        .simple(
            id: "hs.press-to-handstand",
            title: "Press to Handstand",
            cluster: .handstand, tier: 7, type: .skill,
            target: .reps(exercise: "press to handstand", count: 1),
            prereqs: [PrerequisiteGroup(["hs.straddle-press", "hs.freestanding-hs-30", "cl.straddle-l-sit"])],
            isMythic: true,
            primary: [.shoulders, .core], secondary: [.arms],
            subtitle: "Legs glued. Straight up.",
            description: "One clean pike press to handstand — legs together, arms straight, press from floor pike to vertical handstand without momentum. Gymnastic standard.",
            formCues: [
                "Start pike, legs together, chest on thighs",
                "Arms straight, hands planted firm",
                "Hips rise first, legs follow",
                "No kip, no bent arm, no swing"
            ],
            commonMistakes: [
                "Swinging legs for momentum",
                "Bent arms once the hips rise",
                "Losing the pike shape — hips lead too early"
            ],
            timeline: "2-4 years from straddle press."
        ),
    ]
}
