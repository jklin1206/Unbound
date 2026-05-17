import SwiftUI

/// The four detail sections (Target Muscles / Programming / Form Cues /
/// Substitution) shared by the standalone ExerciseDetailView and the inline
/// expansion inside ExerciseLogCard. Field-based so callers need not hold an
/// `Exercise`.
struct ExerciseDetailSections: View {
    let muscleGroups: [MuscleGroup]
    let sets: Int
    let reps: String
    let restSeconds: Int
    let formCues: String?
    let substitution: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            muscleGroupsSection
                .padding(.top, 8)
            programmingSection
                .padding(.top, 26)
            if let notes = formCues, !notes.isEmpty {
                formCuesSection(notes: notes)
                    .padding(.top, 26)
            }
            if let sub = substitution, !sub.isEmpty {
                substitutionSection(sub: sub)
                    .padding(.top, 26)
            }
        }
    }

    private var muscleGroupsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("TARGET MUSCLES")
                .font(Font.unbound.captionS)
                .tracking(1.5)
                .foregroundColor(Color.unbound.textTertiary)
            ExerciseDetailFlowLayout(spacing: 8) {
                ForEach(muscleGroups, id: \.self) { group in
                    Text(group.displayName)
                        .font(Font.unbound.captionS)
                        .foregroundColor(Color.unbound.accent)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.unbound.accent.opacity(0.14))
                        .clipShape(Capsule())
                }
            }
        }
    }

    private var programmingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("PROGRAMMING")
                .font(Font.unbound.captionS)
                .tracking(1.5)
                .foregroundColor(Color.unbound.textTertiary)
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.unbound.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.unbound.border, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 4)
                .overlay(
                    programmingColumns
                        .padding(.vertical, 20)
                        .padding(.horizontal, 8)
                )
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var programmingColumns: some View {
        HStack(spacing: 0) {
            programmingColumn(label: "SETS", value: "\(sets)", isMono: true)
            Rectangle().fill(Color.unbound.borderSubtle)
                .frame(width: 1).padding(.vertical, 6)
            programmingColumn(label: "REPS", value: reps, isMono: false)
            Rectangle().fill(Color.unbound.borderSubtle)
                .frame(width: 1).padding(.vertical, 6)
            programmingColumn(label: "REST", value: "\(restSeconds)s", isMono: true)
        }
    }

    private func programmingColumn(label: String, value: String, isMono: Bool) -> some View {
        VStack(spacing: 6) {
            if isMono {
                Text(value)
                    .font(Font.unbound.monoL)
                    .foregroundColor(Color.unbound.textPrimary)
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
            } else {
                Text(value)
                    .font(Font.unbound.bodyM)
                    .foregroundColor(Color.unbound.textPrimary)
                    .lineLimit(2).minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
            }
            Text(label)
                .font(Font.unbound.captionS)
                .tracking(1.5)
                .foregroundColor(Color.unbound.textTertiary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
    }

    private func formCuesSection(notes: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("FORM CUES")
                .font(Font.unbound.captionS)
                .tracking(1.5)
                .foregroundColor(Color.unbound.textTertiary)
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "checklist")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.unbound.accent)
                    .frame(width: 24)
                Text(notes)
                    .font(Font.unbound.bodyM)
                    .foregroundColor(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)
            }
            .padding(18)
            .background(Color.unbound.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.unbound.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.30), radius: 10, x: 0, y: 3)
        }
    }

    private func substitutionSection(sub: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SUBSTITUTION")
                .font(Font.unbound.captionS)
                .tracking(1.5)
                .foregroundColor(Color.unbound.textTertiary)
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.unbound.textSecondary)
                    .frame(width: 24)
                Text(sub)
                    .font(Font.unbound.bodyM)
                    .foregroundColor(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)
            }
            .padding(18)
            .background(Color.unbound.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.unbound.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.30), radius: 10, x: 0, y: 3)
        }
    }
}

// MARK: - ExerciseDetailFlowLayout (wrap layout for chips — no third-party dependency)

private struct ExerciseDetailFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var height: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                height += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
