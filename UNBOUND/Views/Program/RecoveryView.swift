import SwiftUI

struct RecoveryView: View {
    let plan: RecoveryPlan

    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Sleep target
                    sleepCard

                    // Activities list
                    activitiesSection

                    // Notes
                    if !plan.notes.isEmpty {
                        notesCard
                    }
                }
                .padding(16)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Recovery")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sleepCard: some View {
        HStack(spacing: 16) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 36))
                .foregroundColor(Color(hex: "AF52DE"))

            VStack(alignment: .leading, spacing: 4) {
                Text("Sleep Target")
                    .font(.bodyText(14))
                    .foregroundColor(.theme.textSecondary)
                Text("\(String(format: "%.1f", plan.sleepHoursTarget)) hours")
                    .font(.headline(24))
                    .foregroundColor(.theme.textPrimary)
                Text("\(plan.restDaysPerWeek) rest days per week")
                    .font(.caption(13))
                    .foregroundColor(.theme.textMuted)
            }
            Spacer()
        }
        .padding(20)
        .background(Color.theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var activitiesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recovery Activities")
                .font(.subheadline(16))
                .foregroundColor(.theme.textPrimary)

            ForEach(plan.activities) { activity in
                RecoveryActivityCard(activity: activity)
            }
        }
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Coach Notes", systemImage: "note.text")
                .font(.bodyMedium(14))
                .foregroundColor(.theme.textSecondary)

            Text(plan.notes)
                .font(.bodyText(14))
                .foregroundColor(.theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Recovery Activity Card

private struct RecoveryActivityCard: View {
    let activity: RecoveryActivity

    var body: some View {
        HStack(spacing: 14) {
            // Icon placeholder
            ZStack {
                Circle()
                    .fill(Color.pink.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: activityIcon)
                    .font(.system(size: 18))
                    .foregroundColor(.pink)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(activity.name)
                    .font(.bodyMedium(15))
                    .foregroundColor(.theme.textPrimary)

                Text(activity.description)
                    .font(.bodyText(13))
                    .foregroundColor(.theme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(activity.durationMinutes) min")
                    .font(.bodyMedium(14))
                    .foregroundColor(.theme.textPrimary)
                Text(activity.frequency)
                    .font(.caption(12))
                    .foregroundColor(.theme.textMuted)
            }
        }
        .padding(14)
        .background(Color.theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var activityIcon: String {
        let name = activity.name.lowercased()
        if name.contains("stretch") || name.contains("yoga") { return "figure.flexibility" }
        if name.contains("walk") { return "figure.walk" }
        if name.contains("foam") || name.contains("roll") { return "roller.fill" }
        if name.contains("ice") || name.contains("cold") { return "snowflake" }
        if name.contains("massage") { return "hand.point.up.fill" }
        if name.contains("breath") || name.contains("meditat") { return "lungs.fill" }
        return "heart.fill"
    }
}
