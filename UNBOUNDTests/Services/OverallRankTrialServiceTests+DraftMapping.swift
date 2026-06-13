import XCTest
@testable import UNBOUND

extension OverallRankTrialServiceTests {
    func testTrialRunnerDraftMapsToValidPerformanceLogBlocks() {
        let definition = OverallRankTrialDefinitions.firstLight
        let draft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: "u1",
            date: Date(timeIntervalSince1970: 100)
        )
        let log = OverallRankTrialRunner.shared.performanceLog(
            from: draft,
            userId: "u1",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 800),
            passing: true
        )

        XCTAssertEqual(draft.source, .overallRankTrial)
        XCTAssertEqual(draft.programId, definition.id)
        XCTAssertEqual(log.source, .overallRankTrial)
        XCTAssertEqual(log.programId, definition.id)
        XCTAssertEqual(log.blocks.count, draft.blocks.count)
        XCTAssertTrue(log.blocks.flatMap(\.exercises).allSatisfy { !$0.sets.isEmpty })
        XCTAssertTrue(OverallRankTrialRunner.shared.evaluatePerformance(log, against: definition))
    }

    func testTheCountDraftMapsToResolvedStationFloors() throws {
        let definition = OverallRankTrialDefinitions.theCount
        let resolved = try XCTUnwrap(resolvedTrial(for: definition, loadout: .homeKit))
        let draft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: "u1",
            date: Date(timeIntervalSince1970: 100),
            resolvedTrial: resolved
        )

        XCTAssertEqual(definition.format, .theCount)
        XCTAssertEqual(draft.title, "The Count")
        XCTAssertEqual(draft.estimatedMinutes, 20)
        XCTAssertEqual(resolved.stations.map(\.category), [.engine, .lower, .push, .pull, .carryCore, .mobilityControl])
        assertDraft(draft, matches: definition, resolvedTrial: resolved)
        assertDraftPassesAndFails(draft, against: definition)
    }

    func testTheForgingDraftMapsToStrikeStations() throws {
        let definition = OverallRankTrialDefinitions.theForging
        let resolved = try XCTUnwrap(resolvedTrial(for: definition, loadout: .homeKit))
        let bodyweightKg = 82.0
        let draft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: "u1",
            date: Date(timeIntervalSince1970: 100),
            resolvedTrial: resolved,
            bodyweightKg: bodyweightKg
        )

        XCTAssertEqual(definition.format, .theForging)
        XCTAssertEqual(draft.title, "The Forging")
        XCTAssertEqual(draft.estimatedMinutes, 30)
        XCTAssertEqual(resolved.stations.count, 5)
        XCTAssertEqual(resolved.stations.map(\.category), [.engine, .hingePower, .push, .pull, .carryCore])
        assertDraft(draft, matches: definition, resolvedTrial: resolved)
        assertDraftPassesAndFails(draft, against: definition, bodyweightKg: bodyweightKg)
    }

    func testDeckOfProofDraftDealsRandomDrawOrder() throws {
        let definition = OverallRankTrialDefinitions.deckOfProof
        let resolved = try XCTUnwrap(resolvedTrial(for: definition, loadout: .homeKit))
        let draft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: "u1",
            date: Date(timeIntervalSince1970: 100),
            resolvedTrial: resolved
        )

        XCTAssertEqual(definition.format, .deckOfProof)
        XCTAssertEqual(draft.title, "Deck of Proof")
        XCTAssertEqual(draft.estimatedMinutes, 42)
        XCTAssertEqual(resolved.stations.count, 52)
        XCTAssertEqual(resolved.stations.filter { $0.category == .push }.count, 13)
        XCTAssertEqual(resolved.stations.filter { $0.category == .lower }.count, 13)
        XCTAssertEqual(resolved.stations.filter { $0.category == .pull }.count, 13)
        XCTAssertEqual(resolved.stations.filter { $0.category == .engine }.count, 0)
        XCTAssertEqual(resolved.stations.filter { $0.category == .carryCore }.count, 13)
        XCTAssertEqual(Array(resolved.stations.map(\.id).prefix(3)), ["deck-card-01", "deck-card-02", "deck-card-03"])
        XCTAssertEqual(Array(resolved.stations.map(\.station.title).prefix(3)), ["Card AH Pushups", "Card 2H Pushups", "Card 3H Pushups"])
        XCTAssertEqual(resolved.stations.first?.standard.minimumValue, 11)
        XCTAssertEqual(Set(resolved.stations.map(\.standard.restSeconds)), [TrialStandards.DeckOfProof.restSeconds])
        XCTAssertEqual(resolved.stations.first { $0.station.title == "Card QC Pullups" }?.standard.minimumValue, 10)
        XCTAssertEqual(draft.blocks.count, resolved.stations.count)
        XCTAssertNotEqual(draft.blocks.map(\.title), resolved.stations.map { $0.station.title })
        XCTAssertEqual(draft.blocks.map(\.title).sorted(), resolved.stations.map { $0.station.title }.sorted())
        XCTAssertEqual(
            draft.blocks.flatMap(\.prescriptions).map(\.movementId).compactMap { $0 }.sorted(),
            resolved.stations.map(\.selectedMovement.movementId).sorted()
        )
        assertDraftPassesAndFails(draft, against: definition)
    }

    func testTheAscentDraftMapsToTenFloorProtocol() throws {
        let definition = OverallRankTrialDefinitions.theAscent
        let resolved = try XCTUnwrap(resolvedTrial(for: definition, loadout: .homeKit))
        let draft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: "u1",
            date: Date(timeIntervalSince1970: 100),
            resolvedTrial: resolved
        )

        assertCatalogBacked(definition)
        XCTAssertEqual(definition.format, .theAscent)
        XCTAssertEqual(draft.title, "The Ascent")
        XCTAssertEqual(draft.estimatedMinutes, 50)
        XCTAssertEqual(resolved.stations.count, 11)
        XCTAssertEqual(resolved.stations.map(\.id).first, "ascent-floor-01")
        XCTAssertEqual(resolved.stations.map(\.id).last, "ascent-floor-10")
        XCTAssertTrue(resolved.stations.map(\.id).contains("ascent-floor-09-push"))
        XCTAssertTrue(resolved.stations.map(\.id).contains("ascent-floor-09-pull"))
        assertDraft(draft, matches: definition, resolvedTrial: resolved)
        assertDraftPassesAndFails(draft, against: definition)
    }

    func testEliteProtocolsScoreCompoundPushAndPullStationsSeparately() throws {
        let ascent = try XCTUnwrap(resolvedTrial(for: OverallRankTrialDefinitions.theAscent, loadout: .homeKit))
        let sevenSeals = try XCTUnwrap(resolvedTrial(for: OverallRankTrialDefinitions.sevenSeals, loadout: .homeKit))

        XCTAssertEqual(ascent.stations.first { $0.id == "ascent-floor-09-push" }?.category, .push)
        XCTAssertEqual(ascent.stations.first { $0.id == "ascent-floor-09-pull" }?.category, .pull)
        XCTAssertFalse(ascent.stations.map(\.id).contains("ascent-floor-09"))
        XCTAssertEqual(sevenSeals.stations.first { $0.id == "seals-explosiveness" }?.category, .explosive)
        XCTAssertEqual(sevenSeals.stations.first { $0.id == "seals-power-hinge" }?.category, .hingePower)
        XCTAssertEqual(sevenSeals.stations.first { $0.id == "seals-power-press" }?.category, .push)
        XCTAssertEqual(sevenSeals.stations.last?.id, "seals-spirit")
        XCTAssertFalse(sevenSeals.stations.map(\.id).contains { $0.hasPrefix("boss-") })
    }

    func testUpperRankDraftsMapToResolvedProtocolsForEveryNewDefinition() throws {
        for trialCase in upperRankTrialCases {
            let definition = trialCase.definition
            let resolved = try XCTUnwrap(resolvedTrial(for: definition, loadout: .homeKit), definition.displayName)
            let bodyweightKg = definition.loadoutVariants
                .flatMap(\.stations)
                .contains { $0.strengthTier != nil } ? 80.0 : nil
            let draft = OverallRankTrialRunner.shared.draft(
                for: definition,
                userId: "u1",
                date: Date(timeIntervalSince1970: 100),
                resolvedTrial: resolved,
                bodyweightKg: bodyweightKg
            )

            assertCatalogBacked(definition)
            assertDraft(draft, matches: definition, resolvedTrial: resolved)
            assertDraftPassesAndFails(draft, against: definition, bodyweightKg: bodyweightKg)
        }
    }

    func testAllRankTrialsCanBeCompletedThroughActiveWorkoutSessionTapThrough() throws {
        for definition in OverallRankTrialDefinitions.all {
            for loadout in TrialLoadout.allCases {
                let resolved = try XCTUnwrap(
                    resolvedTrial(for: definition, loadout: loadout),
                    "\(definition.displayName) / \(loadout.displayName)"
                )
                let draft = OverallRankTrialRunner.shared.draft(
                    for: definition,
                    userId: "u1",
                    date: Date(timeIntervalSince1970: 100),
                    resolvedTrial: resolved,
                    bodyweightKg: 82
                )
                let session = ActiveWorkoutSession(trainingDraft: draft)

                for exerciseIndex in session.exercises.indices {
                    for setIndex in session.exercises[exerciseIndex].sets.indices {
                        session.confirmAsPlanned(exerciseIndex: exerciseIndex, setIndex: setIndex)
                    }
                }

                let progress = session.progressSummary
                let performanceLog = session.assemblePerformanceLog(userId: "u1")
                let evaluationBodyweightKg = definition.loadoutVariants
                    .flatMap(\.stations)
                    .contains { $0.strengthTier != nil } ? 80.0 : 82.0
                let evaluation = OverallRankTrialRunner.shared.evaluateDetailed(
                    performanceLog,
                    against: definition,
                    bodyweightKg: evaluationBodyweightKg
                )

                XCTAssertEqual(session.source, .overallRankTrial, definition.displayName)
                XCTAssertEqual(session.programId, definition.id, definition.displayName)
                XCTAssertFalse(session.hasUnloggedWorkingSets, "\(definition.displayName) / \(loadout.displayName)")
                XCTAssertEqual(progress.loggedWorkingSets, progress.totalWorkingSets, "\(definition.displayName) / \(loadout.displayName)")
                XCTAssertEqual(performanceLog.blocks.count, draft.blocks.count, "\(definition.displayName) / \(loadout.displayName)")
                XCTAssertTrue(evaluation.passed, "\(definition.displayName) / \(loadout.displayName): \(evaluation.failedStation?.failureReason ?? "failed")")
                XCTAssertNil(evaluation.failedStation, "\(definition.displayName) / \(loadout.displayName)")
            }
        }
    }

}
