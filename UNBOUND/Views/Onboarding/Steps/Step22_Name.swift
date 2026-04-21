import SwiftUI

struct Step22_Name: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    @FocusState private var isFieldFocused: Bool

    var body: some View {
        OnboardingScaffold(
            title: "What should we call you?",
            subtitle: "Shown on your profile and scan cards.",
            progress: progress,
            primaryTitle: "Continue",
            primaryEnabled: !flow.displayHandle.trimmingCharacters(in: .whitespaces).isEmpty,
            hudStep: .name,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            VStack(alignment: .leading, spacing: 14) {
                Spacer().frame(height: 8)

                HUDTextInput(
                    text: $flow.displayHandle,
                    placeholder: "Your handle",
                    eyebrow: "HANDLE",
                    isFocused: $isFieldFocused
                )

                Text("You can change this later in settings.")
                    .font(Font.unbound.monoS)
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .padding(.horizontal, 4)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    isFieldFocused = true
                }
            }
        }
    }
}

#Preview {
    Step22_Name(flow: OnboardingFlowViewModel(), progress: 0.73, onBack: {}, onContinue: {})
}
