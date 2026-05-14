import SwiftUI

struct Step_WhyThisProgram: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            title: "Protocol lock confirmed.",
            subtitle: "Your answers mapped to concrete training decisions. Review the build logic below.",
            progress: progress,
            primaryTitle: "This is mine",
            primaryEnabled: true,
            hudStep: .whyThisProgram,
            onBack: onBack,
            onPrimary: {
                UnboundHaptics.heavy()
                onContinue()
            }
        ) {
            WhyThisProgramView(rationale: buildRationale())
                .padding(.horizontal, -6)
                .padding(.top, -6)
        }
    }

    private func buildRationale() -> ProgramRationale {
        LocalProgramGenerator.previewRationale(
            buildIdentity: BuildIdentity(primary: nil, secondary: nil, shape: .balancedAthlete),
            targetFrequency: flow.targetFrequency,
            equipment: flow.equipment,
            experience: flow.experience,
            sessionLength: flow.sessionLength,
            exerciseStyles: flow.exerciseStyles,
            targetAreas: flow.targetAreas,
            goals: flow.goals,
            obstacles: flow.obstacles,
            sleepQuality: flow.sleepQuality,
            stressLevel: flow.stressLevel,
            currentFrequency: flow.currentFrequency,
            commitment: flow.commitment,
            displayHandle: flow.displayHandle,
            age: flow.age,
            gender: flow.gender,
            heightCm: flow.heightCm,
            weightKg: flow.weightKg
        )
    }
}

#Preview {
    Step_WhyThisProgram(
        flow: OnboardingFlowViewModel(),
        progress: 0.8,
        onBack: {},
        onContinue: {}
    )
}
