// UNBOUND/App/UnboundAppDemos.swift
import SwiftUI
import UIKit

#if DEBUG
/// Launch with `-rewardDemo` to drop into the post-workout reward sequence and
/// cycle through a battery of payload variants (no level-up, single rank,
/// multi-rank feat, many exercises with different badges, the full kitchen sink
/// with PRs + badge, gate-trial receipts, a sealed vow). Advances to the next
/// scenario each time the sequence is dismissed (the demo auto-advance loops
/// it). Used to record/iterate reward UX. `-rewardDemoManual` opens the same
/// battery WITHOUT the timed auto-advance, for tap-paced review/screenshots.
struct RewardDemoView: View {
    @State private var index: Int
    @State private var runID = UUID()
    private let scenarios = RewardDemoScenarios.all

    /// `-rewardDemoIndex <n>` (0-based) starts the battery at scenario n, so a
    /// review session can jump straight to a late scenario without walking the
    /// whole cycle.
    init() {
        let args = ProcessInfo.processInfo.arguments
        var start = 0
        if let flag = args.firstIndex(of: "-rewardDemoIndex"), flag + 1 < args.count,
           let value = Int(args[flag + 1]) {
            start = max(0, min(RewardDemoScenarios.all.count - 1, value))
        }
        _index = State(initialValue: start)
    }

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
        cosmetics: [CosmeticUnlockReward] = [],
        arcs: Int = 90,
        trial: RankTrialRewardCallout? = nil
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
        s.arcsEarned = arcs
        s.rankTrialCallout = trial
        // Radar shapes on the honest cumulative scale (continuousHexFill),
        // exactly like the real receipts. Untrained axes rest at plausible
        // mid-journey levels so the demo silhouette looks like a real user.
        if !attrs.isEmpty {
            var before: [AttributeKey: Double] = [:]
            var after: [AttributeKey: Double] = [:]
            for (key, level) in restingLevels {
                let fill = AttributeLevelCurve.continuousHexFill(level: level, progress: 0.4) * 100
                before[key] = fill
                after[key] = fill
            }
            for a in attrs {
                before[a.key] = AttributeLevelCurve.continuousHexFill(level: a.previousLevel, progress: a.previousProgress) * 100
                after[a.key] = AttributeLevelCurve.continuousHexFill(level: a.currentLevel, progress: a.currentProgress) * 100
            }
            s.attributePreviousHexValues = before
            s.attributeCurrentHexValues = after
        }
        s = RewardPayloadBuilder.attachProofRewards(result, to: s)
        return RewardDemoScenario(label: label, summary: s)
    }

    /// Resting levels for the untrained axes; only trained axes move.
    static let restingLevels: [AttributeKey: Int] = [
        .power: 5, .control: 4, .endurance: 3, .vitality: 2, .mobility: 4, .explosiveness: 3
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
              ]),

        // 6 — GATE RECEIPT (passed): the trial-receipt beat. In the live flow a
        //     FIRST pass plays TheCrossingView instead (this beat is stripped from
        //     the tail), so this receipt only renders on a duplicate re-clear.
        scene("GATE RE-CLEARED", xp: xp(120, 15, 0.30, 15, 0.52),
              entries: [entry("pullup", "pp.pullup", [set(reps: 15)])],
              trial: RankTrialRewardCallout(
                id: "demo-gate-pass",
                title: "The Forging",
                subtitle: "Forged gate cleared",
                statusLine: "Official result saved",
                detailLine: "4/4 stations cleared",
                receiptLine: "4/4 stations cleared",
                passed: true)),

        // 7 — GATE HELD: the failed-trial receipt. Note the live flow routes a
        //     failed gate to GateVerdictView (with the banked-spoils line) and
        //     skips the sequence — this page renders only on edge paths.
        scene("GATE HELD", xp: xp(90, 15, 0.52, 15, 0.70),
              streak: StreakReward(dayCount: 12, didExtend: true),
              trial: RankTrialRewardCallout(
                id: "demo-gate-fail",
                title: "The Reckoning",
                subtitle: "Veteran gate held",
                statusLine: "First failed station saved",
                detailLine: "Weighted Pull-Up: 2 reps short",
                receiptLine: "3/4 stations cleared",
                passed: false))
    ]
}

#endif
