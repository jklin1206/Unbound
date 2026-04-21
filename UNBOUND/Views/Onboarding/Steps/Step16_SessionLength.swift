import SwiftUI

struct Step16_SessionLength: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            title: "How long is a typical session?",
            subtitle: nil,
            progress: progress,
            primaryTitle: "Continue",
            primaryEnabled: flow.sessionLength != nil,
            hudStep: .sessionLength,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            VStack(spacing: 12) {
                ForEach(Array(SessionLength.allCases.enumerated()), id: \.element) { idx, s in
                    HUDSelectRow(
                        index: idx + 1,
                        title: s.displayName,
                        subtitle: subtitle(for: s),
                        isSelected: flow.sessionLength == s
                    ) {
                        flow.sessionLength = s
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    private func subtitle(for s: SessionLength) -> String {
        switch s {
        case .thirty: return "Tight, focused"
        case .fortyFive: return "Balanced"
        case .sixty: return "Recommended"
        case .ninetyPlus: return "Heavy volume"
        }
    }
}

#Preview {
    Step16_SessionLength(flow: OnboardingFlowViewModel(), progress: 0.53, onBack: {}, onContinue: {})
}
