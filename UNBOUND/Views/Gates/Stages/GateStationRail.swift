import SwiftUI

/// A thin segmented rail — one segment per trial station — used by the in-trial world
/// stages to show how many stations have been logged. `filled` segments take the gate's
/// tint; the rest stay dim. Generic over any station count.
struct GateStationRail: View {
    let total: Int
    let filled: Int
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<max(total, 1), id: \.self) { i in
                Capsule()
                    .fill(i < filled ? tint : Color.white.opacity(0.14))
                    .frame(height: 4)
                    .shadow(color: i < filled ? tint.opacity(0.6) : .clear, radius: 4)
            }
        }
        .animation(.easeOut(duration: 0.4), value: filled)
    }
}
