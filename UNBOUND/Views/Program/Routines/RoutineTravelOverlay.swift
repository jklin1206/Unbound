import SwiftUI
import UIKit

struct RoutineTravelOverlay: View {
    let routine: RoutineDef
    let progress: CGFloat

    var body: some View {
        ZStack {
            Color.unbound.bg.opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .stroke(routine.category.color.opacity(0.16), lineWidth: 18)
                        .frame(width: 166, height: 166)
                        .scaleEffect(1 + progress * 0.45)
                        .opacity(Double(1 - progress * 0.55))
                    Image(systemName: routine.category.systemImage)
                        .font(.system(size: 54, weight: .black))
                        .foregroundStyle(routine.category.color)
                        .offset(x: progress * 22, y: -progress * 18)
                        .scaleEffect(1 + progress * 0.12)
                }

                Text("ENTERING MISSION")
                    .font(Font.unbound.monoS.weight(.heavy))
                    .tracking(2.0)
                    .foregroundStyle(routine.category.color)
            }
            .padding(.horizontal, 28)
        }
    }
}
