import XCTest
import UIKit
@testable import UNBOUND

final class MovementResolverTests: XCTestCase {
    func testEveryCatalogExerciseHasVisualAsset() {
        let exerciseDefinitions = MovementCatalog.definitions
            .filter { $0.role == .canonicalExercise }

        XCTAssertEqual(exerciseDefinitions.count, ExerciseCatalog.allExercises.count)

        for definition in exerciseDefinitions {
            let assetName = ExerciseVisualAsset.assetName(for: definition)

            XCTAssertEqual(
                ExerciseVisualAsset.existingAssetName(for: definition),
                assetName,
                "\(definition.displayName) should resolve \(assetName)"
            )
            XCTAssertNotNil(UIImage(named: assetName), "\(assetName) should ship in Assets.xcassets")
        }
    }

    func testEveryBodyweightProgramCandidateHasVisualAsset() {
        let equipment: [Equipment] = [
            .bodyweight,
            .pullupBar,
            .dipStation,
            .rings,
            .bench,
            .bands
        ]
        let definitions = MovementCatalog.programDefinitions(style: .bodyweight, userEquipment: equipment)

        let missing = definitions.filter { ExerciseVisualAsset.existingAssetName(for: $0) == nil }

        XCTAssertTrue(
            missing.isEmpty,
            "Program candidates missing exercise visuals:\n\(missing.map { "\($0.id) — \($0.displayName)" }.joined(separator: "\n"))"
        )
    }

    func testGeneratedWarmupExercisesResolveToBundledVisualAssets() throws {
        let normalInput = makeWarmupInput(
            trainingStyle: .hybrid,
            equipment: [.bodyweight, .dumbbells, .barbell, .bench],
            experience: .current
        )
        let floorOnlyInput = makeWarmupInput(
            trainingStyle: .bodyweight,
            equipment: [.bodyweight],
            experience: .current
        )
        let warmups = DayTemplate.allCases.flatMap { template in
            DeterministicProgramGenerator.warmupExercises(for: template, input: normalInput)
                + DeterministicProgramGenerator.warmupExercises(for: template, input: floorOnlyInput)
        }
        let uniqueWarmupNames = Set(warmups.map(\.name))

        for name in uniqueWarmupNames.sorted() {
            let resolved = MovementCatalog.resolvedTrainingMovement(name: name)
            let definition = try XCTUnwrap(resolved?.exact, "\(name) should resolve to a movement definition")
            let assetName = try XCTUnwrap(
                ExerciseVisualAsset.existingAssetName(for: definition),
                "\(name) should resolve to a bundled visual asset"
            )
            XCTAssertNotNil(UIImage(named: assetName), "\(name) should load \(assetName)")
        }
    }

    /// Progression variants fall into two groups:
    /// - Movements distinct enough to warrant their own picture must NOT be an
    ///   exact byte-copy of their base.
    /// - Pure depth/difficulty variants intentionally REUSE their base
    ///   movement's picture (the pose is only a few degrees apart, not worth
    ///   distinct art - a confirmed product decision). They must still ship a
    ///   loadable asset, but may equal the base.
    func testProgressionVariantVisualsAreDistinctOrIntentionallyShared() throws {
        let distinctVariantPairs = [
            ("exercise_visual_exercise_tuck-one-leg-nordic-curl", "exercise_visual_exercise_nordic-curl"),
            ("exercise_visual_exercise_one-leg-nordic-curl", "exercise_visual_exercise_nordic-curl"),
            ("exercise_visual_exercise_single-leg-glute-bridge", "exercise_visual_exercise_glute-bridge"),
            ("exercise_visual_exercise_one-arm-inverted-row", "exercise_visual_exercise_one-arm-row"),
            ("exercise_visual_exercise_single-leg-extension", "exercise_visual_exercise_leg-extensions")
        ]

        let sharedBaseVariants = [
            "exercise_visual_exercise_assisted-squat",
            "exercise_visual_exercise_parallel-squat",
            "exercise_visual_exercise_deep-step-up",
            "exercise_visual_exercise_partial-pistol-squat",
            "exercise_visual_exercise_beginner-shrimp-squat",
            "exercise_visual_exercise_intermediate-shrimp-squat",
            "exercise_visual_exercise_two-hand-shrimp-squat",
            "exercise_visual_exercise_elevated-two-hand-shrimp-squat",
            "exercise_visual_exercise_nordic-curl-negative",
            "exercise_visual_exercise_nordic-curl-arms-overhead",
            "exercise_visual_exercise_bodyweight-leg-extension",
            "exercise_visual_exercise_advanced-nordic-hip-hinge"
        ]

        for (variantAssetName, baseAssetName) in distinctVariantPairs {
            let variantImage = try XCTUnwrap(
                UIImage(named: variantAssetName),
                "\(variantAssetName) should ship in Assets.xcassets"
            )
            let baseImage = try XCTUnwrap(
                UIImage(named: baseAssetName),
                "\(baseAssetName) should ship in Assets.xcassets"
            )
            XCTAssertNotEqual(
                variantImage.pngData(),
                baseImage.pngData(),
                "\(variantAssetName) should have its own distinct picture, not a copy of \(baseAssetName)"
            )
        }

        for variantAssetName in sharedBaseVariants {
            XCTAssertNotNil(
                UIImage(named: variantAssetName),
                "\(variantAssetName) should ship a loadable asset (may intentionally reuse its base picture)"
            )
        }
    }

    func testBandProgramExercisesResolveToDirectCurrentBandVisuals() throws {
        let expectedAssetsByMovementId = [
            "exercise.band-row": "exercise_visual_exercise_band-row",
            "exercise.band-lat-pull": "exercise_visual_exercise_band-lat-pull",
            "exercise.band-curl": "exercise_visual_exercise_band-curl",
            "exercise.band-tricep-extension": "exercise_visual_exercise_band-tricep-extension"
        ]

        for (movementId, expectedAssetName) in expectedAssetsByMovementId {
            let definition = try XCTUnwrap(MovementCatalog.definition(for: movementId))

            XCTAssertEqual(
                ExerciseVisualAsset.existingAssetName(for: definition),
                expectedAssetName,
                "\(definition.displayName) should use its direct current band visual"
            )
            XCTAssertNotNil(UIImage(named: expectedAssetName))
        }
    }

    func testFloorBodyweightClassificationsStayBeginnerAppropriate() throws {
        let gluteBridge = try XCTUnwrap(MovementCatalog.canonicalExercise(named: "Glute Bridge"))
        XCTAssertEqual(gluteBridge.blockKind, .bodyweight)
        XCTAssertEqual(gluteBridge.rankTemplate, .bodyweightReps)
        XCTAssertEqual(gluteBridge.loggerMode, .bodyweightSets)

        let bodyweightLegExtension = try XCTUnwrap(
            MovementCatalog.canonicalExercise(named: "Bodyweight Leg Extension")
        )
        XCTAssertEqual(bodyweightLegExtension.blockKind, .bodyweight)
        XCTAssertEqual(bodyweightLegExtension.difficulty, .intermediate)

        let jumpSquat = try XCTUnwrap(MovementCatalog.canonicalExercise(named: "Jump Squat"))
        XCTAssertEqual(jumpSquat.blockKind, .bodyweight)
        XCTAssertEqual(jumpSquat.difficulty, .intermediate)

        let beltSquat = try XCTUnwrap(MovementCatalog.canonicalExercise(named: "Belt Squat"))
        XCTAssertTrue(beltSquat.equipment.contains(.machine))
        XCTAssertFalse(
            MovementCatalog.isProgramCompatible(
                beltSquat,
                style: .bodyweight,
                userEquipment: [.bodyweight]
            )
        )
    }

    func testBandAssistedPullUpResolvesToAssistedVariantWithAssistedTag() {
        let resolved = MovementResolver.resolve("Band-Assisted Pull-Up")

        XCTAssertEqual(resolved.role, .canonicalExercise)
        XCTAssertTrue(resolved.rankable)
        XCTAssertEqual(resolved.rankTemplate, .bodyweightReps)
        XCTAssertEqual(resolved.blockKind, .bodyweight)
        XCTAssertEqual(resolved.loggerMode, .bodyweightSets)
        XCTAssertEqual(resolved.movementId, "exercise.assisted-pullup-band")
        XCTAssertEqual(resolved.canonicalExerciseName, "assisted pullup (band)")
        XCTAssertEqual(resolved.movementSlot, .verticalPull)
        XCTAssertTrue(resolved.variationTags.contains(.assisted))
    }

    func testNegativeTempoPullUpPreservesVariationTags() {
        let resolved = MovementResolver.resolve("Tempo Negative Pull-Up")

        XCTAssertEqual(resolved.movementId, "exercise.negative-pullup")
        XCTAssertEqual(resolved.canonicalExerciseName, "negative pullup")
        XCTAssertTrue(resolved.variationTags.contains(.tempo))
        XCTAssertTrue(resolved.variationTags.contains(.negative))
    }

    func testLegacyDisplayCanonicalAndUnderscoreNamesResolveToCatalogMovements() {
        let benchDisplay = MovementResolver.resolve("Barbell Bench Press")
        let benchCanonical = MovementResolver.resolve("bench press")
        let benchLegacy = MovementResolver.resolve("bench_press")

        XCTAssertEqual(benchDisplay.movementId, "exercise.bench-press")
        XCTAssertEqual(benchCanonical.movementId, benchDisplay.movementId)
        XCTAssertEqual(benchLegacy.movementId, benchDisplay.movementId)
        XCTAssertEqual(benchLegacy.canonicalExerciseName, "bench press")

        let pulldownDisplay = MovementResolver.resolve("Lat Pulldown (Neutral)")
        let pulldownLegacy = MovementResolver.resolve("lat_pulldown_neutral")

        XCTAssertEqual(pulldownDisplay.movementId, "exercise.lat-pulldown-neutral")
        XCTAssertEqual(pulldownLegacy.movementId, pulldownDisplay.movementId)
        XCTAssertEqual(pulldownLegacy.rankStandardMovementId, "exercise.lat-pulldown")

        let cableRowShortName = MovementResolver.resolve("cable row")
        let cableRowLegacy = MovementResolver.resolve("cable_row_seated")

        XCTAssertEqual(cableRowShortName.movementId, "exercise.cable-row-seated")
        XCTAssertEqual(cableRowLegacy.movementId, cableRowShortName.movementId)
        XCTAssertEqual(cableRowShortName.movementSlot, .horizontalPull)
    }

    func testTrainingMovementResolutionPrefersCatalogIdsAndKeepsLegacyNamesWorking() throws {
        let savedByIds = try XCTUnwrap(MovementCatalog.resolvedTrainingMovement(
            name: "Saved Pulldown Label",
            movementId: "exercise.lat-pulldown-neutral",
            rankStandardMovementId: "exercise.lat-pulldown-neutral"
        ))

        XCTAssertEqual(savedByIds.exact.id, "exercise.lat-pulldown-neutral")
        XCTAssertEqual(savedByIds.standard?.id, "exercise.lat-pulldown")
        XCTAssertEqual(savedByIds.standard?.displayName, "Lat Pulldown (Bar)")

        let legacyName = try XCTUnwrap(MovementCatalog.resolvedTrainingMovement(
            name: "lat_pulldown_neutral"
        ))

        XCTAssertEqual(legacyName.exact.id, "exercise.lat-pulldown-neutral")
        XCTAssertEqual(legacyName.standard?.id, "exercise.lat-pulldown")
    }

    func testWallHandstandSixtySecondsResolvesToSkillHoldWork() {
        let resolved = MovementResolver.resolve("Wall Handstand 60s")

        XCTAssertEqual(resolved.role, .skillDrill)
        XCTAssertEqual(resolved.blockKind, .skill)
        XCTAssertEqual(resolved.loggerMode, .skillAttempts)
        XCTAssertEqual(resolved.skillId, "hs.wall-handstand-30")
        XCTAssertTrue(resolved.variationTags.contains(.wallSupported))
    }

    func testWallHandstandHasWorkoutReferenceVisualAsset() throws {
        let resolved = MovementResolver.resolve("Wall Handstand")
        let definition = try XCTUnwrap(MovementCatalog.definition(for: resolved.movementId))

        XCTAssertEqual(definition.role, .skillDrill)
        XCTAssertEqual(definition.id, "skill-drill.wall-handstand")
        XCTAssertEqual(
            ExerciseVisualAsset.existingAssetName(for: definition),
            "exercise_visual_exercise_wall-handstand"
        )
    }

    func testCardioNamesResolveToCardioLogger() {
        let run = MovementResolver.resolve("Run")
        let bike = MovementResolver.resolve("Easy Bike Flush")
        let row = MovementResolver.resolve("100m Row Repeat")

        XCTAssertEqual(run.role, .cardioModality)
        XCTAssertEqual(run.rankTemplate, .cardioPerformance)
        XCTAssertEqual(run.blockKind, .cardio)
        XCTAssertEqual(run.loggerMode, .cardio)
        XCTAssertEqual(run.cardioType, .run)

        XCTAssertEqual(bike.cardioType, .bike)
        XCTAssertEqual(row.cardioType, .row)
        XCTAssertTrue(row.variationTags.contains(.interval))
    }

    func testCarryAndSledResolveToCarryLogger() {
        let farmer = MovementResolver.resolve("Farmer Carry")
        let sled = MovementResolver.resolve("Light Sled March")

        XCTAssertEqual(farmer.role, .carrySled)
        XCTAssertEqual(farmer.rankTemplate, .carrySled)
        XCTAssertEqual(farmer.blockKind, .carry)
        XCTAssertEqual(farmer.loggerMode, .carry)

        XCTAssertEqual(sled.role, .carrySled)
        XCTAssertEqual(sled.displayName, "Sled Push")
        XCTAssertEqual(sled.loggerMode, .carry)
    }

    func testMobilityNamesResolveToDurationQualityLogger() {
        let hipFlexor = MovementResolver.resolve("Hip Flexor Stretch")
        let wrist = MovementResolver.resolve("Reverse Wrist Stretch")
        let greatest = MovementResolver.resolve("World's Greatest Stretch")

        XCTAssertEqual(hipFlexor.role, .mobilityDuration)
        XCTAssertEqual(hipFlexor.rankTemplate, .mobilityDuration)
        XCTAssertEqual(hipFlexor.loggerMode, .mobility)
        XCTAssertEqual(hipFlexor.blockKind, .routine)

        XCTAssertEqual(wrist.role, .mobilityDuration)
        XCTAssertEqual(wrist.displayName, "Wrist Prep Flow")
        XCTAssertEqual(greatest.role, .mobilityDuration)
        XCTAssertEqual(greatest.displayName, "World's Greatest Stretch")
    }

    func testRoutineContainerStaysRoutineContainer() {
        guard let routine = MovementCatalog.definitions.first(where: { $0.id == "routine.morning-mobility-flow" }) else {
            XCTAssertNil(MovementCatalog.definition(for: "routine.morning-mobility-flow"))
            return
        }

        XCTAssertEqual(routine.role, .routineContainer)
        XCTAssertFalse(routine.rankable)
        XCTAssertEqual(routine.rankTemplate, .routineCompletion)
        XCTAssertEqual(routine.loggerMode, .routinePlayer)
        XCTAssertNil(routine.canonicalExerciseName)
    }

    func testUnknownRoutineStepDoesNotBecomeExercise() {
        let resolved = MovementResolver.resolve("Gate 8 Mystery Finisher")

        XCTAssertEqual(resolved.role, .routineStep)
        XCTAssertEqual(resolved.blockKind, .routine)
        XCTAssertEqual(resolved.loggerMode, .routinePlayer)
        XCTAssertNil(resolved.canonicalExerciseName)
    }

    func testEveryCanonicalExerciseHasExecutableMovementMetadata() {
        let canonical = MovementCatalog.definitions.filter { $0.role == .canonicalExercise }
        XCTAssertEqual(canonical.count, ExerciseCatalog.allExercises.count)

        let missing = canonical.filter { definition in
            definition.rankTemplate == .unranked
                || definition.equipment.isEmpty
                || definition.muscleGroups.isEmpty
                || definition.bodyRegions.isEmpty
                || definition.substitutionGroup.isEmpty
                || definition.attributeWeights.isEmpty
        }

        XCTAssertTrue(
            missing.isEmpty,
            "Canonical exercises missing movement metadata:\n\(missing.map(\.displayName).joined(separator: "\n"))"
        )
    }

    func testEveryLiveSkillNodeHasGeneratedSkillTargetMovement() {
        let liveSkillNodes = SkillGraph.shared.nodes
        let skillTargets = MovementCatalog.definitions.filter { $0.role == .skillTarget }

        XCTAssertGreaterThanOrEqual(skillTargets.count, liveSkillNodes.count)

        let missing = liveSkillNodes.filter { node in
            MovementCatalog.definition(for: "skill.\(node.id)") == nil
        }
        XCTAssertTrue(
            missing.isEmpty,
            "Missing skill target movements:\n\(missing.map(\.id).joined(separator: "\n"))"
        )

        for node in liveSkillNodes {
            let movement = MovementCatalog.definition(for: "skill.\(node.id)")
            XCTAssertEqual(movement?.skillId, node.id)
            XCTAssertEqual(movement?.skillAssociations, [node.id])
            XCTAssertEqual(movement?.role, .skillTarget)
            XCTAssertEqual(movement?.blockKind, .skill)
            XCTAssertEqual(movement?.rankable, false)
            XCTAssertEqual(movement?.rankTemplate, .unranked)
            XCTAssertEqual(movement?.movementSlot, .skill)
            XCTAssertEqual(movement?.rankStandardMovementId, "skill.\(node.id)")
            XCTAssertFalse(movement?.equipment.isEmpty ?? true)
            XCTAssertFalse(movement?.attributeWeights.isEmpty ?? true)
            XCTAssertFalse(movement?.bodyRegions.isEmpty ?? true)
        }
    }

    func testMovementCatalogExposesFinalStateQuerySurfaces() {
        XCTAssertEqual(MovementCatalog.legacyExercises.count, ExerciseCatalog.allExercises.count)
        XCTAssertGreaterThanOrEqual(MovementCatalog.skillTargets.count, SkillGraph.shared.nodes.count)
        XCTAssertGreaterThan(MovementCatalog.rankStandards.count, 100)
        XCTAssertGreaterThan(MovementCatalog.loggableVariants.count, 15)
        XCTAssertGreaterThan(MovementCatalog.loggableMovements.count, MovementCatalog.rankStandards.count)
        XCTAssertEqual(MovementCatalog.cardioMovements.count, CardioType.allCases.count)
        XCTAssertFalse(MovementCatalog.carryMovements.isEmpty)
        XCTAssertGreaterThanOrEqual(MovementCatalog.mobilityMovements.count, 18)

        let invalidVariants = MovementCatalog.loggableVariants.compactMap { variant -> String? in
            guard let standard = MovementCatalog.rankStandard(for: variant) else {
                return "\(variant.id) -> \(variant.rankStandardMovementId)"
            }
            return standard.rankStandardMovementId == standard.id ? nil : "\(variant.id) -> non-standard \(standard.id)"
        }

        XCTAssertTrue(
            invalidVariants.isEmpty,
            "Variants must resolve directly to a ranked standard:\n\(invalidVariants.joined(separator: "\n"))"
        )

        XCTAssertEqual(MovementCatalog.catalogExercises(for: .pullVertical).count, 22)
        XCTAssertEqual(
            MovementCatalog.catalogExercise(named: "Barbell Bench Press")?.name,
            "bench press"
        )
    }

    func testMovementCatalogDrivesExerciseLibraryAndSwapAlternatives() {
        XCTAssertEqual(
            ExerciseLibrary.all.count,
            MovementCatalog.legacyExercises.count + MovementCatalog.mobilityMovements.count
        )
        XCTAssertGreaterThan(ExerciseLibrary.all.count, 140)

        let safetyBarSquat = ExerciseLibrary.all.first { $0.canonicalName == "safety bar squat" }
        XCTAssertEqual(safetyBarSquat?.equipment.contains("Barbell"), true)
        XCTAssertEqual(safetyBarSquat?.category, .compound)
        XCTAssertEqual(safetyBarSquat?.movementSlot, .squat)
        XCTAssertEqual(safetyBarSquat?.loggerMode, .strengthSets)
        XCTAssertEqual(safetyBarSquat?.rankTemplate, .barbellStrength)

        let hollowRock = ExerciseLibrary.all.first { $0.canonicalName == "hollow rock" }
        XCTAssertEqual(hollowRock?.rankTemplate, .bodyweightReps)
        XCTAssertEqual(hollowRock?.category, .bodyweight)
        XCTAssertEqual(hollowRock?.loggerMode, .bodyweightSets)

        let hipFlexorStretch = ExerciseLibrary.all.first { $0.id == "mobility.hip-flexor-stretch" }
        XCTAssertEqual(hipFlexorStretch?.category, .mobility)
        XCTAssertEqual(hipFlexorStretch?.movementSlot, .mobility)
        XCTAssertEqual(hipFlexorStretch?.loggerMode, .mobility)
        XCTAssertEqual(hipFlexorStretch?.rankTemplate, .mobilityDuration)

        let pulldownAlternatives = MovementCatalog.catalogAlternatives(to: "Lat Pulldown (Neutral)")
        XCTAssertFalse(pulldownAlternatives.contains { $0.name == "lat pulldown (neutral)" })
        XCTAssertTrue(pulldownAlternatives.contains { $0.name == "lat pulldown" })
        XCTAssertTrue(pulldownAlternatives.allSatisfy {
            MovementCatalog.canonicalExercise(named: $0.name)?.movementSlot == .verticalPull
        })

        let rowAlternatives = MovementCatalog.catalogAlternatives(to: "Machine Row")
        XCTAssertFalse(rowAlternatives.contains { $0.name == "lat pulldown" })
        XCTAssertTrue(rowAlternatives.allSatisfy {
            MovementCatalog.canonicalExercise(named: $0.name)?.movementSlot == .horizontalPull
        })
    }

    func testExerciseLibrarySearchFiltersSwapAlternativesByNameMuscleEquipmentAndSlot() {
        let rowAlternatives = MovementCatalog.catalogAlternatives(to: "Machine Row")

        let dumbbellMatches = ExerciseLibrarySearch.filteredAlternatives(
            rowAlternatives,
            searchText: "dumbbell"
        )
        XCTAssertFalse(dumbbellMatches.isEmpty)
        XCTAssertTrue(dumbbellMatches.allSatisfy { alternative in
            MovementCatalog.canonicalExercise(named: alternative.name)?.equipment.contains(.dumbbell) == true
        })

        let backMatches = ExerciseLibrarySearch.filteredAlternatives(
            rowAlternatives,
            searchText: "back",
            selectedSlot: .horizontalPull
        )
        XCTAssertFalse(backMatches.isEmpty)
        XCTAssertTrue(backMatches.allSatisfy { alternative in
            MovementCatalog.canonicalExercise(named: alternative.name)?.movementSlot == .horizontalPull
        })

        let noMatches = ExerciseLibrarySearch.filteredAlternatives(
            rowAlternatives,
            searchText: "quadriceps",
            selectedSlot: .horizontalPull
        )
        XCTAssertTrue(noMatches.isEmpty)
    }

    func testExerciseLibrarySearchRanksRecentsAndPreferences() throws {
        let rowAlternatives = MovementCatalog.catalogAlternatives(to: "Machine Row")
        let availablePreference = ExercisePreference(
            id: "user:dumbbell-row",
            userId: "user",
            exerciseName: "Dumbbell Row",
            displayName: "Dumbbell Row",
            status: .available,
            muscleGroups: [.back, .lats],
            substitutePreference: nil,
            notes: nil,
            updatedAt: Date()
        )
        let avoidPreference = ExercisePreference(
            id: "user:barbell-row",
            userId: "user",
            exerciseName: "Barbell Bent-Over Row",
            displayName: "Barbell Bent-Over Row",
            status: .avoid,
            muscleGroups: [.back, .lats],
            substitutePreference: nil,
            notes: nil,
            updatedAt: Date()
        )
        let statusesByKey = ExercisePreferenceLookup.index([availablePreference, avoidPreference])
            .mapValues(\.status)

        let ranked = ExerciseLibrarySearch.filteredAlternatives(
            rowAlternatives,
            searchText: "",
            recentExerciseNames: Set(ExercisePreferenceLookup.keys(for: try XCTUnwrap(
                MovementCatalog.catalogExercise(named: "Cable Row (Seated)")
            ))),
            preferenceStatusesByKey: statusesByKey
        )

        XCTAssertEqual(ranked.first?.displayName, "Dumbbell Row")
        XCTAssertLessThan(
            try XCTUnwrap(ranked.firstIndex { $0.displayName == "Barbell Bent-Over Row" }),
            ranked.count
        )
        XCTAssertGreaterThan(
            try XCTUnwrap(ranked.firstIndex { $0.displayName == "Barbell Bent-Over Row" }),
            try XCTUnwrap(ranked.firstIndex { $0.displayName == "Cable Row (Seated)" })
        )

        let availableSignals = ExerciseLibrarySearch.signals(
            for: try XCTUnwrap(MovementCatalog.catalogExercise(named: "Dumbbell Row")),
            preferenceStatusesByKey: statusesByKey
        )
        XCTAssertEqual(availableSignals.preferenceStatus, .available)
        XCTAssertTrue(availableSignals.badges.contains("Favorite"))

        let favoritesOnly = ExerciseLibrarySearch.filteredAlternatives(
            rowAlternatives,
            searchText: "",
            contextFilter: .favorites,
            preferenceStatusesByKey: statusesByKey
        )
        XCTAssertEqual(favoritesOnly.map(\.displayName), ["Dumbbell Row"])

        let availableOnly = ExerciseLibrarySearch.filteredAlternatives(
            rowAlternatives,
            searchText: "",
            contextFilter: .available,
            preferenceStatusesByKey: statusesByKey
        )
        XCTAssertEqual(availableOnly.map(\.displayName), ["Dumbbell Row"])

        let recentSignals = ExerciseLibrarySearch.signals(
            for: try XCTUnwrap(MovementCatalog.catalogExercise(named: "Cable Row (Seated)")),
            recentExerciseNames: Set(ExercisePreferenceLookup.keys(for: try XCTUnwrap(
                MovementCatalog.catalogExercise(named: "Cable Row (Seated)")
            )))
        )
        XCTAssertTrue(recentSignals.isRecent)

        let recentOnly = ExerciseLibrarySearch.filteredAlternatives(
            rowAlternatives,
            searchText: "",
            contextFilter: .recent,
            recentExerciseNames: Set(ExercisePreferenceLookup.keys(for: try XCTUnwrap(
                MovementCatalog.catalogExercise(named: "Cable Row (Seated)")
            )))
        )
        XCTAssertEqual(recentOnly.map(\.displayName), ["Cable Row (Seated)"])
    }

    func testExerciseLibrarySearchSurfacesCompatibilityState() throws {
        let rowAlternatives = MovementCatalog.catalogAlternatives(to: "Machine Row")
        let barbellRow = try XCTUnwrap(MovementCatalog.catalogExercise(named: "Barbell Bent-Over Row"))
        let bodyweightRow = try XCTUnwrap(MovementCatalog.catalogExercise(named: "Inverted Row"))
        let avoidPreference = ExercisePreference(
            id: "user:barbell-row",
            userId: "user",
            exerciseName: "Barbell Bent-Over Row",
            displayName: "Barbell Bent-Over Row",
            status: .avoid,
            muscleGroups: [.back, .lats],
            substitutePreference: nil,
            notes: nil,
            updatedAt: Date()
        )
        let statusesByKey = ExercisePreferenceLookup.index([avoidPreference]).mapValues(\.status)

        let unavailable = ExerciseLibrarySearch.compatibilityState(
            for: barbellRow,
            preferredSlot: .horizontalPull,
            availableEquipment: [.bodyweight],
            preferenceStatusesByKey: [:]
        )
        XCTAssertEqual(unavailable.level, .unavailable)
        XCTAssertFalse(unavailable.isSelectable)
        XCTAssertEqual(unavailable.badgeTitle, "Unavailable")

        let avoided = ExerciseLibrarySearch.compatibilityState(
            for: barbellRow,
            preferredSlot: .horizontalPull,
            availableEquipment: [.fullGym],
            preferenceStatusesByKey: statusesByKey
        )
        XCTAssertEqual(avoided.level, .avoided)
        XCTAssertFalse(avoided.isSelectable)

        let compatible = ExerciseLibrarySearch.compatibilityState(
            for: bodyweightRow,
            preferredSlot: .horizontalPull,
            availableEquipment: [.bodyweight],
            preferenceStatusesByKey: [:]
        )
        XCTAssertEqual(compatible.level, .compatible)
        XCTAssertTrue(compatible.isSelectable)

        let ranked = ExerciseLibrarySearch.filteredAlternatives(
            rowAlternatives,
            searchText: "",
            selectedSlot: .horizontalPull,
            preferenceStatusesByKey: statusesByKey,
            availableEquipment: [.bodyweight]
        )
        XCTAssertLessThan(
            try XCTUnwrap(ranked.firstIndex { $0.displayName == bodyweightRow.displayName }),
            try XCTUnwrap(ranked.firstIndex { $0.displayName == barbellRow.displayName })
        )
    }

    func testEveryExerciseLibraryItemHasSearchableProgramMetadataAndResolvableCatalogExercise() {
        let issues = ExerciseLibrary.all.compactMap { item -> String? in
            guard let definition = MovementCatalog.definition(for: item.id) else {
                return "\(item.name) missing definition"
            }
            guard definition.role == .mobilityDuration
                || MovementCatalog.catalogExercise(for: definition) != nil
            else {
                return "\(item.name) missing catalog exercise"
            }
            guard !item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return "\(item.id) empty display name"
            }
            guard item.movementSlot != .routine, item.movementSlot != .skill else {
                return "\(item.name) has non-exercise slot \(item.movementSlot)"
            }
            guard !item.metadataSummary.isEmpty else {
                return "\(item.name) missing metadata"
            }
            guard !item.equipmentSummary.isEmpty else {
                return "\(item.name) missing equipment"
            }
            return nil
        }

        XCTAssertTrue(
            issues.isEmpty,
            "Exercise library items must be searchable and resolvable:\n\(issues.joined(separator: "\n"))"
        )
    }

    func testExercisePreferenceLookupKeepsSavedNameCompatibility() {
        let displayNamePreference = ExercisePreference(
            id: "user:Barbell Bench Press",
            userId: "user",
            exerciseName: "Barbell Bench Press",
            displayName: "Bench Press",
            status: .avoid,
            muscleGroups: [.chest],
            substitutePreference: nil,
            notes: nil,
            updatedAt: Date()
        )
        let legacyNamePreference = ExercisePreference(
            id: "user:lat_pulldown_neutral",
            userId: "user",
            exerciseName: "lat_pulldown_neutral",
            displayName: "Lat Pulldown (Neutral)",
            status: .available,
            muscleGroups: [.back, .lats],
            substitutePreference: nil,
            notes: nil,
            updatedAt: Date()
        )

        let indexed = ExercisePreferenceLookup.index([displayNamePreference, legacyNamePreference])
        let bench = ExerciseLibrary.all.first { $0.canonicalName == "bench press" }
        let neutralPulldown = MovementCatalog.catalogExercise(named: "Lat Pulldown (Neutral)")

        XCTAssertEqual(
            bench?.preferenceLookupKeys.compactMap { indexed[$0]?.status }.first,
            .avoid
        )
        XCTAssertEqual(
            neutralPulldown.flatMap { ExercisePreferenceLookup.keys(for: $0).compactMap { indexed[$0]?.status }.first },
            .available
        )
    }

    func testMovementCatalogProgramAvailabilityUsesStructuredEquipment() {
        let bodyweightOnly = MovementCatalog.programDefinitions(
            style: .bodyweight,
            userEquipment: [.bodyweight]
        )
        XCTAssertTrue(bodyweightOnly.contains { $0.displayName == "Push-Up" })
        XCTAssertTrue(bodyweightOnly.contains { $0.displayName == "Bodyweight Squat" })
        XCTAssertFalse(bodyweightOnly.contains { $0.displayName == "Lat Pulldown (Bar)" })
        XCTAssertFalse(bodyweightOnly.contains { $0.displayName == "Pull-Up" })
        XCTAssertFalse(bodyweightOnly.contains { $0.displayName == "Ab Wheel" })

        let bodyweightWithBar = MovementCatalog.programDefinitions(
            style: .bodyweight,
            userEquipment: [.bodyweight, .pullupBar]
        )
        XCTAssertTrue(bodyweightWithBar.contains { $0.displayName == "Pull-Up" })
        XCTAssertFalse(bodyweightWithBar.contains { $0.displayName == "Dip (Tricep)" })
        XCTAssertFalse(bodyweightWithBar.contains { $0.displayName == "Straight Bar Dip" })

        let bodyweightWithDipStation = MovementCatalog.programDefinitions(
            style: .bodyweight,
            userEquipment: [.bodyweight, .dipStation]
        )
        XCTAssertTrue(bodyweightWithDipStation.contains { $0.displayName == "Dip (Tricep)" })
        XCTAssertTrue(bodyweightWithDipStation.contains { $0.displayName == "Straight Bar Dip" })

        let bodyweightWithRings = MovementCatalog.programDefinitions(
            style: .bodyweight,
            userEquipment: [.bodyweight, .rings]
        )
        XCTAssertTrue(bodyweightWithRings.contains { $0.displayName == "Ring Dip" })
        XCTAssertTrue(bodyweightWithRings.contains { $0.displayName == "Inverted Row" })

        let machines = MovementCatalog.programDefinitions(
            style: .machines,
            userEquipment: [.machines]
        )
        XCTAssertTrue(machines.contains { $0.displayName == "Lat Pulldown (Bar)" })
        XCTAssertTrue(machines.contains { $0.displayName == "Machine Row" })
        XCTAssertFalse(machines.contains { $0.displayName == "Barbell Back Squat" })
    }

    func testMovementCatalogProgramAlternativesStayCompatibleAndSameSlot() {
        let rowAlternatives = MovementCatalog.programAlternatives(
            to: "Machine Row",
            style: .machines,
            userEquipment: [.machines]
        )

        XCTAssertFalse(rowAlternatives.isEmpty)
        XCTAssertTrue(rowAlternatives.allSatisfy {
            $0.movementSlot == .horizontalPull
                && MovementCatalog.isProgramCompatible($0, style: .machines, userEquipment: [.machines])
        })
        XCTAssertFalse(rowAlternatives.contains { $0.displayName == "Lat Pulldown (Bar)" })
    }

    func testCatalogSwapAlternativesStayProgramCompatibleAndSameSlot() {
        let alternatives = MovementCatalog.catalogAlternatives(
            to: "Machine Row",
            style: .machines,
            userEquipment: [.machines],
            excludedNames: ["Hammer Strength Row"]
        )

        XCTAssertFalse(alternatives.isEmpty)
        XCTAssertFalse(alternatives.contains { $0.displayName == "Hammer Strength Row" })
        XCTAssertFalse(alternatives.contains { $0.displayName == "Dumbbell Row" })
        XCTAssertTrue(alternatives.allSatisfy { alternative in
            guard let definition = MovementCatalog.canonicalExercise(named: alternative.name) else { return false }
            return definition.movementSlot == .horizontalPull
                && MovementCatalog.isProgramCompatible(definition, style: .machines, userEquipment: [.machines])
        })
    }

    func testMovementCatalogValidationHasNoPolicyIssues() {
        let issues = MovementCatalogValidation.issues()
        XCTAssertTrue(
            issues.isEmpty,
            "MovementCatalog policy validation failed:\n\(issues.joined(separator: "\n"))"
        )
    }

    func testMovementSkillAssociationsPointAtExistingSkillNodes() {
        let skillIds = Set(SkillGraph.shared.nodes.map(\.id))
        let invalidLinks = MovementCatalog.definitions.flatMap { definition in
            definition.skillAssociations
                .filter { !skillIds.contains($0) }
                .map { "\(definition.id) -> \($0)" }
        }

        XCTAssertTrue(
            invalidLinks.isEmpty,
            "Movement skill associations must point at live skill nodes:\n\(invalidLinks.joined(separator: "\n"))"
        )
    }

    func testGeneratedSkillTargetsResolveBySkillIdWithoutStealingCanonicalExerciseNames() {
        let byId = MovementResolver.resolve("hs.wall-handstand-30")
        XCTAssertEqual(byId.role, .skillTarget)
        XCTAssertEqual(byId.skillId, "hs.wall-handstand-30")
        XCTAssertEqual(byId.blockKind, .skill)

        let canonicalExercise = MovementResolver.resolve("Muscle-Up")
        XCTAssertEqual(canonicalExercise.role, .canonicalExercise)
        XCTAssertEqual(canonicalExercise.canonicalExerciseName, "muscle-up")
    }

    func testCalisthenicsDrillRailsResolveToOwningSkills() {
        let drills: [(String, String)] = [
            ("Two-Finger Tent", "oah.one-arm-handstand-5s"),
            ("Off-Hand Float", "oah.one-arm-handstand-5s"),
            ("Band-Assisted Full Planche", "pl.full-planche"),
            ("Advanced Tuck Back Lever", "cl.straddle-back-lever"),
            ("Tuck L-Sit", "cal.l-sit-10"),
            ("Foot-Supported L-Sit", "cal.l-sit-10")
        ]

        for (name, skillId) in drills {
            let resolved = MovementResolver.resolve(name)
            XCTAssertEqual(resolved.role, .skillDrill, name)
            XCTAssertEqual(resolved.skillId, skillId, name)
            XCTAssertEqual(resolved.blockKind, .skill, name)
        }

        let tuckedLSitExercise = MovementResolver.resolve("L-Sit (Tucked)")
        XCTAssertEqual(tuckedLSitExercise.role, .canonicalExercise)
        XCTAssertEqual(tuckedLSitExercise.loggerMode, .hold)

        let genericWeightShift = MovementResolver.resolve("Weight Shift")
        XCTAssertNotEqual(genericWeightShift.skillId, "hs.wall-supported-oah")
    }

    func testRepresentativeGymExercisesHaveExpectedTemplatesAndSlots() {
        let bench = MovementResolver.resolve("Bench Press")
        XCTAssertEqual(bench.rankTemplate, .barbellStrength)
        XCTAssertEqual(bench.movementSlot, .horizontalPush)
        XCTAssertTrue(bench.bodyRegions.contains(.midLowerChest))
        XCTAssertTrue(bench.bodyRegions.contains(.frontSideDelts))
        XCTAssertTrue(bench.bodyRegions.contains(.triceps))

        let inclineBench = MovementResolver.resolve("Incline Bench Press")
        XCTAssertTrue(inclineBench.bodyRegions.contains(.upperChest))
        XCTAssertFalse(inclineBench.bodyRegions.contains(.midLowerChest))

        let legPress = MovementResolver.resolve("Leg Press")
        XCTAssertEqual(legPress.rankTemplate, .machineStrength)
        XCTAssertEqual(legPress.movementSlot, .squat)
        XCTAssertTrue(legPress.bodyRegions.contains(.quads))
        XCTAssertTrue(legPress.bodyRegions.contains(.glutes))

        let machineLegExtension = MovementResolver.resolve("Leg Extension")
        XCTAssertEqual(machineLegExtension.rankTemplate, .machineStrength)
        XCTAssertEqual(machineLegExtension.blockKind, .strength)

        let bodyweightLegExtension = MovementResolver.resolve("Bodyweight Leg Extension")
        XCTAssertEqual(bodyweightLegExtension.movementId, "exercise.bodyweight-leg-extension")
        XCTAssertEqual(bodyweightLegExtension.rankTemplate, .bodyweightReps)
        XCTAssertEqual(bodyweightLegExtension.blockKind, .bodyweight)
        XCTAssertEqual(bodyweightLegExtension.loggerMode, .bodyweightSets)
        XCTAssertEqual(bodyweightLegExtension.skillId, nil)
        XCTAssertEqual(bodyweightLegExtension.rankStandardMovementId, "exercise.bodyweight-leg-extension")
        XCTAssertFalse(MovementCatalog.definition(for: "exercise.bodyweight-leg-extension")?.equipment.contains(.machine) ?? true)
        XCTAssertTrue(MovementCatalog.definition(for: "exercise.bodyweight-leg-extension")?.skillAssociations.contains("ld.leg-extensions") ?? false)

        let neutralPulldown = MovementResolver.resolve("Lat Pulldown (Neutral)")
        XCTAssertEqual(neutralPulldown.rankTemplate, .machineStrength)
        XCTAssertEqual(neutralPulldown.blockKind, .strength)
        XCTAssertEqual(neutralPulldown.loggerMode, .strengthSets)
        XCTAssertEqual(neutralPulldown.variantOfMovementId, "exercise.lat-pulldown")
        XCTAssertEqual(neutralPulldown.rankStandardMovementId, "exercise.lat-pulldown")
        XCTAssertTrue(neutralPulldown.bodyRegions.contains(.lats))
        XCTAssertFalse(neutralPulldown.bodyRegions.contains(.rhomboids))
        XCTAssertFalse(neutralPulldown.bodyRegions.contains(.lowerBack))

        let dipMachine = MovementResolver.resolve("Dip Machine")
        XCTAssertEqual(dipMachine.rankTemplate, .machineStrength)
        XCTAssertEqual(dipMachine.blockKind, .strength)

        let wideGripPulldown = MovementResolver.resolve("Wide-Grip Lat Pulldown")
        XCTAssertEqual(wideGripPulldown.rankStandardMovementId, "exercise.lat-pulldown")

        let straightArmPulldown = MovementResolver.resolve("Straight-Arm Pulldown")
        XCTAssertNil(straightArmPulldown.variantOfMovementId)
        XCTAssertEqual(straightArmPulldown.rankStandardMovementId, "exercise.straight-arm-pulldown")
        XCTAssertTrue(straightArmPulldown.bodyRegions.contains(.lats))

        let plateLoadedPress = MovementResolver.resolve("Plate Loaded Chest Press")
        XCTAssertEqual(plateLoadedPress.rankTemplate, .machineStrength)
        XCTAssertEqual(plateLoadedPress.rankStandardMovementId, "exercise.machine-chest-press")
        XCTAssertTrue(plateLoadedPress.bodyRegions.contains(.midLowerChest))
        XCTAssertFalse(plateLoadedPress.bodyRegions.contains(.upperChest))

        let hammerStrengthRow = MovementResolver.resolve("Hammer Strength Row")
        XCTAssertEqual(hammerStrengthRow.rankTemplate, .machineStrength)
        XCTAssertEqual(hammerStrengthRow.rankStandardMovementId, "exercise.machine-row")
        XCTAssertTrue(hammerStrengthRow.bodyRegions.contains(.lats))
        XCTAssertTrue(hammerStrengthRow.bodyRegions.contains(.rhomboids))
        XCTAssertFalse(hammerStrengthRow.bodyRegions.contains(.rearDelts))

        let facePull = MovementResolver.resolve("Face Pull")
        XCTAssertEqual(Set(facePull.bodyRegions), Set([.rearDelts, .rhomboids, .traps]))

        let declineSitup = MovementResolver.resolve("Decline Sit-Up")
        XCTAssertEqual(declineSitup.rankTemplate, .bodyweightReps)
        XCTAssertEqual(declineSitup.blockKind, .bodyweight)

        let holdMovements = [
            "L-Sit",
            "L-Sit (Tucked)",
            "Tuck Front Lever",
            "Advanced Tuck Front Lever"
        ]
        for movement in holdMovements {
            let resolved = MovementResolver.resolve(movement)
            XCTAssertEqual(resolved.rankTemplate, .holdControl, "\(movement) should use hold/control ranking")
            XCTAssertEqual(resolved.loggerMode, .hold, "\(movement) should use the hold timer")
        }

        let repControlMovements = [
            "Dragon Flag",
            "Hanging Leg Raise",
            "Hanging Knee Raise",
            "Captain's Chair Leg Raise"
        ]
        for movement in repControlMovements {
            let resolved = MovementResolver.resolve(movement)
            XCTAssertEqual(resolved.rankTemplate, .bodyweightReps, "\(movement) should rank by reps")
            XCTAssertEqual(resolved.loggerMode, .bodyweightSets, "\(movement) should use bodyweight rep logging")
        }

        let hollowRock = MovementResolver.resolve("Hollow Rock")
        XCTAssertEqual(hollowRock.rankTemplate, .bodyweightReps)
        XCTAssertEqual(hollowRock.loggerMode, .bodyweightSets)

        // Tucked L-sit follows its core-lever tier (2 → intermediate). The old
        // .beginner hardcode fed L-sits to never-trained users' general pools
        // (2026-07-13 generator review, F7).
        let tuckedLSit = MovementCatalog.definition(for: "exercise.l-sit-tucked")
        XCTAssertEqual(tuckedLSit?.difficulty, .intermediate)

        let straightBarDip = MovementResolver.resolve("Straight Bar Dip")
        XCTAssertEqual(straightBarDip.movementSlot, .arms)

        let hipAdductor = MovementResolver.resolve("Hip Adductor Machine")
        XCTAssertEqual(hipAdductor.movementSlot, .squat)
        XCTAssertEqual(Set(hipAdductor.bodyRegions), Set([.adductors]))

        let hipAbductor = MovementResolver.resolve("Hip Abductor Machine")
        XCTAssertEqual(Set(hipAbductor.bodyRegions), Set([.abductors, .glutes]))

        let legExtension = MovementResolver.resolve("Leg Extension")
        XCTAssertEqual(Set(legExtension.bodyRegions), Set([.quads]))

        let tricepPushdown = MovementCatalog.definition(for: "exercise.tricep-pushdown")
        XCTAssertEqual(tricepPushdown?.skillAssociations.contains("pp.muscle-up"), false)
        XCTAssertEqual(Set(tricepPushdown?.bodyRegions ?? []), Set([.triceps]))

        let hangingKneeRaise = MovementCatalog.definition(for: "exercise.hanging-knee-raise")
        XCTAssertEqual(hangingKneeRaise?.skillAssociations.contains("cl.hollow-body-30"), true)

        let straightArmPulldownDefinition = MovementCatalog.definition(for: "exercise.straight-arm-pulldown")
        XCTAssertEqual(straightArmPulldownDefinition?.skillAssociations.contains("pp.pullup"), false)
        XCTAssertEqual(straightArmPulldownDefinition?.skillAssociations.contains("pp.strict-pullup"), false)

        let machinePullover = MovementCatalog.definition(for: "exercise.machine-pullover")
        XCTAssertEqual(machinePullover?.skillAssociations.contains("pp.pullup"), false)
        XCTAssertEqual(machinePullover?.skillAssociations.contains("pp.strict-pullup"), false)

        let assistedDipMachine = MovementCatalog.definition(for: "exercise.assisted-dip-machine")
        XCTAssertEqual(assistedDipMachine?.skillAssociations.contains("pp.muscle-up"), false)

        let dipMachineDefinition = MovementCatalog.definition(for: "exercise.dip-machine")
        XCTAssertEqual(dipMachineDefinition?.skillAssociations.contains("pp.muscle-up"), false)

        let bodyweightDip = MovementCatalog.definition(for: "exercise.dip")
        XCTAssertEqual(bodyweightDip?.skillAssociations.contains("pp.muscle-up"), true)

        let straightBarDipDefinition = MovementCatalog.definition(for: "exercise.straight-bar-dip")
        XCTAssertEqual(straightBarDipDefinition?.skillAssociations.contains("pp.muscle-up"), true)

        let closeGripPulldown = MovementCatalog.catalogExercise(named: "close grip lat pulldown")
        XCTAssertEqual(closeGripPulldown?.defaultSubstitute, "lat pulldown")

        let singleLegCurl = MovementCatalog.catalogExercise(named: "single-leg curl")
        XCTAssertEqual(singleLegCurl?.defaultSubstitute, "leg curl (lying)")

        let reverseGripPulldown = MovementCatalog.catalogExercise(named: "reverse grip lat pulldown")
        XCTAssertEqual(reverseGripPulldown?.defaultSubstitute, "lat pulldown")

        let horizontalRows = [
            "Cable Row (Seated)",
            "Machine Row",
            "Hammer Strength Row"
        ]
        for movement in horizontalRows {
            let resolved = MovementResolver.resolve(movement)
            let definition = MovementCatalog.definition(for: resolved.movementId)
            XCTAssertEqual(definition?.movementSlot, .horizontalPull)
            XCTAssertEqual(definition?.skillAssociations.contains("pp.pullup"), false)
            XCTAssertEqual(definition?.skillAssociations.contains("pp.strict-pullup"), false)
        }

        let safetyBarSquat = MovementCatalog.definition(for: "exercise.safety-bar-squat")
        XCTAssertEqual(safetyBarSquat?.equipment.contains(.barbell), true)
        XCTAssertEqual(safetyBarSquat?.equipment.contains(.bodyweight), false)

        let arnoldPress = MovementCatalog.definition(for: "exercise.arnold-press")
        XCTAssertEqual(arnoldPress?.equipment.contains(.dumbbell), true)
        XCTAssertEqual(arnoldPress?.equipment.contains(.bodyweight), false)

        let straightBarPushdown = MovementCatalog.definition(for: "exercise.straight-bar-tricep-pushdown")
        XCTAssertEqual(straightBarPushdown?.equipment.contains(.barbell), false)
        XCTAssertEqual(straightBarPushdown?.equipment.contains(.cable), true)

        let plank = MovementResolver.resolve("Plank")
        XCTAssertEqual(plank.rankTemplate, .holdControl)
        XCTAssertEqual(plank.movementSlot, .core)
        XCTAssertTrue(plank.bodyRegions.contains(.abs))
    }

    func testHangSkillsTreatRingsAndPullupBarAsAlternatives() throws {
        // Skin the cat and German hang work from rings OR a bar; either one
        // must satisfy the pair so bar-only users can reach the back-lever line.
        for id in ["skill.cl.skin-the-cat", "skill.cl.german-hang"] {
            let definition = try XCTUnwrap(MovementCatalog.definition(for: id))
            XCTAssertTrue(
                MovementCatalog.isProgramCompatible(definition, style: .bodyweight, userEquipment: [.bodyweight, .pullupBar]),
                "\(id) should run for a bar-only user"
            )
            XCTAssertTrue(
                MovementCatalog.isProgramCompatible(definition, style: .bodyweight, userEquipment: [.bodyweight, .rings]),
                "\(id) should run for a rings-only user"
            )
            XCTAssertFalse(
                MovementCatalog.isProgramCompatible(definition, style: .bodyweight, userEquipment: [.bodyweight]),
                "\(id) still needs something to hang from"
            )
        }

        // 360-degree pulls are genuinely rings-only — a bar must not qualify.
        let threeSixty = try XCTUnwrap(MovementCatalog.definition(for: "skill.cl.three-sixty-pulls"))
        XCTAssertTrue(MovementCatalog.isProgramCompatible(threeSixty, style: .bodyweight, userEquipment: [.bodyweight, .rings]))
        XCTAssertFalse(MovementCatalog.isProgramCompatible(threeSixty, style: .bodyweight, userEquipment: [.bodyweight, .pullupBar]))
    }

    func testRankableBodyweightLibraryExercisesDeriveRanksFromLoggedReps() throws {
        let rowLow = try XCTUnwrap(StrengthStandards.progressToNextRank(
            metricValue: 1,
            bodyweightKg: 0,
            exerciseKey: "Inverted Row",
            sex: nil
        ))
        let rowHigh = try XCTUnwrap(StrengthStandards.progressToNextRank(
            metricValue: 50,
            bodyweightKg: 0,
            exerciseKey: "Inverted Row",
            sex: nil
        ))
        XCTAssertGreaterThan(rowHigh.current.rawValue, rowLow.current.rawValue)

        let squatLow = try XCTUnwrap(StrengthStandards.progressToNextRank(
            metricValue: 5,
            bodyweightKg: 0,
            exerciseKey: "Bodyweight Squat",
            sex: nil
        ))
        let squatHigh = try XCTUnwrap(StrengthStandards.progressToNextRank(
            metricValue: 120,
            bodyweightKg: 0,
            exerciseKey: "Bodyweight Squat",
            sex: nil
        ))
        XCTAssertGreaterThan(squatHigh.current.rawValue, squatLow.current.rawValue)
    }

    private func makeWarmupInput(
        trainingStyle: TrainingStyle,
        equipment: [Equipment],
        experience: Experience
    ) -> ProgramGeneratorInput {
        ProgramGeneratorInput(
            userId: "warmup-test-user",
            scanId: nil,
            analysisId: nil,
            buildIdentity: BuildIdentity(primary: .control, secondary: nil, shape: .specialist),
            trainingStyle: trainingStyle,
            equipment: equipment,
            targetFrequency: .four,
            trainingDays: [.monday, .tuesday, .thursday, .friday],
            experience: experience,
            focusAreas: [],
            cutModeActive: false,
            trainingFeedbackMode: .quick,
            progressionStates: [:],
            previousBlock: nil,
            weightKg: 75,
            heightCm: 178,
            age: 24,
            sex: .male,
            blockStartDate: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    // MARK: - Gym vocabulary search

    /// "bicep curl" is the single most common thing a lifter types, and it used
    /// to return NOTHING: the catalog says "Dumbbell Curl" / "Arms", never
    /// "bicep", and the matcher required the query to be one contiguous run of
    /// the joined terms.
    func testSearchFindsCurlsByTheWordLiftersActuallyType() {
        let all = ExerciseCatalog.allExercises

        for query in ["bicep curl", "biceps curl", "bicep", "db curl", "curl dumbbell"] {
            let matches = ExerciseLibrarySearch.filteredAlternatives(all, searchText: query)
            XCTAssertFalse(matches.isEmpty, "search '\(query)' should find something")
        }

        let bicepCurl = ExerciseLibrarySearch.filteredAlternatives(all, searchText: "bicep curl")
        XCTAssertTrue(
            bicepCurl.contains { $0.name == "dumbbell curl" },
            "'bicep curl' must surface the Dumbbell Curl"
        )
        // Every hit is genuinely a curl — Arms-filed triceps work must not answer
        // to "bicep" just because it shares a muscle group.
        XCTAssertTrue(
            bicepCurl.allSatisfy { $0.name.contains("curl") },
            "'bicep curl' returned non-curls: \(bicepCurl.map(\.name))"
        )
        XCTAssertFalse(bicepCurl.contains { $0.name == "tricep pushdown" })

        let tricep = ExerciseLibrarySearch.filteredAlternatives(all, searchText: "tricep")
        XCTAssertTrue(tricep.contains { $0.name == "tricep pushdown" })
        XCTAssertFalse(tricep.contains { $0.name == "dumbbell curl" })

        // Word order must not matter, and the anatomical name still works.
        XCTAssertTrue(
            ExerciseLibrarySearch.filteredAlternatives(all, searchText: "curl dumbbell")
                .contains { $0.name == "dumbbell curl" }
        )
    }

    /// The picker filters by BODY PART, not by movement pattern. "Horizontal
    /// Push" is generator vocabulary; a lifter picks by "Chest".
    func testExerciseLibraryFiltersByBodyPart() {
        let all = ExerciseCatalog.allExercises

        let chips = ExerciseLibrarySearch.availableMuscleGroups(in: all)
        XCTAssertEqual(chips, ExerciseLibrarySearch.muscleFilterOrder.filter { chips.contains($0) },
                       "chips must keep a stable anatomical order")
        for expected: MuscleGroup in [.chest, .back, .shoulders, .biceps, .triceps, .quads, .hamstrings, .glutes, .core, .traps] {
            XCTAssertTrue(chips.contains(expected), "expected a \(expected.displayName) chip")
        }
        XCTAssertFalse(chips.contains(.arms), "catalog no longer tags exercises .arms; chip should not surface")
        XCTAssertFalse(chips.contains(.legs), "catalog no longer tags exercises .legs; chip should not surface")

        let chest = ExerciseLibrarySearch.filteredAlternatives(all, searchText: "", selectedMuscle: .chest)
        XCTAssertFalse(chest.isEmpty)
        XCTAssertTrue(chest.allSatisfy { $0.muscleGroups.contains(.chest) })
        XCTAssertTrue(chest.contains { $0.name == "bench press" })
        XCTAssertFalse(chest.contains { $0.name == "barbell curl" })

        // Body part cuts ACROSS movement patterns — the whole point. Chest work
        // lives in horizontal push, but the arms slot holds chest work too.
        let chestSlots = Set(chest.compactMap { MovementCatalog.canonicalExercise(named: $0.name)?.movementSlot })
        XCTAssertTrue(chestSlots.contains(.horizontalPush))
        XCTAssertTrue(chestSlots.contains(.arms), "Dip / bench dip are chest work filed under arms")

        // Traps: previously unreachable by any filter.
        let traps = ExerciseLibrarySearch.filteredAlternatives(all, searchText: "", selectedMuscle: .traps)
        XCTAssertTrue(traps.contains { $0.name == "barbell shrug" })
        XCTAssertTrue(traps.allSatisfy { $0.muscleGroups.contains(.traps) })

        // A body-part chip composes with the text query.
        let chestCable = ExerciseLibrarySearch.filteredAlternatives(
            all, searchText: "cable", selectedMuscle: .chest
        )
        XCTAssertFalse(chestCable.isEmpty)
        XCTAssertTrue(chestCable.allSatisfy { $0.muscleGroups.contains(.chest) })
    }

    /// Traps had no direct work at all in the catalog before the shrug family.
    func testTrapsHaveDirectWorkAndShrugsResolve() {
        let all = ExerciseCatalog.allExercises
        let trapWork = all.filter { $0.muscleGroups.contains(.traps) }
        XCTAssertFalse(trapWork.isEmpty, "no exercise trains traps")

        let shrugs = ExerciseLibrarySearch.filteredAlternatives(all, searchText: "shrug")
        XCTAssertGreaterThanOrEqual(shrugs.count, 5, "expected the full shrug family")
        XCTAssertTrue(
            ExerciseLibrarySearch.filteredAlternatives(all, searchText: "traps")
                .contains { $0.name == "barbell shrug" },
            "'traps' should surface the Barbell Shrug"
        )
    }

    /// Shrugs live in the horizontal-pull pattern so they sit with the other
    /// upper-back pulls — but they are single-joint, so the generator must never
    /// let one anchor a day in place of an actual row.
    func testShrugsNeverAnchorADayAsThePrimaryMovement() throws {
        let shrug = try XCTUnwrap(MovementCatalog.canonicalExercise(named: "barbell shrug"))
        XCTAssertEqual(shrug.movementSlot, .horizontalPull)
        XCTAssertTrue(DeterministicProgramGenerator.isSingleJointAccessory(shrug))
        XCTAssertFalse(DeterministicProgramGenerator.isPrimaryMovement(shrug))

        let row = try XCTUnwrap(MovementCatalog.canonicalExercise(named: "bent-over row"))
        XCTAssertTrue(DeterministicProgramGenerator.isPrimaryMovement(row))
    }

    /// The equipment classifier is keyword-driven, so a variant that shares a
    /// name with a barbell lift ("skull crusher") must not inherit the barbell.
    func testNewArmVariantsClassifyToTheRightImplement() throws {
        func equipment(_ name: String) throws -> [MovementEquipment] {
            try XCTUnwrap(MovementCatalog.canonicalExercise(named: name)).equipment
        }

        XCTAssertTrue(try equipment("dumbbell skull crusher").contains(.dumbbell))
        XCTAssertFalse(
            try equipment("dumbbell skull crusher").contains(.barbell),
            "a dumbbell skull crusher must not require a barbell"
        )
        XCTAssertTrue(try equipment("skull crushers").contains(.barbell))

        XCTAssertTrue(try equipment("zottman curl").contains(.dumbbell))
        XCTAssertTrue(try equipment("drag curl").contains(.barbell))
        XCTAssertTrue(try equipment("trap bar shrug").contains(.barbell))
        XCTAssertTrue(try equipment("reverse curl").contains(.barbell))
        XCTAssertTrue(try equipment("cable shrug").contains(.cable))

        // Bench dip is bodyweight — it must never demand loading equipment.
        let benchDip = try XCTUnwrap(MovementCatalog.canonicalExercise(named: "bench dip"))
        XCTAssertEqual(benchDip.blockKind, .bodyweight)
        XCTAssertTrue(benchDip.equipment.contains(.bodyweight))
    }

    /// A bar lift whose common name never contains the word "barbell" used to
    /// resolve to an EMPTY equipment set and fall through to `.bodyweight` —
    /// which would have offered a Power Clean to someone training on a floor.
    func testBarLiftsWithoutTheWordBarbellStillRequireABarbell() throws {
        for name in ["power clean", "hang clean", "clean and jerk", "power snatch",
                     "thruster", "rack pull", "barbell high pull", "zercher squat",
                     "box squat", "front rack lunge", "sumo deadlift", "seal row"] {
            let def = try XCTUnwrap(MovementCatalog.canonicalExercise(named: name), name)
            XCTAssertTrue(def.equipment.contains(.barbell), "\(name) must require a barbell")
            XCTAssertFalse(
                def.equipment.contains(.bodyweight),
                "\(name) must not be offered as bodyweight work"
            )
        }
    }

    /// Program score is equipment-intent minus a difficulty tiebreaker, so a lift
    /// left at the default `.beginner` outranks the staple it should sit behind.
    /// Olympic lifts floor at `.advanced`; heavy partials at `.intermediate`.
    func testTechnicalLiftsNeverOutrankTheStapleTheySitBehind() throws {
        func def(_ n: String) throws -> MovementDefinition {
            try XCTUnwrap(MovementCatalog.canonicalExercise(named: n), n)
        }
        for name in ["power clean", "hang clean", "clean and jerk", "power snatch", "thruster",
                     "rack pull", "barbell high pull"] {
            XCTAssertEqual(try def(name).difficulty, .advanced, "\(name) is not novice work")
        }

        // Lower programScore wins. The staples must still beat the technical lifts.
        let squat = MovementCatalog.programScore(try def("back squat"), style: .freeWeights)
        let deadlift = MovementCatalog.programScore(try def("deadlift"), style: .freeWeights)
        for name in ["power clean", "clean and jerk", "power snatch", "rack pull"] {
            let score = MovementCatalog.programScore(try def(name), style: .freeWeights)
            XCTAssertGreaterThan(score, squat, "\(name) must not outrank the back squat")
            XCTAssertGreaterThan(score, deadlift, "\(name) must not outrank the deadlift")
        }
    }

    /// "fly" and "lateral raise" name a pattern, not an implement. Claiming the
    /// dumbbell unconditionally made a Cable Fly require dumbbells, hiding every
    /// cable/machine fly and raise from a gym with no free weights.
    func testCableAndMachineFliesDoNotRequireDumbbells() throws {
        func equipment(_ n: String) throws -> [MovementEquipment] {
            try XCTUnwrap(MovementCatalog.canonicalExercise(named: n), n).equipment
        }
        for name in ["cable fly", "incline cable fly", "lateral raise (cable)", "cable rear delt fly"] {
            XCTAssertTrue(try equipment(name).contains(.cable), "\(name) should need a cable")
            XCTAssertFalse(try equipment(name).contains(.dumbbell), "\(name) must not need dumbbells")
        }
        for name in ["machine lateral raise", "rear delt fly (machine)"] {
            XCTAssertFalse(try equipment(name).contains(.dumbbell), "\(name) must not need dumbbells")
        }
        // The genuine free-weight versions still do.
        XCTAssertTrue(try equipment("dumbbell fly").contains(.dumbbell))
        XCTAssertTrue(try equipment("lateral raise (db)").contains(.dumbbell))
    }
}
