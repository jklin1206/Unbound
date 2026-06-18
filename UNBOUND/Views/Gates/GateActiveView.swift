import SwiftUI

/// In-trial view (spec §6.4): the world-stage header over the true-black calm
/// logging surface (one logging spine — reuses the existing ExerciseLogCard via
/// the injected `loggingSurface`). Plan 2 passes demo cards; Plan 4 passes the
/// live ActiveWorkoutSession grid and replaces the per-format dispatch.
struct GateActiveView<LoggingSurface: View>: View {
    let world: GateWorld
    let stationIndex: Int
    let stationCount: Int
    let stationsCleared: Int
    let currentStationTitle: String
    @ViewBuilder var loggingSurface: () -> LoggingSurface

    var body: some View {
        ZStack(alignment: .top) {
            Color.unbound.bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    GateActiveHeaderView(
                        world: world, stationIndex: stationIndex, stationCount: stationCount,
                        stationsCleared: stationsCleared, currentStationTitle: currentStationTitle)
                    loggingSurface()
                        .padding(.horizontal, 16)
                }
                .padding(.bottom, 60)
            }
        }
        .accessibilityIdentifier("gate-active-view")
    }
}
