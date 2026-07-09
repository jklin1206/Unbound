import Foundation

// Associated metadata: substitution groups, skill associations,
// contraindication tags, logger mode/metric, and logging aliases.
extension MovementCatalog {
    static func substitutionGroup(for exercise: CatalogExercise) -> String {
        let slot = movementSlot(for: exercise).rawValue
        let template = rankTemplate(for: exercise).rawValue
        return "\(slot).\(template)"
    }

    static func skillAssociations(for exercise: CatalogExercise) -> [String] {
        let name = normalized(exercise.name)
        var skills: Set<String> = []
        let verticalPullSkillNames: Set<String> = [
            "negative pullup", "assisted pullup band", "assisted pullup machine",
            "chin up", "pullup", "wide grip pullup", "weighted pullup", "chest to bar pullup",
            "lat pulldown neutral", "wide grip lat pulldown", "close grip lat pulldown",
            "reverse grip lat pulldown", "lat pulldown", "single arm pulldown"
        ]
        if verticalPullSkillNames.contains(name) {
            skills.formUnion(["pp.pullup", "pp.strict-pullup"])
        }
        if name == "dip" || name == "straight bar dip" {
            skills.insert("pp.muscle-up")
        }
        if name.contains("pike") || name.contains("handstand") || name.contains("overhead press") {
            skills.formUnion(["hs.wall-handstand-30", "cal.handstand-pushup"])
        }
        if name.contains("pushup") || name.contains("bench") || name.contains("chest press") {
            skills.insert("cal.pushup")
        }
        if name == "assisted squat" || name == "parallel squat" || name == "bodyweight squat" || name == "cossack squat" {
            skills.insert("ld.deep-squat")
        }
        if name.contains("step up") {
            skills.insert("ld.step-up")
        }
        if name.contains("bulgarian split squat") {
            skills.formUnion(["ld.bulgarian-split-squat", "ld.pistol-squat"])
        } else if name.contains("split squat") {
            skills.formUnion(["ld.split-squat", "ld.pistol-squat"])
        }
        if name.contains("weighted pistol") {
            skills.insert("ld.weighted-pistol")
        } else if name.contains("pistol") {
            skills.insert("ld.pistol-squat")
        }
        if name.contains("shrimp") {
            skills.insert("ld.shrimp-squat")
        }
        if name.contains("nordic") || name.contains("leg curl") {
            skills.insert("ld.nordic-curl")
        }
        if name == "bodyweight leg extension" {
            skills.insert("ld.leg-extensions")
        }
        if name.contains("plank") || name.contains("hollow") || name.contains("leg raise") || name.contains("knee raise") || name.contains("situp") {
            skills.insert("cl.hollow-body-30")
        }
        return skills.sorted()
    }

    static func contraindicationTags(for exercise: CatalogExercise) -> [String] {
        let name = normalized(exercise.displayName + " " + exercise.name)
        var tags: Set<String> = []
        if name.contains("squat") || name.contains("lunge") || name.contains("leg press") || name.contains("step up") || name.contains("pistol") {
            tags.insert("knee-sensitive")
        }
        if name.contains("deadlift") || name.contains("good morning") || name.contains("row") || name.contains("back extension") {
            tags.insert("low-back-sensitive")
        }
        if name.contains("overhead") || name.contains("dip") || name.contains("handstand") || name.contains("upright row") || name.contains("pullover") {
            tags.insert("shoulder-sensitive")
        }
        if name.contains("wrist") || name.contains("pushup") || name.contains("planche") {
            tags.insert("wrist-sensitive")
        }
        return tags.sorted()
    }

    static func loggerMode(for exercise: CatalogExercise) -> MovementLoggerMode {
        if rankTemplate(for: exercise) == .holdControl {
            return .hold
        }
        return blockKind(for: exercise) == .bodyweight ? .bodyweightSets : .strengthSets
    }

    static func defaultMetric(for exercise: CatalogExercise) -> TrainingMetricKind {
        loggerMode(for: exercise) == .hold ? .holdSeconds : .reps
    }

    static func exerciseAliases(for exercise: CatalogExercise) -> [String] {
        var aliases = [exercise.displayName, exercise.name]
        switch exercise.name {
        case "negative pullup":
            aliases += ["negative pull-up", "tempo negative pull-up", "eccentric pull-up", "pull-up negative"]
        case "assisted pullup (band)":
            aliases += ["band-assisted pull-up", "band assisted pull up", "assisted pull-up band", "assisted pull-up (band)", "banded pull-up"]
        case "assisted pullup machine":
            aliases += ["assisted pull-up machine", "machine assisted pull-up"]
        case "pullup":
            aliases += ["pull-up", "pull up", "strict pull-up", "strict pullup", "tempo pull-up"]
        case "chin up":
            aliases += ["chin-up", "strict chin-up", "weighted chin-up"]
        case "pushup":
            aliases += ["push-up", "push ups", "push-ups", "strict push-up", "tempo push-up"]
        case "pike pushup":
            aliases += ["pike push-up", "pike push ups", "pike hold"]
        case "bent-over row":
            // "Barbell row" is the canonical horizontal-pull family name
            // (StrengthStandards); without this alias a logged "barbell row"
            // falls through name resolution to the cardio "row" inference and
            // earns cardio attribute weights instead of the heavy-row vector.
            aliases += ["barbell row"]
        case "inverted row":
            aliases += ["australian row", "ring row", "bodyweight row"]
        case "cable row (seated)":
            aliases += ["cable row", "seated row", "seated cable row"]
        case "band row":
            aliases += ["banded row", "light band row", "band row prep"]
        case "band lat pull":
            aliases += ["band lat pulldown", "band pulldown", "banded lat pulldown"]
        case "hanging knee raise":
            aliases += ["captain chair knee raise", "captain's chair knee raise"]
        case "hanging leg raise":
            aliases += ["captain chair leg raise", "captain's chair leg raise"]
        case "bodyweight squat":
            aliases += ["full squat", "air squat", "strict squat"]
        case "assisted squat":
            aliases += ["supported squat"]
        case "parallel squat":
            aliases += ["squat to parallel"]
        case "split squat":
            aliases += ["stationary lunge"]
        case "deep step up":
            aliases += ["high step up", "deep step-up", "high step-up"]
        case "partial pistol squat":
            aliases += ["box pistol", "box pistol squat", "partial pistol"]
        case "assisted pistol squat":
            aliases += ["pistol squat assisted", "supported pistol squat"]
        case "weighted pistol":
            aliases += ["weighted pistol squat", "loaded pistol squat"]
        case "beginner shrimp squat":
            aliases += ["beginner shrimp"]
        case "intermediate shrimp squat":
            aliases += ["int shrimp squat", "intermediate shrimp", "int shrimp"]
        case "two-hand shrimp squat":
            aliases += ["2-hand shrimp squat", "two hand shrimp squat", "2h shrimp squat"]
        case "elevated two-hand shrimp squat":
            aliases += ["elevated 2-hand shrimp squat", "elevated 2h shrimp squat", "deficit two-hand shrimp squat"]
        case "nordic curl negative":
            aliases += ["nordic negative", "negative nordic curl", "eccentric nordic curl"]
        case "nordic curl arms overhead":
            aliases += ["arms-overhead nordic curl", "overhead nordic curl"]
        case "tuck one-leg nordic curl":
            aliases += ["tuck one leg nordic curl", "tuck single-leg nordic curl"]
        case "one-leg nordic curl":
            aliases += ["one leg nordic curl", "single-leg nordic curl", "single leg nordic curl"]
        case "bodyweight leg extension":
            aliases += ["bodyweight leg extensions", "reverse nordic", "reverse-nordic", "reverse nordic curl", "kneeling leg extension"]
        case "plank":
            aliases += ["plank hold", "plank max hold"]
        case "face pull":
            aliases += ["face pulls", "cable face pull"]
        case "band face pull":
            aliases += ["band face pulls", "banded face pull"]
        case "machine chest press":
            aliases += ["plate loaded chest press", "hammer strength chest press", "converging chest press"]
        case "machine row":
            aliases += ["plate loaded row", "hammer strength row", "hammer strength low row"]
        case "seated machine press":
            aliases += ["plate loaded shoulder press"]
        default:
            break
        }
        return Array(Set(aliases))
    }
}
