import Foundation

// MARK: - MovementCoaching
//
// Curated coaching (form cues + common mistakes) for non-skill catalog
// movements — barbell, dumbbell, and machine lifts that don't map to a skill
// node and therefore have no `SkillNode.formCues` to borrow.
//
// Resolution order (see `entry(for:)`):
//   1. A specific authored entry keyed by the movement's canonical exercise
//      name (e.g. "back squat").
//   2. A movement-pattern fallback keyed by `MovementSlot`, so every strength
//      exercise shows pattern-appropriate coaching instead of nothing.
//
// Skill-linked movements prefer the skill node's authored cues; this is the
// fallback for unlinked gym work. `resolved(for:)` is the single entry point
// used by the rank detail. This mirrors the curated `SkillGuideLibrary`.

enum MovementCoaching {
    struct Entry: Equatable {
        let cues: [String]
        let mistakes: [String]
    }

    /// Coaching for a catalog movement, or `nil` for non-strength slots
    /// (cardio / mobility / carry / routine) that don't take rep-form cues.
    static func entry(for definition: MovementDefinition) -> Entry? {
        specificEntry(for: definition) ?? patternEntry(for: definition)
    }

    /// The single source of truth for an exercise's coaching, shared by every
    /// surface (in-workout card, exercise detail, rank library). Precedence:
    ///   1. Exercise-specific authored coaching (e.g. "bench press").
    ///   2. The linked skill node's authored cues / mistakes — generated
    ///      skill-target movements record the link in `skillAssociations`, so
    ///      use `primarySkillId`.
    ///   3. A movement-pattern fallback, so every strength lift still coaches.
    /// Returns empty arrays for non-strength slots.
    static func resolved(for definition: MovementDefinition) -> (cues: [String], mistakes: [String]) {
        if let entry = specificEntry(for: definition) {
            return (entry.cues, entry.mistakes)
        }
        if let skillId = definition.primarySkillId,
           let node = SkillGraph.shared.node(id: skillId) {
            return (node.formCues, node.commonMistakes)
        }
        if let entry = patternEntry(for: definition) {
            return (entry.cues, entry.mistakes)
        }
        return ([], [])
    }

    /// Exercise-specific authored coaching (e.g. "bench press"), or `nil`.
    /// Preferred over a borrowed skill association so a barbell lift shows its
    /// own cues rather than its skill-rank link's (a bench press contributes to
    /// a push skill, but its form cues are not a push-up's).
    static func specificEntry(for definition: MovementDefinition) -> Entry? {
        if let canonical = definition.canonicalExerciseName?.lowercased(),
           let specific = specific[canonical] {
            return specific
        }
        return specific[definition.displayName.lowercased()]
    }

    /// Movement-pattern fallback by `MovementSlot`, or `nil` for non-strength slots.
    static func patternEntry(for definition: MovementDefinition) -> Entry? {
        patternFallback[definition.movementSlot]
    }

    // MARK: - Specific entries (canonical exercise name, lowercased)

    private static let specific: [String: Entry] = [
        // ── Horizontal push ──────────────────────────────────────────────
        "bench press": Entry(
            cues: [
                "Shoulder blades pinned back and down, slight upper-back arch",
                "Bar lowers to the lower chest, forearms stacked vertical",
                "Elbows tucked to roughly 45°, not flared to the sides",
                "Drive the feet into the floor and press the bar back over the shoulders"
            ],
            mistakes: [
                "Flaring the elbows to 90° — beats up the shoulders",
                "Bouncing the bar off the chest instead of a controlled touch",
                "Hips lifting off the bench to cheat the press",
                "Stopping short of lockout or half-repping the bottom"
            ]
        ),
        "incline bench press": Entry(
            cues: [
                "Bench at 30°-45° — higher hits more shoulder, less chest",
                "Bar lowers to the upper chest / collarbone line",
                "Shoulder blades set, elbows tucked under the bar",
                "Press up and slightly back, not straight out toward the ceiling"
            ],
            mistakes: [
                "Bench too steep — turns it into an overhead press",
                "Letting the elbows flare and the shoulders roll forward",
                "Bouncing the bar or losing the upper-back set"
            ]
        ),
        "dumbbell bench press": Entry(
            cues: [
                "Shoulder blades retracted, dumbbells stacked over the elbows",
                "Lower until the chest stretches — deeper range than a barbell",
                "Press up and slightly together without clanking the bells",
                "Wrists stacked straight over the elbows the whole way"
            ],
            mistakes: [
                "Dropping the elbows below the bench and straining the shoulders",
                "Pressing the dumbbells apart so the wrists bend back",
                "Losing the upper-back arch and rolling the shoulders forward"
            ]
        ),
        "chest fly": Entry(
            cues: [
                "Soft, fixed elbow bend held the entire set",
                "Open the arms in a wide arc, feel the chest stretch",
                "Squeeze the chest to bring the hands together over the sternum",
                "Shoulder blades stay back and down — don't shrug"
            ],
            mistakes: [
                "Bending and straightening the elbows — that's a press, not a fly",
                "Going so deep the shoulder takes the load instead of the chest",
                "Using momentum to swing the weights together"
            ]
        ),

        // ── Vertical push ────────────────────────────────────────────────
        "overhead press": Entry(
            cues: [
                "Brace the core and squeeze the glutes — ribs down, no big layback",
                "Bar starts on the front delts, travels straight over the mid-foot",
                "Move the head back to clear the bar, then push it through at the top",
                "Lock out with the bar stacked over the shoulders and ears"
            ],
            mistakes: [
                "Leaning back into a standing incline press",
                "Pressing the bar forward instead of straight up",
                "Flaring the elbows wide at the start",
                "Stopping short of a full overhead lockout"
            ]
        ),
        "dumbbell shoulder press": Entry(
            cues: [
                "Dumbbells start at ear height, elbows slightly in front of the body",
                "Brace the core so the lower back doesn't arch",
                "Press up and slightly together to a stacked lockout",
                "Control the dumbbells back down to ears — no free-fall"
            ],
            mistakes: [
                "Arching the lower back to heave the weight up",
                "Clanking the dumbbells together and losing tension",
                "Half-repping the bottom or not reaching lockout"
            ]
        ),
        "arnold press": Entry(
            cues: [
                "Start with palms facing you at chin height",
                "Rotate the palms forward as you press overhead",
                "Keep the core braced and ribs down through the rotation",
                "Reverse the rotation smoothly on the way down"
            ],
            mistakes: [
                "Rushing the rotation so the shoulders take a bad angle",
                "Leaning back to press heavier weight",
                "Letting the elbows drift behind the body at the bottom"
            ]
        ),
        "lateral raise": Entry(
            cues: [
                "Lead with the elbows, soft bend held constant",
                "Raise to about shoulder height — no higher",
                "Pour-the-water tilt so the side delt stays loaded",
                "Lower slowly under control, resist the drop"
            ],
            mistakes: [
                "Swinging the weight up with the lower back and traps",
                "Shrugging the shoulders toward the ears",
                "Going way above shoulder height and handing it to the traps"
            ]
        ),
        "rear delt fly": Entry(
            cues: [
                "Hinge forward, chest down, slight elbow bend",
                "Open the arms wide leading with the pinkies",
                "Squeeze the rear delts, not the mid-back",
                "Control the return — no momentum"
            ],
            mistakes: [
                "Turning it into a row by driving the elbows back and down",
                "Using the traps and lower back to swing the weight",
                "Going too heavy and losing the rear-delt focus"
            ]
        ),
        "face pull": Entry(
            cues: [
                "Rope at upper-chest / face height",
                "Pull toward the forehead, splitting the rope apart",
                "Elbows stay high, externally rotate at the end",
                "Squeeze the rear delts and mid-back, then control back out"
            ],
            mistakes: [
                "Pulling low into a row instead of up to the face",
                "Dropping the elbows so the lats take over",
                "Jerking the weight with the whole body"
            ]
        ),

        // ── Horizontal pull ──────────────────────────────────────────────
        "barbell row": Entry(
            cues: [
                "Hinge to ~45°, neutral spine, brace hard",
                "Pull the bar to the lower ribs / belly, driving the elbows back",
                "Squeeze the shoulder blades together at the top",
                "Lower under control — don't let the bar drop"
            ],
            mistakes: [
                "Standing up / heaving the bar with the lower back",
                "Rounding the back instead of holding the hinge",
                "Shrugging up instead of rowing back",
                "Using a huge range with a bouncing bottom"
            ]
        ),
        "dumbbell row": Entry(
            cues: [
                "Flat back, supported on a bench or your own knee",
                "Row the dumbbell to the hip, elbow driving past the ribs",
                "Squeeze the lat at the top, no torso twist",
                "Lower all the way to a full stretch under control"
            ],
            mistakes: [
                "Twisting the torso to throw the weight up",
                "Shrugging the shoulder toward the ear",
                "Half-repping instead of a full stretch at the bottom"
            ]
        ),
        "seated cable row": Entry(
            cues: [
                "Tall chest, slight forward lean to start the stretch",
                "Pull to the belly, elbows close, blades squeezing together",
                "Stay upright — don't rock back and forth",
                "Control the stretch forward without rounding"
            ],
            mistakes: [
                "Using the lower back to rock the weight in and out",
                "Rounding the upper back at the stretch",
                "Shrugging instead of driving the elbows back"
            ]
        ),

        // ── Vertical pull ────────────────────────────────────────────────
        "lat pulldown": Entry(
            cues: [
                "Set the shoulders down first, chest up, slight lean back",
                "Pull the bar to the upper chest leading with the elbows",
                "Squeeze the lats at the bottom, no big body swing",
                "Control the bar all the way up to a full stretch"
            ],
            mistakes: [
                "Swinging the torso to muscle the bar down",
                "Pulling behind the neck — bad for the shoulders",
                "Shrugging up at the stretch instead of staying long"
            ]
        ),

        // ── Squat / quad ─────────────────────────────────────────────────
        "back squat": Entry(
            cues: [
                "Brace the core hard before you unrack — big belly breath",
                "Knees track over the toes, push them out on the way down",
                "Sink to at least parallel with the hips below the knee crease",
                "Drive through the whole foot and stand tall at the top"
            ],
            mistakes: [
                "Knees caving inward under load",
                "Heels rising / weight shifting onto the toes",
                "Cutting depth and quarter-squatting heavy weight",
                "Rounding the lower back at the bottom"
            ]
        ),
        "front squat": Entry(
            cues: [
                "Elbows high, bar resting on the front delts, not the wrists",
                "Stay upright — chest tall through the whole rep",
                "Brace and sink straight down to depth",
                "Drive up keeping the elbows high so the bar doesn't dump"
            ],
            mistakes: [
                "Letting the elbows drop so the chest collapses forward",
                "Coming up hips-first into a good-morning",
                "Cutting depth because the upright position feels hard"
            ]
        ),
        "goblet squat": Entry(
            cues: [
                "Hold the weight at the chest, elbows tucked",
                "Sit straight down between the hips, chest tall",
                "Elbows brush the inside of the knees at the bottom",
                "Drive through the heels to stand"
            ],
            mistakes: [
                "Leaning forward and letting the weight pull you down",
                "Heels lifting at the bottom",
                "Rounding the back instead of staying braced"
            ]
        ),
        "leg press": Entry(
            cues: [
                "Feet mid-platform, shoulder-width, full foot pressing",
                "Lower until the knees reach ~90° without the hips rounding",
                "Push through the heels, don't lock the knees hard",
                "Keep the lower back flat against the pad"
            ],
            mistakes: [
                "Going so deep the hips round and lift off the pad",
                "Slamming the knees into lockout",
                "Letting the knees cave inward on the press"
            ]
        ),
        "leg extension": Entry(
            cues: [
                "Pad sits on the lower shin, not the ankle",
                "Extend to straight and pause briefly to squeeze the quad",
                "Lower slowly — resist the weight on the way down",
                "Keep the hips and back settled in the seat"
            ],
            mistakes: [
                "Swinging / kicking the weight up with momentum",
                "Lifting the hips off the seat to move more weight",
                "Cutting the lockout squeeze short"
            ]
        ),
        "walking lunge": Entry(
            cues: [
                "Long step, torso tall, brace the core",
                "Drop the back knee toward the floor under control",
                "Front shin stays roughly vertical, knee over the foot",
                "Drive through the front heel to step through"
            ],
            mistakes: [
                "Short steps that push the knee way past the toes",
                "Letting the front knee cave inward",
                "Leaning the torso forward and losing the brace"
            ]
        ),

        // ── Hinge / posterior ────────────────────────────────────────────
        "deadlift": Entry(
            cues: [
                "Bar over mid-foot, shins close, brace the core hard",
                "Take the slack out, then push the floor away with the legs",
                "Keep the bar dragging up the legs, lats tight",
                "Stand tall — hips and shoulders rise together"
            ],
            mistakes: [
                "Rounding the lower back instead of bracing neutral",
                "Hips shooting up first so it becomes a stiff-leg pull",
                "Jerking the bar off the floor instead of a smooth pull",
                "The bar drifting out in front of the shins"
            ]
        ),
        "trap bar deadlift": Entry(
            cues: [
                "Stand in the center, chest up, brace the core",
                "Push the floor away through the whole foot",
                "Hips and shoulders rise together to a tall lockout",
                "Control the descent — don't drop it from the top"
            ],
            mistakes: [
                "Squatting it down too low so the hips drop under the handles",
                "Rounding the back on the way up",
                "Yanking the weight instead of a smooth pull"
            ]
        ),
        "romanian deadlift": Entry(
            cues: [
                "Soft knees, push the hips straight back",
                "Bar drags down the thighs, back stays flat",
                "Feel the hamstrings stretch — stop when the back wants to round",
                "Drive the hips forward to stand, squeeze the glutes at the top"
            ],
            mistakes: [
                "Turning it into a squat by bending the knees too much",
                "Rounding the lower back chasing extra range",
                "Hyperextending and leaning back at the top",
                "Letting the bar drift away from the legs"
            ]
        ),
        "dumbbell romanian deadlift": Entry(
            cues: [
                "Soft knees, hinge the hips back with the dumbbells close",
                "Back flat, dumbbells track down the front of the legs",
                "Stretch the hamstrings, then drive the hips forward",
                "Stand tall and squeeze the glutes — don't lean back"
            ],
            mistakes: [
                "Bending the knees so it becomes a squat",
                "Rounding the back to reach lower",
                "Letting the dumbbells drift forward away from the legs"
            ]
        ),
        "hip thrust": Entry(
            cues: [
                "Upper back on the bench, chin tucked, ribs down",
                "Drive through the heels and squeeze the glutes to lockout",
                "Shins vertical at the top, body in a flat tabletop",
                "Lower under control without dumping the hips"
            ],
            mistakes: [
                "Overarching the lower back instead of squeezing the glutes",
                "Pushing through the toes so the quads take over",
                "Short range — not reaching a full hip lockout"
            ]
        ),

        // ── Arms ─────────────────────────────────────────────────────────
        "dumbbell curl": Entry(
            cues: [
                "Elbows pinned at the sides, shoulders still",
                "Curl up with a full squeeze, supinate the wrist",
                "Lower all the way to a straight arm under control",
                "No swinging — the upper arm stays put"
            ],
            mistakes: [
                "Swinging the torso and using momentum",
                "Letting the elbows drift forward to cheat the top",
                "Half-repping instead of fully straightening at the bottom"
            ]
        ),
        "barbell curl": Entry(
            cues: [
                "Elbows pinned to the sides, brace the core",
                "Curl the bar with control, squeeze at the top",
                "Lower to a full stretch — straight arms",
                "Keep the wrists neutral, not cranked back"
            ],
            mistakes: [
                "Heaving the bar up with the lower back",
                "Letting the elbows swing forward at the top",
                "Bouncing out of the bottom instead of controlling it"
            ]
        ),
        "hammer curl": Entry(
            cues: [
                "Neutral grip — thumbs up the whole rep",
                "Elbows pinned, curl up and squeeze",
                "Lower slowly to straight arms",
                "Keep the shoulders quiet, no swinging"
            ],
            mistakes: [
                "Swinging the dumbbells with body english",
                "Letting the elbows travel forward",
                "Cutting the bottom stretch short"
            ]
        ),
        "tricep pushdown": Entry(
            cues: [
                "Elbows pinned at the sides, slight forward lean",
                "Push down to a full lockout, squeeze the triceps",
                "Control the weight back up to ~90° at the elbow",
                "Keep the shoulders down, no shrugging"
            ],
            mistakes: [
                "Letting the elbows flare out and drift forward",
                "Using the shoulders and bodyweight to push the weight",
                "Half-repping instead of a full lockout"
            ]
        ),
        "skull crusher": Entry(
            cues: [
                "Upper arms vertical, elbows pointing at the ceiling",
                "Lower the bar to the forehead / just behind the head",
                "Extend with the triceps, elbows staying put",
                "Control the eccentric — don't drop it at your face"
            ],
            mistakes: [
                "Letting the elbows flare wide and drift",
                "Turning it into a press by moving the upper arms",
                "Going too heavy and losing control near the head"
            ]
        ),
        "shrug": Entry(
            cues: [
                "Stand tall, arms straight, brace the core",
                "Shrug the shoulders straight up toward the ears",
                "Pause and squeeze the traps at the top",
                "Lower under control to a full stretch"
            ],
            mistakes: [
                "Rolling the shoulders instead of shrugging straight up",
                "Bending the elbows to turn it into a row",
                "Bouncing with the knees to heave the weight"
            ]
        ),

        // ── Calves ───────────────────────────────────────────────────────
        "calf raise": Entry(
            cues: [
                "Press up onto the balls of the feet to a full point",
                "Pause and squeeze the calves at the top",
                "Lower slowly to a deep stretch below the step",
                "Keep the knees mostly straight for the gastroc"
            ],
            mistakes: [
                "Bouncing with a tiny range of motion",
                "Skipping the bottom stretch",
                "Rushing the reps with no top squeeze"
            ]
        )
    ]

    // MARK: - Pattern fallback (by MovementSlot)

    private static let patternFallback: [MovementSlot: Entry] = [
        .squat: Entry(
            cues: [
                "Brace the core before you descend",
                "Knees track over the toes — push them out",
                "Hit honest depth, then drive through the whole foot",
                "Stand tall and controlled at the top"
            ],
            mistakes: [
                "Knees caving inward under load",
                "Heels lifting / shifting onto the toes",
                "Cutting depth on heavier sets"
            ]
        ),
        .hinge: Entry(
            cues: [
                "Push the hips back, keep the back flat",
                "Brace hard — neutral spine, not rounded",
                "Feel the hamstrings load, then drive the hips forward",
                "Lock out tall, squeeze the glutes"
            ],
            mistakes: [
                "Rounding the lower back",
                "Squatting it instead of hinging at the hips",
                "Hyperextending and leaning back at the top"
            ]
        ),
        .horizontalPush: Entry(
            cues: [
                "Set the shoulder blades back and down",
                "Elbows tucked ~45°, forearms stacked vertical",
                "Control the eccentric, no bouncing",
                "Press to a full lockout"
            ],
            mistakes: [
                "Flaring the elbows wide",
                "Bouncing the weight out of the bottom",
                "Stopping short of lockout"
            ]
        ),
        .verticalPush: Entry(
            cues: [
                "Brace the core, keep the ribs down",
                "Press straight up, weight stacking over the shoulders",
                "Lock out fully overhead",
                "Control the weight back down"
            ],
            mistakes: [
                "Leaning back into a standing incline press",
                "Pressing forward instead of straight up",
                "Half-repping the lockout"
            ]
        ),
        .horizontalPull: Entry(
            cues: [
                "Set a stable position and brace",
                "Drive the elbows back, squeeze the shoulder blades",
                "Pull to the torso, then control the stretch",
                "Stay tight — don't heave with the lower back"
            ],
            mistakes: [
                "Using momentum / body english to move the weight",
                "Shrugging instead of rowing back",
                "Rounding the back at the stretch"
            ]
        ),
        .verticalPull: Entry(
            cues: [
                "Set the shoulders down first",
                "Lead with the elbows, pull to the upper chest",
                "Squeeze the lats, then control the full stretch up",
                "Minimise body swing"
            ],
            mistakes: [
                "Swinging the torso to muscle the weight",
                "Shrugging up at the stretch",
                "Cutting the range short"
            ]
        ),
        .arms: Entry(
            cues: [
                "Pin the elbows and keep the upper arm still",
                "Move through a full range with control",
                "Squeeze hard at peak contraction",
                "Resist the weight on the way back"
            ],
            mistakes: [
                "Swinging with the torso for momentum",
                "Letting the elbows drift to cheat the rep",
                "Half-repping instead of full range"
            ]
        ),
        .core: Entry(
            cues: [
                "Brace as if about to take a punch",
                "Move slowly and deliberately — no momentum",
                "Keep the lower back controlled, ribs down",
                "Exhale and squeeze through the hardest part"
            ],
            mistakes: [
                "Yanking with the hip flexors instead of the abs",
                "Holding the breath and bearing down",
                "Letting the lower back arch off under load"
            ]
        ),
        .calves: Entry(
            cues: [
                "Press to a full point on the balls of the feet",
                "Squeeze at the top",
                "Lower to a deep stretch under control",
                "Full range every rep"
            ],
            mistakes: [
                "Bouncing with a short range",
                "Skipping the bottom stretch",
                "Rushing with no top squeeze"
            ]
        )
    ]
}
