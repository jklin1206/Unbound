import SwiftUI

// MARK: - OverviewTabView (Phase 3a / 2g polish)
//
// First tab in SkillDetailView.
//   • HOW TO UNLOCK   — derived checklist. Long lists collapse to 2 rows
//                        + "Show more" disclosure.
//   • PRO TIP         — first formCue. Tight single-card treatment.
//   • MORE COMING SOON — consolidates the old RESEARCH-BACKED PATH +
//                        KEY STATISTICS stubs into one card with inline
//                        badges; the individual sections return in Phase 3b.

struct OverviewTabView: View {
    let node: SkillNode
    /// Graph is passed so we can resolve prereq ids → titles cleanly.
    /// Nil-tolerant: if we can't resolve, we fall back to a humanized id.
    var graph: SkillGraph? = nil

    @State private var unlockExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            howToUnlockSection
            proTipCallout
            comingSoonCard
        }
    }

    // MARK: - How to unlock

    private var howToUnlockSection: some View {
        let steps = unlockSteps
        let collapsedLimit = 2
        let needsCollapse = steps.count > collapsedLimit
        let visible = (needsCollapse && !unlockExpanded)
            ? Array(steps.prefix(collapsedLimit))
            : steps

        return VStack(alignment: .leading, spacing: 10) {
            sectionHeader("How to Unlock")

            VStack(alignment: .leading, spacing: 10) {
                ForEach(visible, id: \.title) { step in
                    unlockRow(step: step)
                }
                if needsCollapse {
                    showMoreButton(total: steps.count, expanded: unlockExpanded)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
        }
    }

    private struct UnlockStep {
        let title: String
        let detail: String?
    }

    private var unlockSteps: [UnlockStep] {
        var steps: [UnlockStep] = []

        // Step 1: Prerequisite — resolve id → title via graph, not the raw
        // hyphenated id. Old bug: "Pp.5 Pullups" came from capitalizing
        // "pp-5-pullups" literally. Now "Clear Pull-Up" lands correctly.
        let allPrereqIds = node.prereqs.flatMap { $0.nodeIds }
        if let firstPrereqId = allPrereqIds.first {
            let title = graph?.node(id: firstPrereqId)?.title
                ?? humanize(id: firstPrereqId)
            steps.append(
                UnlockStep(
                    title: "Clear \(title)",
                    detail: nil
                )
            )
        }

        // Step 2: Level 1 criterion — first clean rep.
        if let lvl1 = node.levels.first(where: { $0.level == 1 }) {
            steps.append(
                UnlockStep(
                    title: "Your first rep",
                    detail: lvl1.criterion
                )
            )
        }

        // Step 3: Ongoing — log sessions.
        steps.append(
            UnlockStep(
                title: "Log sessions",
                detail: "Each session feeds the XP bar and levels this skill up."
            )
        )

        return steps
    }

    /// Fallback when the graph lookup misses. Turns "pp-5-pullups" into
    /// "5 Pullups" rather than the old "Pp.5 Pullups" artifact — strips
    /// any short leading token that looks like a prefix code.
    private func humanize(id: String) -> String {
        let parts = id
            .split(separator: "-")
            .map { String($0) }
        guard !parts.isEmpty else { return id }
        // Drop a 1-2 char leading token (e.g. "pp", "hs") treated as a
        // namespace prefix. Leave meaningful first tokens alone.
        let meaningful: [String] = {
            if let first = parts.first, first.count <= 2, !first.contains(where: \.isNumber) {
                return Array(parts.dropFirst())
            }
            return parts
        }()
        return meaningful
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    private func unlockRow(step: UnlockStep) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.unbound.accent.opacity(0.15))
                    .frame(width: 26, height: 26)
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Color.unbound.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                if let detail = step.detail {
                    Text(detail)
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func showMoreButton(total: Int, expanded: Bool) -> some View {
        Button {
            UnboundHaptics.medium()
            withAnimation(.easeOut(duration: 0.2)) {
                unlockExpanded.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Text(expanded ? "Show less" : "Show \(total - 2) more")
                    .font(Font.unbound.captionS.weight(.semibold))
                    .tracking(1.0)
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(Color.unbound.textSecondary)
            .padding(.top, 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pro tip

    private var proTipCallout: some View {
        let tip: String = {
            if let first = node.formCues.first, !first.isEmpty { return first }
            return "Consistency beats intensity. Train the progressions, not the skill."
        }()
        return VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Pro Tip")

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.unbound.impact)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color.unbound.impact.opacity(0.15)))
                Text(tip)
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
        }
    }

    // MARK: - Consolidated "coming soon"

    /// Replaces the old two separate RESEARCH-BACKED PATH + KEY STATISTICS
    /// stub cards. One card, two inline badges — less shouty, same intent.
    private var comingSoonCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("More coming soon")

            VStack(alignment: .leading, spacing: 12) {
                Text("Research-backed progressions and key statistics arrive in a future update.")
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    comingSoonBadge(icon: "text.book.closed", label: "Research path")
                    comingSoonBadge(icon: "chart.bar.xaxis", label: "Key stats")
                    Spacer(minLength: 0)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(placeholderBackground)
        }
    }

    private func comingSoonBadge(icon: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(label)
                .font(Font.unbound.captionS.weight(.semibold))
                .tracking(0.6)
        }
        .foregroundStyle(Color.unbound.textTertiary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(Color.unbound.surfaceElevated)
        )
        .overlay(
            Capsule().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    // MARK: - Styling helpers

    /// Phase 2i header style — Title Case, semibold headline, primary text
    /// color, no tracking.
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(.headline).weight(.semibold))
            .foregroundStyle(Color.unbound.textPrimary)
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
