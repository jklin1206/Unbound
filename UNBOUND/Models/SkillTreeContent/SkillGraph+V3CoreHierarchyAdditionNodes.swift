import Foundation

extension SkillGraph {
    static let v3CoreHierarchyAdditionNodes: [SkillNode] = [
        // MARK: Core — Spine/Raised gap nodes
        .simple(
            id: "cl.bird-dog-plank",
            title: "Bird Dog Plank",
            cluster: .coreLever, tier: 2, type: .hold,
            target: .hold(exercise: "bird dog plank", seconds: 30),
            prereqs: [PrerequisiteGroup("cal.plank-30")],
            primary: [.core, .glutes], secondary: [.back, .shoulders],
            subtitle: "Anti-rotation under tension.",
            description: "From a full plank, extend the opposite arm and leg simultaneously without hip or shoulder drift. The anti-rotation skill that separates owned cores from surface-deep planks.",
            formCues: [
                "Plank position first — straight line, braced",
                "Extended arm at shoulder height, leg at hip height",
                "Hips and shoulders stay SQUARE — no tilt",
                "Breathe — this is a steady-state hold"
            ],
            commonMistakes: [
                "Hips tilting toward the unsupported side",
                "Free leg rising above hip line",
                "Shoulders rotating open"
            ],
            timeline: "2-6 weeks from plank."
        ),
        .simple(
            id: "cl.v-sit",
            title: "V-Sit",
            cluster: .coreLever, tier: 5, type: .hold,
            target: .hold(exercise: "v-sit", seconds: 10),
            prereqs: [PrerequisiteGroup("cal.l-sit-10")],
            primary: [.core, .arms], secondary: [.shoulders],
            subtitle: "L-Sit, compressed upward.",
            description: "From a seated push-up position, lift the legs until they're above horizontal — body forms a V shape. 10 seconds. The compression and hip-flexor strength benchmark beyond the L-sit.",
            formCues: [
                "Hands planted on floor or parallettes, arms locked",
                "Legs dead straight and ABOVE horizontal",
                "Compress torso toward thighs",
                "Keep shoulders depressed — not shrugged"
            ],
            commonMistakes: [
                "Legs only at L-sit angle — not above horizontal",
                "Bent knees to fake the compression",
                "Shoulders creeping up toward ears"
            ],
            timeline: "6-18 months from clean L-sit."
        ),
        .simple(
            id: "cl.straddle-l-sit",
            title: "Straddle L-Sit",
            cluster: .coreLever, tier: 6, type: .hold,
            target: .hold(exercise: "straddle l-sit", seconds: 10),
            prereqs: [PrerequisiteGroup("cl.semi-straddle-l-sit")],
            primary: [.core, .arms], secondary: [.shoulders],
            subtitle: "Wide. Horizontal. Humbling.",
            description: "L-sit with legs split into a wide straddle — legs parallel to floor, toes pointed outward. 10 seconds. The lateral compression demand the standard L-sit doesn't test.",
            formCues: [
                "Legs locked straight, wide straddle",
                "Toes pointed outward, not up",
                "Legs parallel to floor — not dropping down",
                "Active shoulders, arms locked"
            ],
            commonMistakes: [
                "Legs drooping below horizontal",
                "Bent knees to cheat the width",
                "Hip flexors tight — legs won't open wide"
            ],
            timeline: "6-12 months from clean L-sit."
        ),
        .simple(
            id: "cl.dragon-flag-hip-raise",
            title: "Dragon Flag Hip Raise",
            cluster: .coreLever, tier: 4, type: .skill,
            target: .reps(exercise: "dragon flag hip raise", count: 8),
            prereqs: [PrerequisiteGroup("cl.reverse-crunch")],
            equipment: [.elevatedSurface],
            primary: [.core], secondary: [.back, .shoulders],
            subtitle: "Dragon flag's missing link.",
            description: "Lying on a bench gripping behind the head, drive the hips up until the body forms a straight line pointing at the ceiling — then lower with control. 8 reps. The concentric piece the dragon flag negative doesn't train.",
            formCues: [
                "Grip hard behind the head — two anchor points",
                "Drive hips straight up, not toward the face",
                "Body stays rigid — no pike at the top",
                "Lower with control, don't drop"
            ],
            commonMistakes: [
                "Piking at the hips to fake the top position",
                "Kipping with the legs for momentum",
                "Releasing the grip before the rep is done"
            ],
            timeline: "2-4 months from reverse crunch."
        ),
        .simple(
            id: "cl.decline-situp",
            title: "Decline Sit-Up",
            cluster: .coreLever, tier: 4, type: .skill,
            target: .reps(exercise: "decline sit-up", count: 15),
            prereqs: [PrerequisiteGroup("cl.levitation-crunch")],
            equipment: [.elevatedSurface],
            primary: [.core], secondary: [.legs],
            subtitle: "More range. More burn.",
            description: "Sit-up on a decline bench — feet anchored above the head, full ROM from fully extended to torso at the knees. 15 reps.",
            formCues: [
                "Feet anchored above hip height — steeper = harder",
                "Full ROM — torso all the way back, then up to knees",
                "Arms crossed on chest, don't pull on the neck",
                "Control the eccentric — don't slam back"
            ],
            commonMistakes: [
                "Using momentum to pop up",
                "Yanking the head forward",
                "Partial ROM — cutting the descent short"
            ],
            timeline: "2-4 weeks from crunch."
        ),

        // MARK: Core — Canonical hierarchy additions
        .simple(
            id: "cl.knee-raise",
            title: "Knee Raise",
            cluster: .coreLever, tier: 3, type: .skill,
            target: .reps(exercise: "knee raise", count: 12),
            prereqs: [PrerequisiteGroup("cl.hollow-body-30")],
            primary: [.core], secondary: [.shoulders],
            subtitle: "Supported knee lifts.",
            description: "12 knee raises while supporting body on parallel bars or dip station — keep torso upright, drive knees up to chest, control the descent. Floor variant acceptable for early levels.",
            formCues: [
                "Shoulders depressed, body supported",
                "Drive knees toward chest, not just up",
                "No swinging or kipping",
                "Slow eccentric"
            ],
            commonMistakes: [
                "Swinging for momentum",
                "Partial ROM — knees stop at 90°",
                "Shrugged shoulders under support"
            ],
            timeline: "1-4 weeks from hollow body."
        ),
        .simple(
            id: "cl.leg-raise",
            title: "Leg Raise",
            cluster: .coreLever, tier: 4, type: .skill,
            target: .reps(exercise: "leg raise", count: 12),
            prereqs: [PrerequisiteGroup("cl.knee-raise")],
            primary: [.core], secondary: [.legs],
            subtitle: "Straight legs, full ROM.",
            description: "12 strict leg raises — supine on floor or supported on dip bars. Legs locked straight, lower back pressed down, raise legs to vertical, controlled descent.",
            formCues: [
                "Lower back pressed flat throughout",
                "Legs locked straight",
                "Raise to perpendicular, no further",
                "No bouncing or kipping"
            ],
            commonMistakes: [
                "Bent knees mid-rep — that's a knee raise",
                "Lumbar arching off the floor",
                "Using momentum on the way down"
            ],
            timeline: "2-6 weeks from knee raise."
        ),
        .simple(
            id: "cl.semi-straddle-l-sit",
            title: "Semi Straddle L-Sit",
            cluster: .coreLever, tier: 5, type: .hold,
            target: .hold(exercise: "semi straddle l-sit", seconds: 10),
            prereqs: [PrerequisiteGroup("cal.l-sit-10")],
            primary: [.core, .arms], secondary: [.shoulders, .legs],
            subtitle: "L-sit with one leg straddled out.",
            description: "10s hold with one leg in standard L-sit position, the other leg opened to the side at ~45°. Bridges L-sit to full straddle.",
            formCues: [
                "Hands press down, shoulders depressed",
                "One leg locked forward, one leg opened ~45°",
                "Both legs above hand line",
                "Switch sides each set"
            ],
            commonMistakes: [
                "Open leg drops below hand line",
                "Bent knees on either leg",
                "Shoulders shrugging up"
            ],
            timeline: "2-6 months from clean L-sit."
        ),
    ]
}
