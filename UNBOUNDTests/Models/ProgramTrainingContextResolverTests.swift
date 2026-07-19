import XCTest
@testable import UNBOUND

/// Locks the ability-level contract: the picker's experience selection is
/// authoritative in EVERY training mode. Lifting/machines users were once
/// pinned to their onboarding experience because the resolver silently
/// dropped the selection outside calisthenics/hybrid.
final class ProgramTrainingContextResolverTests: XCTestCase {
    private func resolve(
        mode: ProgramTrainingContextMode,
        selected: Experience?,
        current: Experience?
    ) -> ProgramTrainingContextResolution {
        ProgramTrainingContextResolver.resolve(
            selection: ProgramTrainingContextSelection(
                scope: .ongoing,
                mode: mode,
                equipment: [.fullGym],
                experience: selected
            ),
            currentStyle: .freeWeights,
            currentEquipment: [.fullGym],
            currentExerciseStyles: [],
            currentExperience: current
        )
    }

    func testLiftingModeHonorsSelectedExperience() {
        XCTAssertEqual(
            resolve(mode: .lifting, selected: .current, current: .never).experience,
            .current
        )
    }

    func testEveryModeHonorsSelectedExperience() {
        for mode in ProgramTrainingContextMode.allCases {
            XCTAssertEqual(
                resolve(mode: mode, selected: .tried, current: .never).experience,
                .tried,
                "\(mode) dropped the selected experience"
            )
        }
    }

    func testNoSelectionFallsBackToCurrentExperience() {
        XCTAssertEqual(
            resolve(mode: .lifting, selected: nil, current: .tried).experience,
            .tried
        )
    }
}
