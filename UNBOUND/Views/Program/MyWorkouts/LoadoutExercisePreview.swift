import SwiftUI

/// A loadout's exercises rendered in the daily-card row style
/// (`ProgramVisualExerciseRow`: art thumbnail, name, muscles, sets × target),
/// shared by the Loadouts tab list and the day loadout picker. `limit` caps
/// the rows for collapsed previews (with a "+N more" tail); nil shows all.
struct LoadoutExercisePreview: View {
    let workout: SavedWorkout
    var limit: Int? = 3

    var body: some View {
        let prescriptions = workout.blocks.flatMap(\.prescriptions)
        let visible = limit.map { Array(prescriptions.prefix($0)) } ?? prescriptions

        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(visible.enumerated()), id: \.element.id) { index, prescription in
                ProgramVisualExerciseRow(prescription: prescription)
                if index < visible.count - 1 {
                    Divider()
                        .padding(.leading, 56)
                        .overlay(Color.unbound.borderSubtle.opacity(0.55))
                }
            }
            if prescriptions.count > visible.count {
                Text("+\(prescriptions.count - visible.count) more")
                    .font(Font.unbound.captionS.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(Color.unbound.textPrimary.opacity(0.62))
                    .padding(.top, 4)
                    .padding(.leading, 2)
            }
        }
    }
}
