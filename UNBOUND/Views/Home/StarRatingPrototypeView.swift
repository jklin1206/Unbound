import SwiftUI

// MARK: - Star-Standard prototype UI (pull family)
//
// A self-contained preview of the Overcooked-style star rating: each pull node
// shows 0–3 stars vs its standard + the concrete next-star threshold. Additive
// prototype — not wired into the live skill cards yet. See
// docs/STAR-STANDARD-DESIGN.md. Drop into a debug menu or use the #Preview.

/// 3-star badge with filled/hollow stars.
struct StarRatingBadge: View {
    let stars: Int
    var size: CGFloat = 16

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: i < stars ? "star.fill" : "star")
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(i < stars ? Color.unbound.accent : Color.unbound.border)
            }
        }
        .accessibilityLabel("\(stars) of 3 stars")
    }
}

/// One skill row: title, stars, and the next-star target (the one dominant number).
struct StarSkillRow: View {
    let title: String
    let standard: StarStandard
    let rating: StarRating

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                Spacer()
                StarRatingBadge(stars: rating.stars)
            }

            if let next = rating.nextThreshold {
                // The hero: concrete next-star target + where you are.
                HStack(spacing: 6) {
                    Text(nextStarLabel)
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.accent)
                    Text("·  you're at \(scoreLabel(rating.bestScore))")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
                ProgressView(value: rating.progressToNext)
                    .tint(Color.unbound.accent)
                    .scaleEffect(x: 1, y: 1.4, anchor: .center)
            } else {
                Text("MASTERED ★★★")
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.accent)
            }
        }
        .padding(14)
        .background(Color.unbound.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    private var nextStarLabel: String {
        let star = rating.stars + 1
        let stars = String(repeating: "★", count: star)
        return "\(stars) at \(thresholdLabel(rating.nextThreshold ?? 0))"
    }

    private func thresholdLabel(_ v: Double) -> String {
        switch standard.metric {
        case .reps:           return "\(Int(v)) reps"
        case .seconds:        return "\(Int(v))s"
        case .bodyweightRatio: return "+\(Int(v * 100))% bw"
        }
    }

    private func scoreLabel(_ v: Double) -> String {
        switch standard.metric {
        case .reps:           return "\(Int(v))"
        case .seconds:        return "\(Int(v))s"
        case .bodyweightRatio: return "+\(Int(v * 100))%"
        }
    }
}

/// The pull family as a star list, rated against a sample athlete's logs.
struct StarRatingPrototypeView: View {
    let logs: [WorkoutLog]
    let bodyweightKg: Double

    private let order = [
        "pp.dead-hang", "pp.pullup", "pp.chin-up", "pp.wide-pullup",
        "pp.weighted-pullup", "pp.archer-pullup", "pp.muscle-up",
        "pp.ring-muscle-up", "pp.strict-muscle-up", "pp.one-arm-pullup"
    ]
    private let titles = [
        "pp.dead-hang": "Dead Hang", "pp.pullup": "Pull-Up", "pp.chin-up": "Chin-Up",
        "pp.wide-pullup": "Wide Pull-Up", "pp.weighted-pullup": "Weighted Pull-Up",
        "pp.archer-pullup": "Archer Pull-Up", "pp.muscle-up": "Muscle-Up",
        "pp.ring-muscle-up": "Ring Muscle-Up", "pp.strict-muscle-up": "Strict Muscle-Up",
        "pp.one-arm-pullup": "One-Arm Pull-Up"
    ]

    private var totalWeightedPoints: Int {
        order.reduce(0) { acc, id in
            guard let std = PullStarStandards.table[id] else { return acc }
            return acc + StarRatingEngine.rate(std, logs: logs, bodyweightKg: bodyweightKg).weightedPoints(weight: std.weight)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    Text("PULL — STAR PROTOTYPE")
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textSecondary)
                    Spacer()
                    Text("\(totalWeightedPoints) pts")
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.accent)
                }
                .padding(.bottom, 4)

                ForEach(order, id: \.self) { id in
                    if let std = PullStarStandards.table[id] {
                        StarSkillRow(
                            title: titles[id] ?? id,
                            standard: std,
                            rating: StarRatingEngine.rate(std, logs: logs, bodyweightKg: bodyweightKg)
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
// MARK: - Debug entry (Settings → Dev)

/// Loads the signed-in user's real pull logs; falls back to a sample athlete so
/// the screen is always populated. Wired into Settings → Dev for a live look.
struct StarRatingPrototypeDebugView: View {
    @State private var logs: [WorkoutLog] = []
    @State private var loading = true

    var body: some View {
        Group {
            if loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.unbound.bg.ignoresSafeArea())
            } else {
                StarRatingPrototypeView(logs: logs, bodyweightKg: 75)
            }
        }
        .navigationTitle("Pull Stars (Prototype)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let uid = AuthService.shared.currentUserId ?? "anonymous"
            let real = (try? await WorkoutLogService.shared.fetchRecentLogs(userId: uid, limit: 300)) ?? []
            logs = real.isEmpty ? StarRatingPrototypeSample.logs : real
            loading = false
        }
    }
}

/// A sample intermediate athlete — solid pull-ups, a muscle-up, some weighted work.
enum StarRatingPrototypeSample {
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
    StarRatingPrototypeView(logs: StarRatingPrototypeSample.logs, bodyweightKg: 75)
}
#endif
