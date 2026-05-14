import Foundation

// MARK: - BadgeCatalog
//
// Declarative list of all unlockable badges. Ordered roughly by rarity /
// expected unlock order so the gallery reads sensibly.

enum BadgeCatalog {

    static let all: [Badge] = [
        // MARK: Onboarding / first-touch
        Badge(
            id: "archetype_chosen",
            displayName: "Path Chosen",
            description: "Picked your archetype — the arc begins.",
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
            id: "streak_14",
            displayName: "Fortnight",
            description: "14-session streak. The routine is starting to own the calendar.",
            iconSystemName: "calendar.circle.fill",
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
            id: "streak_60",
            displayName: "Iron Season",
            description: "60-session streak. Discipline is no longer temporary.",
            iconSystemName: "shield.lefthalf.filled",
            rarity: .legendary,
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
            id: "sessions_25",
            displayName: "Twenty-Five",
            description: "25 lifetime sessions. The start is behind you.",
            iconSystemName: "25.circle.fill",
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
            id: "sessions_100",
            displayName: "Hundred Club",
            description: "100 lifetime sessions logged.",
            iconSystemName: "100.circle.fill",
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
        Badge(
            id: "sessions_500",
            displayName: "Five Hundred",
            description: "500 logged sessions. This is no longer a phase.",
            iconSystemName: "medal.fill",
            rarity: .legendary,
            unlockedAt: nil
        ),

        // MARK: Session quality
        Badge(
            id: "clean_sweep",
            displayName: "Clean Sweep",
            description: "Finished every planned exercise in a session.",
            iconSystemName: "checkmark.seal.fill",
            rarity: .common,
            unlockedAt: nil
        ),
        Badge(
            id: "hour_glass",
            displayName: "Hour Glass",
            description: "Logged a session that lasted 60 minutes or more.",
            iconSystemName: "hourglass.circle.fill",
            rarity: .rare,
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
            displayName: "Forged",
            description: "Reached the Forged title on any tracked lift.",
            iconSystemName: "c.circle.fill",
            rarity: .common,
            unlockedAt: nil
        ),
        Badge(
            id: "rank_b_any",
            displayName: "Honed",
            description: "Reached the Honed title on any tracked lift.",
            iconSystemName: "b.circle.fill",
            rarity: .rare,
            unlockedAt: nil
        ),
        Badge(
            id: "rank_a_any",
            displayName: "Unbound",
            description: "Reached the Unbound title on any tracked lift.",
            iconSystemName: "a.circle.fill",
            rarity: .rare,
            unlockedAt: nil
        ),
        Badge(
            id: "rank_s_any",
            displayName: "Ascendant",
            description: "Reached the Ascendant title on any tracked lift.",
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
        Badge(
            id: "first_pullup",
            displayName: "First Pull",
            description: "Completed a set of pull-ups or chin-ups.",
            iconSystemName: "figure.pullup",
            rarity: .common,
            unlockedAt: nil
        ),
        Badge(
            id: "first_dip",
            displayName: "Locked Out",
            description: "Completed a set of dips.",
            iconSystemName: "figure.strengthtraining.functional",
            rarity: .common,
            unlockedAt: nil
        ),
        Badge(
            id: "first_pistol_squat",
            displayName: "Single-Leg Steel",
            description: "Completed a set of pistol squats.",
            iconSystemName: "figure.step.training",
            rarity: .rare,
            unlockedAt: nil
        ),
        Badge(
            id: "pushup_50_set",
            displayName: "Fifty Straight",
            description: "Hit 50 push-ups in one set.",
            iconSystemName: "50.square.fill",
            rarity: .rare,
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
        Badge(
            id: "scan_archive_5",
            displayName: "Scan Archive",
            description: "Built a five-scan body record.",
            iconSystemName: "person.crop.rectangle.stack.fill",
            rarity: .rare,
            unlockedAt: nil
        ),
        Badge(
            id: "scan_archive_10",
            displayName: "Ten Reads",
            description: "Completed 10 body scans.",
            iconSystemName: "waveform.path.ecg.rectangle",
            rarity: .legendary,
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
            displayName: "Two-Week Read",
            description: "Two bi-weekly scans within 14 days of each other.",
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
        ),
        Badge(
            id: "proof_10",
            displayName: "Proof Stack",
            description: "Saved 10 progress captures.",
            iconSystemName: "photo.on.rectangle.angled",
            rarity: .rare,
            unlockedAt: nil
        ),
        Badge(
            id: "proof_25",
            displayName: "Archive Built",
            description: "Saved 25 progress captures.",
            iconSystemName: "square.grid.3x3.fill",
            rarity: .legendary,
            unlockedAt: nil
        )
    ]

    static var byId: [String: Badge] {
        Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    }
}
