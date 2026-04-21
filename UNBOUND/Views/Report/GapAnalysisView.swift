import SwiftUI

struct GapAnalysisView: View {
    let focusAreas: [FocusArea]
    let onUnlock: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Focus Areas")
                .font(.subheadline())
                .foregroundColor(.theme.textPrimary)

            if focusAreas.isEmpty {
                Text("No focus areas identified.")
                    .font(.caption())
                    .foregroundColor(.theme.textMuted)
            } else {
                VStack(spacing: 10) {
                    ForEach(focusAreas, id: \.muscleGroup) { area in
                        FocusAreaCard(area: area)
                    }
                }
            }

            GradientButton(title: "Unlock Your Custom Program", action: onUnlock)
                .padding(.top, 4)
        }
        .padding(20)
        .background(Color.theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct FocusAreaCard: View {
    let area: FocusArea

    private var isTopThree: Bool { area.priority <= 3 }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            priorityBadge

            VStack(alignment: .leading, spacing: 6) {
                Text(area.muscleGroup.displayName)
                    .font(isTopThree ? .subheadline(16) : .bodyMedium(15))
                    .foregroundColor(.theme.textPrimary)

                Text(area.rationale)
                    .font(.caption())
                    .foregroundColor(.theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 4) {
                    Image(systemName: "target")
                        .font(.caption(11))
                        .foregroundColor(.theme.primary)
                    Text(area.suggestedFocus)
                        .font(.caption(12))
                        .foregroundColor(.theme.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 2)
            }
        }
        .padding(isTopThree ? 16 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.theme.surfaceLight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isTopThree ? Color.theme.primary.opacity(0.5) : Color.clear, lineWidth: isTopThree ? 1.5 : 0)
        )
    }

    private var priorityBadge: some View {
        ZStack {
            Circle()
                .fill(isTopThree ? Color.theme.primary : Color.theme.surfaceLight)
                .frame(width: 28, height: 28)
            Text("\(area.priority)")
                .font(.bodyMedium(12))
                .foregroundColor(isTopThree ? .white : .theme.textMuted)
        }
        .padding(.top, 2)
    }
}
