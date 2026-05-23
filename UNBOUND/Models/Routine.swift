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
    let spReward: Int
    var steps: [RoutineStep] = []
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
            durationLabel: "~20 MIN", category: .cardio, spReward: 25,
            steps: [
                .timed(label: "Warm-up walk", seconds: 120, style: .work),
                .note(text: "Conversational pace — you can hold a sentence. Target HR 60–70% max (~180 − your age)."),
                .timed(label: "Zone 2 walk", seconds: 1200, style: .work),
                .timed(label: "Cool-down", seconds: 60, style: .rest)
            ]),

        RoutineDef(id: "intervals-15", title: "15-min HR intervals",
            subtitle: "5 × 1-min hard / 1-min easy. Build conditioning.",
            durationLabel: "~15 MIN", category: .cardio, spReward: 35,
            steps: [
                .timed(label: "Warm-up", seconds: 300, style: .work),
                .interval(label: "HR intervals", rounds: 5,
                          segments: [IS("GO — max effort", 60), IS("Recover", 60)]),
                .timed(label: "Cool-down", seconds: 180, style: .rest)
            ]),

        RoutineDef(id: "easy-bike-30", title: "30-min easy bike",
            subtitle: "Steady-state spin. Low impact recovery cardio.",
            durationLabel: "~30 MIN", category: .cardio, spReward: 30,
            steps: [
                .note(text: "Seat: leg ~90% extended at bottom. RPM 80–90, light–moderate resistance. Nasal breathing if you can."),
                .timed(label: "Easy bike", seconds: 1800, style: .work),
                .instruction(text: "Stretch quads and hip flexors.", cue: nil)
            ]),

        // ───────── Mobility ─────────
        RoutineDef(id: "mobility-10", title: "Morning mobility flow",
            subtitle: "Spine, hips, shoulders. Wake the body up.",
            durationLabel: "~10 MIN", category: .mobility, spReward: 15,
            steps: [
                .instruction(text: "Cat-cow × 10 — slow, full range", cue: nil),
                .instruction(text: "World's greatest stretch × 5 / side", cue: nil),
                .instruction(text: "Thread the needle × 8 / side", cue: nil),
                .instruction(text: "Hip 90-90 switches × 10", cue: nil),
                .instruction(text: "Shoulder circles forward + back × 10", cue: nil),
                .timed(label: "Deep squat hold", seconds: 60, style: .work)
            ]),

        RoutineDef(id: "stretch-8", title: "Evening stretch",
            subtitle: "Cool-down flexibility. Hip openers, hamstring.",
            durationLabel: "~8 MIN", category: .mobility, spReward: 10,
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
            durationLabel: "~15 MIN", category: .mobility, spReward: 20,
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

        // ───────── Challenges ─────────
        RoutineDef(id: "100-pushup", title: "100 pushup challenge",
            subtitle: "As many sets as it takes. Track your count.",
            durationLabel: "~15 MIN", category: .challenge, spReward: 50,
            steps: [
                .repTarget(name: "Push-ups", target: 100,
                           cue: "Chest to ~1 inch from floor, elbows ~45°. Rest as long as you need between bursts."),
                .note(text: "As many sets as it takes. Log each burst as you go.")
            ]),

        RoutineDef(id: "plank-ladder", title: "Plank ladder",
            subtitle: "30s / 45s / 60s / 75s / 90s — rest 30s between.",
            durationLabel: "~12 MIN", category: .challenge, spReward: 40,
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
            durationLabel: "~8 MIN", category: .challenge, spReward: 45,
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
            durationLabel: "~60–90 MIN", category: .challenge, spReward: 200,
            steps: [
                .repTarget(name: "Push-ups", target: 100, cue: nil),
                .repTarget(name: "Sit-ups", target: 100, cue: "Full range, hands behind head"),
                .repTarget(name: "Bodyweight squats", target: 100, cue: "Parallel depth minimum"),
                .instruction(text: "10 km run — any pace, no stopping", cue: nil),
                .note(text: "No rest days. No excuses. This protocol exists — so does overtraining. Earn it.")
            ]),

        RoutineDef(id: "8-gates-protocol", title: "8 Gates Protocol",
            subtitle: "8 rounds. Each gate adds a layer. You stop when your body does.",
            durationLabel: "~45 MIN", category: .challenge, spReward: 120,
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
            durationLabel: "~40 MIN", category: .challenge, spReward: 90,
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
            durationLabel: "~30 MIN", category: .challenge, spReward: 85,
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
            durationLabel: "~25 MIN", category: .challenge, spReward: 70,
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
            durationLabel: "~20 MIN", category: .challenge, spReward: 50,
            steps: [
                .repTarget(name: "Push-ups", target: 30, cue: nil),
                .repTarget(name: "Sit-ups", target: 30, cue: nil),
                .repTarget(name: "Bodyweight squats", target: 30, cue: nil),
                .instruction(text: "2 km run (or 12-min treadmill walk/jog)", cue: nil),
                .note(text: "E-rank version. Daily for 2 weeks. Wk3: 50 reps + 5km. Wk5: 100 reps + 10km — you're no longer E-rank. The only way to level up is to show up.")
            ]),

        RoutineDef(id: "thunder-circuit", title: "Thunder Circuit",
            subtitle: "Speed, power, explosiveness. Train the fast-twitch you've been ignoring.",
            durationLabel: "~20 MIN", category: .challenge, spReward: 65,
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
            durationLabel: "~50 MIN", category: .challenge, spReward: 110,
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
            durationLabel: "~35 MIN", category: .challenge, spReward: 95,
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
            subtitle: "No equipment. Pushup, squat, lunge, plank.",
            durationLabel: "~30 MIN", category: .altCircuit, spReward: 40,
            steps: [
                .circuit(rounds: 3, restBetweenSeconds: 60, steps: [
                    .instruction(text: "Push-ups × 15", cue: nil),
                    .instruction(text: "Bodyweight squats × 20", cue: nil),
                    .instruction(text: "Reverse lunges × 12 / leg", cue: nil),
                    .instruction(text: "Pike push-ups × 10", cue: nil),
                    .instruction(text: "Glute bridges × 20", cue: nil),
                    .timed(label: "Plank", seconds: 45, style: .work)
                ])
            ]),

        RoutineDef(id: "db-full-25", title: "Dumbbell full-body",
            subtitle: "Compound circuit with a pair of DBs.",
            durationLabel: "~25 MIN", category: .altCircuit, spReward: 45,
            steps: [
                .circuit(rounds: 3, restBetweenSeconds: 90, steps: [
                    .instruction(text: "DB goblet squat × 12", cue: nil),
                    .instruction(text: "DB Romanian deadlift × 10", cue: nil),
                    .instruction(text: "DB bent-over row × 10 / arm", cue: nil),
                    .instruction(text: "DB shoulder press × 10", cue: nil),
                    .instruction(text: "DB chest press × 12", cue: nil),
                    .instruction(text: "DB curl × 12", cue: nil)
                ])
            ])
    ]
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
