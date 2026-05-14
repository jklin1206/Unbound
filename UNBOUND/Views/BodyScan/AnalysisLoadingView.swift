import SwiftUI

struct AnalysisLoadingView: View {
    @ObservedObject var viewModel: BodyScanViewModel
    @EnvironmentObject var services: ServiceContainer
    @Environment(\.dismiss) private var dismiss

    @State private var pulseOpacity: Double = 0.4
    @State private var showReport = false

    private var archetypeFunFact: String {
        return "Analyzing your build — every rep you've done is about to pay off."
    }

    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Pulsing silhouette
                ZStack {
                    Circle()
                        .fill(Color.theme.primary.opacity(0.1))
                        .frame(width: 160, height: 160)
                        .scaleEffect(pulseOpacity == 1.0 ? 1.1 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                            value: pulseOpacity
                        )

                    Image(systemName: "figure.stand")
                        .font(.system(size: 72, weight: .light))
                        .foregroundColor(.theme.primary)
                        .opacity(pulseOpacity)
                        .animation(
                            .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                            value: pulseOpacity
                        )
                }

                // Progress status
                VStack(spacing: 12) {
                    if viewModel.analysisProgress != .idle && viewModel.analysisProgress != .failed {
                        ProgressView()
                            .tint(.theme.primary)
                            .scaleEffect(1.2)
                    }

                    Text(viewModel.analysisProgress.rawValue)
                        .font(.bodyMedium(17))
                        .foregroundColor(.theme.textPrimary)
                        .multilineTextAlignment(.center)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.analysisProgress.rawValue)
                }

                // Fun fact card
                VStack(spacing: 8) {
                    Text("Did you know?")
                        .font(.caption(13))
                        .foregroundColor(.theme.primary)
                        .textCase(.uppercase)
                        .tracking(1.2)

                    Text(archetypeFunFact)
                        .font(.bodyText(14))
                        .foregroundColor(.theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(20)
                .background(Color.theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 32)

                Spacer()

                // Retry button on failure
                if viewModel.analysisProgress == .failed {
                    VStack(spacing: 12) {
                        Text("Something went wrong. Check your connection and try again.")
                            .font(.caption())
                            .foregroundColor(.theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        GradientButton(title: "Retry Analysis", action: {
                            Task { await viewModel.startAnalysis() }
                        })
                        .padding(.horizontal, 32)
                    }
                    .padding(.bottom, 48)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            pulseOpacity = 1.0
            if viewModel.analysisProgress == .idle || viewModel.analysisProgress == .failed {
                Task { await viewModel.startAnalysis() }
            }
        }
        .onChange(of: viewModel.analysisProgress) { _, newValue in
            if newValue == .complete {
                showReport = true
            }
        }
        .fullScreenCover(isPresented: $showReport) {
            // Report view will be implemented in Task 14
            // Placeholder dismiss for now
            ZStack {
                Color.theme.background.ignoresSafeArea()
                VStack(spacing: 20) {
                    Text("Analysis Complete!")
                        .font(.headline(28))
                        .foregroundColor(.theme.textPrimary)
                    Text("Report view coming in Task 14")
                        .font(.bodyText())
                        .foregroundColor(.theme.textSecondary)
                    GradientButton(title: "Done", action: { showReport = false })
                        .padding(.horizontal, 32)
                }
            }
        }
    }
}
