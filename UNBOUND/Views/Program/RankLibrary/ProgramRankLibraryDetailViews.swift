import SwiftUI
import UIKit

struct ProgramRankLibraryDetailScreen: View {
    let row: ProgramRankLibraryRow
    let onLogged: () async -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch row.source {
                case .exercise:
                    ProgramRankExerciseDetailView(row: row, onLogged: onLogged)
                case .skill:
                    if let movementRow = movementDetailRow(for: row) {
                        ProgramRankExerciseDetailView(row: movementRow, onLogged: onLogged)
                    } else if let node = SkillGraph.shared.node(id: row.sourceId) {
                        SkillDetailView(
                            node: node,
                            graph: SkillGraph.shared,
                            nodeStates: SkillProgressService.shared.nodeStates
                        )
                    } else {
                        missingSkillState
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        UnboundHaptics.soft()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.unbound.textPrimary)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color.unbound.surface.opacity(0.92)))
                            .overlay(Circle().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close rank detail")
                }
            }
        }
    }

    private func movementDetailRow(for row: ProgramRankLibraryRow) -> ProgramRankLibraryRow? {
        guard let definition = MovementCatalog.definition(for: row.sourceId)
            ?? MovementCatalog.resolvedTrainingMovement(name: row.title)?.standard
        else { return nil }

        return ProgramRankLibraryRow(
            id: "movement-detail-\(definition.rankStandardMovementId)",
            title: definition.displayName,
            subtitle: definition.movementSlot.displayName,
            detail: row.detail,
            metric: row.metric,
            tier: row.tier,
            visualAssetName: row.visualAssetName,
            totalAP: row.totalAP,
            source: .exercise,
            sourceId: definition.rankStandardMovementId,
            sectionTitle: definition.movementSlot.displayName,
            sectionOrder: row.sectionOrder,
            lastActivityAt: row.lastActivityAt,
            earnedOverride: row.earnedOverride,
            isRankHidden: row.isRankHidden
        )
    }

    private var missingSkillState: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "questionmark.diamond")
                    .font(.system(size: 34, weight: .regular))
                    .foregroundStyle(Color.unbound.textTertiary)
                Text("Skill not found")
                    .font(Font.unbound.titleS)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text("This rank no longer maps to a skill node.")
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(28)
        }
    }
}

struct ProgramRankLibraryExpandedRow: View {
    let row: ProgramRankLibraryRow
    let onLogged: () async -> Void

    private var tint: Color { row.tier.rewardTextTint }

    private var rankText: String {
        row.isRankHidden ? "—" : row.tier.displayName.uppercased()
    }

    private var statusText: String {
        if row.isEarned && row.tier.next == nil { return "MAXED" }
        return row.isEarned ? "EARNED" : "UNPROVEN"
    }

    private var targetLabel: String {
        if row.isEarned && row.tier.next == nil { return "PEAK STANDARD" }
        return row.isEarned ? "NEXT STANDARD" : "FIRST STANDARD"
    }

    private var lastActivityText: String {
        guard let lastActivityAt = row.lastActivityAt else { return "NONE" }
        return lastActivityAt.formatted(.dateTime.month(.abbreviated).day())
    }

    private var movementDefinition: MovementDefinition? {
        guard row.source == .exercise else { return nil }
        return MovementCatalog.definition(for: row.sourceId)
            ?? MovementCatalog.resolvedTrainingMovement(name: row.title)?.standard
    }

    private var associatedSkillNode: SkillNode? {
        if row.source == .skill {
            return SkillGraph.shared.node(id: row.sourceId)
        }
        guard let skillId = movementDefinition?.skillId else { return nil }
        return SkillGraph.shared.node(id: skillId)
    }

    private var ladderRows: [ProgramRankExpandedLadderRow] {
        if let associatedSkillNode {
            return annotatedRows(skillRows(for: associatedSkillNode))
        }
        if let movementDefinition {
            return annotatedRows(strengthRows(for: movementDefinition))
        }
        return []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                summaryTile(label: "STATUS", value: statusText, tint: row.isEarned ? Color.unbound.success : Color.unbound.textTertiary)
                summaryTile(label: "RANK", value: rankText, tint: tint)
                summaryTile(label: "LAST", value: lastActivityText, tint: Color.unbound.coachCyan)
            }

            targetPanel

            if !ladderRows.isEmpty {
                ladderPanel
            }

            if row.source == .exercise {
                NavigationLink {
                    ProgramRankExerciseDetailView(row: row) {
                        await onLogged()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(tint)
                        Text("LOG / VIEW HISTORY")
                            .font(Font.unbound.captionS.weight(.heavy))
                            .tracking(1.2)
                            .foregroundStyle(Color.unbound.textPrimary)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(Color.unbound.textTertiary)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(tint.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(tint.opacity(0.22), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(tint.opacity(row.isEarned ? 0.20 : 0.11), lineWidth: 1)
        )
        .padding(.leading, 12)
        .accessibilityElement(children: .contain)
    }

    private var targetPanel: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: row.source == .skill ? "scope" : "chart.line.uptrend.xyaxis")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(Circle().fill(tint.opacity(0.14)))

            VStack(alignment: .leading, spacing: 5) {
                Text(targetLabel)
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text(row.detail)
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.bg.opacity(0.44))
        )
    }

    private var ladderPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RANK PATH")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.3)
                .foregroundStyle(Color.unbound.textTertiary)

            VStack(spacing: 0) {
                ForEach(ladderRows) { ladderRow in
                    ladderLine(ladderRow)
                }
            }
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.unbound.bg.opacity(0.34))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
            )
        }
    }

    private func ladderLine(_ ladderRow: ProgramRankExpandedLadderRow) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(ladderRow.tier.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .opacity(ladderRow.status == .locked ? 0.42 : 1.0)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(ladderRow.tier.displayName.uppercased())
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(0.9)
                        .foregroundStyle(ladderRow.status.tint(base: tint))
                    Text(ladderRow.status.displayName)
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(ladderRow.status.tint(base: tint))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(ladderRow.status.tint(base: tint).opacity(0.13)))
                }

                Text(ladderRow.detail)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(ladderRow.status == .locked ? Color.unbound.textTertiary : Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func summaryTile(label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(Color.unbound.textTertiary)
            Text(value)
                .font(Font.unbound.monoS.weight(.black))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.56)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.unbound.bg.opacity(0.42))
        )
    }

    private func skillRows(for node: SkillNode) -> [(tier: SkillTier, detail: String)] {
        SkillTier.allCases
            .filter { $0.rawValue >= node.rankFloor.rawValue }
            .map { tier in
                (
                    tier: tier,
                    detail: node.tierCriteria[tier].map(Self.criterionSummary)
                        ?? node.target.displayName
                )
            }
    }

    private func strengthRows(for definition: MovementDefinition) -> [(tier: SkillTier, detail: String)] {
        let key = MovementCatalog.normalized(definition.canonicalExerciseName ?? definition.displayName)
        return SkillTier.allCases.compactMap { tier in
            guard let ratio = StrengthStandards.ratio(exerciseKey: key, tier: tier, sex: nil) else { return nil }
            let ratioText = String(format: "%.2g", ratio)
            let prefix = definition.rankTemplate == .weightedBodyweight ? "added load " : ""
            return (tier: tier, detail: "\(prefix)\(ratioText)x bodyweight")
        }
    }

    private func annotatedRows(_ rows: [(tier: SkillTier, detail: String)]) -> [ProgramRankExpandedLadderRow] {
        guard !rows.isEmpty else { return [] }

        let visibleTiers = rows.map(\.tier)
        let nextTier = row.isEarned ? row.tier.next : row.tier
        let currentTier = nextTier.flatMap { target in
            visibleTiers.first { $0.rawValue >= target.rawValue }
        }

        return rows.map { candidate in
            let isCleared = row.isEarned
                && !row.isRankHidden
                && candidate.tier.rawValue <= row.tier.rawValue
            let status: ProgramRankExpandedLadderStatus
            if isCleared {
                status = .cleared
            } else if candidate.tier == currentTier {
                status = .current
            } else {
                status = .locked
            }

            return ProgramRankExpandedLadderRow(
                tier: candidate.tier,
                detail: candidate.detail,
                status: status
            )
        }
    }

    private static func criterionSummary(_ criterion: TierCriterion) -> String {
        switch criterion {
        case .reps(let count, let exerciseName):
            return "\(count) \(displayExerciseName(exerciseName))"
        case .seconds(let seconds):
            return "\(seconds)-second hold"
        case .exerciseSeconds(let seconds, let exerciseName):
            return "\(seconds)s \(displayExerciseName(exerciseName)) hold"
        case .weightKg(let weight):
            return "\(Int(weight.rounded())) kg working set"
        case .exerciseWeightKg(let weight, let exerciseName):
            return "\(Int(weight.rounded())) kg \(displayExerciseName(exerciseName))"
        case .bodyweightRatio(let ratio):
            return "\(String(format: "%.2g", ratio))x bodyweight"
        case .exerciseBodyweightRatio(let ratio, let exerciseName):
            return "\(String(format: "%.2g", ratio))x bodyweight \(displayExerciseName(exerciseName))"
        case .variant(let name):
            return "Log \(displayExerciseName(name))"
        case .compound(let criteria):
            return criteria.map(criterionSummary).joined(separator: " + ")
        }
    }

    private static func displayExerciseName(_ name: String) -> String {
        name
            .split(separator: " ")
            .map { part in
                part
                    .split(separator: "-")
                    .map { $0.prefix(1).uppercased() + $0.dropFirst() }
                    .joined(separator: "-")
            }
            .joined(separator: " ")
    }
}

struct ProgramRankExpandedLadderRow: Identifiable {
    let tier: SkillTier
    let detail: String
    let status: ProgramRankExpandedLadderStatus

    var id: SkillTier { tier }
}

enum ProgramRankExpandedLadderStatus {
    case cleared
    case current
    case locked

    var displayName: String {
        switch self {
        case .cleared: return "CLEARED"
        case .current: return "NEXT"
        case .locked: return "LOCKED"
        }
    }

    func tint(base: Color) -> Color {
        switch self {
        case .cleared: return Color.unbound.success
        case .current: return base
        case .locked: return Color.unbound.textTertiary
        }
    }
}

// MARK: - Rank exercise detail
