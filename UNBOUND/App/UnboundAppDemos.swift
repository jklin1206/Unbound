// UNBOUND/App/UnboundAppDemos.swift
import SwiftUI
import UIKit

#if DEBUG
@MainActor
struct RankTrialReadyReviewView: View {
    private let definition: OverallRankTrialDefinition
    private let draft: TrainingSessionDraft

    init() {
        let definitions = OverallRankTrialDefinitions.all
        let index = Self.requestedTrialIndex(in: definitions) ?? 0
        let definition = definitions[index]
        let equipment: Set<MovementEquipment> = [
            .bodyweight,
            .barbell,
            .dumbbell,
            .kettlebell,
            .cable,
            .machine,
            .pullupBar,
            .dipStation,
            .rings,
            .bench,
            .box,
            .band,
            .sled,
            .cardioMachine,
            .openSpace
        ]
        let resolution = RankTrialLoadoutResolver.shared.resolve(
            definition: definition,
            userId: DevBuildBootstrapper.userId,
            equipment: equipment
        )
        self.definition = definition
        self.draft = definition.makeDraft(
            userId: DevBuildBootstrapper.userId,
            resolvedTrial: resolution.resolvedTrial,
            bodyweightKg: 82
        )
    }

    var body: some View {
        WorkoutReadyView(draft: draft)
            .accessibilityIdentifier("rankTrialReadyReview.\(definition.id)")
    }

    private static func requestedTrialIndex(in definitions: [OverallRankTrialDefinition]) -> Int? {
        let args = ProcessInfo.processInfo.arguments
        let env = ProcessInfo.processInfo.environment
        let requested = value(after: "-rankTrialReadyReviewTrial", in: args)
            ?? value(after: "--rank-trial-ready-review-trial", in: args)
            ?? env["RANK_TRIAL_READY_REVIEW_TRIAL"]
        guard let requested, !requested.isEmpty else { return nil }

        if let numeric = Int(requested), definitions.indices.contains(numeric) {
            return numeric
        }

        let normalized = requested
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
        return definitions.firstIndex { definition in
            definition.id
                .replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: "_", with: "")
                .lowercased() == normalized
            || definition.displayName
                .replacingOccurrences(of: "The ", with: "")
                .replacingOccurrences(of: " ", with: "")
                .lowercased() == normalized
            || definition.format.rawValue.lowercased() == normalized
        }
    }

    private static func value(after flag: String, in args: [String]) -> String? {
        guard let index = args.firstIndex(of: flag), args.indices.contains(index + 1) else { return nil }
        return args[index + 1]
    }
}

/// Launch with `-rewardDemo` to drop into the post-workout reward sequence and
/// cycle through a battery of payload variants (no level-up, single rank,
/// multi-rank feat, many exercises with different badges, the full kitchen sink
/// with PRs + badge). Advances to the next scenario each time the sequence is
/// dismissed (the demo auto-advance loops it). Used to record/iterate reward UX.
struct RewardDemoView: View {
    @State private var index = 0
    @State private var runID = UUID()
    private let scenarios = RewardDemoScenarios.all

    /// The active scenario, tagged with a post-workout photo context so the
    /// final beat shows the opt-in "Add a photo" button in the demo.
    private var demoSummary: WorkoutRewardSequenceSummary {
        var summary = scenarios[index].summary
        summary.workoutPhotoContext = WorkoutPhotoSummary(
            title: scenarios[index].label,
            completedAt: Date(),
            durationMinutes: 42,
            exercises: ["Bench Press · 3×5", "Incline DB · 3×10", "Cable Fly · 3×12"]
        )
        return summary
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            WorkoutRewardSequenceView(
                summary: demoSummary,
                onAddWorkoutPhoto: { _ in }
            ) {
                index = (index + 1) % scenarios.count
                runID = UUID()
            }
            .id(runID)

            VStack {
                Text("DEMO \(index + 1)/\(scenarios.count) · \(scenarios[index].label)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.top, 2)
                Spacer()
            }
        }
    }
}

private struct RewardDemoScenario {
    let label: String
    let summary: WorkoutRewardSequenceSummary
}

private enum RewardDemoScenarios {
    static func set(reps: Int = 0, weightKg: Double? = nil, seconds: Int? = nil) -> SetLog {
        SetLog(id: UUID().uuidString, setNumber: 1, weightKg: weightKg, reps: reps,
               rpe: 8, isWarmup: false, durationSeconds: seconds)
    }
    static func entry(_ name: String, _ node: String, _ sets: [SetLog]) -> ExerciseLogEntry {
        ExerciseLogEntry(id: "demo-\(node)", exerciseName: name, movementId: nil,
                         rankStandardMovementId: node, plannedSets: sets.count,
                         plannedReps: "—", sets: sets, skipped: false, notes: nil)
    }

    /// Explicit XP state so the level-up bar can be demonstrated at any level:
    /// `progBefore`/`progAfter` drive the bar, `lvlBefore`/`lvlAfter` the number.
    static func xp(_ total: Int, _ lvlBefore: Int, _ progBefore: Double, _ lvlAfter: Int, _ progAfter: Double) -> XPReward {
        XPReward(
            total: total,
            previousLevel: lvlBefore, newLevel: lvlAfter,
            previousProgress: progBefore, newProgress: progAfter,
            previousXP: 0, currentXP: progAfter * 100,
            levelFloorXP: 0, nextLevelXP: 100,
            breakdown: [XPBreakdownLine(label: "Session XP", amount: total)]
        )
    }

    static func attr(_ key: AttributeKey, _ from: RankTitle, _ to: RankTitle,
                     _ lvlFrom: Int, _ lvlTo: Int, _ pFrom: Double, _ pTo: Double, xp: Double) -> AttributeDeltaReward {
        AttributeDeltaReward(
            key: key, xpGained: xp, previousXP: 0, currentXP: xp,
            previousLevel: lvlFrom, currentLevel: lvlTo,
            previousProgress: pFrom, currentProgress: pTo,
            previousTier: from, currentTier: to
        )
    }

    static func scene(
        _ label: String, xp xpReward: XPReward,
        entries: [ExerciseLogEntry] = [], lifts: [LiftProgressReward] = [],
        attrs: [AttributeDeltaReward] = [], prs: [PersonalRecordReward] = [],
        badges: [BadgeUnlock] = [], streak: StreakReward? = nil,
        cosmetics: [CosmeticUnlockReward] = []
    ) -> RewardDemoScenario {
        let log = WorkoutLog(
            id: "demo-\(label)", userId: "demo", programId: "demo", dayNumber: 1,
            plannedWorkoutName: label, startedAt: Date(timeIntervalSince1970: 0),
            completedAt: Date(timeIntervalSince1970: 1920), exerciseEntries: entries,
            overallNotes: nil, overallRPE: 8, durationMinutes: 38)
        let result = entries.isEmpty
            ? ProofEngineResult.empty(logId: "demo-\(label)", source: .generated)
            : ProofEngine.evaluate(log: log, source: .generated)
        var s = WorkoutRewardSequenceSummary.simpleReceipt(
            workoutName: label, durationMinutes: 38, workSets: max(entries.count + lifts.count, 1),
            volumeKg: lifts.isEmpty ? 0 : 4280, rpe: 8, xpTotal: xpReward.total,
            xpLabel: "Session XP", sourceName: "Program", badges: badges)
        s.xp = xpReward
        s.liftProgress = lifts
        s.attributeDeltas = attrs
        s.personalRecords = prs
        s.streak = streak
        s.cosmeticUnlocks = cosmetics
        // Reward hex = progress toward NEXT level (0–1), which moves a lot per
        // session. Untrained axes hold at a resting progress; trained axes animate
        // from levelProgressStart (0 if it leveled up) → currentProgress. Honest
        // values — this is the real per-level progress, not a fudge.
        if !attrs.isEmpty {
            var before = restingProgress
            var after = restingProgress
            for a in attrs {
                before[a.key] = a.levelProgressStart
                after[a.key] = a.currentProgress
            }
            s.attributePreviousHexValues = before.mapValues { $0 * 100 }
            s.attributeCurrentHexValues = after.mapValues { $0 * 100 }
            s.attributePreviousLevels = Dictionary(uniqueKeysWithValues: attrs.map { ($0.key, $0.previousLevel) })
            s.attributeLevels = Dictionary(uniqueKeysWithValues: attrs.map { ($0.key, $0.currentLevel) })
        }
        s = RewardPayloadBuilder.attachProofRewards(result, to: s)
        return RewardDemoScenario(label: label, summary: s)
    }

    /// Resting level-progress (0–1) for the untrained axes; only trained axes move.
    static let restingProgress: [AttributeKey: Double] = [
        .power: 0.46, .control: 0.30, .endurance: 0.24, .vitality: 0.18, .mobility: 0.40, .explosiveness: 0.28
    ]

    // Reusable lift/skill bits.
    static let squatUp = LiftProgressReward(liftName: "Back Squat", family: .legs, fromTier: .forged, toTier: .veteran, fromProgress: 0.86, toProgress: 0.24, xpGained: 110)
    static let benchProg = LiftProgressReward(liftName: "Bench Press", family: .press, fromTier: .apprentice, toTier: .apprentice, fromProgress: 0.38, toProgress: 0.66, xpGained: 64)
    static let deadliftUp = LiftProgressReward(liftName: "Deadlift", family: .pull, fromTier: .veteran, toTier: .master, fromProgress: 0.80, toProgress: 0.15, xpGained: 130)

    static let all: [RewardDemoScenario] = [
        // 1 — NO level-up: bar fills part-way within a level. One skill + one lift.
        scene("NO LEVEL UP", xp: xp(60, 7, 0.30, 7, 0.62),
              entries: [entry("pushup", "cal.pushup", [set(reps: 13)])],
              lifts: [benchProg],
              streak: StreakReward(dayCount: 3, didExtend: true)),

        // 2 — ONE level-up: bar fills to 100, number flips 7→8, refills to carryover.
        scene("ONE LEVEL UP", xp: xp(180, 7, 0.58, 8, 0.20),
              entries: [
                entry("pullup", "pp.pullup", [set(reps: 13)]),
                entry("plank", "cal.plank-30", [set(seconds: 60)])
              ],
              lifts: [squatUp],
              attrs: [attr(.power, .forged, .veteran, 4, 5, 0.7, 0.22, xp: 120)],
              streak: StreakReward(dayCount: 7, didExtend: true)),

        // 3 — MULTI level-up: 12 → 14 (two fills + flips), bigger XP haul.
        scene("MULTI LEVEL UP", xp: xp(520, 12, 0.42, 14, 0.35),
              entries: [
                entry("pushup", "cal.pushup", [set(reps: 30)]),
                entry("dip", "cal.5-dips", [set(reps: 20)])
              ],
              lifts: [squatUp, deadliftUp],
              attrs: [
                attr(.power, .veteran, .veteran, 5, 5, 0.4, 0.7, xp: 90),
                attr(.control, .apprentice, .forged, 3, 4, 0.8, 0.3, xp: 110)
              ]),

        // 4 — LIFTS + SKILLS + STATS together on one RANKS page.
        scene("LIFTS + SKILLS", xp: xp(240, 9, 0.50, 10, 0.30),
              entries: [
                entry("pullup", "pp.pullup", [set(reps: 23)]),
                entry("pistol squat", "ld.pistol-squat", [set(reps: 13)])
              ],
              lifts: [squatUp, benchProg, deadliftUp],
              attrs: [
                attr(.power, .forged, .veteran, 4, 5, 0.6, 0.2, xp: 120),
                attr(.endurance, .novice, .novice, 2, 2, 0.3, 0.55, xp: 70)
              ]),

        // 5 — EVERYTHING: multi level-up + top-tier skills + lifts + attrs + PRs + badge.
        scene("EVERYTHING · GOLD", xp: xp(640, 18, 0.55, 20, 0.40),
              entries: [
                entry("pushup", "cal.pushup", [set(reps: 90)]),
                entry("pullup", "pp.pullup", [set(reps: 32)]),
                entry("muscle-up", "pp.muscle-up", [set(reps: 17)])
              ],
              lifts: [squatUp, deadliftUp],
              attrs: [
                attr(.power, .veteran, .master, 5, 6, 0.7, 0.25, xp: 160),
                attr(.control, .forged, .veteran, 4, 5, 0.6, 0.3, xp: 120)
              ],
              prs: [
                PersonalRecordReward(liftName: "Pull-Up", valueText: "32 reps", deltaText: "+5", family: .pull),
                PersonalRecordReward(liftName: "Deadlift", valueText: "180 kg", deltaText: "+7.5", family: .pull)
              ],
              badges: [
                BadgeUnlock(id: "first_session", title: "First Rep",
                            subtitle: "Logged your first session.", assetName: "badge_art_first_session"),
                BadgeUnlock(id: "streak_14", title: "Two-Week Forge",
                            subtitle: "Held a 14-day streak.", assetName: "badge_art_streak_14"),
                BadgeUnlock(id: "streak_100", title: "Century",
                            subtitle: "100 days. Unbroken.", assetName: "badge_art_streak_100")
              ],
              streak: StreakReward(dayCount: 21, didExtend: true),
              cosmetics: [
                CosmeticUnlockReward(title: "Jade Skin",
                                     subtitle: "Skill-tree cosmetic — equip in Appearance.",
                                     tint: Color.unbound.success)
              ])
    ]
}

#endif
