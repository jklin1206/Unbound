import SwiftUI

struct ReportShareView: View {
    let analysis: BodyAnalysis
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                shareableCard
                    .padding()

                Button {
                    shareImage()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .font(.bodyMedium())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.theme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
            }
            .background(Color.theme.background)
            .navigationTitle("Share Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.theme.primary)
                }
            }
        }
    }

    private var shareableCard: some View {
        VStack(spacing: 16) {
            Text("UNBOUND")
                .font(.headline(24))
                .foregroundColor(.theme.primary)
                .tracking(2)

            ScoreRing(score: analysis.overallScore, maxScore: 100, size: 100)

            Text(analysis.targetArchetype.displayName.uppercased())
                .font(.subheadline())
                .foregroundColor(.theme.textPrimary)
                .tracking(2)

            Text(analysis.summary)
                .font(.caption())
                .foregroundColor(.theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .background(Color.theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @MainActor
    private func shareImage() {
        let renderer = ImageRenderer(content: shareableCard.frame(width: 350))
        renderer.scale = 3
        guard let image = renderer.uiImage else { return }

        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }
        rootVC.present(activityVC, animated: true)
    }
}
