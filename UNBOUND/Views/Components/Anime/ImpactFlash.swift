import SwiftUI

struct ImpactFlashModifier: ViewModifier {
    @Binding var trigger: Bool
    var duration: Double = 0.09
    var color: Color = .white

    @State private var opacity: Double = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                color.opacity(opacity)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            )
            .onChange(of: trigger) { _, newValue in
                guard newValue else { return }
                withAnimation(.easeOut(duration: duration * 0.4)) {
                    opacity = 1.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + duration * 0.4) {
                    withAnimation(.easeIn(duration: duration * 0.6)) {
                        opacity = 0
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    trigger = false
                }
            }
    }
}

extension View {
    func impactFlash(trigger: Binding<Bool>, duration: Double = 0.09, color: Color = .white) -> some View {
        modifier(ImpactFlashModifier(trigger: trigger, duration: duration, color: color))
    }
}

private struct ImpactFlashPreview: View {
    @State private var trigger = false
    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            Button("Trigger flash") { trigger = true }
                .foregroundStyle(.white)
        }
        .impactFlash(trigger: $trigger)
    }
}

#Preview {
    ImpactFlashPreview()
}
