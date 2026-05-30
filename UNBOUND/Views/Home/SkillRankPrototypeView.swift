import SwiftUI

// MARK: - Skill-mastery stars prototype UI (pull family)
//
// Each skill shows 5 DISCRETE stars (★★★☆☆) + the next concrete goal + your PB —
// no progress bar (reps are chunky; a bar would fake continuity). A star fills
// on a PR; per-session dopamine is XP, which lives elsewhere. Additive prototype;
// reachable from Settings → Dev. See docs/STAR-STANDARD-DESIGN.md.

private func formatValue(_ metric: SkillMetric, _ v: Double) -> String {
    switch metric {
    case .reps:           return "\(Int(v)) reps"
    case .seconds:        return "\(Int(v))s"
    case .bodyweightRatio: return "+\(Int(v * 100))% bw"
    }
}

/// Honest whole-number tally to the next star — "7 / 10 reps", no fractional bar.
private func formatTally(_ metric: SkillMetric, best: Double, next: Double) -> String {
    switch metric {
    case .reps:            return "next star: \(Int(best)) / \(Int(next)) reps"
    case .seconds:         return "next star: \(Int(best)) / \(Int(next))s"
    case .bodyweightRatio: return "next star: +\(Int(best * 100)) / +\(Int(next * 100))% bw"
    }
}

struct SkillStars: View {
    let stars: Int   // 0…5
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<5, id: \.self) { i in
                Image(systemName: i < stars ? "star.fill" : "star")
                    .font(.system(size: 13))
                    .foregroundStyle(i < stars ? Color.unbound.accent : Color.unbound.textTertiary.opacity(0.4))
            }
        }
    }
}

struct SkillRankRow: View {
    let title: String
    let metric: SkillMetric
    let result: SkillRankResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                Spacer()
                Text(result.label.uppercased())
                    .font(Font.unbound.captionS)
                    .foregroundStyle(result.isMastered ? Color.unbound.accent : Color.unbound.textSecondary)
            }

            SkillStars(stars: result.stars)

            HStack {
                if let next = result.nextThreshold {
                    Text(formatTally(metric, best: result.best, next: next))
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textTertiary)
                } else {
                    Text("MASTERED")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.accent)
                }
                Spacer()
                if result.best > 0 {
                    Text("PB \(formatValue(metric, result.best))")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
            }
        }
        .padding(14)
        .background(Color.unbound.surface, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct SkillRankPrototypeView: View {
    let logs: [WorkoutLog]
    let bodyweightKg: Double

    private let order = [
        "pp.dead-hang", "pp.pullup", "pp.chin-up", "pp.wide-pullup",
        "pp.weighted-pullup", "pp.archer-pullup", "pp.muscle-up",
        "pp.ring-muscle-up", "pp.strict-muscle-up", "pp.one-arm-pullup"
    ]
    private let titles: [String: String] = [
        "pp.dead-hang": "Dead Hang", "pp.pullup": "Pull-Up", "pp.chin-up": "Chin-Up",
        "pp.wide-pullup": "Wide Pull-Up", "pp.weighted-pullup": "Weighted Pull-Up",
        "pp.archer-pullup": "Archer Pull-Up", "pp.muscle-up": "Muscle-Up",
        "pp.ring-muscle-up": "Ring Muscle-Up", "pp.strict-muscle-up": "Strict Muscle-Up",
        "pp.one-arm-pullup": "One-Arm Pull-Up"
    ]

    private var totalPoints: Int {
        order.reduce(0) { acc, id in
            guard let std = PullSkillStandards.table[id] else { return acc }
            return acc + SkillRankEngine.weightedPoints(SkillRankEngine.rank(std, logs: logs, bodyweightKg: bodyweightKg), weight: std.weight)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    Text("PULL — SKILL MASTERY (5 stars)")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                    Spacer()
                    Text("\(totalPoints) pts")
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.accent)
                }
                .padding(.bottom, 4)

                ForEach(order, id: \.self) { id in
                    if let std = PullSkillStandards.table[id] {
                        SkillRankRow(
                            title: titles[id] ?? id,
                            metric: std.metric,
                            result: SkillRankEngine.rank(std, logs: logs, bodyweightKg: bodyweightKg)
                        )
                    }
                }
            }
            .padding(20)
        }
        .background(Color.unbound.bg.ignoresSafeArea())
    }
}

#if DEBUG
struct SkillRankPrototypeDebugView: View {
    @State private var logs: [WorkoutLog] = []
    @State private var loading = true

    var body: some View {
        Group {
            if loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.unbound.bg.ignoresSafeArea())
            } else {
                SkillRankPrototypeView(logs: logs, bodyweightKg: 75)
            }
        }
        .navigationTitle("Pull Skill Mastery (Prototype)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let uid = AuthService.shared.currentUserId ?? "anonymous"
            let real = (try? await WorkoutLogService.shared.fetchRecentLogs(userId: uid, limit: 300)) ?? []
            logs = real.isEmpty ? SkillRankPrototypeSample.logs : real
            loading = false
        }
    }
}

enum SkillRankPrototypeSample {
    static let logs: [WorkoutLog] = {
        func mk(_ exercise: String, reps: Int, weightKg: Double? = nil, seconds: Int? = nil) -> WorkoutLog {
            WorkoutLog(
                id: exercise, userId: "u", programId: "p", dayNumber: 1, plannedWorkoutName: "x",
                startedAt: Date(timeIntervalSince1970: 1), completedAt: Date(timeIntervalSince1970: 2),
                exerciseEntries: [
                    ExerciseLogEntry(id: exercise, exerciseName: exercise, plannedSets: 1, plannedReps: "\(reps)",
                                     sets: [SetLog(id: "s", setNumber: 1, weightKg: weightKg, reps: reps, rpe: nil, isWarmup: false, durationSeconds: seconds)],
                                     skipped: false, notes: nil)
                ],
                overallNotes: nil, overallRPE: nil, durationMinutes: nil)
        }
        return [
            mk("dead hang", reps: 0, seconds: 75), mk("pullup", reps: 12), mk("chin-up", reps: 14),
            mk("wide pullup", reps: 7), mk("weighted pullup", reps: 1, weightKg: 20),
            mk("archer pullup", reps: 2), mk("muscle-up", reps: 1),
        ]
    }()
}

#Preview {
    SkillRankPrototypeView(logs: SkillRankPrototypeSample.logs, bodyweightKg: 75)
}
#endif
