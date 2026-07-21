import XCTest
import UIKit
@testable import UNBOUND

extension MovementProgressServiceTests {
    func testBodyMapNoveltyDropsAsSameRegionsSaturate() async throws {
        let database = MockDatabaseService()
        let service = BodyMapProgressService.shared
        let firstGain = benchGain(sourceLogId: "perf-body-1", rawAP: 100)
        let secondGain = benchGain(sourceLogId: "perf-body-2", rawAP: 100)

        let first = await service.ingest(
            movementAPGains: [firstGain],
            userId: "u1",
            sourceLogId: "perf-body-1",
            at: Date(timeIntervalSince1970: 200),
            database: database
        )
        let second = await service.ingest(
            movementAPGains: [secondGain],
            userId: "u1",
            sourceLogId: "perf-body-2",
            at: Date(timeIntervalSince1970: 200),
            database: database
        )
        let duplicate = await service.ingest(
            movementAPGains: [secondGain],
            userId: "u1",
            sourceLogId: "perf-body-2",
            at: Date(timeIntervalSince1970: 250),
            database: database
        )
        let profile: BodyMapProfile = try await database.read(
            collection: "body_map_profiles",
            documentId: "u1"
        )

        XCTAssertEqual(first.noveltyMultiplier, 1.5, accuracy: 0.001)
        XCTAssertLessThan(second.noveltyMultiplier, first.noveltyMultiplier)
        XCTAssertEqual(duplicate.noveltyMultiplier, 1.0, accuracy: 0.001)
        XCTAssertTrue(duplicate.wasDuplicate)
        XCTAssertGreaterThan(profile.load(for: .midLowerChest).lifetimeLoad, 0)
        XCTAssertEqual(profile.processedSourceLogIds, ["perf-body-1", "perf-body-2"])
    }

    func testBodyRegionTrainingLedgerSeparatesDirectSecondaryAndSkillPractice() {
        let loads = BodyRegionTrainingLedger.loads(for: [
            Exercise(
                id: "ledger-bench",
                name: "Bench Press",
                muscleGroups: [.chest, .shoulders, .triceps],
                sets: 4,
                reps: "6-8",
                restSeconds: 120,
                rpe: 8,
                notes: nil,
                substitution: nil
            ),
            Exercise(
                id: "ledger-pullup",
                name: "Pullup",
                muscleGroups: [.back, .lats, .biceps],
                sets: 3,
                reps: "6-10",
                restSeconds: 120,
                rpe: 8,
                notes: nil,
                substitution: nil
            ),
            Exercise(
                id: "ledger-handstand",
                name: "Freestanding Handstand",
                muscleGroups: [.shoulders, .core],
                sets: 5,
                reps: "20s",
                restSeconds: 90,
                rpe: 7,
                notes: nil,
                substitution: nil
            )
        ])
        let byRegion = Dictionary(uniqueKeysWithValues: loads.map { ($0.region, $0) })

        XCTAssertEqual(byRegion[.midLowerChest]?.directHardSets, 4)
        XCTAssertEqual(byRegion[.triceps]?.secondaryExposureSets, 4)
        XCTAssertEqual(byRegion[.lats]?.directHardSets, 3)
        XCTAssertEqual(byRegion[.biceps]?.secondaryExposureSets, 3)
        XCTAssertEqual(byRegion[.frontSideDelts]?.secondaryExposureSets, 4)
        XCTAssertEqual(byRegion[.frontSideDelts]?.skillPracticeSets, 5)
        XCTAssertEqual(byRegion[.frontSideDelts]?.jointTendonStressSets, 5)
        XCTAssertEqual(byRegion[.forearms]?.skillPracticeSets, 5)
        XCTAssertEqual(byRegion[.forearms]?.jointTendonStressSets, 5)
    }

    func testBodyRegionTrainingLedgerKeepsMachineAndBackRegionsPrecise() {
        func loadMap(
            for name: String,
            muscleGroups: [MuscleGroup],
            sets: Int = 3
        ) -> [BodyRegion: BodyRegionTrainingLoad] {
            let loads = BodyRegionTrainingLedger.loads(for: [
                Exercise(
                    id: "ledger-\(MovementCatalog.slug(name))",
                    name: name,
                    muscleGroups: muscleGroups,
                    sets: sets,
                    reps: "8-12",
                    restSeconds: 90,
                    rpe: 8,
                    notes: nil,
                    substitution: nil
                )
            ])
            return Dictionary(uniqueKeysWithValues: loads.map { ($0.region, $0) })
        }

        let latPulldown = loadMap(for: "Lat Pulldown", muscleGroups: [.back, .lats, .biceps])
        XCTAssertEqual(latPulldown[.lats]?.directHardSets, 3)
        XCTAssertNil(latPulldown[.rhomboids])
        XCTAssertNil(latPulldown[.lowerBack])

        let machineRow = loadMap(for: "Machine Row", muscleGroups: [.back, .lats, .biceps])
        XCTAssertEqual(machineRow[.lats]?.directHardSets, 3)
        XCTAssertEqual(machineRow[.rhomboids]?.directHardSets, 3)
        XCTAssertNil(machineRow[.rearDelts])

        let facePull = loadMap(for: "Face Pull", muscleGroups: [.shoulders, .back, .traps])
        XCTAssertEqual(facePull[.rearDelts]?.directHardSets, 3)
        XCTAssertEqual(facePull[.rhomboids]?.directHardSets, 3)
        XCTAssertEqual(facePull[.traps]?.directHardSets, 3)
        XCTAssertNil(facePull[.lats])
        XCTAssertNil(facePull[.triceps])

        let tricepPushdown = loadMap(for: "Tricep Pushdown", muscleGroups: [.triceps])
        XCTAssertEqual(tricepPushdown[.triceps]?.directHardSets, 3)
        XCTAssertNil(tricepPushdown[.biceps])

        let machineChestPress = loadMap(for: "Machine Chest Press", muscleGroups: [.chest, .shoulders, .triceps])
        XCTAssertEqual(machineChestPress[.midLowerChest]?.directHardSets, 3)
        XCTAssertNil(machineChestPress[.upperChest])

        let inclineBenchPress = loadMap(for: "Incline Bench Press", muscleGroups: [.chest, .shoulders, .triceps])
        XCTAssertEqual(inclineBenchPress[.upperChest]?.directHardSets, 3)
        XCTAssertNil(inclineBenchPress[.midLowerChest])

        let hipAdductor = loadMap(for: "Hip Adductor Machine", muscleGroups: [.quads, .glutes])
        XCTAssertEqual(hipAdductor[.adductors]?.directHardSets, 3)
        XCTAssertNil(hipAdductor[.quads])
        XCTAssertNil(hipAdductor[.glutes])

        let hipAbductor = loadMap(for: "Hip Abductor Machine", muscleGroups: [.glutes])
        XCTAssertEqual(hipAbductor[.abductors]?.directHardSets, 3)
        XCTAssertEqual(hipAbductor[.glutes]?.directHardSets, 3)

        let legExtension = loadMap(for: "Leg Extension", muscleGroups: [.quads])
        XCTAssertEqual(legExtension[.quads]?.directHardSets, 3)
        XCTAssertNil(legExtension[.hamstrings])
    }

    func testBodyRegionTrainingLedgerSeparatesMobilityAndCarryStressFromHardSets() {
        let draft = TrainingSessionDraft(
            userId: "u1",
            source: .routine,
            title: "Mobility + Carry",
            estimatedMinutes: 24,
            blocks: [
                TrainingBlock(
                    kind: .routine,
                    title: "Mobility",
                    prescriptions: [
                        TrainingBlockPrescription(
                            exerciseName: "Deep Squat Hold",
                            sets: 2,
                            target: .holdSeconds(45),
                            restSeconds: 20
                        )
                    ]
                ),
                TrainingBlock(
                    kind: .carry,
                    title: "Loaded Carry",
                    prescriptions: [
                        TrainingBlockPrescription(
                            exerciseName: "Farmer Carry",
                            sets: 4,
                            target: .distanceMeters(40),
                            restSeconds: 90,
                            muscleGroups: [.back, .biceps, .triceps, .shoulders]
                        )
                    ]
                )
            ]
        )

        let byRegion = Dictionary(uniqueKeysWithValues: BodyRegionTrainingLedger.loads(for: draft).map { ($0.region, $0) })

        XCTAssertEqual(byRegion[.quads]?.mobilityControlSets, 2)
        XCTAssertEqual(byRegion[.glutes]?.mobilityControlSets, 2)
        XCTAssertEqual(byRegion[.forearms]?.jointTendonStressSets, 4)
        XCTAssertEqual(byRegion[.traps]?.jointTendonStressSets, 4)
        XCTAssertEqual(byRegion[.lowerBack]?.jointTendonStressSets, 4)
        XCTAssertEqual(byRegion[.frontSideDelts]?.jointTendonStressSets, 4)
    }

    func testBodyRegionTrainingLedgerTreatsPlanksAsTrunkBracingNotDirectLowBack() {
        let loads = BodyRegionTrainingLedger.loads(for: [
            Exercise(
                id: "ledger-plank",
                name: "Plank",
                muscleGroups: [.core],
                sets: 3,
                reps: "30s",
                restSeconds: 45,
                rpe: 7,
                notes: nil,
                substitution: nil
            )
        ])
        let byRegion = Dictionary(uniqueKeysWithValues: loads.map { ($0.region, $0) })

        XCTAssertEqual(byRegion[.abs]?.directHardSets, 3)
        XCTAssertEqual(byRegion[.obliques]?.directHardSets, 3)
        XCTAssertEqual(byRegion[.lowerBack]?.directHardSets ?? 0, 0)
        XCTAssertEqual(byRegion[.lowerBack]?.secondaryExposureSets, 3)
    }

    func testTrainingCompletionBodyMapUsesRoleWeightedLoadsForProfile() async throws {
        let services = ServiceContainer.mock
        let log = PerformanceLog(
            id: "perf-body-role-weighted",
            userId: "mock-user-123",
            source: .program,
            title: "Push",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 200),
            blocks: [
                PerformanceBlock(
                    kind: .strength,
                    title: "Push",
                    exercises: [
                        PerformanceExercise(
                            name: "Bench Press",
                            plannedSets: 1,
                            plannedTarget: "5 reps",
                            sets: [PerformanceSet(setNumber: 1, reps: 5, weightKg: 100, rpe: 8)]
                        )
                    ]
                )
            ]
        )

        _ = try await TrainingCompletionService.shared.complete(log, services: services)
        let bodyMap: BodyMapProfile = try await services.database.read(
            collection: "body_map_profiles",
            documentId: "mock-user-123"
        )

        XCTAssertGreaterThan(bodyMap.load(for: .midLowerChest).lifetimeLoad, bodyMap.load(for: .frontSideDelts).lifetimeLoad)
        XCTAssertGreaterThan(bodyMap.load(for: .midLowerChest).lifetimeLoad, bodyMap.load(for: .triceps).lifetimeLoad)
        XCTAssertEqual(bodyMap.load(for: .midLowerChest).recentDirectHardSets, 1)
        XCTAssertEqual(bodyMap.load(for: .frontSideDelts).recentSecondaryExposureSets, 1)
        XCTAssertEqual(bodyMap.load(for: .triceps).recentSecondaryExposureSets, 1)
    }

    func testBodyMapRoleOnlyTrainingLoadUpdatesProfileWithoutMovementAP() async throws {
        let database = MockDatabaseService()
        var tendonLoad = BodyRegionTrainingLoad(region: .forearms)
        tendonLoad.add(4, as: .jointTendonStress)

        let result = await BodyMapProgressService.shared.ingest(
            movementAPGains: [],
            userId: "role-only-user",
            sourceLogId: "role-only-carry",
            at: Date(timeIntervalSince1970: 200),
            trainingLoads: [tendonLoad],
            database: database
        )
        let profile: BodyMapProfile = try await database.read(
            collection: "body_map_profiles",
            documentId: "role-only-user"
        )

        XCTAssertFalse(result.wasDuplicate)
        XCTAssertEqual(result.regionRewards.first?.region, .forearms)
        XCTAssertGreaterThan(result.regionRewards.first?.loadAdded ?? 0, 0)
        XCTAssertEqual(profile.load(for: .forearms).recentJointTendonStressSets, 4)
        XCTAssertGreaterThan(profile.load(for: .forearms).recentLoad, 0)
    }

}
