#if DEBUG
import Foundation
import UIKit

// MARK: - Arc recap demo seed
//
// `--unbound-arc-recap-demo`: boots straight into a block-complete surface
// with a full recap story — a 30-day window of performance logs with real
// load/rep climbs, an attribute snapshot pinned at block start, and a level
// climb anchored by a dated completion receipt — so the end-of-Arc recap
// sequence can be reviewed on-sim with honest data.

extension DevBuildBootstrapper {
    static let arcRecapDemoArg = "--unbound-arc-recap-demo"

    static func seedArcRecapDemo() async {
        AuthService.shared.activateDevUser(id: userId)
        await seedProgramProofState(rawValue: ProgramProofState.blockComplete.rawValue)

        let now = Date()
        let windowStart = now.addingTimeInterval(-31 * 86_400)

        await seedArcRecapBlock(windowStart: windowStart, now: now)
        await seedArcRecapPerformanceLogs(windowStart: windowStart)
        await seedArcRecapLevelReceipt(windowStart: windowStart, now: now)
        await seedArcRecapBeforePhoto(windowStart: windowStart)
    }

    /// A rendered stand-in for the photo taken at the previous Arc's recap,
    /// so the photo beat demos its before/after pair.
    private static func seedArcRecapBeforePhoto(windowStart: Date) async {
        let size = CGSize(width: 600, height: 800)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            let colors = [UIColor(white: 0.16, alpha: 1).cgColor, UIColor.black.cgColor]
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0, 1]
            ) {
                context.cgContext.drawLinearGradient(
                    gradient,
                    start: .zero,
                    end: CGPoint(x: 0, y: size.height),
                    options: []
                )
            }
            let figure = UIImage(
                systemName: "figure.stand",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 260, weight: .regular)
            )?.withTintColor(UIColor(white: 0.42, alpha: 1))
            if let figure {
                let rect = CGRect(
                    x: (size.width - figure.size.width) / 2,
                    y: (size.height - figure.size.height) / 2,
                    width: figure.size.width,
                    height: figure.size.height
                )
                figure.draw(in: rect)
            }
        }
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }

        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ScanPhotos/\(userId)/arc-recap-demo", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("before.jpg")
        try? data.write(to: fileURL)

        let photo = ProgressPhoto(
            id: "arc-recap-demo-before-photo",
            userId: userId,
            storageUrl: fileURL.path,
            capturedAt: windowStart.addingTimeInterval(-86_400),
            source: .manual
        )
        try? await DatabaseService.shared.create(
            photo,
            collection: "progressPhotos",
            documentId: photo.id
        )
    }

    // MARK: Attribute story (hex before/after)

    @MainActor
    private static func seedArcRecapBlock(windowStart: Date, now: Date) async {
        func profile(levels: [AttributeKey: Int], at date: Date) -> AttributeProfile {
            AttributeProfile(
                userId: userId,
                values: Dictionary(uniqueKeysWithValues: levels.map { key, level in
                    (key, AttributeValue(
                        xp: AttributeLevelCurve.xpRequired(forLevel: level) + 1,
                        lastContributionAt: date
                    ))
                }),
                computedAt: date
            )
        }

        let before = profile(
            levels: [.power: 18, .vitality: 14, .control: 12, .endurance: 16, .mobility: 8, .explosiveness: 10],
            at: windowStart
        )
        let after = profile(
            levels: [.power: 22, .vitality: 15, .control: 14, .endurance: 19, .mobility: 8, .explosiveness: 13],
            at: now
        )
        AttributeProfileStore.shared.save(after)

        // Mid-ladder experience so the System's difficulty offer demos.
        try? await DatabaseService.shared.update(
            ["experience": Experience.tried.rawValue],
            collection: "users",
            documentId: userId
        )

        let latest = await ProgramBlockStore.shared.latestBlock(userId: userId)
        let block = ProgramBlock(
            id: "arc-recap-demo-block",
            userId: userId,
            programId: "proof-program",
            blockNumber: (latest?.blockNumber ?? 1) + 1,
            startedAt: windowStart,
            scanId: nil,
            startAttributes: AttributeProfileSnapshot(before)
        )
        await ProgramBlockStore.shared.save(block)
    }

    // MARK: Session story (highlights + volume)

    private static func seedArcRecapPerformanceLogs(windowStart: Date) async {
        // First and last sessions carry the notable climbs; the middle
        // sessions make the session count and volume odometer honest.
        let sessions: [(dayOffset: Int, bench: Double, gobletKg: Double, pushupReps: Int)] = [
            (1, 60, 40, 8),
            (4, 60, 40, 9),
            (7, 62.5, 42.5, 9),
            (10, 62.5, 42.5, 10),
            (13, 65, 45, 11),
            (16, 65, 45, 11),
            (19, 67.5, 47.5, 12),
            (22, 67.5, 47.5, 12),
            (25, 70, 50, 13),
            (28, 70, 50, 14)
        ]

        for (index, session) in sessions.enumerated() {
            let startedAt = windowStart.addingTimeInterval(Double(session.dayOffset) * 86_400)
            let log = PerformanceLog(
                id: "arc-recap-demo-log-\(index)",
                userId: userId,
                source: .program,
                title: "Arc Session \(index + 1)",
                startedAt: startedAt,
                completedAt: startedAt.addingTimeInterval(2_700),
                blocks: [
                    PerformanceBlock(
                        id: "arc-recap-demo-block-\(index)",
                        kind: .strength,
                        title: "Main Work",
                        exercises: [
                            demoExercise(name: "Barbell Bench Press", weightKg: session.bench, reps: 8, sets: 4),
                            demoExercise(name: "Goblet Squat", weightKg: session.gobletKg, reps: 10, sets: 3),
                            demoExercise(name: "Push-Up", weightKg: nil, reps: session.pushupReps, sets: 3)
                        ]
                    )
                ]
            )
            try? await DatabaseService.shared.create(
                log,
                collection: "performanceLogs",
                documentId: log.id
            )
        }
    }

    private static func demoExercise(
        name: String,
        weightKg: Double?,
        reps: Int,
        sets: Int
    ) -> PerformanceExercise {
        PerformanceExercise(
            name: name,
            plannedSets: sets,
            plannedTarget: "\(reps)",
            sets: (1...sets).map { setNumber in
                PerformanceSet(
                    setNumber: setNumber,
                    reps: reps,
                    weightKg: weightKg,
                    rpe: 7,
                    isWarmup: false
                )
            }
        )
    }

    // MARK: Level story (climb anchored by a dated receipt)

    private static func seedArcRecapLevelReceipt(windowStart: Date, now: Date) async {
        let xpBefore = OverallLevelCurve.xpRequired(forLevel: 40) + 50
        let xpNow = OverallLevelCurve.xpRequired(forLevel: 42) + 200

        var progress = OverallLevelProgress(userId: userId)
        progress.totalXP = xpNow
        progress.updatedAt = now
        try? await DatabaseService.shared.create(
            progress,
            collection: "overall_level_progress",
            documentId: userId
        )

        // TrainingCompletionRecord only constructs from a live completion
        // result, so the dated anchor decodes from JSON like the unit fixtures.
        let json: [String: Any] = [
            "id": "arc-recap-demo-receipt",
            "performanceLogId": "arc-recap-demo-receipt",
            "userId": userId,
            "completedAt": windowStart.addingTimeInterval(-86_400).timeIntervalSince1970,
            "sessionLogIds": [String](),
            "replay": [
                "movementAPGains": [Any](),
                "movementProgressStates": [Any](),
                "movementProgressPriorStates": [String: Any](),
                "updatedMovementProgressIds": [Any](),
                "attributeRewards": [Any](),
                "attributeRankUpEventCount": 0,
                "bodyMapNoveltyMultiplier": 1,
                "bodyMapRegionRewards": [Any](),
                "overallLevelReward": [
                    "xpGained": 100,
                    "noveltyMultiplier": 1,
                    "previousXP": xpBefore - 100,
                    "currentXP": xpBefore,
                    "previousLevel": OverallLevelCurve.level(forXP: xpBefore - 100),
                    "currentLevel": OverallLevelCurve.level(forXP: xpBefore),
                    "previousProgressToNextLevel": 0,
                    "currentProgressToNextLevel": 0
                ],
                "overallLevelXPGained": 100,
                "skillXPGained": 0,
                "streakCount": 9,
                "streakExtended": true,
                "unlockedSkins": [Any](),
                "bodyweightKg": 80
            ]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: json) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard let record = try? decoder.decode(TrainingCompletionRecord.self, from: data) else { return }
        try? await DatabaseService.shared.create(
            record,
            collection: "training_completion_records",
            documentId: record.id
        )
    }
}
#endif
