import SwiftUI

/// Router for the in-trial world stage (spec §6.4). Each gate gets a bespoke,
/// interactive living-world backdrop keyed off `world.element`; gates without a
/// bespoke stage yet fall back to the banner header. The calm logging surface
/// (one logging spine) always renders beneath this in `GateActiveView`.
struct GateWorldStageView: View {
    let world: GateWorld
    let stationIndex: Int       // 0-based current station
    let stationCount: Int
    let stationsCleared: Int
    let currentStationTitle: String

    var body: some View {
        switch world.element {
        case .lanterns:
            LanternCourtyardStage(
                world: world,
                stationCount: stationCount,
                stationsCleared: stationsCleared,
                currentStationTitle: currentStationTitle
            )
        case .forge:
            ForgeStage(
                world: world,
                stationCount: stationCount,
                stationsCleared: stationsCleared,
                currentStationTitle: currentStationTitle
            )
        case .seals:
            SealAltarStage(
                world: world,
                stationCount: stationCount,
                stationsCleared: stationsCleared,
                currentStationTitle: currentStationTitle
            )
        case .siege:
            BreachGateStage(
                world: world,
                stationCount: stationCount,
                stationsCleared: stationsCleared,
                currentStationTitle: currentStationTitle
            )
        case .landings:
            GoldenStairStage(
                world: world,
                stationCount: stationCount,
                stationsCleared: stationsCleared,
                currentStationTitle: currentStationTitle
            )
        default:
            // Not-yet-bespoke gates keep the banner header (Plan 4 fills these in).
            GateActiveHeaderView(
                world: world,
                stationIndex: stationIndex,
                stationCount: stationCount,
                stationsCleared: stationsCleared,
                currentStationTitle: currentStationTitle
            )
        }
    }
}
