import SwiftUI

struct MuscleGroupBreakdown: View {
    let assessments: [MuscleGroupAssessment]
    let radarData: [MuscleRadarChart.RadarDataPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Muscle Groups")
                .font(.subheadline())
                .foregroundColor(.theme.textPrimary)

            MuscleRadarChart(data: radarData)
                .frame(maxWidth: .infinity)

            VStack(spacing: 8) {
                ForEach(assessments, id: \.muscleGroup) { assessment in
                    MuscleGroupRow(assessment: assessment)
                }
            }
        }
        .padding(20)
        .background(Color.theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct MuscleGroupRow: View {
    let assessment: MuscleGroupAssessment
    @State private var isExpanded = false

    private var gapColor: Color {
        if assessment.gap < 10 { return .theme.success }
        if assessment.gap < 25 { return .theme.warning }
        return .theme.danger
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(assessment.muscleGroup.displayName)
                            .font(.bodyMedium())
                            .foregroundColor(.theme.textPrimary)
                        Text(assessment.assessment)
                            .font(.caption(12))
                            .foregroundColor(.theme.textSecondary)
                            .lineLimit(isExpanded ? nil : 1)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        MiniRankBadge(
                            letter: MuscleGroupTierCalculator
                                .tierOnly(for: assessment)
                                .letter,
                            side: 26
                        )

                        Text("\(assessment.currentScore)")
                            .font(.stat(16))
                            .foregroundColor(.theme.textPrimary)

                        gapBadge

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption())
                            .foregroundColor(.theme.textMuted)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider().background(Color.theme.surfaceLight)

                    Text(assessment.recommendation)
                        .font(.caption())
                        .foregroundColor(.theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 12)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.theme.surfaceLight)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var gapBadge: some View {
        Text("Gap \(assessment.gap)")
            .font(.caption(11))
            .foregroundColor(gapColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(gapColor.opacity(0.15))
            .clipShape(Capsule())
    }
}
