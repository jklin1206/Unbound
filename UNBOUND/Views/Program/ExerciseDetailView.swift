import SwiftUI

struct ExerciseDetailView: View {
    let exercise: Exercise

    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Target Muscles
                    muscleGroupsSection
                        .padding(.top, 8)

                    // Programming
                    programmingSection
                        .padding(.top, 26)

                    // Form Cues
                    if let notes = exercise.notes, !notes.isEmpty {
                        formCuesSection(notes: notes)
                            .padding(.top, 26)
                    }

                    // Substitution
                    if let sub = exercise.substitution, !sub.isEmpty {
                        substitutionSection(sub: sub)
                            .padding(.top, 26)
                    }
                }
                .padding(16)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Target Muscles

    private var muscleGroupsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("TARGET MUSCLES")
                .font(Font.unbound.captionS)
                .tracking(1.5)
                .foregroundColor(Color.unbound.textTertiary)

            // Wrapping chip layout
            FlowLayout(spacing: 8) {
                ForEach(exercise.muscleGroups, id: \.self) { group in
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

    // MARK: - Programming

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
            programmingColumn(
                label: "SETS",
                value: "\(exercise.sets)",
                isMono: true
            )

            Rectangle()
                .fill(Color.unbound.borderSubtle)
                .frame(width: 1)
                .padding(.vertical, 6)

            programmingColumn(
                label: "REPS",
                value: exercise.reps,
                isMono: false
            )

            Rectangle()
                .fill(Color.unbound.borderSubtle)
                .frame(width: 1)
                .padding(.vertical, 6)

            programmingColumn(
                label: "REST",
                value: "\(exercise.restSeconds)s",
                isMono: true
            )
        }
    }

    private func programmingColumn(label: String, value: String, isMono: Bool) -> some View {
        VStack(spacing: 6) {
            if isMono {
                Text(value)
                    .font(Font.unbound.monoL)
                    .foregroundColor(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
            } else {
                Text(value)
                    .font(Font.unbound.bodyM)
                    .foregroundColor(Color.unbound.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
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

    // MARK: - Form Cues

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

    // MARK: - Substitution

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

// MARK: - FlowLayout
// Simple wrap layout for chips — no third-party dependency.

private struct FlowLayout: Layout {
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

#Preview {
    NavigationStack {
        ExerciseDetailView(exercise: Exercise(
            id: "1",
            name: "Barbell Back Squat",
            muscleGroups: [.legs, .glutes, .core],
            sets: 4,
            reps: "6-8",
            restSeconds: 120,
            rpe: 8,
            notes: "Keep chest up, brace core, drive through heels. Maintain neutral spine throughout the movement.",
            substitution: "Goblet Squat or Leg Press"
        ))
    }
}
