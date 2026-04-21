import SwiftUI

struct HUDPanel<Content: View>: View {
    var isActive: Bool = false
    var pulse: Bool = false
    var inset: CGFloat = 8
    @ViewBuilder var content: () -> Content

    var body: some View {
        if isActive && pulse {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                let breathe = 0.6 + 0.4 * (sin(t * 0.6 * .pi * 2) + 1.0) / 2.0
                panelBody(breathe: breathe)
            }
        } else {
            panelBody(breathe: isActive ? 1.0 : 0.0)
        }
    }

    @ViewBuilder
    private func panelBody(breathe: Double) -> some View {
        let shape = ChamferedRectangle(inset: inset)
        content()
            .background(
                shape
                    .fill(Color.unbound.surface)
            )
            .overlay(
                shape
                    .stroke(
                        isActive ? Color.unbound.accent.opacity(breathe) : Color.unbound.borderSubtle,
                        lineWidth: isActive ? 2 : 1
                    )
            )
            .overlay(alignment: .top) {
                if isActive {
                    Rectangle()
                        .fill(Color.unbound.accent.opacity(0.3 * breathe))
                        .frame(height: 1)
                        .padding(.horizontal, inset)
                }
            }
            .clipShape(shape)
            .shadow(
                color: isActive
                    ? Color.unbound.accent.opacity(0.35 * (0.5 + 0.5 * breathe))
                    : .clear,
                radius: isActive ? 16 * (0.6 + 0.4 * breathe) : 0
            )
    }
}

#Preview("HUDPanel states") {
    ZStack {
        Color.unbound.bg.ignoresSafeArea()
        VStack(spacing: 20) {
            HUDPanel(isActive: false) {
                Text("INACTIVE")
                    .font(Font.unbound.titleS)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .padding(20)
                    .frame(maxWidth: .infinity)
            }
            HUDPanel(isActive: true, pulse: false) {
                Text("ACTIVE")
                    .font(Font.unbound.titleS)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .padding(20)
                    .frame(maxWidth: .infinity)
            }
            HUDPanel(isActive: true, pulse: true) {
                Text("ACTIVE + PULSE")
                    .font(Font.unbound.titleS)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .padding(20)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
    }
}
