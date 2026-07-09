import Foundation
@testable import UNBOUND

// MARK: - GateKeyPacingModel
//
// The human-performance model behind the gate-key pacing simulation
// (GateKeyPacingSimulator). This file is the DESIGNER-FACING half: every
// constant that shapes the curves is a named parameter here with a doc
// comment, so gate keys can be retuned against believable user timelines
// without touching the engine.
//
// What the model does NOT do: it never invents its own rank thresholds. All
// tier boundaries are read from the app's real tables at runtime —
// `StrengthStandards.ratio(exerciseKey:tier:sex:)` for loads (compounds,
// accessory families, weighted pull-up) and each skill node's generated
// `tierCriteria` (SkillGraph) for bodyweight reps/holds. The model only
// supplies the TIMING: how many months of realistic training it takes an
// average dedicated trainee to reach each of those anchors.

/// One tunable knob-set for the whole simulation. `.default` is the
/// calibrated baseline; tests may override fields for what-if runs.
struct GateKeyPacingTuning {

    // MARK: Session cadence and XP

    /// Average overall AP per completed session. Matches the
    /// `OverallLevelCurve` calibration comment (2026-06-18 year-sim: ~416
    /// AP/session average across the 7 personas; L90 ≈ 312 sessions ≈ 18
    /// months at 4x/week). Overall level in this sim is
    /// `OverallLevelCurve.level(forXP: sessions * sessionAP)`.
    var sessionAP: Double = 416

    /// Average weeks per month (365.25 / 12 / 7).
    var weeksPerMonth: Double = 4.345

    /// Fraction of scheduled sessions a persona actually completes, by the
    /// year-sim adherence profile. Multiplies both XP accrual and
    /// training-age accrual (missed sessions neither level you nor make you
    /// stronger).
    var adherenceRate: [YearAdherenceProfile: Double] = [
        .steady: 0.90,
        .aggressive: 0.95,
        .inconsistent: 0.65,
        .stressed: 0.80
    ]

    // MARK: Training age (performance head start)

    /// Months of effective prior training the persona walks in with, by
    /// onboarding experience. This shifts PERFORMANCE only — overall level
    /// and attribute XP always start at zero (level is time-in-app), which
    /// is exactly the tension this harness studies: a strong new user's
    /// movement keys can turn long before the level floor does.
    var experienceHeadStartMonths: [Experience: Double] = [
        .never: 0,
        .tried: 4,
        .used: 9,
        .current: 24
    ]

    /// Training-age accrual rate per calendar month by how much of the
    /// persona's week a movement occupies. Spec: frequently trained
    /// movements progress ~20-30% faster; rarely touched ones slower.
    var emphasisAgeRate: [PacingEmphasis: Double] = [
        .primary: 1.25,
        .secondary: 1.0,
        .occasional: 0.70
    ]

    /// Relative share of session AP each movement soaks up, by emphasis
    /// (normalized across the persona's movement set before use). Stands in
    /// for AttributeIngest's per-entry effort-mass share.
    var emphasisAPWeight: [PacingEmphasis: Double] = [
        .primary: 2.0,
        .secondary: 1.0,
        .occasional: 0.5
    ]

    // MARK: Lift progression milestones (training-age months → ratio anchors)
    //
    // Real-world timing for a dedicated average male trainee on a
    // bodyweight-ratio lift, anchored to the app's own band ordinals
    // (Novice=1, Forged=3, Master=5, Vessel=6, Ascendant=7; the 5-band
    // StrengthLevel arrays map Beginner/Novice/Intermediate/Advanced/Elite
    // to ordinals 1/3/5/7/8, with 2/4/6 interpolated). Spec anchors:
    // Intermediate (=Master) at month 12-18, Advanced (=Ascendant) around
    // year 4-6, Vessel (the interpolated midpoint anchor in the app's
    // tables) roughly month 24-36. Veteran (interpolated ordinal 4) sits
    // between Forged and Master.
    var liftMilestoneMonths: [RankTier: Double] = [
        .novice: 2,
        .forged: 7,
        .veteran: 10,
        .master: 14,
        .vessel: 30,
        .ascendant: 60
    ]

    // MARK: Bodyweight skill progression milestones
    //
    // Rep-max / hold-max growth for bodyweight skills: fast early, long
    // taper. Spec anchors: Master rep anchor (e.g. 40 pushups / 13 pullups)
    // around month 8-14, Vessel ~16-26, Ascendant (index 3, e.g. 64
    // pushups) ~30-48. Veteran is the interpolated rung between Forged and
    // Master (also keeps sparse variant ladders like nordic curl anchored).
    var skillMilestoneMonths: [RankTier: Double] = [
        .novice: 1,
        .forged: 5,
        .veteran: 8,
        .master: 11,
        .vessel: 21,
        .ascendant: 38
    ]

    /// Extra months added to every milestone of a "feat" skill — a node
    /// whose generated ladder has no Novice criterion (handstand pushup,
    /// tuck planche, ...: the first clean rep/hold is already a mid-ladder
    /// rank). Reflects the long skill-acquisition runway before rep 1.
    var featDelayMonths: Double = 12

    /// Day-zero performance as a fraction of the first available anchor
    /// (mirrors StrengthStandards' initiate ramp, which starts at half the
    /// Novice anchor). Applied only when the ladder has a Novice rung;
    /// feat skills start from zero.
    var startFractionOfFirstAnchor: Double = 0.5

    // MARK: Attribute fan-out

    /// Fallback attribute vector for a SKILL movement whose exercise name
    /// has no row in AttributeContributions.json (e.g. dead hang, wall
    /// handstand). Control-dominant, mirroring the catalog's other
    /// isometric/skill rows.
    var defaultSkillAttributeVector: [AttributeKey: Double] = [
        .control: 0.70, .power: 0.20, .mobility: 0.10
    ]

    /// Fallback attribute vector for a LIFT with no catalog row. Power
    /// dominant, mirroring the catalog's compound rows.
    var defaultLiftAttributeVector: [AttributeKey: Double] = [
        .power: 0.85, .explosiveness: 0.15
    ]

    // MARK: Output grid

    /// Candidate `movementsAtRank` gate keys to sweep: every (count, rank)
    /// pair under both pool definitions, reported as the month each would
    /// first be satisfied. Includes the shipped ladder's top-gate counts
    /// (4 / 5 / 6 as of the 2026-07-09 retune).
    var candidateCounts: [Int] = [4, 5, 6, 8, 10]
    var candidateRanks: [RankTier] = [.master, .vessel, .ascendant]

    /// Attribute ranks whose ">= rank" axis counts are emitted per month.
    var reportedAttributeRanks: [RankTier] = [.veteran, .master, .vessel]

    /// Movement ranks whose ">= rank" pool counts are emitted per month.
    var reportedMovementRanks: [RankTier] = [.master, .vessel, .ascendant]

    /// Sentinel month for "never turned within the simulated horizon".
    var neverMonth: Int = 999

    static let `default` = GateKeyPacingTuning()
}

// MARK: - Movement + persona specs

/// How much of the persona's training week a movement occupies.
enum PacingEmphasis: String, CaseIterable {
    case primary      // a staple, trained ~2+ times/week
    case secondary    // regular, ~1x/week
    case occasional   // shows up some weeks
}

/// What a trained movement is, for tier evaluation.
enum PacingMovementKind {
    /// Loaded movement ranked by StrengthStandards (compound or variant,
    /// accessory family, or weighted pull-up). `exerciseKey` is the logged
    /// exercise name StrengthStandards resolves.
    case lift(exerciseKey: String)
    /// Bodyweight rep/hold skill ranked against its skill node's generated
    /// tierCriteria (SkillGraph). `exerciseName` is the node's OWN movement
    /// name (the anchor's exerciseName): evaluation is name-gated with the
    /// same MovementProofMatcher the app uses, so variant ladders (pistol,
    /// nordic) only clear the tiers this movement actually proves.
    case skill(nodeId: String, exerciseName: String)
}

struct PacingMovement {
    let kind: PacingMovementKind
    /// Key into AttributeContributions.json for the attribute fan-out.
    /// nil → the tuning's default vector for the movement kind. May be a
    /// close proxy when the exact name has no row (documented per use).
    let attributeName: String?
    let emphasis: PacingEmphasis

    static func lift(_ exerciseKey: String, attr: String? = nil, _ emphasis: PacingEmphasis) -> PacingMovement {
        PacingMovement(kind: .lift(exerciseKey: exerciseKey), attributeName: attr ?? exerciseKey, emphasis: emphasis)
    }

    static func skill(_ nodeId: String, name: String, attr: String?, _ emphasis: PacingEmphasis) -> PacingMovement {
        PacingMovement(kind: .skill(nodeId: nodeId, exerciseName: name), attributeName: attr, emphasis: emphasis)
    }
}

/// A year-sim persona plus the pacing-model inputs the year sim doesn't
/// carry (bodyweight, sex, trained-movement set).
struct PacingPersonaSpec {
    let id: String
    let displayName: String
    let sessionsPerWeek: Double
    let adherence: YearAdherenceProfile
    let experience: Experience
    let bodyweightKg: Double
    let sex: BiologicalSex
    let movements: [PacingMovement]
}

// MARK: - Persona trained-movement mapping
//
// ROUTE TAKEN (documented per the harness spec): a static mapping per
// persona rather than running the full program generator. The 7 baseline
// personas' schedules/equipment/experience are reused verbatim from
// `BaselineYearProgramSimulator.personas`; the movement sets below are the
// stable staples the real generator prescribes for each equipment/style
// combination (verified against the year-sim exports: bodyweight personas
// live on pushup/row/squat-pattern/core-hold families; dumbbell personas on
// DB bench/row/RDL/goblet + pull-ups; gym personas on the big-4 + the
// AccessoryStandards families; the calisthenics persona additionally on
// lever/planche/handstand feats). This keeps the harness deterministic and
// decoupled from generator churn — retune sets here if the generator's
// staple selection materially changes.
enum GateKeyPacingPersonas {

    /// Bodyweights (kg) per persona — male defaults, chosen once so ratio
    /// standards resolve; the model treats bodyweight as stable.
    static let bodyweightKg: [String: Double] = [
        "home-bodyweight-beginner": 78,
        "home-dumbbell-bench": 80,
        "full-gym-intermediate": 82,
        "advanced-strength": 90,
        "advanced-calisthenics": 72,
        "travel-inconsistent": 78,
        "cut-mode-hybrid": 85
    ]

    static let movements: [String: [PacingMovement]] = [
        "home-bodyweight-beginner": [
            .skill("cal.pushup", name: "pushup", attr: "pushup", .primary),
            .skill("cal.incline-pushup", name: "incline pushup", attr: "incline pushup", .occasional),
            .skill("ld.split-squat", name: "split squat", attr: "split squat", .primary),
            .skill("ld.step-up", name: "step up", attr: "walking lunge", .secondary),   // attr proxy: no "step-up" row
            .skill("ld.glute-bridge", name: "glute bridge", attr: "glute bridge", .secondary),
            .skill("cal.plank-30", name: "plank", attr: "plank", .primary),
            .skill("cl.hollow-body-30", name: "hollow body hold", attr: "hollow rock", .secondary),
            .skill("pp.row", name: "row", attr: "inverted row", .secondary)
        ],
        "home-dumbbell-bench": [
            .lift("dumbbell bench press", .primary),
            .lift("goblet squat", .primary),
            .lift("dumbbell romanian deadlift", .secondary),
            .lift("dumbbell overhead press", .secondary),
            .lift("dumbbell row", .primary),
            .lift("band curl", .occasional),
            .lift("overhead tricep extension", .occasional),
            .skill("pp.pullup", name: "pullup", attr: "pullup", .primary),
            .skill("cal.pushup", name: "pushup", attr: "pushup", .secondary),
            .skill("cl.hanging-knee-raise", name: "hanging knee raise", attr: "hanging knee raise", .secondary),
            .skill("cal.plank-30", name: "plank", attr: "plank", .occasional)
        ],
        "full-gym-intermediate": [
            .lift("bench press", .primary),
            .lift("back squat", .primary),
            .lift("deadlift", .primary),
            .lift("overhead press", .secondary),
            .lift("barbell row", attr: "bent-over row", .secondary),
            .lift("lat pulldown", .secondary),
            .lift("hip thrust", .secondary),
            .lift("leg extension", .occasional),
            .lift("leg curl (lying)", .occasional),
            .lift("standing calf raise", .occasional),
            .lift("barbell curl", .occasional),
            .lift("tricep pushdown", .occasional),
            .lift("cable crunch", .occasional),
            .skill("pp.pullup", name: "pullup", attr: "pullup", .secondary),
            .skill("cal.5-dips", name: "dip", attr: "dip", .occasional),
            .skill("cal.plank-30", name: "plank", attr: "plank", .occasional)
        ],
        "advanced-strength": [
            .lift("bench press", .primary),
            .lift("back squat", .primary),
            .lift("deadlift", .primary),
            .lift("overhead press", .secondary),
            .lift("barbell row", attr: "bent-over row", .secondary),
            .lift("weighted pull-up", attr: "weighted pullup", .secondary),
            .lift("hip thrust", .secondary),
            .lift("barbell curl", .occasional),
            .lift("tricep pushdown", .occasional),
            .lift("standing calf raise", .occasional),
            .skill("pp.pullup", name: "pullup", attr: "pullup", .secondary),
            .skill("cal.plank-30", name: "plank", attr: "plank", .occasional)
        ],
        "advanced-calisthenics": [
            .skill("cal.pushup", name: "pushup", attr: "pushup", .primary),
            .skill("pp.pullup", name: "pullup", attr: "pullup", .primary),
            .skill("cal.5-dips", name: "dip", attr: "dip", .primary),
            .skill("cal.pike-pushup", name: "pike pushup", attr: "pike pushup", .primary),
            .skill("cl.hollow-body-30", name: "hollow body hold", attr: "hollow rock", .primary),
            .skill("pl.tuck-planche", name: "tuck planche", attr: nil, .primary),           // no catalog row → default vector
            .skill("hs.wall-handstand-30", name: "wall handstand", attr: nil, .primary),    // no catalog row → default vector
            .skill("pp.chin-up", name: "chin-up", attr: "chin-up", .secondary),
            .skill("cal.diamond-pushup", name: "diamond pushup", attr: "diamond pushup", .secondary),
            .skill("cal.l-sit-10", name: "l-sit", attr: "l-sit", .secondary),
            .skill("cl.tuck-front-lever", name: "tuck front lever", attr: "tuck front lever", .secondary),
            .skill("ld.pistol-squat", name: "pistol squat", attr: "pistol squat", .secondary),
            .skill("cl.hanging-leg-raise", name: "hanging leg raise", attr: "hanging leg raise", .secondary),
            .skill("cal.archer-pushup", name: "archer pushup", attr: "archer pushup", .occasional),
            .skill("cal.handstand-pushup", name: "handstand pushup", attr: nil, .occasional), // no catalog row → default vector
            .skill("ld.nordic-curl", name: "nordic curl", attr: "nordic curl", .occasional),
            .skill("pp.dead-hang", name: "dead hang", attr: nil, .occasional)               // no catalog row → default vector
        ],
        "travel-inconsistent": [
            .lift("dumbbell bench press", .primary),
            .lift("goblet squat", .secondary),
            .lift("dumbbell row", .secondary),
            .skill("cal.pushup", name: "pushup", attr: "pushup", .primary),
            .skill("pp.pullup", name: "pullup", attr: "pullup", .secondary),
            .skill("cal.plank-30", name: "plank", attr: "plank", .occasional),
            .skill("ld.split-squat", name: "split squat", attr: "split squat", .occasional)
        ],
        "cut-mode-hybrid": [
            .lift("bench press", .primary),
            .lift("deadlift", .primary),
            .lift("back squat", .secondary),
            .lift("overhead press", .occasional),
            .lift("lat pulldown", .secondary),
            .lift("barbell curl", .occasional),
            .skill("pp.pullup", name: "pullup", attr: "pullup", .primary),
            .skill("cal.pushup", name: "pushup", attr: "pushup", .secondary),
            .skill("cal.plank-30", name: "plank", attr: "plank", .occasional)
        ]
    ]

    /// Build the pacing spec for a baseline year-sim persona. Traps (via
    /// `precondition`) on an unmapped persona id so a new year-sim persona
    /// can't silently run with an empty movement set.
    static func spec(for persona: YearSimulationPersona) -> PacingPersonaSpec {
        guard let movementSet = movements[persona.id], let bw = bodyweightKg[persona.id] else {
            preconditionFailure("GateKeyPacingPersonas has no mapping for persona \(persona.id) — add one.")
        }
        return PacingPersonaSpec(
            id: persona.id,
            displayName: persona.displayName,
            sessionsPerWeek: Double(persona.trainingDays.count),
            adherence: persona.adherence,
            experience: persona.experience,
            bodyweightKg: bw,
            sex: .male,
            movements: movementSet
        )
    }

    static var all: [PacingPersonaSpec] {
        BaselineYearProgramSimulator.personas.map(spec(for:))
    }

    static func spec(id: String) -> PacingPersonaSpec? {
        BaselineYearProgramSimulator.personas.first { $0.id == id }.map(spec(for:))
    }
}
