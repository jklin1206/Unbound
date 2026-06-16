import XCTest
@testable import UNBOUND

extension WeeklyVowsServiceTests {
    func openCurrentVow(userId: String = "u-1") {
        var state = service.state(userId: userId)
        state.currentVow?.capstoneState = .windowOpen
        store.save(state, userId: userId)
    }

    func makePerformanceLog(
        from draft: TrainingSessionDraft,
        completedAt: Date = Date(timeIntervalSince1970: 1_700_000_600)
    ) -> PerformanceLog {
        let block = draft.blocks[0]
        let exercises = block.prescriptions.enumerated().map { index, prescription in
            PerformanceExercise(
                id: prescription.id,
                name: prescription.exerciseName,
                movementId: prescription.movementId,
                rankStandardMovementId: prescription.rankStandardMovementId,
                plannedSets: prescription.sets,
                plannedTarget: prescription.target.displayText,
                sets: (0..<max(1, prescription.sets)).map { setIndex in
                    PerformanceSet(
                        setNumber: setIndex + 1,
                        reps: 20,
                        weightKg: 100,
                        holdSeconds: 600,
                        durationSeconds: 600,
                        distanceMeters: 5_000,
                        calories: 500,
                        rpe: prescription.rpe
                    )
                }
            )
        }
        return PerformanceLog(
            id: "weekly-vow-log-\(UUID().uuidString)",
            userId: draft.userId,
            draftId: draft.id,
            source: draft.source,
            title: draft.title,
            startedAt: completedAt.addingTimeInterval(-600),
            completedAt: completedAt,
            programId: draft.programId,
            dayNumber: draft.dayNumber,
            blocks: [
                PerformanceBlock(
                    kind: block.kind,
                    title: block.title,
                    skillId: block.skillId,
                    exercises: exercises
                )
            ]
        )
    }

    func makeEmptyPerformanceLog(from draft: TrainingSessionDraft) -> PerformanceLog {
        let block = draft.blocks[0]
        let prescription = block.prescriptions[0]
        let completedAt = Date(timeIntervalSince1970: 1_700_000_600)
        return PerformanceLog(
            id: "weekly-vow-empty-log-\(UUID().uuidString)",
            userId: draft.userId,
            draftId: draft.id,
            source: draft.source,
            title: draft.title,
            startedAt: completedAt.addingTimeInterval(-600),
            completedAt: completedAt,
            programId: draft.programId,
            dayNumber: draft.dayNumber,
            blocks: [
                PerformanceBlock(
                    kind: block.kind,
                    title: block.title,
                    skillId: block.skillId,
                    exercises: [
                        PerformanceExercise(
                            id: prescription.id,
                            name: prescription.exerciseName,
                            movementId: prescription.movementId,
                            rankStandardMovementId: prescription.rankStandardMovementId,
                            plannedSets: prescription.sets,
                            plannedTarget: prescription.target.displayText,
                            sets: []
                        )
                    ]
                )
            ]
        )
    }

    /// EXPAND step (Binding Vows v2 Core-1): `ensureCurrentWeek` now draws from
    /// the bank pool (all cards `kind: .apex`), so the legacy routed-training
    /// tests can no longer fish an `.ember`/`.overdrive` card out of the live
    /// draw. This seeds the SAME legacy 3-card set the old generator produced and
    /// returns the requested kind, keeping those tests exercising the kept
    /// routed-training machinery. Retired in Core-3 along with the routed path.
    @discardableResult
    @MainActor
    func seedLegacyWeekCard(
        _ kind: WeeklyVowKind,
        weekStart: Date = Date(timeIntervalSince1970: 1_700_000_000),
        userId: String = "u-1"
    ) -> WeeklyVowCard {
        let profile = attribute.snapshot(userId: userId, asOf: .now)
        let legacyCards = WeeklyVowGenerator.cards(
            profile: profile,
            history: [],
            weekStart: weekStart,
            weekNumber: 1
        )
        var state = service.state(userId: userId)
        state.currentWeekStart = weekStart
        state.currentWeekCards = legacyCards
        state.currentTrial = nil
        state.skippedCurrentWeek = false
        store.save(state, userId: userId)
        return legacyCards.first { $0.kind == kind }!
    }

    func makeAxisCard(kind: WeeklyVowKind, axis: AttributeKey) -> WeeklyVowCard {
        WeeklyVowCard(
            id: "weekly-vow-test-\(kind.rawValue)-\(axis.rawValue)",
            kind: kind,
            theme: .axis(axis),
            displayName: "\(kind.displayName) · \(axis.displayName)",
            blurb: "A focused proof for \(axis.displayName.lowercased()).",
            capstone: WeeklyVowProof(
                displayName: "Proof",
                description: "Complete the proof work.",
                evaluation: .manualClaim
            ),
            prescription: WeeklyVowPrescription(
                placement: kind == .ember ? .recoveryDay : .afterWorkout,
                minMinutes: kind == .ember ? 8 : 6,
                maxMinutes: kind == .ember ? 12 : 12,
                minRPE: kind == .ember ? 3 : 7,
                maxRPE: kind == .ember ? 5 : 8
            )
        )
    }

    /// Build a v2 lane/bet/target card carrying the transient back-compat old
    /// fields (kind/theme/capstone). Used by Core-1 economics tests.
    func makeVowCard(
        lane: VowLane,
        bet: VowBet,
        target: VowTarget? = nil
    ) -> WeeklyVowCard {
        let resolvedTarget = target ?? VowTarget(count: 1, noun: "session")
        return WeeklyVowCard(
            id: "weekly-vow-test-\(lane.rawValue)-\(bet.rawValue)",
            kind: .apex,
            theme: .wildcard,
            displayName: "\(lane.displayLabel) · \(bet.displayLabel)",
            blurb: "A bound vow for \(lane.displayLabel.lowercased()).",
            capstone: WeeklyVowProof(
                displayName: "Proof",
                description: "Complete the vow.",
                evaluation: .manualClaim
            ),
            prescription: nil,
            lane: lane,
            bet: bet,
            target: resolvedTarget
        )
    }

    func assertNoLegacyWeeklyCopy(
        _ copy: [String],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for text in copy {
            XCTAssertFalse(text.localizedCaseInsensitiveContains("trial"), "Unexpected legacy copy: \(text)", file: file, line: line)
            XCTAssertFalse(text.localizedCaseInsensitiveContains("challenge"), "Unexpected legacy copy: \(text)", file: file, line: line)
        }
    }
}
