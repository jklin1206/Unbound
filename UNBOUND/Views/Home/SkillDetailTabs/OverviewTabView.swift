import SwiftUI

// MARK: - OverviewTabView (Phase 3a)
//
// First tab in SkillDetailView. Three sections:
//   • HOW TO UNLOCK — 2-3 derived checklist rows
//   • PRO TIP — first formCue, or a generic placeholder
//   • Greyed placeholder cards for RESEARCH-BACKED PATH + KEY STATISTICS
//     (populated in Phase 3b once educational content is authored).

struct OverviewTabView: View {
    let node: SkillNode

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            howToUnlockSection
            proTipCallout
            placeholderCard(
                title: "RESEARCH-BACKED PATH",
                subtitle: "Coming in a future update.",
                icon: "text.book.closed"
            )
            placeholderCard(
                title: "KEY STATISTICS",
                subtitle: "Coming in a future update.",
                icon: "chart.bar.xaxis"
            )
        }
    }

    // MARK: - How to unlock

    private var howToUnlockSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("HOW TO UNLOCK")

            VStack(alignment: .leading, spacing: 10) {
                ForEach(unlockSteps, id: \.title) { step in
                    unlockRow(step: step)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
        }
    }

    private struct UnlockStep {
        let title: String
        let detail: String
    }

    private var unlockSteps: [UnlockStep] {
        var steps: [UnlockStep] = []

        // Step 1: highest-rank prereq summary (if any)
        let allPrereqs = node.prereqs.flatMap { $0.nodeIds }
        if let firstPrereqId = allPrereqs.first {
            let name = firstPrereqId
                .replacingOccurrences(of: "-", with: " ")
                .capitalized
            steps.append(
                UnlockStep(
                    title: "Build the base",
                    detail: "Clear prerequisite · \(name)"
                )
            )
        }

        // Step 2: Level 1 criterion
        if let lvl1 = node.levels.first(where: { $0.level == 1 }) {
            steps.append(
                UnlockStep(
                    title: "Your first rep",
                    detail: lvl1.criterion
                )
            )
        }

        // Step 3: call to action
        steps.append(
            UnlockStep(
                title: "Log sessions",
                detail: "Log sessions on this skill to level up the XP bar."
            )
        )

        return steps
    }

    private func unlockRow(step: UnlockStep) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.unbound.accent.opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Color.unbound.accent)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(step.title)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text(step.detail)
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Pro tip

    private var proTipCallout: some View {
        let tip: String = {
            if let first = node.formCues.first, !first.isEmpty { return first }
            return "Consistency beats intensity. Train the progressions, not just the skill."
        }()
        return VStack(alignment: .leading, spacing: 10) {
            sectionHeader("PRO TIP")

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.unbound.impact)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.unbound.impact.opacity(0.15)))
                Text(tip)
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
        }
    }

    // MARK: - Placeholders

    private func placeholderCard(title: String, subtitle: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title)

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.unbound.surfaceElevated))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textSecondary)
                    Text(subtitle)
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
                Spacer(minLength: 0)
                Text("SOON")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(Color.unbound.surfaceElevated)
                    )
                    .overlay(
                        Capsule().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                    )
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(placeholderBackground)
            .opacity(0.85)
        }
    }

    // MARK: - Styling helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Font.unbound.captionS.weight(.heavy))
            .tracking(2.0)
            .foregroundStyle(Color.unbound.textTertiary)
    }

    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface)
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.unbound.border, lineWidth: 1)
        }
    }

    private var placeholderBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface.opacity(0.5))
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    Color.unbound.border.opacity(0.7),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                )
        }
    }
}
