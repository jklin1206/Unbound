import SwiftUI

// MARK: - Step04_PickArchetype (DEPRECATED — Phase 11)
//
// This step is no longer reachable: .archetype was removed from OnboardingStep
// and this view is no longer routed from OnboardingContainerView.
// File is kept to avoid cascading deletes — fully removed in Phase 17.
//
// TODO(Phase 17): delete this file entirely.

struct Step04_PickArchetype: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    // Local stub — flow.archetype was removed in Phase 11.
    @State private var selectedArchetype: Archetype? = nil

    var body: some View {
        OnboardingScaffold(
            title: "Who do you want to become?",
            subtitle: "Pick the build you'd actually be proud to walk around in. No wrong answer.",
            progress: progress,
            primaryTitle: "Continue",
            primaryEnabled: selectedArchetype != nil,
            hudStep: .buildSeed, // .archetype removed; use nearest valid step
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
                        isSelected: selectedArchetype == arch
                    ) {
                        selectedArchetype = arch
                    }
                }
            }
        }
    }

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
