import SwiftUI

struct BodyScoreCard: View {
    let analysis: BodyAnalysis

    var body: some View {
        VStack(spacing: 20) {
            ScoreRing(score: analysis.overallScore, maxScore: 100, size: 150)

            VStack(spacing: 6) {
                Text("Your snapshot · \(analysis.targetArchetype.displayName)")
                    .font(.subheadline(20))
                    .foregroundColor(.theme.textPrimary)
                    .multilineTextAlignment(.center)

                Text(analysis.targetArchetype.animeReferences.joined(separator: " / "))
                    .font(.caption())
                    .foregroundColor(.theme.primary)
            }

            Text(analysis.summary)
                .font(.bodyText())
                .foregroundColor(.theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Divider()
                .background(Color.theme.surfaceLight)

            HStack(alignment: .top, spacing: 16) {
                bulletList(title: "Strengths", items: analysis.strengths, color: .theme.success)
                bulletList(title: "Weaknesses", items: analysis.weaknesses, color: .theme.danger)
            }
        }
        .padding(20)
        .background(Color.theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func bulletList(title: String, items: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.bodyMedium(14))
                .foregroundColor(color)

            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 6) {
                    Circle()
                        .fill(color)
                        .frame(width: 5, height: 5)
                        .padding(.top, 5)
                    Text(item)
                        .font(.caption())
                        .foregroundColor(.theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
