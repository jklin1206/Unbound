import Foundation

// Per-exercise classification traits derived from the exercise name:
// block kind, rank template, equipment, difficulty.
extension MovementCatalog {
    static func blockKind(for exercise: CatalogExercise) -> TrainingBlockKind {
        let name = normalized(exercise.name)
        let bodyweightNames: Set<String> = [
            "incline pushup", "pushup", "diamond pushup", "decline pushup",
            "pseudo planche pushup", "archer pushup", "pike pushup", "wall handstand pushup",
            "negative pullup", "assisted pullup band", "assisted pullup machine",
            "chin up", "pullup", "wide grip pullup", "neutral grip pullup", "weighted pullup", "chest to bar pullup",
            "straight bar dip", "dip", "bench dip",
            "banded muscle up", "low bar muscle up transition", "assisted turnover freeze", "muscle up",
            "plank", "high plank", "hollow hold", "l sit tucked", "l sit", "tuck front lever",
            "advanced tuck front lever", "dragon flag", "hanging knee raise", "hanging leg raise",
            "captains chair knee raise", "captains chair leg raise", "bodyweight squat",
            "assisted squat", "parallel squat", "split squat", "walking lunge", "step up",
            "deep step up", "cossack squat", "partial pistol squat", "assisted pistol squat",
            "pistol squat", "weighted pistol", "assisted shrimp squat", "beginner shrimp squat",
            // Entries are compared against `normalized(...)` output, which
            // turns every non-alphanumeric into a space — so keys here must be
            // space-separated ("two hand", not "two-hand") or they never match.
            "intermediate shrimp squat", "shrimp squat", "two hand shrimp squat",
            "elevated two hand shrimp squat", "nordic curl negative", "nordic curl",
            "nordic curl arms overhead", "tuck one leg nordic curl", "one leg nordic curl",
            "superman pull",
            "bodyweight leg extension", "glute bridge", "inverted row", "prone shoulder raise", "ab wheel", "decline situp", "roman chair situp",
            "hollow rock", "jump squat",
            // Core work is logged as reps/holds, never as load.
            "side plank", "crunch", "situp", "bicycle crunch", "russian twist", "v up",
            "flutter kick", "dead bug", "bird dog", "mountain climber", "toes to bar",
            "sissy squat", "neutral grip pullup"
            // NB: the lunges are deliberately NOT here. Like "walking lunge" they
            // stay .strength so they can be logged with dumbbells; their equipment
            // still falls back to .bodyweight, so a floor-only user keeps them.
        ]
        if bodyweightNames.contains(name) {
            return .bodyweight
        }
        return .strength
    }

    static func rankTemplate(for exercise: CatalogExercise) -> MovementRankTemplate {
        let name = normalized(exercise.name)
        let display = normalized(exercise.displayName)
        if display.contains("weighted") || name.contains("weighted") {
            return .weightedBodyweight
        }
        if name == "hollow rock" {
            return .bodyweightReps
        }
        let bodyweightRepControlNames: Set<String> = [
            "dragon flag", "hanging knee raise", "hanging leg raise",
            "captains chair knee raise", "captains chair leg raise"
        ]
        if bodyweightRepControlNames.contains(name) {
            return .bodyweightReps
        }
        let holdControlNames: Set<String> = [
            "plank", "hollow hold", "l sit tucked", "l sit", "tuck front lever",
            "advanced tuck front lever"
        ]
        if display.contains("plank") || display.contains("hold") || display.contains("hollow") || holdControlNames.contains(name) || (display.contains("hang") && !bodyweightRepControlNames.contains(name)) {
            return .holdControl
        }
        if blockKind(for: exercise) == .bodyweight {
            return .bodyweightReps
        }
        if equipment(for: exercise).contains(where: { [.machine, .cable, .smithMachine].contains($0) }) {
            return .machineStrength
        }
        return .barbellStrength
    }

    static func equipment(for exercise: CatalogExercise) -> [MovementEquipment] {
        let name = normalized(exercise.displayName + " " + exercise.name)
        var equipment: Set<MovementEquipment> = []
        let isDumbbellVariant = name.contains("dumbbell")
        let isKettlebellVariant = name.contains("kettlebell")
        let isBandVariant = name.contains("band")
        let isMachineVariant = name.contains("machine")
            || name.contains("smith")
            || name.contains("cable")
            || name.contains("belt squat")
            || name.contains("plate loaded")
            || name.contains("hammer strength")
        let isBodyweightLegExtension = name.contains("bodyweight leg extension")
            || name.contains("reverse nordic")

        if name.contains("smith") { equipment.insert(.smithMachine) }
        if !isBandVariant,
           name.contains("barbell") || name.contains("safety bar") || name.contains("trap bar") || name.contains("back squat") || name.contains("front squat") || name.contains("good morning") || name.contains("landmine") || name.contains("t bar row") || name.contains("meadows") || name.contains("pendlay") || name.contains("drag curl")
            // Bar lifts whose common name never says "barbell". Without these the
            // equipment set comes back EMPTY and the movement falls through to
            // `.bodyweight` — a Power Clean offered to someone with no equipment.
            || name.contains("clean") || name.contains("snatch") || name.contains("jerk") || name.contains("thruster")
            || name.contains("rack pull") || name.contains("high pull") || name.contains("zercher")
            || name.contains("box squat") || name.contains("front rack") || name.contains("seal row") || name.contains("yates") {
            equipment.insert(.barbell)
        }
        if !isDumbbellVariant,
           !isKettlebellVariant,
           !isBandVariant,
           !isMachineVariant,
           name.contains("deadlift") || name.contains("bench press") || name.contains("overhead press") || name.contains("hip thrust") {
            equipment.insert(.barbell)
        }
        // Skull crushers and preacher curls exist in both barbell/EZ-bar and
        // dumbbell forms — only claim the bar when the name isn't a dumbbell variant.
        if name.contains("ez bar") || (name.contains("skull crusher") && !isDumbbellVariant) { equipment.insert(.barbell) }
        if name.contains("upright row"), !isDumbbellVariant, !isBandVariant { equipment.insert(.barbell) }
        // "fly" and "lateral raise" name a PATTERN, not an implement — they exist
        // in dumbbell, cable and machine forms. Claiming the dumbbell
        // unconditionally made a Cable Fly require dumbbells too, which hid every
        // cable/machine fly and raise from a gym that has no free weights.
        if name.contains("dumbbell") || name.contains("arnold press") || name.contains("goblet") || (name.contains("hammer curl") && !name.contains("rope")) || name.contains("zottman curl") || ((name.contains("lateral raise") || name.contains("fly")) && !isMachineVariant) || name.contains("weighted pistol") || name.contains("concentration curl") || name.contains("spider curl") || name.contains("chest supported row") || name.contains("single leg rdl") { equipment.insert(.dumbbell) }
        if name.contains("weighted pistol") || name.contains("goblet") { equipment.insert(.kettlebell) }
        if name.contains("kettlebell") { equipment.insert(.kettlebell) }
        if !isBandVariant,
           name.contains("cable") || name.contains("pulldown") || name.contains("pushdown") || name.contains("face pull") || name.contains("pallof") || name.contains("rope") {
            equipment.insert(.cable)
        }
        if name.contains("machine") || name.contains("belt squat") || name.contains("plate loaded") || name.contains("hammer strength") || name.contains("converging") || name.contains("leg press") || name.contains("hack squat") || name.contains("pendulum") || name.contains("v squat") || name.contains("pec deck") || name.contains("leg curl") || (!isBodyweightLegExtension && name.contains("leg extension")) || name.contains("reverse hyper") || name.contains("glute ham") || name.contains("captain") || name.contains("standing calf raise") || name.contains("seated calf raise") || name.contains("donkey calf raise") { equipment.insert(.machine) }
        if name.contains("back extension") || name.contains("roman chair") || name.contains("skull crusher") || name.contains("spider curl") { equipment.insert(.bench) }
        if name.contains("pullup") || name.contains("chin up") || name.contains("hanging") || name.contains("toes to bar") { equipment.insert(.pullupBar) }
        if name.contains("ab wheel") { equipment.insert(.mobilityTool) }
        if name.contains("dip") { equipment.insert(.dipStation) }
        if name.contains("ring") { equipment.insert(.rings) }
        if name.contains("bench") || name.contains("incline") || name.contains("decline") || name.contains("chest supported") { equipment.insert(.bench) }
        if name.contains("box") || name.contains("step up") { equipment.insert(.box) }
        if name.contains("parallette") { equipment.insert(.parallettes) }
        if name.contains("band") { equipment.insert(.band) }

        if equipment.isEmpty || blockKind(for: exercise) == .bodyweight {
            equipment.insert(.bodyweight)
        }

        return equipment.sorted { $0.rawValue < $1.rawValue }
    }

    static func difficulty(for exercise: CatalogExercise) -> MovementDifficulty {
        let normalizedName = normalized(exercise.name)
        if normalizedName == "bodyweight leg extension" {
            return .intermediate
        }
        if normalizedName == "jump squat" {
            return .intermediate
        }

        // Advanced-skill names floor at .advanced regardless of progression
        // tier: a tier-1 "Wall Handstand Push-Up" is still a handstand, and a
        // low family tier must never hand levers/planche work to beginners.
        let name = normalized(exercise.displayName + " " + exercise.name)
        // Olympic lifts are technical, not "easy because the name has no keyword".
        // Left at the default they scored as BEGINNER barbell work, which let a
        // Power Clean out-rank a Back Squat as a novice's primary lift.
        // Olympic lifts, plus the heavy partials/pulls. `.intermediate` is not
        // enough: it scores a Rack Pull DEAD LEVEL with the deadlift (both -15 in
        // freeWeights), so the tiebreak alone decided whether a novice's hinge day
        // was anchored by a full deadlift or a partial. These sit behind the staple.
        if name.contains("clean") || name.contains("snatch") || name.contains("jerk") || name.contains("thruster")
            || name.contains("rack pull") || name.contains("high pull") {
            return .advanced
        }
        if name.contains("one arm") || name.contains("one-leg") || name.contains("planche") || name.contains("nordic") || name.contains("pistol") || name.contains("shrimp") || name.contains("handstand") || name.contains("front lever") || name.contains("back lever") {
            return .advanced
        }

        if let tier = exercise.progressionTier {
            switch tier {
            case ..<2: return .beginner
            case 2...4: return .intermediate
            case 5...6: return .advanced
            default: return .elite
            }
        }

        // Heavy bar lifts whose name never says "barbell" — same trap as above:
        // a Rack Pull left at .beginner scores BELOW a deadlift and would be
        // chosen as a novice's primary hinge.
        if name.contains("deadlift") || name.contains("barbell") || name.contains("front squat") || name.contains("overhead press") || name.contains("dip") || name.contains("pullup")
            || name.contains("zercher") || name.contains("box squat") || name.contains("front rack")
            || name.contains("sumo") || name.contains("seal row") || name.contains("yates") || name.contains("sissy") {
            return .intermediate
        }
        return .beginner
    }
}
