import SwiftUI
import UIKit

struct RoutineChallengeDots: View {
    let challenges: [RoutineDef]
    let selectedId: String

    var body: some View {
        HStack(spacing: 9) {
            ForEach(challenges) { routine in
                Capsule()
                    .fill(routine.id == selectedId ? routine.category.color : Color.unbound.textTertiary.opacity(0.32))
                    .frame(width: routine.id == selectedId ? 24 : 7, height: 7)
                    .animation(.easeInOut(duration: 0.2), value: selectedId)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 20)
    }
}
