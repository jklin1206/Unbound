import SwiftUI

struct Step22_Name: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    @FocusState private var isFieldFocused: Bool
    // Local buffer — binds to TextField so only this view re-renders per keystroke.
    // Synced back to flow on submit and focus-loss, not on every character.
    @State private var localHandle: String = ""

    var body: some View {
        OnboardingScaffold(
            title: "What should we call you?",
            subtitle: "Shown on your profile and scan cards.",
            progress: progress,
            primaryTitle: "Continue",
            primaryEnabled: !localHandle.trimmingCharacters(in: .whitespaces).isEmpty,
            hudStep: .name,
            onBack: onBack,
            onPrimary: {
                flow.displayHandle = localHandle
                onContinue()
            }
        ) {
            VStack(alignment: .leading, spacing: 14) {
                Spacer().frame(height: 8)

                HUDTextInput(
                    text: $localHandle,
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
                localHandle = flow.displayHandle
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    isFieldFocused = true
                }
            }
            .onChange(of: isFieldFocused) { _, focused in
                if !focused { flow.displayHandle = localHandle }
            }
        }
    }
}

#Preview {
    Step22_Name(flow: OnboardingFlowViewModel(), progress: 0.73, onBack: {}, onContinue: {})
}
