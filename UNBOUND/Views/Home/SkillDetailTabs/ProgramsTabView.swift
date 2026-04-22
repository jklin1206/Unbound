import SwiftUI

// MARK: - ProgramsTabView (Phase 3a)
//
// Placeholder for Phase 5's block-generator integration. Single disabled
// OPT IN button + "coming soon" caption. No functional wiring yet.

struct ProgramsTabView: View {
    let node: SkillNode

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("PROGRAMS")

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.unbound.accent)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.unbound.accent.opacity(0.15)))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Opt into \(node.title)")
                            .font(Font.unbound.bodyLStrong)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Opt into this skill and your current 2-week block will include targeted accessory work.")
                            .font(Font.unbound.bodyS)
                            .foregroundStyle(Color.unbound.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }

                UnboundButton(
                    title: "OPT IN",
                    variant: .secondary,
                    icon: "lock.fill",
                    isEnabled: false
                ) {
                    // No-op — wired in Phase 5
                }

                HStack(spacing: 6) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Coming soon — Phase 5 integrates with the program block generator.")
                        .font(Font.unbound.captionS)
                }
                .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
        }
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
