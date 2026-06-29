import Foundation

extension SkillGraph {
    static let v3PlancheAdditionNodes: [SkillNode] = [
        // ────────────────────────────────────────────────────────────────
        // PLANCHE ADDITIONS — bent arm + half-lay + one-arm (mythic)
        // ────────────────────────────────────────────────────────────────

        .simple(
            id: "pl.bent-arm-planche",
            title: "Bent Arm Planche",
            cluster: .planche, tier: 4, type: .hold,
            target: .hold(exercise: "bent arm planche", seconds: 3),
            prereqs: [PrerequisiteGroup(["hs.elbow-lever", "cal.pseudo-planche-pushup", "hs.crane-pose"])],
            equipment: [.parallettes],
            primary: [.shoulders, .chest, .core],
            subtitle: "Planche before the straight-arm demand.",
            description: "3-second bent arm planche — legs extended behind the body, arms bent at roughly 90°, body horizontal. Easier shoulder leverage than straight-arm but still brutal.",
            formCues: [
                "Arms bend to ~90°, elbows into the ribs",
                "Body horizontal, legs extended",
                "Shoulders protract hard",
                "Chest drives forward toward the floor"
            ],
            commonMistakes: [
                "Losing the horizontal line — hips drop",
                "Arms bending too much — turns into a pushup",
                "Not extending the legs fully"
            ],
            timeline: "6-18 months from elbow lever."
        ),
        .simple(
            id: "pl.half-lay-planche",
            title: "Half-Lay Planche",
            cluster: .planche, tier: 6, type: .hold,
            target: .hold(exercise: "half-lay planche", seconds: 3),
            prereqs: [PrerequisiteGroup(["pl.straddle-planche", "cal.pseudo-planche-pushup"])],
            equipment: [.parallettes],
            primary: [.shoulders, .core],
            subtitle: "Half-straddle. Half-closed.",
            description: "3-second half-lay planche — straddle planche with legs narrowed toward the full position. The bridge between straddle and full planche.",
            formCues: [
                "Start from rock-solid straddle planche",
                "Elbows locked, shoulders protracted and depressed",
                "Close the legs halfway toward parallel",
                "Hips stay at shoulder height",
                "Toes pointed, legs squeeze even at narrower angle"
            ],
            commonMistakes: [
                "Closing legs too fast — lever jumps",
                "Hip drop as the lever tightens",
                "Banana back"
            ],
            timeline: "6-18 months from straddle planche."
        ),
    ]
}
