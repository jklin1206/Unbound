import Foundation

// MARK: - RoutineLibrary

enum RoutineLibrary {
    private static func IS(_ l: String, _ s: Int) -> IntervalSegment {
        IntervalSegment(label: l, seconds: s)
    }

    static let routines: [RoutineDef] = [

        // ───────── Cardio ─────────
        RoutineDef(id: "z2-walk-20", title: "Zone 2 Walk",
            subtitle: "Keep HR in zone 2. Easy breathing, steady pace.",
            durationLabel: "~20 MIN", category: .cardio, difficultyTier: .initiate, difficultyWeight: 25,
            steps: [
                .timed(label: "Warm-up walk", seconds: 120, style: .work),
                .note(text: "Conversational pace — you can hold a sentence. Target HR 60–70% max (~180 − your age)."),
                .timed(label: "Zone 2 walk", seconds: 1200, style: .work),
                .timed(label: "Cool-down", seconds: 60, style: .rest)
            ]),

        RoutineDef(id: "intervals-15", title: "Heart Rate Intervals",
            subtitle: "5 × 1-min hard / 1-min easy. Build conditioning.",
            durationLabel: "~15 MIN", category: .cardio, difficultyTier: .apprentice, difficultyWeight: 35,
            steps: [
                .timed(label: "Warm-up", seconds: 180, style: .work),
                .interval(label: "HR intervals", rounds: 5,
                          segments: [IS("GO — max effort", 60), IS("Recover", 60)]),
                .timed(label: "Cool-down", seconds: 120, style: .rest)
            ]),

        RoutineDef(id: "easy-bike-30", title: "Easy Bike",
            subtitle: "Steady-state spin. Low impact recovery cardio.",
            durationLabel: "~30 MIN", category: .cardio, difficultyTier: .novice, difficultyWeight: 30,
            steps: [
                .note(text: "Seat: leg ~90% extended at bottom. RPM 80–90, light–moderate resistance. Nasal breathing if you can."),
                .timed(label: "Easy bike", seconds: 1800, style: .work),
                .instruction(text: "Stretch quads and hip flexors.", cue: nil)
            ]),

        RoutineDef(id: "incline-siege-walk", title: "Incline Siege Walk",
            subtitle: "Treadmill incline work with a controlled climb and reset.",
            durationLabel: "~25 MIN", category: .cardio, difficultyTier: .initiate, difficultyWeight: 32,
            steps: [
                .timed(label: "Flat warm-up walk", seconds: 180, style: .work),
                .instruction(text: "Set incline to 6-8%", cue: "Choose a grade where you can still breathe through the nose for short stretches."),
                .timed(label: "Incline climb", seconds: 900, style: .work),
                .timed(label: "Flat reset walk", seconds: 120, style: .work),
                .instruction(text: "Set incline to 10-12%", cue: "Hold posture tall. Hands hover near the rails without leaning on them."),
                .timed(label: "Final incline climb", seconds: 240, style: .work),
                .timed(label: "Cool-down walk", seconds: 120, style: .rest)
            ]),

        RoutineDef(id: "stair-tower-climb", title: "Stair Tower Climb",
            subtitle: "Stair climber conditioning with steady pressure.",
            durationLabel: "~18 MIN", category: .cardio, difficultyTier: .novice, difficultyWeight: 36,
            steps: [
                .timed(label: "Easy stair climb", seconds: 180, style: .work),
                .interval(label: "Stair pressure rounds", rounds: 6,
                          segments: [IS("Climb strong", 60), IS("Recover easy", 45)]),
                .timed(label: "Hands-free steady climb", seconds: 180, style: .work),
                .timed(label: "Cool-down stairs", seconds: 90, style: .rest)
            ]),

        RoutineDef(id: "rower-engine-intervals", title: "Rower Engine Intervals",
            subtitle: "Rowing intervals for legs, lungs, and pacing discipline.",
            durationLabel: "~18 MIN", category: .cardio, difficultyTier: .apprentice, difficultyWeight: 44,
            steps: [
                .timed(label: "Easy row warm-up", seconds: 240, style: .work),
                .instruction(text: "Row technique reset", cue: "Legs drive first, body swings second, arms finish last."),
                .interval(label: "Rower power rounds", rounds: 8,
                          segments: [IS("Hard row", 30), IS("Easy row", 60)]),
                .timed(label: "Cool-down row", seconds: 180, style: .rest)
            ]),

        RoutineDef(id: "jump-rope-footwork", title: "Jump Rope Footwork",
            subtitle: "Low-impact rope rounds with fast feet and clean rhythm.",
            durationLabel: "~16 MIN", category: .cardio, difficultyTier: .apprentice, difficultyWeight: 42,
            steps: [
                .timed(label: "Bounce prep without rope", seconds: 90, style: .work),
                .interval(label: "Basic bounce rounds", rounds: 4,
                          segments: [IS("Jump rope", 45), IS("Rest", 30)]),
                .interval(label: "Fast feet rounds", rounds: 4,
                          segments: [IS("Fast rope", 30), IS("Rest", 30)]),
                .timed(label: "Calf pedal", seconds: 60, style: .work)
            ]),

        // ───────── Mobility ─────────
        RoutineDef(id: "mobility-10", title: "Morning Mobility",
            subtitle: "Spine, hips, shoulders. Wake the body up.",
            durationLabel: "~10 MIN", category: .mobility, difficultyTier: .novice, difficultyWeight: 15,
            steps: [
                .instruction(text: "Cat-cow x 10", cue: "Slow, full range. Let each vertebra move."),
                .instruction(text: "World's greatest stretch x 5 / side", cue: "Long lunge, hand inside foot, rotate through the ribs."),
                .instruction(text: "Thread the needle x 8 / side", cue: "Reach under, then open tall. Keep hips quiet."),
                .instruction(text: "Hip 90-90 switches x 10", cue: "Chest tall, knees rotate side to side under control."),
                .instruction(text: "Shoulder CARs x 5 / side", cue: "Big pain-free circles, ribs stacked."),
                .timed(label: "Deep squat hold", seconds: 60, style: .work)
            ]),

        RoutineDef(id: "stretch-8", title: "Evening Stretch",
            subtitle: "Cool-down flexibility. Hip openers, hamstring.",
            durationLabel: "~8 MIN", category: .mobility, difficultyTier: .initiate, difficultyWeight: 10,
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

        RoutineDef(id: "hip-flow-15", title: "Hip Flow",
            subtitle: "15-min mobility sequence targeting hip health.",
            durationLabel: "~15 MIN", category: .mobility, difficultyTier: .forged, difficultyWeight: 20,
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

        RoutineDef(id: "shoulder-spine-12", title: "Shoulder + Spine",
            subtitle: "Open the upper back, lats, chest, wrists.",
            durationLabel: "~12 MIN", category: .mobility, difficultyTier: .apprentice, difficultyWeight: 18,
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

        RoutineDef(id: "ankle-squat-10", title: "Ankle + Squat",
            subtitle: "Dorsiflexion, calves, squat depth.",
            durationLabel: "~10 MIN", category: .mobility, difficultyTier: .novice, difficultyWeight: 16,
            steps: [
                .instruction(text: "Knee-to-wall ankle rocks x 10 / side", cue: "Heel stays down, knee tracks middle toes."),
                .timed(label: "Calf pedal", seconds: 60, style: .work),
                .timed(label: "Deep squat hold", seconds: 75, style: .work),
                .instruction(text: "Hip 90-90 switches x 8", cue: "Stay tall. Rotate smoothly between sides."),
                .timed(label: "Half-kneeling hamstring rock — left", seconds: 45, style: .work),
                .timed(label: "Half-kneeling hamstring rock — right", seconds: 45, style: .work)
            ]),

        RoutineDef(id: "posterior-chain-12", title: "Posterior Chain",
            subtitle: "Hamstrings, calves, glutes, low-back decompression.",
            durationLabel: "~12 MIN", category: .mobility, difficultyTier: .apprentice, difficultyWeight: 18,
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

        RoutineDef(id: "wrist-shoulder-prep-8", title: "Wrist + Shoulder Prep",
            subtitle: "Before pushups, handstands, dips, or planks.",
            durationLabel: "~8 MIN", category: .mobility, difficultyTier: .novice, difficultyWeight: 14,
            steps: [
                .instruction(text: "Wrist rocks x 12", cue: "Forward and back with full palm contact."),
                .instruction(text: "Shoulder CARs x 5 / side", cue: "Big slow circles without rib flare."),
                .timed(label: "Wall pec stretch — left", seconds: 40, style: .work),
                .timed(label: "Wall pec stretch — right", seconds: 40, style: .work),
                .timed(label: "Lat prayer stretch", seconds: 60, style: .work),
                .instruction(text: "Cat-cow x 8", cue: "Use it to reset the spine before loading the shoulders.")
            ]),

        RoutineDef(id: "desk-reset-6", title: "Desk Reset",
            subtitle: "Fast neck-free upper-body reset after sitting.",
            durationLabel: "~6 MIN", category: .mobility, difficultyTier: .initiate, difficultyWeight: 10,
            steps: [
                .instruction(text: "Shoulder CARs x 4 / side", cue: "Slow and clean. No shrugging through the hard part."),
                .instruction(text: "Thoracic rotation x 6 / side", cue: "Keep hips still and rotate through the upper back."),
                .timed(label: "Wall pec stretch — left", seconds: 35, style: .work),
                .timed(label: "Wall pec stretch — right", seconds: 35, style: .work),
                .timed(label: "Child's pose reach", seconds: 60, style: .work),
                .instruction(text: "Wrist rocks x 10", cue: "Small pressure, full palm contact.")
            ]),

        RoutineDef(id: "full-body-unlock-20", title: "Full-Body Mobility",
            subtitle: "A complete mobility pass for rest days.",
            durationLabel: "~20 MIN", category: .mobility, difficultyTier: .veteran, difficultyWeight: 28,
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
        RoutineDef(id: "100-pushup", title: "100 Push-Up Trial",
            subtitle: "Clear 100 clean reps in as many sets as needed.",
            durationLabel: "~15 MIN", category: .challenge, difficultyTier: .forged, difficultyWeight: 50,
            steps: [
                .repTarget(name: "Push-ups", target: 100,
                           cue: "Chest to ~1 inch from floor, elbows ~45°. Rest as long as you need between bursts."),
                .note(text: "As many sets as it takes. Log each burst as you go.")
            ]),

        RoutineDef(id: "plank-ladder", title: "Plank Ladder",
            subtitle: "30s / 45s / 60s / 75s / 90s — rest 30s between.",
            durationLabel: "~8 MIN", category: .challenge, difficultyTier: .novice, difficultyWeight: 40,
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

        RoutineDef(id: "tabata-core", title: "Tabata Core",
            subtitle: "8 × 20s on / 10s off. 4 rotating moves.",
            durationLabel: "~5 MIN", category: .challenge, difficultyTier: .apprentice, difficultyWeight: 45,
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

        RoutineDef(id: "hero-entry-exam", title: "Hero Entry Exam",
            subtitle: "A small baseline: push, squat, sit-up, and short run.",
            durationLabel: "~12 MIN", category: .challenge, difficultyTier: .initiate, difficultyWeight: 35,
            steps: [
                .repTarget(name: "Push-ups", target: 20, cue: "Clean reps, stop before form breaks."),
                .repTarget(name: "Sit-ups", target: 20, cue: nil),
                .repTarget(name: "Bodyweight squats", target: 20, cue: "Full foot pressure, chest tall."),
                .instruction(text: "1 km jog or brisk walk", cue: "Easy pace. Finish with control.")
            ]),

        RoutineDef(id: "ninja-academy-circuit", title: "Ninja Academy Circuit",
            subtitle: "Footwork, core, and bodyweight control in quick rounds.",
            durationLabel: "~14 MIN", category: .challenge, difficultyTier: .novice, difficultyWeight: 42,
            steps: [
                .circuit(rounds: 3, restBetweenSeconds: 40, steps: [
                    .instruction(text: "Bear crawl 10m forward + 10m back", cue: nil),
                    .instruction(text: "Reverse lunges × 8 / side", cue: "Quiet steps, tall posture."),
                    .instruction(text: "Push-ups × 8", cue: "Elevate hands if needed."),
                    .timed(label: "Hollow body hold", seconds: 25, style: .work),
                    .instruction(text: "Fast feet in place × 30", cue: "Light contacts, steady breathing.")
                ])
            ]),

        RoutineDef(id: "spirit-shot-conditioning", title: "Spirit Shot Conditioning",
            subtitle: "Short stance holds, sharp pushes, and sprint bursts.",
            durationLabel: "~16 MIN", category: .challenge, difficultyTier: .novice, difficultyWeight: 44,
            steps: [
                .circuit(rounds: 3, restBetweenSeconds: 45, steps: [
                    .timed(label: "Horse stance hold", seconds: 35, style: .work),
                    .instruction(text: "Explosive push-ups × 6", cue: "Hands can stay grounded; move fast."),
                    .instruction(text: "Shadow-box straight punches × 30", cue: "Exhale on each strike."),
                    .timed(label: "Sprint in place", seconds: 25, style: .work),
                    .timed(label: "Rest", seconds: 30, style: .rest)
                ])
            ]),

        RoutineDef(id: "hunter-exam-roadwork", title: "Hunter Exam Roadwork",
            subtitle: "Roadwork with bodyweight checkpoints along the route.",
            durationLabel: "~24 MIN", category: .challenge, difficultyTier: .apprentice, difficultyWeight: 58,
            steps: [
                .timed(label: "Easy run or incline walk", seconds: 360, style: .work),
                .instruction(text: "Push-ups × 12", cue: nil),
                .instruction(text: "Bodyweight squats × 20", cue: nil),
                .timed(label: "Easy run or incline walk", seconds: 360, style: .work),
                .instruction(text: "Walking lunges × 12 / leg", cue: nil),
                .timed(label: "Plank", seconds: 45, style: .work),
                .timed(label: "Final run or incline walk", seconds: 360, style: .work)
            ]),

        RoutineDef(id: "pirate-crew-conditioning", title: "Pirate Crew Conditioning",
            subtitle: "Carries, core, and hill bursts for travel-ready stamina.",
            durationLabel: "~22 MIN", category: .challenge, difficultyTier: .apprentice, difficultyWeight: 56,
            steps: [
                .circuit(rounds: 3, restBetweenSeconds: 50, steps: [
                    .instruction(text: "Loaded carry 30m down + back", cue: "Backpack, dumbbells, or bags."),
                    .instruction(text: "Step-ups × 10 / leg", cue: "Use stairs, bench, or a sturdy step."),
                    .instruction(text: "Push-ups × 10", cue: nil),
                    .timed(label: "Side plank — left", seconds: 25, style: .work),
                    .timed(label: "Side plank — right", seconds: 25, style: .work),
                    .timed(label: "Hill burst or stair climb", seconds: 30, style: .work)
                ])
            ]),

        RoutineDef(id: "alchemy-gate-circuit", title: "Alchemy Gate Circuit",
            subtitle: "Trade upper and lower body work with strict rest.",
            durationLabel: "~26 MIN", category: .challenge, difficultyTier: .forged, difficultyWeight: 68,
            steps: [
                .circuit(rounds: 4, restBetweenSeconds: 60, steps: [
                    .instruction(text: "Push-ups × 12", cue: "Clean lockout."),
                    .instruction(text: "Split squats × 8 / side", cue: "Smooth reps, no bounce."),
                    .instruction(text: "Pike push-ups × 8", cue: "Shorten range if shoulders need it."),
                    .instruction(text: "Hip hinge good mornings × 15", cue: "Hands across chest, hips back."),
                    .timed(label: "Hollow body hold", seconds: 35, style: .work)
                ]),
                .note(text: "Keep the exchange even: same tempo, same quality, every round.")
            ]),

        RoutineDef(id: "saitama-protocol", title: "Everyday Hero Protocol",
            subtitle: "100 push-ups, sit-ups, squats, and a 10 km run.",
            durationLabel: "~60–90 MIN", category: .challenge, difficultyTier: .master, difficultyWeight: 140,
            steps: [
                .repTarget(name: "Push-ups", target: 100, cue: nil),
                .repTarget(name: "Sit-ups", target: 100, cue: "Full range, hands behind head"),
                .repTarget(name: "Bodyweight squats", target: 100, cue: "Parallel depth minimum"),
                .instruction(text: "10 km run — any pace, no stopping", cue: nil),
                .note(text: "High-volume dungeon. Scale it if recovery drops.")
            ]),

        RoutineDef(id: "8-gates-protocol", title: "Eight Gates",
            subtitle: "Eight escalating rounds where each gate adds work.",
            durationLabel: "~45 MIN", category: .challenge, difficultyTier: .unbound, difficultyWeight: 150,
            steps: [
                .instruction(text: "Gate 1 — 10 push-ups", cue: nil),
                .timed(label: "Rest", seconds: 75, style: .rest),
                .instruction(text: "Gate 2 — 10 push-ups + 15 squats", cue: nil),
                .timed(label: "Rest", seconds: 75, style: .rest),
                .instruction(text: "Gate 3 — 10 push-ups + 15 squats + 10 dips (chair/bench)", cue: nil),
                .timed(label: "Rest", seconds: 75, style: .rest),
                .instruction(text: "Gate 4 — 10 push-ups + 15 squats + 10 dips + 10 pull-ups (or 15 Australian rows)", cue: nil),
                .timed(label: "Rest", seconds: 75, style: .rest),
                .instruction(text: "Gate 5 — 10 push-ups + 15 squats + 10 dips + 10 pull-ups + 20 mountain climbers", cue: nil),
                .timed(label: "Rest", seconds: 75, style: .rest),
                .instruction(text: "Gate 6 — 10 push-ups + 15 squats + 10 dips + 10 pull-ups + 20 mountain climbers + 30s plank hold", cue: nil),
                .timed(label: "Rest", seconds: 75, style: .rest),
                .instruction(text: "Gate 7 — 10 push-ups + 15 squats + 10 dips + 10 pull-ups + 20 mountain climbers + 30s plank + 10 burpees", cue: nil),
                .timed(label: "Rest", seconds: 75, style: .rest),
                .instruction(text: "Gate 8 — 10 push-ups + 15 squats + 10 dips + 10 pull-ups + 20 mountain climbers + 30s plank + 10 burpees + 400m sprint", cue: nil),
                .note(text: "Clear each gate with clean reps. Stop before form breaks.")
            ]),

        RoutineDef(id: "beach-forge", title: "Beach Forge",
            subtitle: "Carries, sprints, pull-ups, and squats under steady pressure.",
            durationLabel: "~40 MIN", category: .challenge, difficultyTier: .master, difficultyWeight: 90,
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
                .note(text: "Hard outdoor conditioning. Keep the carries braced and the sprints honest.")
            ]),

        RoutineDef(id: "underground-grind", title: "Underground Calisthenics",
            subtitle: "Pull-ups, dips, push-ups, and core. Simple street-gym work.",
            durationLabel: "~30 MIN", category: .challenge, difficultyTier: .veteran, difficultyWeight: 85,
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

        RoutineDef(id: "3d-maneuver-conditioning", title: "Scout Maneuver Conditioning",
            subtitle: "Grip, core, pulling power, and jumps under fatigue.",
            durationLabel: "~25 MIN", category: .challenge, difficultyTier: .veteran, difficultyWeight: 70,
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
                .note(text: "Keep each jump crisp and every pull controlled.")
            ]),

        RoutineDef(id: "daily-quest", title: "Daily Quest",
            subtitle: "A simple daily baseline to keep the work moving.",
            durationLabel: "~20 MIN", category: .challenge, difficultyTier: .initiate, difficultyWeight: 50,
            steps: [
                .repTarget(name: "Push-ups", target: 30, cue: nil),
                .repTarget(name: "Sit-ups", target: 30, cue: nil),
                .repTarget(name: "Bodyweight squats", target: 30, cue: nil),
                .instruction(text: "2 km run (or 12-min treadmill walk/jog)", cue: nil),
                .note(text: "Your everyday baseline — keep the reps clean and log it to hold your streak.")
            ]),

        RoutineDef(id: "thunder-circuit", title: "Thunder Sprint",
            subtitle: "Short explosive sets for speed and power.",
            durationLabel: "~20 MIN", category: .challenge, difficultyTier: .forged, difficultyWeight: 65,
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
                .note(text: "Explosive reps only. Stop a set when speed drops.")
            ]),

        RoutineDef(id: "gravity-chamber", title: "Gravity Chamber",
            subtitle: "Weighted volume with steady pressure.",
            durationLabel: "~50 MIN", category: .challenge, difficultyTier: .ascendant, difficultyWeight: 110,
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
                .note(text: "No equipment? Add one rep each set and use volume as the load.")
            ]),

        RoutineDef(id: "vessel-protocol", title: "Vessel Conditioning",
            subtitle: "Strength, speed, and carrying capacity.",
            durationLabel: "~35 MIN", category: .challenge, difficultyTier: .vessel, difficultyWeight: 95,
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
                .note(text: "Move sharply and keep every set controlled.")
            ]),

        // ───────── Alt circuits ─────────
        RoutineDef(id: "bw-full-30", title: "Bodyweight Kit",
            subtitle: "No equipment. Balanced push, legs, hinge, pull option, core.",
            durationLabel: "~30 MIN", category: .altCircuit, difficultyTier: .apprentice, difficultyWeight: 40,
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

        RoutineDef(id: "db-full-25", title: "Dumbbell Pair",
            subtitle: "Pair of dumbbells. Simple strength circuit, easy to scale.",
            durationLabel: "~25 MIN", category: .altCircuit, difficultyTier: .forged, difficultyWeight: 45,
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

        RoutineDef(id: "hotel-full-20", title: "Hotel Room Kit",
            subtitle: "Small-space workout for travel days. No equipment needed.",
            durationLabel: "~20 MIN", category: .altCircuit, difficultyTier: .novice, difficultyWeight: 35,
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

        RoutineDef(id: "gym-full-45", title: "Gym Builder",
            subtitle: "Squat, press, hinge, pull, carry/core. A complete gym day.",
            durationLabel: "~45 MIN", category: .altCircuit, difficultyTier: .master, difficultyWeight: 65,
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

        RoutineDef(id: "athletic-full-28", title: "Athletic Circuit",
            subtitle: "Power, strength, and core in one fast circuit.",
            durationLabel: "~28 MIN", category: .altCircuit, difficultyTier: .veteran, difficultyWeight: 50,
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
        sortedByDifficulty(routines)
    }

    static func routines(category: RoutineCategory) -> [RoutineDef] {
        sortedByDifficulty(routines.filter { $0.category == category })
    }

    static func sortedByDifficulty(_ routines: [RoutineDef]) -> [RoutineDef] {
        routines.sorted { lhs, rhs in
            if lhs.difficultyTier != rhs.difficultyTier {
                return lhs.difficultyTier < rhs.difficultyTier
            }
            if lhs.difficultyWeight != rhs.difficultyWeight {
                return lhs.difficultyWeight < rhs.difficultyWeight
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
