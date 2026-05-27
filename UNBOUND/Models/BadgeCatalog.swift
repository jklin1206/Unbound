import Foundation

// MARK: - BadgeCatalog
//
// Declarative list of all unlockable badges. Ordered roughly by rarity /
// expected unlock order so the gallery reads sensibly.

enum BadgeCatalog {

    static let all: [Badge] = [
        // MARK: Onboarding / first-touch
        Badge(
            id: "first_build_identity_resolved",
            displayName: "Build Emerges",
            description: "Your training shaped a build — the arc begins.",
            iconSystemName: "hexagon.fill",
            rarity: .common,
            unlockedAt: nil
        ),
        Badge(
            id: "calibration_complete",
            displayName: "Calibrated",
            description: "Finished your Chapter V baselines. We know where you start.",
            iconSystemName: "dial.medium",
            rarity: .common,
            unlockedAt: nil
        ),
        Badge(
            id: "first_session",
            displayName: "First Rep",
            description: "Logged your first session. The work begins.",
            iconSystemName: "bolt.fill",
            rarity: .common,
            unlockedAt: nil
        ),
        Badge(
            id: "first_scan",
            displayName: "Mirror Check",
            description: "Completed your first body scan.",
            iconSystemName: "camera.viewfinder",
            rarity: .common,
            unlockedAt: nil
        ),

        // MARK: Streaks
        Badge(
            id: "streak_3",
            displayName: "Three in a Row",
            description: "3-session streak. Consistency has a face now.",
            iconSystemName: "flame",
            rarity: .common,
            unlockedAt: nil
        ),
        Badge(
            id: "streak_7",
            displayName: "One Week In",
            description: "7 sessions without a break.",
            iconSystemName: "flame.fill",
            rarity: .rare,
            unlockedAt: nil
        ),
        Badge(
            id: "streak_30",
            displayName: "One Moon",
            description: "30 sessions in a row. Habit is identity.",
            iconSystemName: "flame.circle.fill",
            rarity: .rare,
            unlockedAt: nil
        ),
        Badge(
            id: "streak_100",
            displayName: "Century",
            description: "100-session streak. Rare air.",
            iconSystemName: "crown.fill",
            rarity: .legendary,
            unlockedAt: nil
        ),

        // MARK: Volume
        Badge(
            id: "sessions_10",
            displayName: "Double Digits",
            description: "10 lifetime sessions logged.",
            iconSystemName: "10.circle.fill",
            rarity: .common,
            unlockedAt: nil
        ),
        Badge(
            id: "sessions_50",
            displayName: "Fifty Deep",
            description: "50 lifetime sessions. The foundation's thick now.",
            iconSystemName: "50.circle.fill",
            rarity: .rare,
            unlockedAt: nil
        ),
        Badge(
            id: "sessions_250",
            displayName: "Quarter Thousand",
            description: "250 logged sessions. Freak status unlocked.",
            iconSystemName: "trophy.fill",
            rarity: .legendary,
            unlockedAt: nil
        ),

        // MARK: Rank milestones
        Badge(
            id: "first_rank_up",
            displayName: "Ascension",
            description: "Your first rank-up event.",
            iconSystemName: "arrow.up.right.circle.fill",
            rarity: .common,
            unlockedAt: nil
        ),
        Badge(
            id: "rank_c_any",
            displayName: "C-Tier",
            description: "Reached C on any tracked lift.",
            iconSystemName: "c.circle.fill",
            rarity: .common,
            unlockedAt: nil
        ),
        Badge(
            id: "rank_b_any",
            displayName: "B-Tier",
            description: "Reached B on any tracked lift.",
            iconSystemName: "b.circle.fill",
            rarity: .rare,
            unlockedAt: nil
        ),
        Badge(
            id: "rank_a_any",
            displayName: "A-Tier",
            description: "Reached A on any tracked lift. Elite territory.",
            iconSystemName: "a.circle.fill",
            rarity: .rare,
            unlockedAt: nil
        ),
        Badge(
            id: "rank_s_any",
            displayName: "S-Tier",
            description: "Reached S on any tracked lift. The summit.",
            iconSystemName: "s.circle.fill",
            rarity: .legendary,
            unlockedAt: nil
        ),

        // MARK: Skills
        Badge(
            id: "first_muscle_up",
            displayName: "Over the Bar",
            description: "Completed a set of muscle-ups.",
            iconSystemName: "figure.climbing",
            rarity: .legendary,
            unlockedAt: nil
        ),
        Badge(
            id: "first_handstand_pushup",
            displayName: "Inversion",
            description: "Completed a set of handstand pushups.",
            iconSystemName: "figure.gymnastics",
            rarity: .legendary,
            unlockedAt: nil
        ),

        // MARK: Strength relative
        Badge(
            id: "bw_squat_2x",
            displayName: "Double Weight Squat",
            description: "Back-squatted 2× bodyweight.",
            iconSystemName: "figure.strengthtraining.traditional",
            rarity: .rare,
            unlockedAt: nil
        ),
        Badge(
            id: "bw_bench_1_5x",
            displayName: "One-and-a-Half",
            description: "Bench-pressed 1.5× bodyweight.",
            iconSystemName: "figure.strengthtraining.functional",
            rarity: .rare,
            unlockedAt: nil
        ),
        Badge(
            id: "bw_deadlift_3x",
            displayName: "Triple Pull",
            description: "Deadlifted 3× bodyweight.",
            iconSystemName: "figure.cooldown",
            rarity: .legendary,
            unlockedAt: nil
        ),

        // MARK: Scan habit
        Badge(
            id: "scan_streak_3",
            displayName: "Three-Scan Arc",
            description: "Logged three body scans across weeks.",
            iconSystemName: "chart.line.uptrend.xyaxis",
            rarity: .rare,
            unlockedAt: nil
        ),

        // MARK: Photo ritual (daily capture + cadence)
        Badge(
            id: "first_photo",
            displayName: "Day Zero",
            description: "Captured your first progress photo.",
            iconSystemName: "camera.fill",
            rarity: .common,
            unlockedAt: nil
        ),
        Badge(
            id: "biweekly_scan",
            displayName: "Checkpoint Streak",
            description: "Two monthly checkpoints completed on cadence.",
            iconSystemName: "sparkle.magnifyingglass",
            rarity: .rare,
            unlockedAt: nil
        ),
        Badge(
            id: "monthly_arc",
            displayName: "Monthly Arc",
            description: "Four or more captures in a rolling 30-day window.",
            iconSystemName: "calendar.badge.checkmark",
            rarity: .rare,
            unlockedAt: nil
        )
    ]

    static var byId: [String: Badge] {
        Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    }
}
