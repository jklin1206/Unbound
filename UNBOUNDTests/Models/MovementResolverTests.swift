import XCTest
@testable import UNBOUND

final class MovementResolverTests: XCTestCase {
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

    func testWallHandstandSixtySecondsResolvesToSkillHoldWork() {
        let resolved = MovementResolver.resolve("Wall Handstand 60s")

        XCTAssertEqual(resolved.role, .skillDrill)
        XCTAssertEqual(resolved.blockKind, .skill)
        XCTAssertEqual(resolved.loggerMode, .skillAttempts)
        XCTAssertEqual(resolved.skillId, "hs.wall-handstand-30")
        XCTAssertTrue(resolved.variationTags.contains(.wallSupported))
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

        XCTAssertEqual(hipFlexor.role, .mobilityDuration)
        XCTAssertEqual(hipFlexor.rankTemplate, .mobilityDuration)
        XCTAssertEqual(hipFlexor.loggerMode, .mobility)
        XCTAssertEqual(hipFlexor.blockKind, .routine)

        XCTAssertEqual(wrist.role, .mobilityDuration)
        XCTAssertEqual(wrist.displayName, "Wrist Prep Flow")
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

        XCTAssertEqual(skillTargets.count, liveSkillNodes.count)

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
        XCTAssertEqual(MovementCatalog.skillTargets.count, SkillGraph.shared.nodes.count)
        XCTAssertGreaterThan(MovementCatalog.rankStandards.count, 100)
        XCTAssertEqual(MovementCatalog.movementStandardLadders.count, MovementCatalog.rankStandards.count)
        XCTAssertGreaterThan(MovementCatalog.loggableVariants.count, 20)
        XCTAssertGreaterThan(MovementCatalog.loggableMovements.count, MovementCatalog.rankStandards.count)
        XCTAssertEqual(MovementCatalog.cardioMovements.count, CardioType.allCases.count)
        XCTAssertFalse(MovementCatalog.carryMovements.isEmpty)
        XCTAssertFalse(MovementCatalog.mobilityMovements.isEmpty)

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

        XCTAssertEqual(MovementCatalog.catalogExercises(for: .pullVertical).count, 20)
        XCTAssertEqual(
            MovementCatalog.catalogExercise(named: "Barbell Bench Press")?.name,
            "bench press"
        )
    }

    func testMovementCatalogDrivesExerciseLibraryAndSwapAlternatives() {
        XCTAssertEqual(ExerciseLibrary.all.count, MovementCatalog.legacyExercises.count)
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
        XCTAssertTrue(bodyweightOnly.contains { $0.displayName == "Pushup" })
        XCTAssertTrue(bodyweightOnly.contains { $0.displayName == "Bodyweight Squat" })
        XCTAssertFalse(bodyweightOnly.contains { $0.displayName == "Lat Pulldown (Bar)" })
        XCTAssertFalse(bodyweightOnly.contains { $0.displayName == "Pull-Up (Bodyweight)" })

        let bodyweightWithBar = MovementCatalog.programDefinitions(
            style: .bodyweight,
            userEquipment: [.bodyweight, .pullupBar]
        )
        XCTAssertTrue(bodyweightWithBar.contains { $0.displayName == "Pull-Up (Bodyweight)" })

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

    func testEveryRankedStandardHasNineTierMovementStandards() {
        let invalid = MovementCatalog.movementStandardLadders.compactMap { ladder -> String? in
            guard ladder.tiers.count == SkillTier.allCases.count,
                  ladder.tiers.map(\.tier) == SkillTier.allCases else {
                return "\(ladder.movementId) -> \(ladder.tiers.map { $0.tier.displayName }.joined(separator: ", "))"
            }
            return nil
        }

        XCTAssertTrue(
            invalid.isEmpty,
            "Every ranked movement standard must expose the full 9-tier ladder:\n\(invalid.joined(separator: "\n"))"
        )

        let benchResolved = MovementResolver.resolve("Bench Press")
        let bench = MovementCatalog.definition(for: benchResolved.movementId).flatMap(MovementCatalog.standardLadder)
        XCTAssertEqual(bench?.tiers.first?.displayText, "0.25x BW x 5")
        XCTAssertEqual(bench?.tiers.last?.tier, .ascendant)

        let pullupResolved = MovementResolver.resolve("Pull-Up")
        let pullup = MovementCatalog.definition(for: pullupResolved.movementId).flatMap(MovementCatalog.standardLadder)
        XCTAssertEqual(pullup?.rankTemplate, .bodyweightReps)
        XCTAssertEqual(pullup?.tiers.last?.primaryMetric, .reps)

        let lSitResolved = MovementResolver.resolve("L-Sit")
        let lSit = MovementCatalog.definition(for: lSitResolved.movementId).flatMap(MovementCatalog.standardLadder)
        XCTAssertEqual(lSit?.rankTemplate, .holdControl)
        XCTAssertEqual(lSit?.tiers.last?.primaryMetric, .holdSeconds)
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

    func testRepresentativeGymExercisesHaveExpectedTemplatesAndSlots() {
        let bench = MovementResolver.resolve("Bench Press")
        XCTAssertEqual(bench.rankTemplate, .barbellStrength)
        XCTAssertEqual(bench.movementSlot, .horizontalPush)
        XCTAssertTrue(bench.bodyRegions.contains(.chest))
        XCTAssertTrue(bench.bodyRegions.contains(.triceps))

        let legPress = MovementResolver.resolve("Leg Press")
        XCTAssertEqual(legPress.rankTemplate, .machineStrength)
        XCTAssertEqual(legPress.movementSlot, .squat)
        XCTAssertTrue(legPress.bodyRegions.contains(.quads))
        XCTAssertTrue(legPress.bodyRegions.contains(.glutes))

        let neutralPulldown = MovementResolver.resolve("Lat Pulldown (Neutral)")
        XCTAssertEqual(neutralPulldown.rankTemplate, .machineStrength)
        XCTAssertEqual(neutralPulldown.blockKind, .strength)
        XCTAssertEqual(neutralPulldown.loggerMode, .strengthSets)
        XCTAssertEqual(neutralPulldown.variantOfMovementId, "exercise.lat-pulldown")
        XCTAssertEqual(neutralPulldown.rankStandardMovementId, "exercise.lat-pulldown")

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

        let hammerStrengthRow = MovementResolver.resolve("Hammer Strength Row")
        XCTAssertEqual(hammerStrengthRow.rankTemplate, .machineStrength)
        XCTAssertEqual(hammerStrengthRow.rankStandardMovementId, "exercise.machine-row")

        let declineSitup = MovementResolver.resolve("Decline Sit-Up")
        XCTAssertEqual(declineSitup.rankTemplate, .bodyweightReps)
        XCTAssertEqual(declineSitup.blockKind, .bodyweight)

        let holdMovements = [
            "L-Sit",
            "L-Sit (Tucked)",
            "Tuck Front Lever",
            "Advanced Tuck Front Lever",
            "Dragon Flag"
        ]
        for movement in holdMovements {
            let resolved = MovementResolver.resolve(movement)
            XCTAssertEqual(resolved.rankTemplate, .holdControl, "\(movement) should use hold/control ranking")
            XCTAssertEqual(resolved.loggerMode, .hold, "\(movement) should use the hold timer")
        }

        let hollowRock = MovementResolver.resolve("Hollow Rock")
        XCTAssertEqual(hollowRock.rankTemplate, .bodyweightReps)
        XCTAssertEqual(hollowRock.loggerMode, .bodyweightSets)

        let tuckedLSit = MovementCatalog.definition(for: "exercise.l-sit-tucked")
        XCTAssertEqual(tuckedLSit?.difficulty, .beginner)

        let straightBarDip = MovementResolver.resolve("Straight Bar Dip")
        XCTAssertEqual(straightBarDip.movementSlot, .arms)

        let hipAdductor = MovementResolver.resolve("Hip Adductor Machine")
        XCTAssertEqual(hipAdductor.movementSlot, .squat)

        let tricepPushdown = MovementCatalog.definition(for: "exercise.tricep-pushdown")
        XCTAssertEqual(tricepPushdown?.skillAssociations.contains("pp.muscle-up"), false)

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
}
