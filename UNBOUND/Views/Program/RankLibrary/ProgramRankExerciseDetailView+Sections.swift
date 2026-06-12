import SwiftUI
import UIKit

extension ProgramRankExerciseDetailView {
    func hero(_ definition: MovementDefinition) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            heroArtwork(definition)
                .frame(maxWidth: .infinity)
                .aspectRatio(1.08, contentMode: .fit)

            VStack(alignment: .leading, spacing: 6) {
                Text(definition.displayName.uppercased())
                    .font(Font.unbound.titleM)
                    .tracking(0.6)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.74)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func heroArtwork(_ definition: MovementDefinition) -> some View {
        if let assetName = row.visualAssetName {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(heroArtworkBackground(for: assetName))

                Image(assetName)
                    .renderingMode(.original)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .scaleEffect(assetName.hasSuffix("_highlight") ? 1.18 : 1.0)
                    .padding(heroArtworkPadding(for: assetName))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .accessibilityLabel("\(definition.displayName) visual")
        } else {
            ExerciseVisualView(definition: definition, size: .hero)
        }
    }

    private func heroArtworkBackground(for assetName: String) -> AnyShapeStyle {
        if shouldUseWhiteArtworkStage(for: assetName) {
            return AnyShapeStyle(Color.white)
        }
        if assetName.hasSuffix("_highlight") {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.36, green: 0.25, blue: 0.15),
                        Color(red: 0.18, green: 0.13, blue: 0.10)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        return AnyShapeStyle(Color.unbound.surfaceElevated.opacity(0.28))
    }

    private func shouldUseWhiteArtworkStage(for assetName: String) -> Bool {
        assetName.hasPrefix("exercise_visual_")
            && row.source == .exercise
            && !row.id.hasPrefix("movement-detail-")
    }

    private func heroArtworkPadding(for assetName: String) -> CGFloat {
        if assetName.hasPrefix("exercise_visual_") { return 6 }
        return assetName.hasSuffix("_highlight") ? 0 : 14
    }

    var progressSummary: some View {
        HStack(alignment: .lastTextBaseline, spacing: 12) {
            Text(displayedTier.displayName.uppercased())
                .font(Font.unbound.titleS.weight(.black))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Spacer(minLength: 8)

            Text(bestSummary)
                .font(Font.unbound.bodyS.weight(.bold))
                .foregroundStyle(Color.unbound.coachCyan)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bestSummary: String {
        if let progress {
            return ProgramRankExerciseFormatter.bestSummary(progress)
        }
        return row.detail
    }

    func targetMapSection(_ definition: MovementDefinition) -> some View {
        let targetRegions = ProgramRankTargetRegionSet.regions(for: definition)

        return detailSection(
            title: "TARGET MAP",
            subtitle: targetRegions.isEmpty ? "No catalog body regions for this standard" : nil
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ProgramRankTargetBodyFigure(
                        side: .front,
                        targetRegions: targetRegions,
                        tint: tint
                    )
                    ProgramRankTargetBodyFigure(
                        side: .back,
                        targetRegions: targetRegions,
                        tint: tint
                    )
                }

                ProgramRankTargetRegionStrip(
                    regions: targetRegions,
                    tint: tint
                )
            }
        }
    }

    func singleLogCard(_ definition: MovementDefinition) -> some View {
        detailSection(title: "LOG A SET") {
            VStack(alignment: .leading, spacing: 14) {
                switch logMode {
                case .oneRepMax:
                    oneRepMaxRail(definition)
                    proofHistoryGraph
                case .reps:
                    repsRail(limit: 80)
                    proofHistoryGraph
                case .hold:
                    secondsRail(title: "Hold Time")
                    proofHistoryGraph
                }

                rankLogActionButton
            }
        }
    }

    private var rankLogActionButton: some View {
        let isEnabled = canSubmit && !isSubmitting

        return Button {
            guard isEnabled else { return }
            UnboundHaptics.medium()
            Task { await submitLog() }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSubmitting ? "hourglass" : "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                Text(isSubmitting ? "Saving Attempt" : "Reveal Rank")
                    .font(Font.unbound.bodyLStrong)
                    .tracking(0.2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(Color.unbound.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                ZStack {
                    Color.unbound.surfaceElevated
                    Rectangle().fill(.thinMaterial).opacity(0.18)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isEnabled ? tint.opacity(0.72) : Color.unbound.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.45), radius: 14, y: 8)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .opacity(isEnabled ? 1 : 0.58)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityIdentifier("program.rankExerciseDetail.logResult")
    }

    private var proofHistoryGraph: some View {
        ProgramRankProofHistoryLineGraph(
            entries: history,
            currentValue: currentProofGraphValue,
            historyValue: proofGraphValue(for:),
            valueFormatter: proofGraphValueText(_:),
            selectedRange: $selectedRepGraphRange,
            tint: tint,
            accessibilityUnit: logMode.accessibilityUnit
        )
    }

    private var currentProofGraphValue: Double {
        switch logMode {
        case .oneRepMax:
            return max(selectedWeightDisplay, 0)
        case .reps:
            return Double(max(selectedReps, 1))
        case .hold:
            return Double(max(selectedSeconds, 1))
        }
    }

    private func proofGraphValue(for entry: ProgramRankExerciseHistoryEntry) -> Double? {
        switch logMode {
        case .oneRepMax:
            guard let oneRepMaxKg = entry.oneRepMaxKg else { return nil }
            return weightUnit.displayValue(fromKilograms: oneRepMaxKg)
        case .reps:
            return entry.reps.map(Double.init)
        case .hold:
            return entry.holdSeconds.map(Double.init)
        }
    }

    private func proofGraphValueText(_ value: Double) -> String {
        switch logMode {
        case .oneRepMax:
            return "\(WeightPlatePolicy.formatDisplayValue(value))\(weightUnit.shortLabel)"
        case .reps:
            return "\(Int(value.rounded()))"
        case .hold:
            return ProgramRankExerciseFormatter.seconds(Int(value.rounded()))
        }
    }

    @ViewBuilder
    func guideLayer(_ definition: MovementDefinition) -> some View {
        if let skillForm = skillFormGuide(for: definition) {
            detailSection(title: "SKILL FORM") {
                FormPhaseSlideshow(
                    phases: skillForm.phases,
                    skillTitle: skillForm.title
                )
            }
        } else {
            SkillGuideLayerView(
                layer: .rankExercise(definition: definition),
                tint: tint,
                isProminent: true
            )
        }
    }

    private func skillFormGuide(for definition: MovementDefinition) -> (title: String, phases: [FormPhase])? {
        guard let skillId = definition.skillId else { return nil }
        let node = SkillGraph.shared.node(id: skillId)
        let phases = FormPhaseLibrary.phases(
            for: skillId,
            fallbackTitle: node?.title ?? definition.displayName,
            formCues: node?.formCues ?? []
        )
        guard !phases.isEmpty else { return nil }
        return (node?.title ?? definition.displayName, phases)
    }

    private var historyCard: some View {
        detailSection(title: "PAST HISTORY", subtitle: "Recent attempts for this rank standard") {
            if isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(Color.unbound.accent)
                    Text("Loading history")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if history.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text("No attempts yet. Reveal one result and it will appear here.")
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(history) { entry in
                        historyRow(entry)
                    }
                }
            }
        }
    }

    var missingState: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.diamond")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(Color.unbound.textTertiary)
            Text("Movement not found")
                .font(Font.unbound.titleS)
                .foregroundStyle(Color.unbound.textPrimary)
            Text("This rank standard no longer maps to a catalog exercise.")
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
    }

    private func historyRow(_ entry: ProgramRankExerciseHistoryEntry) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.summary)
                    .font(Font.unbound.bodyS.weight(.semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(entry.dateText)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }
}
