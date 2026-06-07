import SwiftUI

extension SkillDetailView {
    var nextBeatCard: some View {
        let isTopRank = userSkillTierState.tier(for: node.id) == .ascendant
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("NEXT BEAT")
                    .font(Font.unbound.captionS.weight(.semibold))
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.accent)
                Spacer()
                if isTopRank {
                    topRankBadge
                }
            }

            if isTopRank {
                Text("You've proven this skill at the top rank.")
                    .font(.system(.title3).weight(.semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Keep training to make progress.")
                    .font(.system(.title3).weight(.semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(roundedCardBackground)
    }

    var topRankBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "crown.fill")
                .font(.system(size: 11, weight: .bold))
            Text("Top Rank")
                .font(.system(.caption).weight(.semibold))
        }
        .foregroundStyle(Color.unbound.impact)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.unbound.impact.opacity(0.15)))
        .overlay(Capsule().strokeBorder(Color.unbound.impact.opacity(0.5), lineWidth: 1))
    }

    // MARK: - 6. Form section

    func formSection(showHeader: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            if showHeader {
                HStack(alignment: .firstTextBaseline) {
                    sectionHeader("Form Breakdown")
                    Spacer()
                    Text("\(slideshowPhases.count) STEPS")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
            }

            if !slideshowPhases.isEmpty {
                FormPhaseSlideshow(
                    phases: slideshowPhases,
                    skillTitle: node.title
                )
            } else {
                // Fallback: numbered cue list when no per-phase silhouettes exist yet.
                fallbackStepsList
            }
        }
    }

    func formStandardSummary(_ guide: SkillGuide) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.unbound.accent)
                Text("Clean Rep Standard")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.accent)
                Spacer(minLength: 0)
            }

            Text(guide.standard)
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let note = guide.scoringNote {
                Text(note)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(roundedCardBackground)
    }

    /// Per-skill phase slideshow data. V1 hardcodes Pull-Up; future versions
    /// will move this into SkillNode authored content or a JSON resource.
    var slideshowPhases: [FormPhase] {
        FormPhaseLibrary.phases(for: node.id, fallbackTitle: node.title, formCues: node.formCues)
    }

    /// Numbered cue list — used when no silhouette phases exist for the skill.
    var fallbackStepsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            let steps = derivedFormSteps()
            ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                formStepRow(number: idx + 1, step: step, isLast: idx == steps.count - 1)
            }
        }
    }

    /// Single step row: violet circle badge with number, label + cue text,
    /// vertical connector line to the next step (omitted on last row).
    @ViewBuilder
    func formStepRow(number: Int, step: DerivedFormStep, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(Color.unbound.accent)
                        .frame(width: 28, height: 28)
                    Text("\(number)")
                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Color.unbound.bg)
                }
                if !isLast {
                    Rectangle()
                        .fill(Color.unbound.accent.opacity(0.35))
                        .frame(width: 1.5)
                        .frame(maxHeight: .infinity)
                        .padding(.vertical, 4)
                }
            }
            .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                if let title = step.title {
                    Text(title.uppercased())
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.accent)
                }
                Text(step.cue)
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, isLast ? 0 : 16)

            Spacer(minLength: 0)
        }
    }

    /// Local row model — V1 derives from `formCues`. Future versions will
    /// hydrate this from authored `formSteps: [FormStep]` on SkillNode or
    /// from a JSON resource extracted from the bitmap infographic.
    struct DerivedFormStep {
        let title: String?
        let cue: String
    }

    /// Splits "TITLE — body" / "TITLE: body" patterns so cue becomes a
    /// numbered step with both a label and a body. Falls back to no title
    /// if the cue is just one phrase.
    func derivedFormSteps() -> [DerivedFormStep] {
        node.formCues.prefix(4).map { raw -> DerivedFormStep in
            // Try to detect "TITLE — rest" or "TITLE: rest"
            let separators: [String] = [" — ", " - ", ": "]
            for sep in separators {
                if let range = raw.range(of: sep) {
                    let head = String(raw[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                    let body = String(raw[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                    // Only split if the head reads as a label (short, mostly capitalizable)
                    if head.count <= 32, !body.isEmpty {
                        return DerivedFormStep(title: head, cue: body)
                    }
                }
            }
            return DerivedFormStep(title: nil, cue: raw)
        }
    }
}
