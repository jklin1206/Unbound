import Foundation

// MARK: - BadgeCatalog
//
// Declarative list of all unlockable badges. Ordered roughly by rarity /
// expected unlock order so the gallery reads sensibly.

enum BadgeCatalog {

    static let all: [Badge] = [
        // MARK: Onboarding / first-touch
        badge(
            id: "first_build_identity_resolved",
            displayName: "Origin Spark",
            description: "Your build stops being theory and becomes a living file.",
            unlockCriteria: "Resolve your first Build Identity during onboarding.",
            vowReward: "Vow reward: unlock the Origin Spark title and stamp the genesis relic on your profile.",
            iconSystemName: "sparkles",
            rarity: .common
        ),
        badge(
            id: "calibration_complete",
            displayName: "Baseline Oracle",
            description: "The app has your starting numbers. The weak points have nowhere to hide.",
            unlockCriteria: "Finish the Chapter V baseline calibration.",
            vowReward: "Vow reward: unlock the Baseline Oracle title and claim the calibration relic.",
            iconSystemName: "dial.medium",
            rarity: .common
        ),
        badge(
            id: "first_session",
            displayName: "Ignition Mark",
            description: "The first logged session. The engine finally turns over.",
            unlockCriteria: "Log your first training session.",
            vowReward: "Vow reward: unlock the Ignition Mark title and light the first combat relic.",
            iconSystemName: "bolt.fill",
            rarity: .common
        ),
        badge(
            id: "first_scan",
            displayName: "Mirrorbound",
            description: "The body scan becomes a contract: no more guessing, no more hiding.",
            unlockCriteria: "Complete your first body scan or scan-sourced progress checkpoint.",
            vowReward: "Vow reward: unlock the Mirrorbound title and bind your first visual proof relic.",
            iconSystemName: "camera.viewfinder",
            rarity: .common
        ),

        // MARK: Streaks
        badge(
            id: "streak_3",
            displayName: "Kindling Chain",
            description: "Three sessions chained together. A habit begins to breathe.",
            unlockCriteria: "Reach a current training streak of 3 sessions.",
            vowReward: "Vow reward: unlock the Kindling Chain title and ignite the first streak flame.",
            iconSystemName: "flame",
            rarity: .common
        ),
        badge(
            id: "streak_7",
            displayName: "Ritual Furnace",
            description: "A full week of pressure. The ritual is no longer casual.",
            unlockCriteria: "Reach a current training streak of 7 sessions.",
            vowReward: "Vow reward: unlock the Ritual Furnace title and upgrade your streak flame.",
            iconSystemName: "flame.fill",
            rarity: .rare
        ),
        badge(
            id: "streak_14",
            displayName: "Fortnight Flame",
            description: "Two weeks without dropping the chain. Momentum has teeth now.",
            unlockCriteria: "Reach a current training streak of 14 sessions.",
            vowReward: "Vow reward: unlock the Fortnight Flame title and claim the violet chainfire relic.",
            iconSystemName: "flame.fill",
            rarity: .rare
        ),
        badge(
            id: "streak_30",
            displayName: "Moonfire Pact",
            description: "Thirty sessions in a row. The calendar starts orbiting you.",
            unlockCriteria: "Reach a current training streak of 30 sessions.",
            vowReward: "Vow reward: unlock the Moonfire Pact title and open the lunar streak relic.",
            iconSystemName: "flame.circle.fill",
            rarity: .rare
        ),
        badge(
            id: "streak_60",
            displayName: "Inferno Engine",
            description: "Sixty sessions chained. Discipline is no longer a mood.",
            unlockCriteria: "Reach a current training streak of 60 sessions.",
            vowReward: "Vow reward: unlock the Inferno Engine title and claim the overdrive flame relic.",
            iconSystemName: "flame.circle.fill",
            rarity: .rare
        ),
        badge(
            id: "streak_100",
            displayName: "Streak Crown",
            description: "One hundred sessions unbroken. The streak becomes mythology.",
            unlockCriteria: "Reach a current training streak of 100 sessions.",
            vowReward: "Vow reward: unlock the Streak Crown title and crown the streak archive.",
            iconSystemName: "crown.fill",
            rarity: .legendary
        ),

        // MARK: Volume
        badge(
            id: "sessions_10",
            displayName: "Ledger Spark",
            description: "Ten sessions logged. The archive has a pulse.",
            unlockCriteria: "Log at least 10 lifetime training sessions.",
            vowReward: "Vow reward: unlock the Ledger Spark title and forge the first volume crystal.",
            iconSystemName: "10.circle.fill",
            rarity: .common
        ),
        badge(
            id: "sessions_25",
            displayName: "Ritual Sigil",
            description: "Twenty-five sessions. Enough reps to leave fingerprints in the system.",
            unlockCriteria: "Log at least 25 lifetime training sessions.",
            vowReward: "Vow reward: unlock the Ritual Sigil title and add the emerald volume relic.",
            iconSystemName: "25.circle.fill",
            rarity: .common
        ),
        badge(
            id: "sessions_50",
            displayName: "Foundation Forge",
            description: "Fifty sessions. The foundation is not a metaphor anymore.",
            unlockCriteria: "Log at least 50 lifetime training sessions.",
            vowReward: "Vow reward: unlock the Foundation Forge title and burnish the gold volume relic.",
            iconSystemName: "50.circle.fill",
            rarity: .rare
        ),
        badge(
            id: "sessions_100",
            displayName: "Archive Engine",
            description: "One hundred sessions. Your training history starts looking dangerous.",
            unlockCriteria: "Log at least 100 lifetime training sessions.",
            vowReward: "Vow reward: unlock the Archive Engine title and awaken the violet volume core.",
            iconSystemName: "100.circle.fill",
            rarity: .rare
        ),
        badge(
            id: "sessions_250",
            displayName: "Phantom Mantle",
            description: "Two hundred fifty sessions. This is the point where excuses stop recognizing you.",
            unlockCriteria: "Log at least 250 lifetime training sessions.",
            vowReward: "Vow reward: unlock the Phantom Mantle title and claim the sprinting titan relic.",
            iconSystemName: "trophy.fill",
            rarity: .legendary
        ),
        badge(
            id: "sessions_500",
            displayName: "Titan Archive",
            description: "Five hundred sessions. Almost nobody gets a silhouette this heavy.",
            unlockCriteria: "Log at least 500 lifetime training sessions.",
            vowReward: "Vow reward: unlock the Titan Archive title and seal the colossal archive relic.",
            iconSystemName: "trophy.fill",
            rarity: .legendary
        ),

        // MARK: Session quality
        badge(
            id: "clean_sweep",
            displayName: "No-Skip Seal",
            description: "Every exercise finished. Nothing dodged, nothing left behind.",
            unlockCriteria: "Complete a logged session where every exercise is finished and none are skipped.",
            vowReward: "Vow reward: unlock the No-Skip Seal title and claim the clean-sweep relic.",
            iconSystemName: "checkmark.seal.fill",
            rarity: .common
        ),
        badge(
            id: "hour_glass",
            displayName: "Hourglass Trial",
            description: "Sixty minutes under load. Time noticed.",
            unlockCriteria: "Log a training session with a duration of 60 minutes or more.",
            vowReward: "Vow reward: unlock the Hourglass Trial title and turn the long-hour relic.",
            iconSystemName: "hourglass",
            rarity: .common
        ),

        // MARK: Rank milestones
        badge(
            id: "first_rank_up",
            displayName: "First Break",
            description: "Your first rank crossing. The ladder finally answers.",
            unlockCriteria: "Trigger your first rank change on any tracked movement.",
            vowReward: "Vow reward: unlock the First Break title and raise the chevron relic.",
            iconSystemName: "arrow.up.right.circle.fill",
            rarity: .common
        ),
        badge(
            id: "rank_c_any",
            displayName: "Crest of C",
            description: "The first real gate clears. You are past beginner gravity.",
            unlockCriteria: "Advance any tracked movement to Forged rank or higher.",
            vowReward: "Vow reward: unlock the Crest of C title and equip the emerald rank crest.",
            iconSystemName: "c.circle.fill",
            rarity: .common
        ),
        badge(
            id: "rank_b_any",
            displayName: "B-Rank Breaker",
            description: "B-rank is where casual effort starts getting rejected.",
            unlockCriteria: "Advance any tracked movement to Master rank or higher.",
            vowReward: "Vow reward: unlock the B-Rank Breaker title and claim the amethyst rank crest.",
            iconSystemName: "b.circle.fill",
            rarity: .rare
        ),
        badge(
            id: "rank_a_any",
            displayName: "A-Rank Sovereign",
            description: "A-rank means the movement had to make room for you.",
            unlockCriteria: "Advance any tracked movement to Vessel rank or higher.",
            vowReward: "Vow reward: unlock the A-Rank Sovereign title and take the gold rank crest.",
            iconSystemName: "a.circle.fill",
            rarity: .rare
        ),
        badge(
            id: "rank_s_any",
            displayName: "S-Rank Eclipse",
            description: "S-rank is the summit throwing a shadow behind you.",
            unlockCriteria: "Advance any tracked movement to Ascendant rank or higher.",
            vowReward: "Vow reward: unlock the S-Rank Eclipse title and awaken the eclipse crest.",
            iconSystemName: "s.circle.fill",
            rarity: .legendary
        ),

        // MARK: Skills
        badge(
            id: "first_muscle_up",
            displayName: "Muscle-Up Gate",
            description: "You crossed the bar instead of stopping beneath it.",
            unlockCriteria: "Log any non-warmup set of a muscle-up variation with at least 1 rep.",
            vowReward: "Vow reward: unlock the Muscle-Up Gate title and claim the ring-gate relic.",
            iconSystemName: "figure.climbing",
            rarity: .legendary
        ),
        badge(
            id: "first_handstand_pushup",
            displayName: "Inverted Press",
            description: "Gravity got put on the wrong side of the argument.",
            unlockCriteria: "Log any non-warmup set of handstand push-ups with at least 1 rep.",
            vowReward: "Vow reward: unlock the Inverted Press title and claim the upside-down relic.",
            iconSystemName: "figure.gymnastics",
            rarity: .legendary
        ),
        badge(
            id: "first_pullup",
            displayName: "Bar Conqueror",
            description: "Chin over bar. The simplest proof still hits hard.",
            unlockCriteria: "Log any non-warmup pull-up or chin-up set with at least 1 rep.",
            vowReward: "Vow reward: unlock the Bar Conqueror title and claim the pull-gate relic.",
            iconSystemName: "figure.play",
            rarity: .common
        ),
        badge(
            id: "first_dip",
            displayName: "Dip Cipher",
            description: "Down, up, locked out. The bars accepted the password.",
            unlockCriteria: "Log any non-warmup dip set with at least 1 rep.",
            vowReward: "Vow reward: unlock the Dip Cipher title and claim the parallel-bar relic.",
            iconSystemName: "figure.strengthtraining.functional",
            rarity: .common
        ),
        badge(
            id: "first_pistol_squat",
            displayName: "Pistol Monarch",
            description: "One leg stood alone and still won the argument.",
            unlockCriteria: "Log any non-warmup pistol squat set with at least 1 rep.",
            vowReward: "Vow reward: unlock the Pistol Monarch title and claim the single-leg crown relic.",
            iconSystemName: "figure.fall",
            rarity: .rare
        ),
        badge(
            id: "pushup_50_set",
            displayName: "Rep Cannon",
            description: "Fifty push-ups in one set. The floor filed a complaint.",
            unlockCriteria: "Log a non-warmup push-up set with 50 or more reps.",
            vowReward: "Vow reward: unlock the Rep Cannon title and load the push relic.",
            iconSystemName: "figure.core.training",
            rarity: .rare
        ),

        // MARK: Strength relative
        badge(
            id: "bw_squat_2x",
            displayName: "Squat Colossus",
            description: "Two times bodyweight on the squat. The floor gets negotiated with.",
            unlockCriteria: "With bodyweight saved, log a squat working set at 2x bodyweight or heavier.",
            vowReward: "Vow reward: unlock the Squat Colossus title and claim the leg-day monolith.",
            iconSystemName: "figure.strengthtraining.traditional",
            rarity: .rare
        ),
        badge(
            id: "bw_bench_1_5x",
            displayName: "Bench Titan",
            description: "A bench press heavy enough to make the bar feel personal.",
            unlockCriteria: "With bodyweight saved, log a bench press working set at 1.5x bodyweight or heavier.",
            vowReward: "Vow reward: unlock the Bench Titan title and claim the iron-press relic.",
            iconSystemName: "figure.strengthtraining.functional",
            rarity: .rare
        ),
        badge(
            id: "bw_deadlift_3x",
            displayName: "Deadlift Abyss",
            description: "Three times bodyweight from the floor. That is not a lift; that is a warning.",
            unlockCriteria: "With bodyweight saved, log a deadlift working set at 3x bodyweight or heavier.",
            vowReward: "Vow reward: unlock the Deadlift Abyss title and open the abyssal pull relic.",
            iconSystemName: "figure.cooldown",
            rarity: .legendary
        ),

        // MARK: Scan habit
        badge(
            id: "scan_streak_3",
            displayName: "Scan Signal",
            description: "Three scans. Enough signal for the arc to start speaking back.",
            unlockCriteria: "Complete at least 3 body scans.",
            vowReward: "Vow reward: unlock the Scan Signal title and charge the scan crystal.",
            iconSystemName: "chart.line.uptrend.xyaxis",
            rarity: .rare
        ),
        badge(
            id: "scan_archive_5",
            displayName: "Proof Archive",
            description: "Five scans banked. The proof is starting to stack.",
            unlockCriteria: "Complete at least 5 body scans.",
            vowReward: "Vow reward: unlock the Proof Archive title and claim the silver archive relic.",
            iconSystemName: "square.stack.3d.up.fill",
            rarity: .rare
        ),
        badge(
            id: "scan_archive_10",
            displayName: "Scan Vault",
            description: "Ten scans on record. Your progress has a vault now.",
            unlockCriteria: "Complete at least 10 body scans.",
            vowReward: "Vow reward: unlock the Scan Vault title and seal the body-archive vault.",
            iconSystemName: "square.stack.3d.up.fill",
            rarity: .legendary
        ),

        // MARK: Photo ritual (daily capture + cadence)
        badge(
            id: "first_photo",
            displayName: "Origin Proof",
            description: "The first progress photo. The story gets a timestamp.",
            unlockCriteria: "Capture your first progress photo.",
            vowReward: "Vow reward: unlock the Origin Proof title and claim the first-photo relic.",
            iconSystemName: "camera.fill",
            rarity: .common
        ),
        badge(
            id: "biweekly_scan",
            displayName: "Biweekly Oracle",
            description: "Two scan checkpoints close enough to show the pattern forming.",
            unlockCriteria: "Complete 2 scan-sourced progress checkpoints within 14 days of each other.",
            vowReward: "Vow reward: unlock the Biweekly Oracle title and claim the cadence-camera relic.",
            iconSystemName: "sparkle.magnifyingglass",
            rarity: .rare
        ),
        badge(
            id: "monthly_arc",
            displayName: "Monthly Chronicle",
            description: "Four captures in thirty days. The month cannot gaslight you anymore.",
            unlockCriteria: "Capture 4 or more progress photos or scans in a rolling 30-day window.",
            vowReward: "Vow reward: unlock the Monthly Chronicle title and bind the month-stack relic.",
            iconSystemName: "calendar.badge.checkmark",
            rarity: .rare
        ),
        badge(
            id: "proof_10",
            displayName: "Proof Stack",
            description: "Ten progress captures. The receipts are starting to look loud.",
            unlockCriteria: "Bank at least 10 total progress captures across photos and scans.",
            vowReward: "Vow reward: unlock the Proof Stack title and claim the proof-stack relic.",
            iconSystemName: "photo.stack.fill",
            rarity: .rare
        ),
        badge(
            id: "proof_25",
            displayName: "Proof Testament",
            description: "Twenty-five captures. That is not a gallery; that is testimony.",
            unlockCriteria: "Bank at least 25 total progress captures across photos and scans.",
            vowReward: "Vow reward: unlock the Proof Testament title and open the black-ledger relic.",
            iconSystemName: "photo.stack.fill",
            rarity: .legendary
        )
    ]

    static var byId: [String: Badge] {
        Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    }

    private static func badge(
        id: String,
        displayName: String,
        description: String,
        unlockCriteria: String,
        vowReward: String,
        iconSystemName: String,
        rarity: Badge.Rarity
    ) -> Badge {
        Badge(
            id: id,
            displayName: displayName,
            description: description,
            unlockCriteria: unlockCriteria,
            vowReward: vowReward,
            iconSystemName: iconSystemName,
            rarity: rarity,
            unlockedAt: nil
        )
    }
}
