import SwiftUI

// MARK: - TechniqueTabView (Phase 3a)
//
// Renders `node.formCues` + `node.commonMistakes` as bullet lists. If neither
// is authored, a single "coming soon" card acts as a placeholder so the tab
// never collapses empty.

struct TechniqueTabView: View {
    let node: SkillNode

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if node.formCues.isEmpty && node.commonMistakes.isEmpty {
                emptyState
            } else {
                if !node.formCues.isEmpty {
                    bulletBlock(
                        title: "FORM CUES",
                        bullets: node.formCues,
                        toneIcon: "sparkles",
                        toneColor: Color.unbound.accent
                    )
                }
                if !node.commonMistakes.isEmpty {
                    bulletBlock(
                        title: "COMMON MISTAKES",
                        bullets: node.commonMistakes,
                        toneIcon: "exclamationmark.triangle.fill",
                        toneColor: Color.unbound.impact
                    )
                }
            }
        }
    }

    // MARK: - Bullet block

    private func bulletBlock(
        title: String,
        bullets: [String],
        toneIcon: String,
        toneColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(bullets, id: \.self) { cue in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: toneIcon)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(toneColor)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(toneColor.opacity(0.15)))
                        Text(cue)
                            .font(Font.unbound.bodyM)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.unbound.textTertiary)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.unbound.surfaceElevated))
            VStack(alignment: .leading, spacing: 3) {
                Text("Technique guide coming soon")
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text("Form cues and common mistakes for this skill haven't been authored yet — check back later.")
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    // MARK: - Styling

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Font.unbound.captionS.weight(.semibold))
            .tracking(1.4)
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
}
