import SwiftUI

struct Step09_Weight: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            title: "What's your current weight?",
            subtitle: nil,
            progress: progress,
            primaryTitle: "Continue",
            hudStep: .weight,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            VStack(spacing: 16) {
                UnitToggle(leftLabel: "kg", rightLabel: "lb", isRight: Binding(
                    get: { !flow.useMetricWeight },
                    set: { flow.useMetricWeight = !$0 }
                ))
                .frame(maxWidth: .infinity, alignment: .center)

                if flow.useMetricWeight {
                    HUDScrollPicker(
                        selection: Binding(
                            get: { Int(flow.weightKg) },
                            set: { flow.weightKg = Double($0) }
                        ),
                        values: Array(40...180),
                        formatter: { "\($0) KG" },
                        eyebrow: "WEIGHT"
                    )
                } else {
                    HUDScrollPicker(
                        selection: Binding(
                            get: { Int((flow.weightKg * 2.2046).rounded()) },
                            set: { flow.weightKg = Double($0) / 2.2046 }
                        ),
                        values: Array(88...400),
                        formatter: { "\($0) LB" },
                        eyebrow: "WEIGHT"
                    )
                }
            }
            .padding(.top, 8)
        }
    }
}

#Preview {
    Step09_Weight(flow: OnboardingFlowViewModel(), progress: 0.3, onBack: {}, onContinue: {})
}
