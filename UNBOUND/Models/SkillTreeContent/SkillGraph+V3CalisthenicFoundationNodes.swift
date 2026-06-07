import Foundation

extension SkillGraph {
    static let v3CalisthenicFoundationNodes: [SkillNode] = [
        // ────────────────────────────────────────────────────────────────
        // CALISTHENIC CONTROL (cal) — pushups + planche + handstand + rings
        // ────────────────────────────────────────────────────────────────

        .simple(
            id: "cal.plank-30",
            title: "Plank",
            cluster: .coreLever, tier: 1, type: .hold,
            target: .hold(exercise: "plank", seconds: 30),
            primary: [.core, .shoulders],
            subtitle: "The core foundation. Cannot skip this.",
            description: "Full-body plank on forearms or hands. Straight line head to heels, core braced, and held without position drift.",
            formCues: [
                "Elbows under shoulders (forearm) or hands under shoulders",
                "Squeeze glutes HARD — prevents lower-back sag",
                "Draw belly button toward spine",
                "Neck neutral, eyes at the floor",
                "Heels driving back, crown reaching forward"
            ],
            commonMistakes: [
                "Hips sagging — breaks the line",
                "Butt in the air — shortens the lever and cheats",
                "Holding breath instead of breathing steady"
            ],
            timeline: "1-4 weeks from zero to 30s clean."
        ),
        .simple(
            id: "cal.l-sit-10",
            title: "L-Sit",
            cluster: .coreLever, tier: 4, type: .hold,
            target: .hold(exercise: "l-sit", seconds: 10),
            prereqs: [PrerequisiteGroup("cl.knee-raise")],
            equipment: [.parallettes, .bodyweight],
            primary: [.core, .shoulders], secondary: [.arms, .legs],
            subtitle: "The move that makes people stop scrolling.",
            description: "Seated on parallettes or floor with hands flat, press body up, legs straight out at 90° from torso, and hold the shape cleanly.",
            formCues: [
                "Hands PRESS DOWN — shoulders depressed, not shrugged",
                "Legs locked, toes pointed, quads engaged",
                "Hollow body — ribs pulled down, pelvis tilted back",
                "Breathe normally — don't hold breath to cheat tension"
            ],
            commonMistakes: [
                "Shrugged shoulders — instant failure position",
                "Bent knees",
                "Hips dropping below parallel to hands"
            ],
            timeline: "1-3 months from solid compressed leg raises."
        ),
        .simple(
            id: "cal.pushup",
            title: "Push-Up",
            cluster: .calisthenicControl, tier: 2, type: .skill,
            target: .reps(exercise: "pushup", count: 10),
            prereqs: [PrerequisiteGroup("cal.incline-pushup")],
            primary: [.chest, .arms, .shoulders], secondary: [.core],
            subtitle: "The upper-body foundation.",
            description: "Full-range pushup from plank — chest touches the floor, elbows tuck at ~45°, full lockout. Target 10 clean reps.",
            formCues: [
                "Hands slightly wider than shoulders, under chest",
                "Elbows at 45° — not flared out, not pinned to ribs",
                "Body rigid as plank — no head-lead",
                "Chest touches down, don't stop halfway",
                "Full lockout at top"
            ],
            commonMistakes: [
                "Sagging hips — breaks the plank line",
                "Flared elbows (90°) — beats up the shoulders",
                "Partial ROM — bouncing off the top without lockout",
                "Head jutting forward before the chest"
            ],
            timeline: "2-6 weeks for first 10 clean reps."
        ),
        .simple(
            id: "cal.5-dips",
            title: "Dip",
            cluster: .calisthenicControl, tier: 3, type: .skill,
            target: .reps(exercise: "dip", count: 5),
            prereqs: [PrerequisiteGroup("cal.bench-dip")],
            equipment: [.parallettes, .elevatedSurface],
            primary: [.chest, .arms, .shoulders],
            subtitle: "Vertical press, meet bodyweight.",
            description: "5 strict dips on parallel bars or rings. Shoulders below elbows at the bottom, full lockout at the top.",
            formCues: [
                "Shoulders pull BELOW elbows at the bottom",
                "Lean slightly forward for chest emphasis, or stay upright for tricep",
                "Full lockout at the top — elbows straight",
                "Control the descent (2s min)"
            ],
            commonMistakes: [
                "Partial ROM — not reaching full shoulder depth",
                "Shrugging at the bottom",
                "Swinging legs for momentum"
            ],
            timeline: "1-3 months from solid pushups."
        ),
        .simple(
            id: "cal.ring-dip",
            title: "Ring Dip",
            cluster: .calisthenicControl, tier: 4, type: .skill,
            target: .reps(exercise: "ring dip", count: 5),
            prereqs: [PrerequisiteGroup("cal.5-dips")],
            isKeystone: true,
            equipment: [.gymnasticRings],
            primary: [.chest, .arms, .shoulders], secondary: [.core],
            subtitle: "Strict dip on unstable rings.",
            description: "5 strict dips on gymnastic rings, starting and ending with rings turned out in full support. Rings demand more stabilizer work than bars at every inch of the ROM.",
            formCues: [
                "Start and end each rep in a locked-out ring support",
                "Turn rings out at the top — wrists rotate, palms forward",
                "Descend with control — shoulders pull below elbows",
                "Rings stay close to the body, not drifting outward",
                "Press up smooth — no kipping"
            ],
            commonMistakes: [
                "Rings flaring wide at the bottom",
                "Partial ROM — not reaching full shoulder depth",
                "Skipping the turn-out at the top — loses the strict standard"
            ],
            timeline: "3-6 months from 5 bar dips."
        ),
        .simple(
            id: "cal.diamond-pushup",
            title: "Diamond Push-Up",
            cluster: .calisthenicControl, tier: 3, type: .skill,
            target: .reps(exercise: "diamond pushup", count: 10),
            prereqs: [PrerequisiteGroup("cal.pushup")],
            primary: [.arms, .chest],
            subtitle: "Triceps on notice.",
            description: "10 pushups with hands together, thumbs and index fingers forming a diamond. Elbows track close to the body. Tricep-dominant.",
            formCues: [
                "Hands touch under sternum, fingers splayed",
                "Elbows drive back past the ribs, not out",
                "Chest touches the hands (or the backs of them)",
                "Keep plank alignment — no piking"
            ],
            commonMistakes: [
                "Hands too low — turns into a regular pushup",
                "Flared elbows — defeats the triceps emphasis",
                "Partial depth to keep reps moving"
            ],
            timeline: "2-6 weeks from the strict push-up."
        ),
        .simple(
            id: "cal.pseudo-planche-pushup",
            title: "Pseudo-Planche Push-Up",
            cluster: .calisthenicControl, tier: 4, type: .skill,
            target: .reps(exercise: "pseudo-planche pushup", count: 5),
            prereqs: [PrerequisiteGroup("cal.decline-pushup")],
            primary: [.shoulders, .chest, .arms], secondary: [.core],
            subtitle: "Planche prep.",
            description: "Pushup with hands low near the ribs or hips, leaning weight forward so shoulders travel past the hands. Hand angle is tolerance-based: slightly out, forward, or backward if wrists and shoulders allow.",
            formCues: [
                "Hands low near ribs/hips; turn fingers only as tolerated",
                "Lean weight forward — shoulders over/past hands",
                "Elbow pits forward, elbows track back",
                "Protract scaps, ribs down, glutes tight"
            ],
            commonMistakes: [
                "Not enough forward lean — just a pushup",
                "Forcing a painful hand angle instead of scaling with parallettes or turnout",
                "Piking hips to cheat the lean"
            ],
            timeline: "1-3 months from diamond pushup."
        ),
        .simple(
            id: "pl.tuck-planche",
            title: "Tuck Planche",
            cluster: .planche, tier: 5, type: .hold,
            target: .hold(exercise: "tuck planche", seconds: 5),
            prereqs: [PrerequisiteGroup("hs.crane-pose")],
            equipment: [.parallettes],
            primary: [.shoulders, .core], secondary: [.chest, .arms],
            subtitle: "The planche on-ramp.",
            description: "Knees tucked tight to chest, weight balanced on straight arms, feet off the floor. Hold for 5 seconds. First real planche position.",
            formCues: [
                "Protract scaps HARD — shoulders spread apart",
                "Hips lift to at least shoulder height",
                "Knees tucked tight, heels near glutes",
                "Fingers turned slightly outward for shoulder safety",
                "Arms locked STRAIGHT throughout"
            ],
            commonMistakes: [
                "Bent arms — wrong skill, builds wrong patterns",
                "Hips drooping below shoulders",
                "Tucked legs come away from torso"
            ],
            timeline: "3-9 months from crane pose."
        ),
        .simple(
            id: "cal.tuck-planche-pushup",
            title: "Tuck Planche Push-Up",
            cluster: .calisthenicControl, tier: 5, type: .skill,
            target: .reps(exercise: "tuck planche pushup", count: 3),
            prereqs: [PrerequisiteGroup(["cal.pseudo-planche-pushup", "pl.tuck-planche"])],
            equipment: [.parallettes],
            primary: [.shoulders, .chest, .core],
            subtitle: "Planche meets press.",
            description: "From a tuck planche hold, bend and press back up while keeping feet off the floor. 3 reps. Shoulder-dominant pressing.",
            formCues: [
                "Enter from a rock-solid tuck planche hold",
                "Descend with control — elbows point back",
                "Keep the tuck tight throughout the descent",
                "Press back to locked-arm planche position"
            ],
            commonMistakes: [
                "Feet touching the floor on the descent",
                "Losing the tuck and collapsing hips",
                "Bouncing out of the bottom"
            ],
            timeline: "6-12 months from tuck planche."
        ),
        .simple(
            id: "pl.straddle-planche",
            title: "Straddle Planche",
            cluster: .planche, tier: 6, type: .hold,
            target: .hold(exercise: "straddle planche", seconds: 5),
            prereqs: [PrerequisiteGroup("pl.tuck-planche")],
            equipment: [.parallettes],
            primary: [.shoulders, .core],
            subtitle: "Legs split, body horizontal.",
            description: "Planche with legs split wide and extended — reduces the lever compared to full planche but still demands horizontal hold. 5 seconds.",
            formCues: [
                "Start from the tuck and extend legs wide, NOT straight back",
                "Elbows locked, scapulae protracted and depressed",
                "Wider split = easier; tighten gradually over months",
                "Point toes, squeeze legs, ribs down",
                "Hips stay level with shoulders"
            ],
            commonMistakes: [
                "Legs drooping below shoulder line",
                "Lazy split — legs drift together",
                "Banana back (lumbar arch, hips drop)"
            ],
            timeline: "1-2 years from tuck planche."
        ),
        .simple(
            id: "pl.full-planche",
            title: "Full Planche",
            cluster: .planche, tier: 7, type: .hold,
            target: .hold(exercise: "full planche", seconds: 5),
            prereqs: [PrerequisiteGroup("pl.half-lay-planche")],
            isKeystone: true,
            equipment: [.parallettes, .bodyweight],
            primary: [.shoulders, .core, .chest, .arms], secondary: [.forearms, .lats],
            subtitle: "Horizontal ceiling.",
            description: "Full horizontal hold. Body straight and parallel to the ground, supported only by straight arms.",
            formCues: [
                "Protract shoulders HARD — scaps apart",
                "Hips level with shoulders — body roughly parallel",
                "Point toes, squeeze glutes, hollow body",
                "Hands turned outward for shoulder safety",
                "Breathe — don't brace statically"
            ],
            commonMistakes: [
                "Banana back (lower back arches, hips drop)",
                "Shoulders rolling forward (scapular collapse)",
                "Bent arms — at this tier, arms MUST stay locked"
            ],
            timeline: "2-4 years from first tuck planche."
        ),
        .simple(
            id: "cal.handstand-pushup",
            title: "Handstand Push-Up",
            cluster: .calisthenicControl, tier: 6, type: .skill,
            target: .reps(exercise: "handstand pushup", count: 1),
            prereqs: [PrerequisiteGroup("cal.elevated-pike-pushup")],
            isKeystone: true,
            primary: [.shoulders, .arms], secondary: [.core, .chest],
            subtitle: "Pressing your bodyweight from upside down.",
            description: "One strict handstand push-up — wall-supported acceptable for the early levels, freestanding for mastery. Hands and crown/head pad form a tripod at the bottom, then arms press to a tall lockout.",
            formCues: [
                "Wall-supported is fine for L1-L3, freestanding for L4-L5",
                "Hands shoulder-width, fingers spread for balance",
                "Crown or head pad touches lightly on a tripod path",
                "Drive evenly through both palms — no favored side",
                "Lockout at the top with ribs tucked, no banana arch"
            ],
            commonMistakes: [
                "Kipping legs off the wall to cheat the press",
                "Partial lockout at the top",
                "Falling out of balance instead of bailing safely"
            ],
            timeline: "2-4 years from bent arm press."
        ),
        .simple(
            id: "cal.ninety-degree-pushup",
            title: "Ninety-Degree Push-Up",
            cluster: .calisthenicControl, tier: 6, type: .skill,
            target: .reps(exercise: "90 degree pushup", count: 1),
            prereqs: [PrerequisiteGroup("cal.handstand-pushup")],
            equipment: [.parallettes],
            primary: [.shoulders, .arms, .chest], secondary: [.core],
            subtitle: "Handstand into a bent-arm planche line.",
            description: "Start from a controlled handstand, lean the shoulders forward, lower as one piece into a bent-arm horizontal line, then press back to handstand without kicking or piking.",
            formCues: [
                "Start from a stacked handstand with shoulders tall",
                "Lean forward as elbows bend — the shoulder shift is part of the skill",
                "Body reaches a horizontal 90-degree bent-arm line",
                "Press back to handstand without kicking the legs"
            ],
            commonMistakes: [
                "Treating it like only a deeper handstand pushup",
                "Elbows flaring out to find leverage",
                "Piking hips or kicking back to handstand"
            ],
            timeline: "5+ years of vertical pressing work.",
            isParallelToParent: true
        ),
        .simple(
            id: "cal.clapping-handstand-pushup",
            title: "Clapping Handstand Push-Up",
            cluster: .calisthenicControl, tier: 7, type: .skill,
            target: .reps(exercise: "clapping handstand pushup", count: 1),
            prereqs: [PrerequisiteGroup("cal.ninety-degree-pushup")],
            isMythic: true,
            primary: [.shoulders, .arms], secondary: [.core, .chest],
            subtitle: "Push the floor away hard enough to clap upside down.",
            description: "One freestanding handstand push-up explosive enough that the hands leave the floor and clap before catching. Power-to-weight on a different planet.",
            formCues: [
                "Start from a stable freestanding handstand",
                "Descend with control to a crown/head-pad tripod target",
                "Drive explosively — hands fully leave the ground",
                "Clap close to the support line, then return hands fast",
                "Catch with slightly bent elbows and rebalance"
            ],
            commonMistakes: [
                "Catching with locked arms — shoulder injury risk",
                "Fake clap that barely separates the hands",
                "Bailing instead of catching the rep"
            ],
            timeline: "Mostly aspirational. 7+ years past first HSPU."
        ),

        // ────────────────────────────────────────────────────────────────
        // HANDSTAND (hs) — wrists, wall holds, freestanding, walks
        // Handstand now owns the inversion path directly on the map.
        // ────────────────────────────────────────────────────────────────

        .simple(
            id: "cal.pike-pushup",
            title: "Pike Push-Up",
            cluster: .calisthenicControl, tier: 4, type: .skill,
            target: .reps(exercise: "pike pushup", count: 10),
            prereqs: [PrerequisiteGroup("cal.diamond-pushup")],
            primary: [.shoulders, .arms], secondary: [.core],
            subtitle: "The vertical pressing pattern HSPU will test.",
            description: "10 strict pike pushups. Hips high, shoulders active, ribs controlled, and head descends between the hands on a tripod-like path. Trains the HSPU motor pattern without the balance demand.",
            formCues: [
                "Hips over shoulders, not over hips",
                "Head lowers between hands toward a tripod target",
                "Elbows track around 45°, not flared",
                "Full ROM — top of head kisses floor"
            ],
            commonMistakes: [
                "Hips too low (regresses to regular pushup)",
                "Elbows flared wide",
                "Cutting range of motion"
            ],
            timeline: "3–8 weeks from diamond pushup."
        ),
        .simple(
            id: "cal.elevated-pike-pushup",
            title: "Elevated Pike Push-Up",
            cluster: .calisthenicControl, tier: 5, type: .skill,
            target: .reps(exercise: "elevated pike pushup", count: 10),
            prereqs: [PrerequisiteGroup("cal.pike-pushup")],
            equipment: [.bodyweight, .elevatedSurface],
            primary: [.shoulders, .arms], secondary: [.core],
            subtitle: "Steeper angle — halfway to vertical pressing.",
            description: "Feet on a box or bench, hips stacked higher. 10 strict reps. The bridge between pike pushup and wall HSPU.",
            formCues: [
                "Box height around mid-shin or higher",
                "Shoulders directly over hands",
                "Head descends between the hands",
                "Slow, controlled descent"
            ],
            commonMistakes: [
                "Going too high too soon — spikes injury risk",
                "Hips dropping mid-set",
                "Rushing reps"
            ],
            timeline: "4–8 weeks after pike pushup × 10."
        ),
        .simple(
            id: "hs.wall-handstand-30",
            title: "Wall Handstand",
            cluster: .handstand, tier: 2, type: .hold,
            target: .hold(exercise: "wall handstand", seconds: 30),
            prereqs: [PrerequisiteGroup("hs.wall-plank")],
            equipment: [.bodyweight],
            primary: [.shoulders, .core], secondary: [.arms],
            subtitle: "Build the line before you chase balance.",
            description: "Chest-to-wall handstand hold with hands close enough to stack wrists, shoulders, hips, and ankles. The wall removes the balance fight so you can build wrist tolerance, locked elbows, active shoulders, hollow tension, and calm breathing upside down.",
            formCues: [
                "Walk in chest-to-wall, not banana-back first",
                "Hands shoulder-width, fingers spread and gripping the floor",
                "Push tall through locked elbows until shoulders cover the ears",
                "Ribs down, glutes tight, toes pointed lightly into the wall",
                "Breathe for the whole hold; do not brace by holding air"
            ],
            commonMistakes: [
                "Stopping too far from the wall and arching into a banana",
                "Soft elbows or shrugged, collapsed shoulders",
                "Counting time after the ribs flare or the low back dumps",
                "Letting the head crane forward instead of staying between the arms"
            ],
            timeline: "4-12 weeks from wall plank if wrists and shoulders are trained consistently."
        ),
        .simple(
            id: "hs.freestanding-hs-30",
            title: "Handstand",
            cluster: .handstand, tier: 3, type: .hold,
            target: .hold(exercise: "freestanding handstand", seconds: 30),
            prereqs: [PrerequisiteGroup("hs.wall-handstand-30")],
            isKeystone: true,
            primary: [.shoulders, .core], secondary: [.forearms],
            subtitle: "Balance is the skill.",
            description: "Freestanding handstand with a stacked body line, active shoulders, quiet legs, and balance corrected through the hands instead of panic steps. The 30-second standard means the hold has stopped being a lucky save and has become a shape you can breathe inside.",
            formCues: [
                "Kick only hard enough to arrive stacked, not crash past vertical",
                "Hands shoulder-width; fingers spread and ready to brake",
                "Push tall through locked elbows so shoulders stay by the ears",
                "Ribs tucked, glutes squeezed, legs together in a hollow line",
                "Use fingertips for overbalance and heel-of-hand pressure for underbalance"
            ],
            commonMistakes: [
                "Chasing seconds after the body bends into a banana",
                "Kicking so hard every attempt becomes a bailout drill",
                "Looking far ahead on the floor and closing the shoulders",
                "Trying to balance with shoulder swings instead of hand pressure",
                "Holding breath to fake stability"
            ],
            timeline: "6-24 months from a clean 60s wall handstand for most consistent athletes; faster if shoulder mobility and wrist tolerance are already built."
        ),
        .simple(
            id: "oah.one-arm-handstand-5s",
            title: "One-Arm Handstand",
            cluster: .oneArmHandstand, tier: 6, type: .hold,
            target: .hold(exercise: "one-arm handstand", seconds: 5),
            prereqs: [PrerequisiteGroup("hs.wall-supported-oah")],
            isKeystone: true,
            isMythic: true,
            primary: [.shoulders, .core],
            subtitle: "Balance at the limit.",
            description: "Freestanding straddle one-arm handstand held for 5 seconds. The support shoulder stays tall over the hand while the free hand comes off only after close-hand shifts, fingertip tents, and side-bend control are owned.",
            formCues: [
                "Prereq: quiet 60-90s handstand plus controlled straddle/tuck shape changes",
                "Close-hand straddle first, then shift hips over the support hand",
                "Support shoulder stays tall; no bent-arm save",
                "Free hand tapers: fingertips, two-finger, one-finger, then float",
                "Exit before shoulder sink, hip dump, or heavy wall lean"
            ],
            commonMistakes: [
                "Attempting before the two-hand line and straddle balance are boring",
                "Jumping into it rather than progressive weight shifts and tent drills",
                "Letting the support shoulder sink or the hips dump sideways"
            ],
            timeline: "3-7 years of daily handstand work."
        ),
        .simple(
            id: "oah.full-one-arm-handstand",
            title: "Full One-Arm Handstand",
            cluster: .oneArmHandstand, tier: 7, type: .hold,
            target: .hold(exercise: "full one arm handstand", seconds: 5),
            prereqs: [PrerequisiteGroup("oah.one-arm-handstand-5s")],
            isMythic: true,
            primary: [.shoulders, .core],
            subtitle: "Free balance on one hand.",
            description: "A strict one-arm handstand with the line narrowed toward legs-together/full-line control, no wall or fingertip support, and a calm exit. This is above the straddle 5s standard, not just another short hover.",
            formCues: [
                "Body stacked over the support hand with shoulder tall",
                "Narrow the legs only after straddle one-arm balance is stable",
                "Finger pressure steers; no bent support elbow",
                "Long line from wrist through heels",
                "Exit intentionally before the line breaks"
            ],
            commonMistakes: [
                "Calling a wide straddle hover the full-line standard",
                "Narrowing legs before the support shoulder can stay tall",
                "Saving with a bent elbow or uncontrolled fall"
            ],
            timeline: "5-10+ years of daily handstand work. Aspirational."
        ),


    ]
}
