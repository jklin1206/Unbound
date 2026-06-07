import XCTest
@testable import UNBOUND

@MainActor
extension TrainingSessionAdapterTests {
    func testTrainingSessionEditSummaryClassifiesAddRemoveSwapAndReorder() {
        let original = makeDraft(["Bench Press", "Overhead Press", "Pullup"])

        var added = original
        added.blocks[0].prescriptions.append(makePrescription("Dumbbell Row"))
        var summary = TrainingSessionEditSummary.compare(original: original, edited: added)
        XCTAssertEqual(summary.addedCount, 1)
        XCTAssertEqual(summary.removedCount, 0)
        XCTAssertEqual(summary.changedSlotCount, 0)
        XCTAssertFalse(summary.reordered)
        XCTAssertEqual(summary.headline, "1 edit staged")

        var removed = original
        removed.blocks[0].prescriptions.remove(at: 1)
        summary = TrainingSessionEditSummary.compare(original: original, edited: removed)
        XCTAssertEqual(summary.addedCount, 0)
        XCTAssertEqual(summary.removedCount, 1)
        XCTAssertEqual(summary.changedSlotCount, 0)

        var swapped = original
        swapped.blocks[0].prescriptions[1] = makePrescription("Seated Dumbbell Press")
        summary = TrainingSessionEditSummary.compare(original: original, edited: swapped)
        XCTAssertEqual(summary.addedCount, 0)
        XCTAssertEqual(summary.removedCount, 0)
        XCTAssertEqual(summary.changedSlotCount, 1)
        XCTAssertFalse(summary.reordered)

        var reordered = original
        reordered.blocks[0].prescriptions.swapAt(0, 1)
        summary = TrainingSessionEditSummary.compare(original: original, edited: reordered)
        XCTAssertEqual(summary.addedCount, 0)
        XCTAssertEqual(summary.removedCount, 0)
        XCTAssertEqual(summary.changedSlotCount, 0)
        XCTAssertTrue(summary.reordered)
    }

    func testTrainingSessionEditPersistenceModesAreExecutable() {
        XCTAssertTrue(TrainingSessionEditPersistence.todayOnly.isImplemented)
        XCTAssertTrue(TrainingSessionEditPersistence.recurringSubstitution.isImplemented)
        XCTAssertTrue(TrainingSessionEditPersistence.equipmentPreference.isImplemented)
        XCTAssertTrue(TrainingSessionEditPersistence.nextBlockBias.isImplemented)
        XCTAssertEqual(TrainingSessionEditPersistence.todayOnly.displayName, "Today only")
    }

    func testSkillRungResolverChoosesRegressionWhenSkillIsNotTrainable() throws {
        let decision = try XCTUnwrap(
            SkillRungResolver.resolve(skillId: "pp.muscle-up", isTrainable: false)
        )

        XCTAssertEqual(decision.targetSkillId, "pp.muscle-up")
        XCTAssertEqual(decision.source, .regression)
        XCTAssertEqual(decision.selectedRungTitle, "10 Strict Pull-Ups")
        XCTAssertEqual(decision.prescriptions.first?.exerciseName, "10 Strict Pull-Ups")
        XCTAssertTrue(decision.reason.contains("Build toward"))
    }

    func testDecisionSkillBlockCarriesSelectedRungMetadata() throws {
        let decision = try XCTUnwrap(
            SkillRungResolver.resolve(skillId: "pp.muscle-up", isTrainable: false)
        )
        let block = TrainingSessionAdapters.skillBlock(decision: decision)

        XCTAssertEqual(block.kind, .skill)
        XCTAssertEqual(block.skillId, "pp.muscle-up")
        XCTAssertEqual(block.selectedRungId, decision.selectedRungId)
        XCTAssertEqual(block.selectedRungSource, .regression)
        XCTAssertEqual(block.selectedRungReason, decision.reason)
        XCTAssertEqual(block.subtitle, "10 Strict Pull-Ups")
        XCTAssertEqual(block.prescriptions.first?.exerciseName, "10 Strict Pull-Ups")
    }

    func testSkillTrainingReviewPromotesCleanCompletedRegressionToNextRung() throws {
        let firstRungId = SkillRungResolver.regressionRungId(
            skillId: "pp.muscle-up",
            name: "10 Strict Pull-Ups"
        )
        let log = makeSkillRungPerformanceLog(
            skillId: "pp.muscle-up",
            skillTitle: "Muscle-Up",
            rungId: firstRungId,
            exerciseName: "10 Strict Pull-Ups",
            sets: [
                PerformanceSet(setNumber: 1, reps: 8, rpe: 7, qualityFlags: [.clean]),
                PerformanceSet(setNumber: 2, reps: 8, rpe: 7, qualityFlags: [.clean]),
                PerformanceSet(setNumber: 3, reps: 8, rpe: 8, qualityFlags: [.clean])
            ]
        )

        let review = try XCTUnwrap(SkillTrainingReviewAgent.evaluate(performanceLog: log).first)
        XCTAssertEqual(review.outcome, .promote)
        XCTAssertEqual(review.selectedRungId, firstRungId)
        XCTAssertEqual(review.completedSets, 3)
        XCTAssertEqual(review.cleanSetRatio, 1.0)

        let next = try XCTUnwrap(
            SkillRungResolver.resolve(
                skillId: "pp.muscle-up",
                isTrainable: false,
                lastReview: review
            )
        )
        XCTAssertEqual(next.selectedRungTitle, "10 Strict Dips")
        XCTAssertTrue(next.reason.contains("Advance one regression rung"))
    }

    func testSkillTrainingReviewHoldsAssistedRegression() throws {
        let rungId = SkillRungResolver.regressionRungId(
            skillId: "pp.muscle-up",
            name: "10 Strict Pull-Ups"
        )
        let log = makeSkillRungPerformanceLog(
            skillId: "pp.muscle-up",
            skillTitle: "Muscle-Up",
            rungId: rungId,
            exerciseName: "10 Strict Pull-Ups",
            sets: [
                PerformanceSet(setNumber: 1, reps: 8, rpe: 7, qualityFlags: [.assisted]),
                PerformanceSet(setNumber: 2, reps: 8, rpe: 7, qualityFlags: [.assisted]),
                PerformanceSet(setNumber: 3, reps: 8, rpe: 8, qualityFlags: [.assisted])
            ]
        )

        let review = try XCTUnwrap(SkillTrainingReviewAgent.evaluate(performanceLog: log).first)
        XCTAssertEqual(review.outcome, .hold)
        XCTAssertTrue(review.reason.contains("assistance"))

        let next = try XCTUnwrap(
            SkillRungResolver.resolve(
                skillId: "pp.muscle-up",
                isTrainable: false,
                lastReview: review
            )
        )
        XCTAssertEqual(next.selectedRungTitle, "10 Strict Pull-Ups")
    }

    func testSkillTrainingReviewRegressesPainFromCurrentRung() throws {
        let secondRungId = SkillRungResolver.regressionRungId(
            skillId: "pp.muscle-up",
            name: "10 Strict Dips"
        )
        let log = makeSkillRungPerformanceLog(
            skillId: "pp.muscle-up",
            skillTitle: "Muscle-Up",
            rungId: secondRungId,
            exerciseName: "10 Strict Dips",
            sets: [
                PerformanceSet(setNumber: 1, reps: 8, rpe: 7, qualityFlags: [.clean]),
                PerformanceSet(setNumber: 2, reps: 5, rpe: 9, qualityFlags: [.pain])
            ]
        )

        let review = try XCTUnwrap(SkillTrainingReviewAgent.evaluate(performanceLog: log).first)
        XCTAssertEqual(review.outcome, .regress)
        XCTAssertTrue(review.reason.contains("Pain"))

        let next = try XCTUnwrap(
            SkillRungResolver.resolve(
                skillId: "pp.muscle-up",
                isTrainable: false,
                lastReview: review
            )
        )
        XCTAssertEqual(next.selectedRungTitle, "10 Strict Pull-Ups")
    }

    func testTrainingSessionEditPreferenceBuilderCreatesRecurringAndAvailablePreferences() throws {
        let original = makeDraft(["Bench Press", "Lat Pulldown"])
        var edited = original
        edited.blocks[0].prescriptions[0] = makePrescription("Dumbbell Bench Press")
        edited.blocks[0].prescriptions[1] = makePrescription("Cable Row (Seated)")

        let swaps = TrainingSessionEditPreferenceBuilder.swapEdits(original: original, edited: edited)
        XCTAssertEqual(swaps.map(\.originalExerciseName), ["Bench Press", "Lat Pulldown"])
        XCTAssertEqual(swaps.map(\.replacementExerciseName), ["Dumbbell Bench Press", "Cable Row (Seated)"])

        let recurring = TrainingSessionEditPreferenceBuilder.preferences(
            for: swaps,
            mode: .recurringSubstitution,
            userId: "u1",
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        XCTAssertEqual(recurring.count, 2)
        let benchPreference = try XCTUnwrap(recurring.first { $0.displayName == "Barbell Bench Press" })
        XCTAssertEqual(benchPreference.status, .substitute)
        XCTAssertEqual(benchPreference.exerciseName, "bench press")
        XCTAssertEqual(benchPreference.substitutePreference, "dumbbell bench press")

        let available = TrainingSessionEditPreferenceBuilder.preferences(
            for: swaps,
            mode: .equipmentPreference,
            userId: "u1",
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        XCTAssertEqual(available.count, 2)
        XCTAssertTrue(available.allSatisfy { $0.status == .available && $0.substitutePreference == nil })
        XCTAssertTrue(available.contains { $0.exerciseName == "dumbbell bench press" })
        XCTAssertTrue(available.contains { $0.exerciseName == "cable row (seated)" })

        let nextBlock = TrainingSessionEditPreferenceBuilder.preferences(
            for: swaps,
            mode: .nextBlockBias,
            userId: "u1",
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        XCTAssertEqual(nextBlock.count, 2)
        XCTAssertTrue(nextBlock.allSatisfy { $0.status == .substitute })
        XCTAssertEqual(
            nextBlock.first { $0.exerciseName == "bench press" }?.notes,
            "Queued from Session Editor for the next block proposal."
        )
    }

    func testTrainingSessionAdaptationSummaryExplainsResolvedDraftChanges() {
        let draft = TrainingSessionDraft(
            id: "draft-adaptation-summary",
            userId: "u1",
            source: .program,
            title: "Adapted Upper",
            estimatedMinutes: 45,
            blocks: [
                TrainingBlock(
                    id: "skill-block",
                    kind: .skill,
                    title: "Handstand",
                    skillId: "hs.wall-handstand-30",
                    prescriptions: [
                        TrainingBlockPrescription(
                            exerciseName: "Wall Handstand Hold",
                            sets: 2,
                            target: .holdSeconds(30),
                            restSeconds: 60
                        )
                    ]
                ),
                TrainingBlock(
                    id: "main-block",
                    kind: .strength,
                    title: "Main Work",
                    prescriptions: [
                        TrainingBlockPrescription(
                            exerciseName: "Dumbbell Bench Press",
                            sets: 3,
                            target: .repsRange(8, 10),
                            restSeconds: 120,
                            notes: "Adjusted for today's modifiers."
                        ),
                        TrainingBlockPrescription(
                            exerciseName: "Lat Pulldown",
                            sets: 2,
                            target: .repsRange(8, 12),
                            restSeconds: 90,
                            notes: "Deload modifier applied. Volume tapered for scheduled skill work."
                        ),
                        TrainingBlockPrescription(
                            exerciseName: "Pushup",
                            sets: 2,
                            target: .reps(8),
                            restSeconds: 90,
                            notes: "Trial prep modifier."
                        )
                    ]
                )
            ]
        )

        let lines = TrainingSessionAdaptationSummary.summarize(draft: draft, isTravelDay: true)

        XCTAssertEqual(
            lines.map(\.kind),
            [.scheduledSkill, .travel, .substitution, .deload, .trialPrep, .skillTaper]
        )
        XCTAssertTrue(lines.allSatisfy { !$0.title.isEmpty && !$0.detail.isEmpty })
    }

    func testProgramModifierSummaryPrioritizesAndCapsVisibleLines() {
        let draft = TrainingSessionDraft(
            id: "draft-modifier-summary",
            userId: "u1",
            source: .program,
            title: "Adapted Upper",
            estimatedMinutes: 45,
            blocks: [
                TrainingBlock(
                    id: "skill-block",
                    kind: .skill,
                    title: "Handstand",
                    skillId: "hs.wall-handstand-30",
                    prescriptions: [
                        TrainingBlockPrescription(
                            exerciseName: "Wall Handstand Hold",
                            sets: 2,
                            target: .holdSeconds(30),
                            restSeconds: 60
                        )
                    ]
                ),
                TrainingBlock(
                    id: "main-block",
                    kind: .strength,
                    title: "Main Work",
                    prescriptions: [
                        TrainingBlockPrescription(
                            exerciseName: "Dumbbell Bench Press",
                            sets: 3,
                            target: .repsRange(8, 10),
                            restSeconds: 120,
                            notes: "Adjusted for today's modifiers."
                        ),
                        TrainingBlockPrescription(
                            exerciseName: "Lat Pulldown",
                            sets: 2,
                            target: .repsRange(8, 12),
                            restSeconds: 90,
                            notes: "Deload modifier applied. Volume tapered for scheduled skill work."
                        ),
                        TrainingBlockPrescription(
                            exerciseName: "Pushup",
                            sets: 2,
                            target: .reps(8),
                            restSeconds: 90,
                            notes: "Trial prep modifier."
                        )
                    ]
                )
            ]
        )

        let summary = ProgramModifierSummary.summarize(
            draft: draft,
            isTravelDay: true,
            visibleLimit: 3
        )

        XCTAssertEqual(summary.lines.count, 6)
        XCTAssertEqual(summary.visibleLines.count, 3)
        XCTAssertEqual(summary.overflowCount, 3)
        XCTAssertEqual(summary.visibleLines.map(\.kind), [.deload, .substitution, .travel])
        XCTAssertEqual(summary.visibleLines.first?.iconName, "gauge.with.dots.needle.33percent")
        XCTAssertEqual(summary.visibleLines.first?.colorRole, .neutral)
    }

}
