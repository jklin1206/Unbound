import SwiftUI

// MARK: - RoutineCategory

enum RoutineCategory: CaseIterable, Hashable {
    case cardio, mobility, challenge, altCircuit

    var label: String {
        switch self {
        case .cardio:     return "CARDIO"
        case .mobility:   return "MOBILITY"
        case .challenge:  return "CHALLENGES"
        case .altCircuit: return "ALT CIRCUITS"
        }
    }

    var systemImage: String {
        switch self {
        case .cardio:     return "figure.run"
        case .mobility:   return "figure.flexibility"
        case .challenge:  return "flame.fill"
        case .altCircuit: return "dumbbell.fill"
        }
    }

    var color: Color {
        switch self {
        case .cardio:     return Color.unbound.coachCyan
        case .mobility:   return Color.unbound.rankGreen
        case .challenge:  return Color.unbound.warnOrange
        case .altCircuit: return Color.unbound.accent
        }
    }
}

// MARK: - RoutineDef

struct RoutineDef: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let durationLabel: String
    let category: RoutineCategory
    let difficultyTier: SkillTier
    let spReward: Int
    var steps: [RoutineStep]

    init(
        id: String,
        title: String,
        subtitle: String,
        durationLabel: String,
        category: RoutineCategory,
        difficultyTier: SkillTier = .initiate,
        spReward: Int,
        steps: [RoutineStep] = []
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.durationLabel = durationLabel
        self.category = category
        self.difficultyTier = difficultyTier
        self.spReward = spReward
        self.steps = steps
    }
}

// MARK: - RoutineLibrary

enum RoutineLibrary {
    private static func IS(_ l: String, _ s: Int) -> IntervalSegment {
        IntervalSegment(label: l, seconds: s)
    }

    static let placeholderRoutines: [RoutineDef] = [

        // ───────── Cardio ─────────
        RoutineDef(id: "z2-walk-20", title: "20-min Zone 2 walk",
            subtitle: "Keep HR in zone 2. Easy breathing, steady pace.",
            durationLabel: "~20 MIN", category: .cardio, difficultyTier: .initiate, spReward: 25,
            steps: [
                .timed(label: "Warm-up walk", seconds: 120, style: .work),
                .note(text: "Conversational pace — you can hold a sentence. Target HR 60–70% max (~180 − your age)."),
                .timed(label: "Zone 2 walk", seconds: 1200, style: .work),
                .timed(label: "Cool-down", seconds: 60, style: .rest)
            ]),

        RoutineDef(id: "intervals-15", title: "15-min HR intervals",
            subtitle: "5 × 1-min hard / 1-min easy. Build conditioning.",
            durationLabel: "~15 MIN", category: .cardio, difficultyTier: .apprentice, spReward: 35,
            steps: [
                .timed(label: "Warm-up", seconds: 180, style: .work),
                .interval(label: "HR intervals", rounds: 5,
                          segments: [IS("GO — max effort", 60), IS("Recover", 60)]),
                .timed(label: "Cool-down", seconds: 120, style: .rest)
            ]),

        RoutineDef(id: "easy-bike-30", title: "30-min easy bike",
            subtitle: "Steady-state spin. Low impact recovery cardio.",
            durationLabel: "~30 MIN", category: .cardio, difficultyTier: .novice, spReward: 30,
            steps: [
                .note(text: "Seat: leg ~90% extended at bottom. RPM 80–90, light–moderate resistance. Nasal breathing if you can."),
                .timed(label: "Easy bike", seconds: 1800, style: .work),
                .instruction(text: "Stretch quads and hip flexors.", cue: nil)
            ]),

        // ───────── Mobility ─────────
        RoutineDef(id: "mobility-10", title: "Morning mobility flow",
            subtitle: "Spine, hips, shoulders. Wake the body up.",
            durationLabel: "~10 MIN", category: .mobility, difficultyTier: .novice, spReward: 15,
            steps: [
                .instruction(text: "Cat-cow x 10", cue: "Slow, full range. Let each vertebra move."),
                .instruction(text: "World's greatest stretch x 5 / side", cue: "Long lunge, hand inside foot, rotate through the ribs."),
                .instruction(text: "Thread the needle x 8 / side", cue: "Reach under, then open tall. Keep hips quiet."),
                .instruction(text: "Hip 90-90 switches x 10", cue: "Chest tall, knees rotate side to side under control."),
                .instruction(text: "Shoulder CARs x 5 / side", cue: "Big pain-free circles, ribs stacked."),
                .timed(label: "Deep squat hold", seconds: 60, style: .work)
            ]),

        RoutineDef(id: "stretch-8", title: "Evening stretch",
            subtitle: "Cool-down flexibility. Hip openers, hamstring.",
            durationLabel: "~8 MIN", category: .mobility, difficultyTier: .initiate, spReward: 10,
            steps: [
                .timed(label: "Hamstring fold — left", seconds: 60, style: .work),
                .timed(label: "Hamstring fold — right", seconds: 60, style: .work),
                .timed(label: "Pigeon pose — left", seconds: 60, style: .work),
                .timed(label: "Pigeon pose — right", seconds: 60, style: .work),
                .timed(label: "Figure-4 — left", seconds: 45, style: .work),
                .timed(label: "Figure-4 — right", seconds: 45, style: .work),
                .timed(label: "Seated forward fold", seconds: 60, style: .work),
                .timed(label: "Spinal twist — left", seconds: 30, style: .work),
                .timed(label: "Spinal twist — right", seconds: 30, style: .work)
            ]),

        RoutineDef(id: "hip-flow-15", title: "Hip flow",
            subtitle: "15-min mobility sequence targeting hip health.",
            durationLabel: "~15 MIN", category: .mobility, difficultyTier: .forged, spReward: 20,
            steps: [
                .instruction(text: "Hip circles × 10 each direction", cue: nil),
                .timed(label: "Deep lunge hold — left", seconds: 45, style: .work),
                .timed(label: "Deep lunge hold — right", seconds: 45, style: .work),
                .instruction(text: "Side-lying clamshell × 15 / side", cue: nil),
                .timed(label: "Frog stretch", seconds: 90, style: .work),
                .timed(label: "Couch stretch — left", seconds: 60, style: .work),
                .timed(label: "Couch stretch — right", seconds: 60, style: .work),
                .instruction(text: "Lateral band walk × 20 steps / side (bodyweight if no band)", cue: nil),
                .instruction(text: "Glute bridge × 15", cue: nil)
            ]),

        RoutineDef(id: "shoulder-spine-12", title: "Shoulder + spine reset",
            subtitle: "Open the upper back, lats, chest, wrists.",
            durationLabel: "~12 MIN", category: .mobility, difficultyTier: .apprentice, spReward: 18,
            steps: [
                .instruction(text: "Shoulder CARs x 5 / side", cue: "Slow circles. Keep ribs down and neck relaxed."),
                .instruction(text: "Thread the needle x 8 / side", cue: "Rotate through the rib cage, not the low back."),
                .timed(label: "Lat prayer stretch", seconds: 60, style: .work),
                .timed(label: "Wall pec stretch — left", seconds: 45, style: .work),
                .timed(label: "Wall pec stretch — right", seconds: 45, style: .work),
                .instruction(text: "Wrist rocks x 12", cue: "Palms down, small rocks, no sharp pressure."),
                .timed(label: "Thoracic rotation — left", seconds: 45, style: .work),
                .timed(label: "Thoracic rotation — right", seconds: 45, style: .work)
            ]),

        RoutineDef(id: "ankle-squat-10", title: "Ankle + squat prep",
            subtitle: "Dorsiflexion, calves, squat depth.",
            durationLabel: "~10 MIN", category: .mobility, difficultyTier: .novice, spReward: 16,
            steps: [
                .instruction(text: "Knee-to-wall ankle rocks x 10 / side", cue: "Heel stays down, knee tracks middle toes."),
                .timed(label: "Calf pedal", seconds: 60, style: .work),
                .timed(label: "Deep squat hold", seconds: 75, style: .work),
                .instruction(text: "Hip 90-90 switches x 8", cue: "Stay tall. Rotate smoothly between sides."),
                .timed(label: "Half-kneeling hamstring rock — left", seconds: 45, style: .work),
                .timed(label: "Half-kneeling hamstring rock — right", seconds: 45, style: .work)
            ]),

        RoutineDef(id: "posterior-chain-12", title: "Posterior chain release",
            subtitle: "Hamstrings, calves, glutes, low-back decompression.",
            durationLabel: "~12 MIN", category: .mobility, difficultyTier: .apprentice, spReward: 18,
            steps: [
                .timed(label: "Hamstring fold — left", seconds: 60, style: .work),
                .timed(label: "Hamstring fold — right", seconds: 60, style: .work),
                .timed(label: "Figure-4 — left", seconds: 60, style: .work),
                .timed(label: "Figure-4 — right", seconds: 60, style: .work),
                .timed(label: "Calf pedal", seconds: 60, style: .work),
                .timed(label: "Child's pose reach", seconds: 75, style: .work),
                .timed(label: "Spinal twist — left", seconds: 35, style: .work),
                .timed(label: "Spinal twist — right", seconds: 35, style: .work)
            ]),

        RoutineDef(id: "wrist-shoulder-prep-8", title: "Wrist + shoulder prep",
            subtitle: "Before pushups, handstands, dips, or planks.",
            durationLabel: "~8 MIN", category: .mobility, difficultyTier: .novice, spReward: 14,
            steps: [
                .instruction(text: "Wrist rocks x 12", cue: "Forward and back with full palm contact."),
                .instruction(text: "Shoulder CARs x 5 / side", cue: "Big slow circles without rib flare."),
                .timed(label: "Wall pec stretch — left", seconds: 40, style: .work),
                .timed(label: "Wall pec stretch — right", seconds: 40, style: .work),
                .timed(label: "Lat prayer stretch", seconds: 60, style: .work),
                .instruction(text: "Cat-cow x 8", cue: "Use it to reset the spine before loading the shoulders.")
            ]),

        RoutineDef(id: "desk-reset-6", title: "Desk reset",
            subtitle: "Fast neck-free upper-body reset after sitting.",
            durationLabel: "~6 MIN", category: .mobility, difficultyTier: .initiate, spReward: 10,
            steps: [
                .instruction(text: "Shoulder CARs x 4 / side", cue: "Slow and clean. No shrugging through the hard part."),
                .instruction(text: "Thoracic rotation x 6 / side", cue: "Keep hips still and rotate through the upper back."),
                .timed(label: "Wall pec stretch — left", seconds: 35, style: .work),
                .timed(label: "Wall pec stretch — right", seconds: 35, style: .work),
                .timed(label: "Child's pose reach", seconds: 60, style: .work),
                .instruction(text: "Wrist rocks x 10", cue: "Small pressure, full palm contact.")
            ]),

        RoutineDef(id: "full-body-unlock-20", title: "Full-body unlock",
            subtitle: "A complete mobility pass for rest days.",
            durationLabel: "~20 MIN", category: .mobility, difficultyTier: .veteran, spReward: 28,
            steps: [
                .instruction(text: "Cat-cow x 10", cue: "Start easy and let the spine warm up."),
                .instruction(text: "World's greatest stretch x 5 / side", cue: "Lunge, elbow, rotate, switch."),
                .timed(label: "Couch stretch — left", seconds: 60, style: .work),
                .timed(label: "Couch stretch — right", seconds: 60, style: .work),
                .timed(label: "Frog stretch", seconds: 75, style: .work),
                .timed(label: "Hamstring fold — left", seconds: 60, style: .work),
                .timed(label: "Hamstring fold — right", seconds: 60, style: .work),
                .instruction(text: "Knee-to-wall ankle rocks x 10 / side", cue: "Keep the heel down on each rep."),
                .timed(label: "Deep squat hold", seconds: 90, style: .work),
                .timed(label: "Lat prayer stretch", seconds: 60, style: .work),
                .timed(label: "Spinal twist — left", seconds: 40, style: .work),
                .timed(label: "Spinal twist — right", seconds: 40, style: .work)
            ]),

        // ───────── Challenges ─────────
        RoutineDef(id: "100-pushup", title: "100 pushup challenge",
            subtitle: "As many sets as it takes. Track your count.",
            durationLabel: "~15 MIN", category: .challenge, difficultyTier: .forged, spReward: 50,
            steps: [
                .repTarget(name: "Push-ups", target: 100,
                           cue: "Chest to ~1 inch from floor, elbows ~45°. Rest as long as you need between bursts."),
                .note(text: "As many sets as it takes. Log each burst as you go.")
            ]),

        RoutineDef(id: "plank-ladder", title: "Plank ladder",
            subtitle: "30s / 45s / 60s / 75s / 90s — rest 30s between.",
            durationLabel: "~8 MIN", category: .challenge, difficultyTier: .novice, spReward: 40,
            steps: [
                .timed(label: "Plank", seconds: 30, style: .work),
                .timed(label: "Rest", seconds: 30, style: .rest),
                .timed(label: "Plank", seconds: 45, style: .work),
                .timed(label: "Rest", seconds: 30, style: .rest),
                .timed(label: "Plank", seconds: 60, style: .work),
                .timed(label: "Rest", seconds: 30, style: .rest),
                .timed(label: "Plank", seconds: 75, style: .work),
                .timed(label: "Rest", seconds: 30, style: .rest),
                .timed(label: "Plank — final", seconds: 90, style: .work),
                .note(text: "Neutral spine, squeeze glutes, breathe steady.")
            ]),

        RoutineDef(id: "tabata-core", title: "Tabata core",
            subtitle: "8 × 20s on / 10s off. 4 rotating moves.",
            durationLabel: "~5 MIN", category: .challenge, difficultyTier: .apprentice, spReward: 45,
            steps: [
                .interval(label: "Mountain climbers", rounds: 2,
                          segments: [IS("WORK", 20), IS("REST", 10)]),
                .interval(label: "Bicycle crunches", rounds: 2,
                          segments: [IS("WORK", 20), IS("REST", 10)]),
                .interval(label: "Hollow body hold", rounds: 2,
                          segments: [IS("WORK", 20), IS("REST", 10)]),
                .interval(label: "V-ups", rounds: 2,
                          segments: [IS("WORK", 20), IS("REST", 10)])
            ]),

        RoutineDef(id: "saitama-protocol", title: "Zero Limit Protocol",
            subtitle: "100 push-ups, 100 sit-ups, 100 squats, 10km run. Every. Single. Day.",
            durationLabel: "~60–90 MIN", category: .challenge, difficultyTier: .ascendant, spReward: 200,
            steps: [
                .repTarget(name: "Push-ups", target: 100, cue: nil),
                .repTarget(name: "Sit-ups", target: 100, cue: "Full range, hands behind head"),
                .repTarget(name: "Bodyweight squats", target: 100, cue: "Parallel depth minimum"),
                .instruction(text: "10 km run — any pace, no stopping", cue: nil),
                .note(text: "No rest days. No excuses. This protocol exists — so does overtraining. Earn it.")
            ]),

        RoutineDef(id: "8-gates-protocol", title: "8 Gates Protocol",
            subtitle: "8 rounds. Each gate adds a layer. You stop when your body does.",
            durationLabel: "~45 MIN", category: .challenge, difficultyTier: .vessel, spReward: 120,
            steps: [
                .instruction(text: "Gate 1 — 10 push-ups", cue: nil),
                .timed(label: "Rest", seconds: 75, style: .rest),
                .instruction(text: "Gate 2 — 10 push-ups + 15 squats", cue: nil),
                .timed(label: "Rest", seconds: 75, style: .rest),
                .instruction(text: "Gate 3 — + 10 dips (chair/bench)", cue: nil),
                .timed(label: "Rest", seconds: 75, style: .rest),
                .instruction(text: "Gate 4 — + 10 pull-ups (or 15 Australian rows)", cue: nil),
                .timed(label: "Rest", seconds: 75, style: .rest),
                .instruction(text: "Gate 5 — repeat Gate 4 + 20 mountain climbers", cue: nil),
                .timed(label: "Rest", seconds: 75, style: .rest),
                .instruction(text: "Gate 6 — repeat Gate 5 + 30s plank hold", cue: nil),
                .timed(label: "Rest", seconds: 75, style: .rest),
                .instruction(text: "Gate 7 — repeat Gate 6 + 10 burpees", cue: nil),
                .timed(label: "Rest", seconds: 75, style: .rest),
                .instruction(text: "Gate 8 — repeat Gate 7 + 400m sprint", cue: nil),
                .note(text: "Most people DNF after Gate 5. That's the point. No skipping, no half gates.")
            ]),

        RoutineDef(id: "beach-forge", title: "Beach Forge",
            subtitle: "Heavy carries, sprints, pull-ups. Zero to forged in 40 minutes.",
            durationLabel: "~40 MIN", category: .challenge, difficultyTier: .master, spReward: 90,
            steps: [
                .instruction(text: "Farmer carry — 2 × heaviest DBs/bags, 40m down & back × 4", cue: nil),
                .timed(label: "Rest", seconds: 60, style: .rest),
                .instruction(text: "400m run (or 2 min treadmill at race pace)", cue: nil),
                .timed(label: "Rest", seconds: 60, style: .rest),
                .instruction(text: "Pull-ups × max reps — 4 sets, rest 45s between", cue: nil),
                .timed(label: "Rest", seconds: 90, style: .rest),
                .instruction(text: "Sandbag/backpack squat × 15 — 3 sets", cue: nil),
                .timed(label: "Rest", seconds: 60, style: .rest),
                .instruction(text: "400m run — final sprint, leave nothing", cue: nil),
                .note(text: "Inspired by carrying dead weight every day until you're not weak anymore.")
            ]),

        RoutineDef(id: "underground-grind", title: "Underground Grind",
            subtitle: "Pull-ups, dips, push-ups, core. Pure calisthenics. No mercy.",
            durationLabel: "~30 MIN", category: .challenge, difficultyTier: .veteran, spReward: 85,
            steps: [
                .circuit(rounds: 4, restBetweenSeconds: 45, steps: [
                    .instruction(text: "Pull-ups × max — strict form", cue: nil),
                    .timed(label: "Rest", seconds: 45, style: .rest),
                    .instruction(text: "Dips × max (bars or chairs)", cue: nil),
                    .timed(label: "Rest", seconds: 45, style: .rest),
                    .instruction(text: "Diamond push-ups × 15", cue: nil),
                    .timed(label: "Rest", seconds: 45, style: .rest),
                    .instruction(text: "Hanging leg raises × 12", cue: nil)
                ]),
                .instruction(text: "Finish: L-sit hold — max duration × 3 attempts", cue: nil),
                .note(text: "No pull-ups? Australian rows under a table × 15.")
            ]),

        RoutineDef(id: "3d-maneuver-conditioning", title: "3D Conditioning",
            subtitle: "Core, grip, pulling power. Built for bodies that move in all directions.",
            durationLabel: "~25 MIN", category: .challenge, difficultyTier: .veteran, spReward: 70,
            steps: [
                .circuit(rounds: 4, restBetweenSeconds: 45, steps: [
                    .timed(label: "Dead hang", seconds: 60, style: .work),
                    .timed(label: "Rest", seconds: 30, style: .rest),
                    .instruction(text: "Pull-ups × 8 — 3s controlled descent", cue: nil),
                    .timed(label: "Rest", seconds: 45, style: .rest),
                    .instruction(text: "Tuck jumps × 10 — drive knees", cue: nil),
                    .timed(label: "Rest", seconds: 30, style: .rest),
                    .timed(label: "Hollow body hold", seconds: 45, style: .work),
                    .timed(label: "Rest", seconds: 30, style: .rest),
                    .instruction(text: "Explosive push-up × 10 (hands leave floor)", cue: nil)
                ]),
                .note(text: "Move like you weigh nothing. Train like it costs something.")
            ]),

        RoutineDef(id: "daily-quest", title: "Daily Quest",
            subtitle: "The weakest start. The discipline compounds. Begin your rank climb.",
            durationLabel: "~20 MIN", category: .challenge, difficultyTier: .initiate, spReward: 50,
            steps: [
                .repTarget(name: "Push-ups", target: 30, cue: nil),
                .repTarget(name: "Sit-ups", target: 30, cue: nil),
                .repTarget(name: "Bodyweight squats", target: 30, cue: nil),
                .instruction(text: "2 km run (or 12-min treadmill walk/jog)", cue: nil),
                .note(text: "Initiate version. Daily for 2 weeks. Week 3: 50 reps + 5 km. Week 5: 100 reps + 10 km. The only way to level up is to show up.")
            ]),

        RoutineDef(id: "thunder-circuit", title: "Thunder Circuit",
            subtitle: "Speed, power, explosiveness. Train the fast-twitch you've been ignoring.",
            durationLabel: "~20 MIN", category: .challenge, difficultyTier: .forged, spReward: 65,
            steps: [
                .circuit(rounds: 3, restBetweenSeconds: 45, steps: [
                    .instruction(text: "Broad jump × 6 — max distance", cue: nil),
                    .timed(label: "Rest", seconds: 30, style: .rest),
                    .instruction(text: "Sprint 40m × 6 — full effort", cue: nil),
                    .timed(label: "Rest", seconds: 45, style: .rest),
                    .instruction(text: "Clap push-ups × 8", cue: nil),
                    .timed(label: "Rest", seconds: 30, style: .rest),
                    .instruction(text: "Jump squats × 12 — land soft, explode", cue: nil),
                    .timed(label: "Rest", seconds: 45, style: .rest),
                    .instruction(text: "Lateral bounds × 10 / side", cue: nil)
                ]),
                .note(text: "Every rep is a strike. Every second of rest is borrowed time.")
            ]),

        RoutineDef(id: "gravity-chamber", title: "Gravity Chamber",
            subtitle: "High volume. Every rep heavier than the last. Build the body that survives pressure.",
            durationLabel: "~50 MIN", category: .challenge, difficultyTier: .unbound, spReward: 110,
            steps: [
                .circuit(rounds: 5, restBetweenSeconds: 60, steps: [
                    .instruction(text: "Weighted push-ups × 20 (plate / loaded pack)", cue: nil)
                ]),
                .circuit(rounds: 5, restBetweenSeconds: 90, steps: [
                    .instruction(text: "Weighted squats × 15 (DBs / barbell)", cue: nil)
                ]),
                .circuit(rounds: 4, restBetweenSeconds: 60, steps: [
                    .instruction(text: "Weighted pull-ups × 8 (belt / DB)", cue: nil)
                ]),
                .circuit(rounds: 3, restBetweenSeconds: 45, steps: [
                    .timed(label: "Weighted plank", seconds: 60, style: .work)
                ]),
                .note(text: "No equipment? +1 rep every set — volume is the weight. The chamber does not adjust to you.")
            ]),

        RoutineDef(id: "vessel-protocol", title: "Vessel Protocol",
            subtitle: "Strength and speed. The body is a weapon. Forge it like one.",
            durationLabel: "~35 MIN", category: .challenge, difficultyTier: .vessel, spReward: 95,
            steps: [
                .circuit(rounds: 4, restBetweenSeconds: 60, steps: [
                    .instruction(text: "Clean & press × 8 — heavy", cue: nil)
                ]),
                .circuit(rounds: 4, restBetweenSeconds: 90, steps: [
                    .instruction(text: "Sprint 100m — walk-back recovery", cue: nil)
                ]),
                .circuit(rounds: 3, restBetweenSeconds: 45, steps: [
                    .instruction(text: "Single-arm DB row × 10 / side — drive the elbow", cue: nil)
                ]),
                .circuit(rounds: 3, restBetweenSeconds: 60, steps: [
                    .instruction(text: "Box jump / step-up jumps × 8", cue: nil)
                ]),
                .circuit(rounds: 3, restBetweenSeconds: 45, steps: [
                    .instruction(text: "Bear crawl 20m fwd + 20m back", cue: nil)
                ]),
                .repTarget(name: "Finish: push-ups", target: 50, cue: "Any style — clock running"),
                .note(text: "A weapon with no edge is dead weight. Stay sharp.")
            ]),

        // ───────── Alt circuits ─────────
        RoutineDef(id: "bw-full-30", title: "Bodyweight full-body",
            subtitle: "No equipment. Balanced push, legs, hinge, pull option, core.",
            durationLabel: "~30 MIN", category: .altCircuit, difficultyTier: .apprentice, spReward: 40,
            steps: [
                .note(text: "Move smoothly. Stop each set with 1-2 clean reps left. Use a table/towel row only if the setup is stable."),
                .timed(label: "Warm-up march + joint circles", seconds: 120, style: .work),
                .circuit(rounds: 3, restBetweenSeconds: 60, steps: [
                    .instruction(text: "Push-ups × 10-15", cue: "Hands under shoulders, ribs down, full lockout."),
                    .instruction(text: "Bodyweight squats × 15-20", cue: "Tripod feet, knees track toes, stand tall."),
                    .instruction(text: "Reverse lunges × 10 / leg", cue: "Step back softly and keep the front foot planted."),
                    .instruction(text: "Inverted rows × 8-12 (or prone swimmers × 12)", cue: "Use a secure table or low bar only. Pull elbows toward ribs."),
                    .instruction(text: "Pike push-ups × 8-10", cue: "Hips high, head travels forward and down."),
                    .instruction(text: "Glute bridges × 18-20", cue: "Drive through heels and stop before the low back arches."),
                    .timed(label: "Plank", seconds: 45, style: .work)
                ]),
                .timed(label: "Deep squat hold", seconds: 60, style: .work)
            ]),

        RoutineDef(id: "db-full-25", title: "Dumbbell full-body",
            subtitle: "Pair of dumbbells. Simple strength circuit, easy to scale.",
            durationLabel: "~25 MIN", category: .altCircuit, difficultyTier: .forged, spReward: 45,
            steps: [
                .note(text: "Pick a load you can control for every rep. If form changes, reduce reps before adding rest."),
                .timed(label: "Warm-up walkout + bodyweight squats", seconds: 120, style: .work),
                .circuit(rounds: 3, restBetweenSeconds: 90, steps: [
                    .instruction(text: "DB goblet squat × 10-12", cue: "Elbows inside knees, chest tall, full foot pressure."),
                    .instruction(text: "DB Romanian deadlift × 10-12", cue: "Soft knees, hips back, lats tight."),
                    .instruction(text: "DB bent-over row × 10 / arm", cue: "Brace on thigh or bench. Pull elbow toward hip."),
                    .instruction(text: "DB chest press × 10-12", cue: "Floor press is fine. Wrists stacked over elbows."),
                    .instruction(text: "DB shoulder press × 8-10", cue: "Squeeze glutes, ribs down, finish biceps near ears."),
                    .timed(label: "Plank", seconds: 45, style: .work)
                ]),
                .instruction(text: "DB curl × 12-15", cue: "Optional finisher. Elbows stay quiet, no swinging.")
            ]),

        RoutineDef(id: "hotel-full-20", title: "Hotel room full-body",
            subtitle: "Small-space workout for travel days. No equipment needed.",
            durationLabel: "~20 MIN", category: .altCircuit, difficultyTier: .novice, spReward: 35,
            steps: [
                .note(text: "Keep the room quiet: soft landings, controlled tempo, and a towel under hands if the floor is slick."),
                .timed(label: "Warm-up march + hip circles", seconds: 120, style: .work),
                .circuit(rounds: 3, restBetweenSeconds: 45, steps: [
                    .instruction(text: "Incline push-ups × 12", cue: "Hands on desk/bed if the floor version is too hard."),
                    .instruction(text: "Bodyweight squats × 18", cue: "Pause for one breath at the bottom."),
                    .instruction(text: "Reverse lunges × 10 / leg", cue: "Step back under control. Keep hips square."),
                    .instruction(text: "Pike push-ups × 8", cue: "Short range is fine if shoulders feel tight."),
                    .instruction(text: "Glute bridges × 20", cue: "Ribs down, squeeze at the top."),
                    .timed(label: "Hollow body hold", seconds: 30, style: .work)
                ]),
                .timed(label: "Seated forward fold", seconds: 60, style: .work)
            ]),

        RoutineDef(id: "gym-full-45", title: "Gym full-body builder",
            subtitle: "Squat, press, hinge, pull, carry/core. A complete gym day.",
            durationLabel: "~45 MIN", category: .altCircuit, difficultyTier: .master, spReward: 65,
            steps: [
                .note(text: "Use moderate loads today. Warm up the first lift with 2 lighter sets before the clock starts."),
                .timed(label: "Warm-up bike or incline walk", seconds: 300, style: .work),
                .circuit(rounds: 3, restBetweenSeconds: 90, steps: [
                    .instruction(text: "Back squat × 6-8", cue: "Brace before each rep. Depth you can own."),
                    .instruction(text: "Bench press × 6-8", cue: "Shoulder blades tucked, feet rooted."),
                    .instruction(text: "Bent-over row × 8-10", cue: "Hinge, brace, row without jerking."),
                    .instruction(text: "Romanian deadlift × 8-10", cue: "Hips back, shins mostly vertical, long spine."),
                    .instruction(text: "Overhead press × 6-8", cue: "Ribs down, press in a straight line."),
                    .instruction(text: "Walking lunge × 10 / leg", cue: "Smooth steps, front knee tracks toes."),
                    .instruction(text: "Hanging knee raise × 10-12", cue: "Posterior tilt first, then lift knees.")
                ]),
                .timed(label: "Hamstring fold", seconds: 60, style: .work)
            ]),

        RoutineDef(id: "athletic-full-28", title: "Athletic full-body circuit",
            subtitle: "Power, strength, and core in one fast circuit.",
            durationLabel: "~28 MIN", category: .altCircuit, difficultyTier: .veteran, spReward: 50,
            steps: [
                .note(text: "Use a kettlebell, dumbbell, or loaded backpack where noted. Keep jumps crisp, not sloppy."),
                .timed(label: "Warm-up walkout + shoulder CARs", seconds: 150, style: .work),
                .circuit(rounds: 4, restBetweenSeconds: 60, steps: [
                    .instruction(text: "Kettlebell swing × 12", cue: "Hinge snap, arms relaxed, bell floats to chest height."),
                    .instruction(text: "Push-ups × 12", cue: "Clean reps only. Elevate hands if needed."),
                    .instruction(text: "Goblet squat × 12", cue: "Drive knees out and keep the chest tall."),
                    .instruction(text: "DB row × 10 / arm", cue: "Pull toward the hip. Control the lower."),
                    .instruction(text: "Jump squats × 8", cue: "Land softly and reset before the next rep."),
                    .timed(label: "Hollow body hold", seconds: 35, style: .work)
                ]),
                .timed(label: "Lat prayer stretch", seconds: 60, style: .work)
            ])
    ]

    static var routinesSortedByDifficulty: [RoutineDef] {
        sortedByDifficulty(placeholderRoutines)
    }

    static func routines(category: RoutineCategory) -> [RoutineDef] {
        sortedByDifficulty(placeholderRoutines.filter { $0.category == category })
    }

    static func sortedByDifficulty(_ routines: [RoutineDef]) -> [RoutineDef] {
        routines.sorted { lhs, rhs in
            if lhs.difficultyTier != rhs.difficultyTier {
                return lhs.difficultyTier < rhs.difficultyTier
            }
            if lhs.spReward != rhs.spReward {
                return lhs.spReward < rhs.spReward
            }
            let lhsRunCount = RoutineRun.build(lhs.steps).run.count
            let rhsRunCount = RoutineRun.build(rhs.steps).run.count
            if lhsRunCount != rhsRunCount {
                return lhsRunCount < rhsRunCount
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
}

// MARK: - SideQuestCategory
// Kept alive for the Home "Daily Quest" path (SideQuestLibrary + SideQuestPlayerView).
// Full retirement deferred to the Home migration sub-project.

enum SideQuestCategory: String, Codable, Sendable, CaseIterable {
    case circuit, cardio, mobility, activity

    var label: String {
        switch self {
        case .circuit:  return "CIRCUIT"
        case .cardio:   return "CARDIO"
        case .mobility: return "MOBILITY"
        case .activity: return "ACTIVITY"
        }
    }

    var color: Color {
        switch self {
        case .circuit:  return Color.unbound.accent
        case .cardio:   return Color.unbound.coachCyan
        case .mobility: return Color.unbound.rankGreen
        case .activity: return Color.unbound.warnOrange
        }
    }
}

// MARK: - SideQuestExercise

struct SideQuestExercise: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let sets: Int
    let reps: String       // "12", "8-12", "30s", "AMRAP", "30s each"
    let restSeconds: Int
    let cue: String?
    let muscleGroups: [String]

    init(
        id: String = UUID().uuidString,
        name: String,
        sets: Int,
        reps: String,
        restSeconds: Int,
        cue: String? = nil,
        muscleGroups: [String] = []
    ) {
        self.id = id
        self.name = name
        self.sets = sets
        self.reps = reps
        self.restSeconds = restSeconds
        self.cue = cue
        self.muscleGroups = muscleGroups
    }

    var defaultRepCount: Int {
        if reps.uppercased().hasPrefix("AMRAP") { return 0 }
        if reps.hasSuffix("s") || reps.lowercased().hasSuffix("s each") {
            let stripped = reps.lowercased()
                .replacingOccurrences(of: " each", with: "")
                .replacingOccurrences(of: "s", with: "")
            return Int(stripped) ?? 30
        }
        if reps.contains("-") {
            let parts = reps.split(separator: "-").compactMap { Int($0) }
            return parts.last ?? 10
        }
        if reps.lowercased().contains("each") {
            return Int(reps.components(separatedBy: " ").first ?? "5") ?? 5
        }
        return Int(reps) ?? 10
    }

    var isTimeBased: Bool {
        reps.hasSuffix("s") || reps.lowercased().hasSuffix("s each") || reps.contains("min")
    }

    var stepperLabel: String { isTimeBased ? "SECS" : "REPS" }
}

// MARK: - SideQuest

struct SideQuest: Codable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let category: SideQuestCategory
    let estimatedMinutes: Int
    let spReward: Int
    let exercises: [SideQuestExercise]

    var totalSets: Int { exercises.reduce(0) { $0 + $1.sets } }
}

// MARK: - SideQuestLog

struct SideQuestLog: Codable, Identifiable {
    let id: String
    let userId: String
    let questId: String
    var startedAt: Date
    var completedAt: Date?
    var setLogs: [SideQuestSetLog]
    var spAwarded: Int

    var isComplete: Bool { completedAt != nil }
}

struct SideQuestSetLog: Codable, Identifiable {
    let id: String
    let exerciseId: String
    var exerciseName: String
    var setNumber: Int
    var completedReps: Int
    var completedAt: Date
}
