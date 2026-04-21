import SwiftUI

// MARK: - Step 04: Pick your archetype
//
// 4 archetype cards in a clean 2×2 grid. Selection required to advance.

struct Step04_PickArchetype: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            title: "Who do you want to become?",
            subtitle: "Pick the build you'd actually be proud to walk around in. No wrong answer.",
            progress: progress,
            primaryTitle: "Continue",
            primaryEnabled: flow.archetype != nil,
            hudStep: .archetype,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 12
            ) {
                ForEach(Array(orderedArchetypes.enumerated()), id: \.element) { idx, arch in
                    ArchetypePickerCard(
                        archetype: arch,
                        index: idx,
                        isSelected: flow.archetype == arch
                    ) {
                        flow.archetype = arch
                    }
                }
            }
        }
    }

    // Order (2×2 grid, left-to-right, top-to-bottom):
    // V-TAPER · SHREDDED / HEAVYWEIGHT · SLEEPER — aspirational first, sleeper last.
    private var orderedArchetypes: [Archetype] {
        [.vTaper, .leanCut, .heavyDuty, .shredded]
    }
}

#Preview {
    Step04_PickArchetype(
        flow: OnboardingFlowViewModel(),
        progress: 0.15,
        onBack: {},
        onContinue: {}
    )
}
