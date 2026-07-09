import SwiftUI

// MARK: - Step_Verdict
//
// The post-scan reveal. Reframed from "verdict" to "snapshot" — the scan is
// a visual record of progress toward the user's chosen archetype, not a
// score against it. No match-% anywhere. Rank shown is the user's gym-earned
// rank (derived from commitment + lifestyle), not a scan output.

struct Step_Verdict: View {
    @Bindable var flow: OnboardingFlowViewModel
    let onContinue: () -> Void

    @State var hasAnimated = false

    var body: some View {
        ZStack {
            verdictScreenBackground

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 18) {
                        Color.clear
                            .frame(height: 0)
                            .id("verdictTop")

                        portfolioSheet
                        if flow.scanInsights != nil {
                            scanSignalStrip
                        }
                        Spacer().frame(height: 124) // space for pinned CTA
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 52)
                }
                .onAppear {
                    DispatchQueue.main.async {
                        proxy.scrollTo("verdictTop", anchor: .top)
                    }
                }
            }

            // Pinned CTA
            VStack {
                Spacer()
                UnboundButton(
                    title: L10n.onboarding("verdict.primary", defaultValue: "Open your first quest"),
                    icon: "arrow.right",
                    action: {
                        // The App Store rating ask now fires earlier, during the
                        // scan-analyzing beat (Step_ScanAnalyzing), so this CTA
                        // just advances into the first-quest demo.
                        onContinue()
                    }
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                .background(
                    LinearGradient(
                        colors: [Color.unbound.bg.opacity(0), Color.unbound.bg],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 120)
                    .ignoresSafeArea(edges: .bottom)
                    .allowsHitTesting(false),
                    alignment: .bottom
                )
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .opacity(revealIsSettled ? 1 : 0)
        .offset(y: revealIsSettled ? 0 : 16)
        .onAppear {
            if isDebugOnboardingPreview {
                hasAnimated = true
                return
            }
            withAnimation(.spring(response: 0.75, dampingFraction: 0.88)) {
                hasAnimated = true
            }
            UnboundHaptics.heavy()
        }
    }

    // MARK: Hero — rank + scan photo

}
