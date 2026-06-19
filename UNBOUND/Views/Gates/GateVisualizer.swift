import SwiftUI

/// A gate's living-world layer, advancing with progress. Plan 4 ships eight
/// bespoke implementations (lanterns igniting, blade glowing, seals shattering);
/// Plan 2 uses DefaultGateVisualizer for every gate.
protocol GateVisualizer: View {
    init(world: GateWorld, stationsCleared: Int, stationCount: Int)
}

/// Generic treatment: N pips fill as stations clear, tinted to the world.
struct DefaultGateVisualizer: GateVisualizer {
    let world: GateWorld
    let stationsCleared: Int
    let stationCount: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<max(stationCount, 1), id: \.self) { i in
                Capsule()
                    .fill(i < stationsCleared ? world.fillTint : Color.white.opacity(0.16))
                    .frame(height: 6)
                    .overlay(i < stationsCleared
                        ? Capsule().fill(world.fillTint).blur(radius: 4).opacity(0.5) : nil)
            }
        }
        .animation(.easeOut(duration: 0.4), value: stationsCleared)
    }
}
