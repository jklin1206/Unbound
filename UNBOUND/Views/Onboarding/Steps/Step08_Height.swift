import SwiftUI

struct Step08_Height: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            title: "How tall are you?",
            subtitle: nil,
            progress: progress,
            primaryTitle: "Continue",
            hudStep: .height,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            VStack(spacing: 16) {
                UnitToggle(leftLabel: "cm", rightLabel: "ft", isRight: Binding(
                    get: { !flow.useMetricHeight },
                    set: { flow.useMetricHeight = !$0 }
                ))
                .frame(maxWidth: .infinity, alignment: .center)

                if flow.useMetricHeight {
                    HUDScrollPicker(
                        selection: Binding(
                            get: { Int(flow.heightCm) },
                            set: { flow.heightCm = Double($0) }
                        ),
                        values: Array(140...220),
                        formatter: { "\($0) CM" },
                        eyebrow: "HEIGHT"
                    )
                } else {
                    HUDScrollPicker(
                        selection: Binding(
                            get: { totalInches(from: flow.heightCm) },
                            set: { flow.heightCm = cm(fromTotalInches: $0) }
                        ),
                        values: Array(54...86),
                        formatter: { inches in
                            let ft = inches / 12
                            let inch = inches % 12
                            return "\(ft)' \(inch)\""
                        },
                        eyebrow: "HEIGHT"
                    )
                }
            }
            .padding(.top, 8)
        }
    }

    private func totalInches(from cm: Double) -> Int {
        Int((cm / 2.54).rounded())
    }

    private func cm(fromTotalInches inches: Int) -> Double {
        Double(inches) * 2.54
    }
}

#Preview {
    Step08_Height(flow: OnboardingFlowViewModel(), progress: 0.26, onBack: {}, onContinue: {})
}
