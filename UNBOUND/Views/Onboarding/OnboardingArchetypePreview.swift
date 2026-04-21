import SwiftUI

struct OnboardingArchetypePreview: View {
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Text("Which physique are you chasing?")
                    .font(.headline(24))
                    .foregroundColor(.theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(Archetype.allCases) { archetype in
                            ArchetypeCard(archetype: archetype)
                                .frame(width: 220)
                        }
                    }
                    .padding(.horizontal, 24)
                }

                Spacer()

                GradientButton(title: "Let's Go", action: onComplete)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 80)
            }
        }
    }
}
