import Foundation

extension SkillGraph {
    static let v3HandstandWallPathNodes: [SkillNode] = [
        // MARK: Handstand — Wall Path gaps
        .simple(
            id: "hs.wall-plank",
            title: "Wall Plank",
            cluster: .handstand, tier: 1, type: .hold,
            target: .hold(exercise: "wall plank", seconds: 30),
            primary: [.shoulders, .core], secondary: [.arms],
            subtitle: "Handstand starts horizontal.",
            description: "Plank position with feet walked up the wall until shoulders stack over wrists. The shared root for wall handstand, headstand, and early planche balance.",
            formCues: [
                "Hands shoulder-width, fingers spread",
                "Walk feet UP the wall until hips over shoulders",
                "Push the floor away until shoulders elevate and elbows stay locked",
                "Core tight, ribs tucked, neck long"
            ],
            commonMistakes: [
                "Hands too far from the wall — sags the position",
                "Piked hips instead of stacked",
                "Collapsed shoulders or neck swallowed by a soft push"
            ],
            timeline: "Immediate to 2 weeks."
        ),
        .simple(
            id: "hs.wall-supported-oah",
            title: "Wall Supported One-Arm Handstand",
            cluster: .handstand, tier: 5, type: .hold,
            target: .hold(exercise: "wall-supported one-arm handstand", seconds: 5),
            prereqs: [PrerequisiteGroup(["hs.freestanding-hs-30", "hs.wall-handstand-30"])],
            primary: [.shoulders, .core], secondary: [.forearms, .arms],
            subtitle: "One arm. Wall for insurance.",
            description: "One-arm handstand drill using chest-to-wall, side-wall, or fingertip wall feedback so the working arm carries the stack without a banana-back lean. The bridge between freestanding handstand and a freestanding one-arm handstand.",
            formCues: [
                "Build a chest-to-wall or side-wall line first",
                "Open to straddle before shifting weight to one hand",
                "Free hand unloads to fingertips; wall is feedback, not support",
                "Support shoulder stays tall, ribs tucked, glutes on"
            ],
            commonMistakes: [
                "Leaning into the wall for active support",
                "Losing the line — banana-ing into the wall",
                "Rushing the weight shift before fingertip pressure is light"
            ],
            timeline: "1-2 years from freestanding handstand."
        ),
    ]
}
