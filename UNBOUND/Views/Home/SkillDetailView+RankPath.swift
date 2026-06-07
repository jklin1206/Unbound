import SwiftUI

extension SkillDetailView {
    var rankPathSection: some View {
        let rows = rankPathRows()
        // Skipped (below-floor) rungs aren't part of a feat's journey — focus and
        // counts run over the achievable rows only.
        let achievableRows = rows.filter { !$0.isSkipped }
        let active = rows.first(where: { $0.isCurrent }) ?? achievableRows.first ?? rows.first
        let clearedCount = rows.filter(\.isCleared).count
        let achievableCount = achievableRows.count

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    sectionHeader("Rank Path")
                    Text("Objective gates for \(node.title)")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(clearedCount)/\(achievableCount)")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .monospacedDigit()
                    Text(readinessHistoryLoaded ? "CLEARED" : "LOADING")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.2)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
            }

            if let active {
                Button {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                        isRankPathExpanded.toggle()
                    }
                    UnboundHaptics.soft()
                } label: {
                    rankFocusCard(active, rows: achievableRows, clearedCount: clearedCount)
                }
                .buttonStyle(.plain)
            }

            if isRankPathExpanded {
                VStack(spacing: 0) {
                    let visibleRows = visibleRankRows(rows)
                    ForEach(Array(visibleRows.enumerated()), id: \.element.id) { index, row in
                        rankPathRow(row, isLast: index == visibleRows.count - 1)
                    }
                }
                .padding(.vertical, 6)
                .background(roundedCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .top)),
                        removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
                    )
                )
            }
        }
    }

    struct RankPathDisplayRow: Identifiable {
        var id: SkillTier { tier }
        let tier: SkillTier
        let detail: String
        let isCleared: Bool
        let isCurrent: Bool
        let isFuture: Bool
        /// Feat node: this tier sits BELOW the floor, so it isn't part of this
        /// skill's journey (the move's first rep jumps straight to the floor).
        /// Rendered de-emphasized — present but not achievable here.
        let isSkipped: Bool
        let unlocks: [SkillUnlockStandards.OutgoingUnlock]
    }

    var outgoingUnlocks: [SkillUnlockStandards.OutgoingUnlock] {
        SkillUnlockStandards.outgoingUnlocks(from: node.id, in: graph)
    }

    func rankPathRows() -> [RankPathDisplayRow] {
        let tiers = SkillTier.allCases
        let floor = node.rankFloor
        // For a feat node, tiers below the floor are skipped (they share the
        // floor's entry criterion). They aren't real gates — exclude them from
        // the "current gate" search so the focus lands on the first honest rung.
        let firstUncleared = tiers.first { tier in
            if tier.rawValue < floor.rawValue { return false }
            guard let criterion = criterion(for: tier) else { return true }
            return !TierCriterionEvaluator.satisfied(
                criterion: criterion,
                history: recentExerciseHistory,
                bodyweightKg: bodyweightKg
            )
        }

        return tiers.map { tier in
            let skipped = tier.rawValue < floor.rawValue
            let criterion = criterion(for: tier)
            let cleared = !skipped && (criterion.map {
                TierCriterionEvaluator.satisfied(
                    criterion: $0,
                    history: recentExerciseHistory,
                    bodyweightKg: bodyweightKg
                )
            } ?? false)
            let current = !skipped && firstUncleared == tier
            return RankPathDisplayRow(
                tier: tier,
                detail: criterion.map(criterionSummary) ?? fallbackRankCriterion(for: tier),
                isCleared: cleared,
                isCurrent: current,
                isFuture: !skipped && !cleared && !current,
                isSkipped: skipped,
                unlocks: outgoingUnlocks.filter { $0.requirement.requiredTier == tier }
            )
        }
    }

    func visibleRankRows(_ rows: [RankPathDisplayRow]) -> [RankPathDisplayRow] {
        // Skipped (below-floor) rungs are dropped from a feat's path — the list
        // simply starts at the floor, which reads as a high-floor skill on its own.
        rows.filter { !$0.isCurrent && !$0.isSkipped }
    }

    func rankFocusCard(_ row: RankPathDisplayRow, rows: [RankPathDisplayRow], clearedCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                rankBadge(tier: row.tier, isCleared: row.isCleared, isCurrent: true)
                    .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 4) {
                    Text(row.isCleared ? "Latest cleared" : "Current gate")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.2)
                        .foregroundStyle(Color.unbound.accent)
                    Text(row.tier.displayName)
                        .font(.system(.title3).weight(.bold))
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text(row.detail)
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 8) {
                    Image(systemName: isRankPathExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.unbound.accent)
                    Text("\(clearedCount)/\(rows.count)")
                        .font(Font.unbound.monoS.weight(.heavy))
                        .foregroundStyle(Color.unbound.textSecondary)
                }
            }

            rankPreviewRail(rows)

            if let plan = SkillTrainingPlanLibrary.plan(for: node.id), !row.isCleared {
                trainingChips(plan: plan, targetText: row.detail)
            }

            if !row.unlocks.isEmpty {
                unlockChips(row.unlocks, prefix: "Unlocks at \(row.tier.displayName)")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.unbound.surface)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.unbound.accent.opacity(0.18),
                                Color.unbound.accent.opacity(0.04),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.unbound.accent.opacity(0.45), lineWidth: 1)
            }
        )
    }

    func rankPreviewRail(_ rows: [RankPathDisplayRow]) -> some View {
        let currentIndex = rows.firstIndex(where: { $0.isCurrent }) ?? 0
        let lower = max(0, currentIndex - 2)
        let upper = min(rows.count - 1, currentIndex + 2)
        let previewRows = Array(rows[lower...upper])

        return HStack(spacing: 0) {
            ForEach(Array(previewRows.enumerated()), id: \.element.id) { index, row in
                VStack(spacing: 5) {
                    rankMiniDot(row)
                    Text(row.tier.displayName.uppercased())
                        .font(.system(size: 8, weight: row.isCurrent ? .heavy : .semibold, design: .monospaced))
                        .tracking(0.7)
                        .foregroundStyle(row.isCurrent ? Color.unbound.accent : Color.unbound.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
                .frame(maxWidth: .infinity)

                if index != previewRows.count - 1 {
                    Rectangle()
                        .fill(row.isCleared ? Color.unbound.accent.opacity(0.55) : Color.unbound.border.opacity(0.6))
                        .frame(height: 1)
                        .frame(maxWidth: 24)
                        .offset(y: -10)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.bg.opacity(0.38))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    @ViewBuilder
    func rankMiniDot(_ row: RankPathDisplayRow) -> some View {
        ZStack {
            Circle()
                .fill(row.isCurrent ? Color.unbound.accent.opacity(0.22) : Color.unbound.surfaceElevated)
                .frame(width: row.isCurrent ? 24 : 18, height: row.isCurrent ? 24 : 18)
            if row.isCleared {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(Color.unbound.accent)
            } else if row.isCurrent {
                Circle()
                    .fill(Color.unbound.accent)
                    .frame(width: 8, height: 8)
            } else {
                Circle()
                    .fill(Color.unbound.textTertiary.opacity(0.45))
                    .frame(width: 6, height: 6)
            }
        }
        .overlay(
            Circle()
                .strokeBorder(row.isCurrent ? Color.unbound.accent : Color.unbound.border, lineWidth: row.isCurrent ? 1.4 : 1)
        )
    }

    func rankPathRow(_ row: RankPathDisplayRow, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                rankBadge(tier: row.tier, isCleared: row.isCleared, isCurrent: row.isCurrent)
                    .frame(width: 34, height: 34)
                if !isLast {
                    Rectangle()
                        .fill(row.isCleared ? Color.unbound.accent.opacity(0.45) : Color.unbound.border.opacity(0.6))
                        .frame(width: 1, height: row.isCurrent ? 44 : 28)
                        .padding(.vertical, 5)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(row.tier.displayName)
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(row.isCurrent ? Color.unbound.accent : (row.isFuture || row.isSkipped ? Color.unbound.textSecondary : Color.unbound.textPrimary))
                    statusPill(for: row)
                }

                Text(row.isSkipped ? "Skipped — this skill starts at \(node.rankFloor.displayName)" : row.detail)
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(row.isFuture || row.isSkipped ? Color.unbound.textTertiary : Color.unbound.textSecondary)
                    .lineLimit(row.isCurrent ? 3 : 2)
                    .fixedSize(horizontal: false, vertical: true)

                if row.isCurrent, let plan = SkillTrainingPlanLibrary.plan(for: node.id) {
                    trainingChips(plan: plan, targetText: row.detail)
                        .padding(.top, 2)
                }

                if !row.unlocks.isEmpty {
                    unlockChips(row.unlocks, prefix: "Unlocks here")
                        .padding(.top, 2)
                }
            }
            .padding(.bottom, isLast ? 0 : 10)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .opacity(row.isSkipped ? 0.4 : (row.isFuture ? 0.74 : 1))
    }

    func statusPill(for row: RankPathDisplayRow) -> some View {
        let label = row.isSkipped ? "SKIPPED" : (row.isCleared ? "CLEARED" : (row.isCurrent ? "NEXT" : "LOCKED"))
        let color = (!row.isSkipped && (row.isCleared || row.isCurrent)) ? Color.unbound.accent : Color.unbound.textTertiary
        return Text(label)
            .font(Font.unbound.captionS.weight(.heavy))
            .tracking(1.0)
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.14)))
    }

    var shouldShowUnlocksNext: Bool {
        !outgoingUnlocks.isEmpty
    }

    var unlocksNextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Unlocks Next")

            VStack(spacing: 10) {
                ForEach(outgoingUnlocks.prefix(5)) { unlock in
                    unlockNextRow(unlock)
                }
            }

            if outgoingUnlocks.count > 5 {
                Text("+\(outgoingUnlocks.count - 5) more branches from this skill")
                    .font(Font.unbound.captionS.weight(.semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
                    .padding(.top, 2)
            }
        }
        .padding(14)
        .background(roundedCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    func unlockNextRow(_ unlock: SkillUnlockStandards.OutgoingUnlock) -> some View {
        let required = unlock.requirement.requiredTier
        let current = userSkillTierState.tier(for: node.id)
        let met = current >= required

        return HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(met ? Color.unbound.accent.opacity(0.18) : Color.unbound.surfaceElevated)
                    .frame(width: 34, height: 34)
                Image(systemName: met ? "arrow.up.circle.fill" : "lock.fill")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(met ? Color.unbound.accent : Color.unbound.textTertiary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(unlock.child.title)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text("Unlocks when \(node.title) reaches \(required.displayName)")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Text(met ? "READY" : required.displayName.uppercased())
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.0)
                .foregroundStyle(met ? Color.unbound.accent : Color.unbound.textTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill((met ? Color.unbound.accent : Color.unbound.textTertiary).opacity(0.14)))
        }
    }

    func unlockChips(_ unlocks: [SkillUnlockStandards.OutgoingUnlock], prefix: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(prefix)
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.2)
                .foregroundStyle(Color.unbound.textTertiary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(unlocks.prefix(4)) { unlock in
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 9, weight: .black))
                            Text(unlock.child.title)
                                .font(Font.unbound.captionS.weight(.bold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(Color.unbound.accent)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color.unbound.accent.opacity(0.12)))
                        .overlay(Capsule().strokeBorder(Color.unbound.accent.opacity(0.28), lineWidth: 1))
                    }
                }
            }
        }
    }

    @ViewBuilder
    func rankBadge(tier: SkillTier, isCleared: Bool, isCurrent: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isCurrent ? Color.unbound.accent.opacity(0.18) : Color.unbound.surfaceElevated)
            if let img = UIImage(named: tier.assetName) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .padding(3)
            } else {
                Text(String(tier.displayName.prefix(1)))
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(isCurrent ? Color.unbound.accent : Color.unbound.textSecondary)
            }

            if isCleared {
                Circle()
                    .fill(Color.unbound.accent)
                    .frame(width: 14, height: 14)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundStyle(Color.unbound.bg)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .overlay(
            Circle()
                .strokeBorder(isCurrent ? Color.unbound.accent : Color.unbound.border, lineWidth: isCurrent ? 1.5 : 1)
        )
        .saturation(isCleared || isCurrent ? 1.0 : 0.4)
    }

    func trainingChips(plan: SkillTrainingPlan, targetText: String) -> some View {
        let options = recommendedTrainingOptions(plan: plan, targetText: targetText)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Train this next")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.2)
                .foregroundStyle(Color.unbound.textTertiary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(options, id: \.name) { option in
                        HStack(spacing: 6) {
                            Image(systemName: "dumbbell.fill")
                                .font(.system(size: 9, weight: .bold))
                            Text(option.name)
                                .font(Font.unbound.captionS.weight(.semibold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(Color.unbound.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color.unbound.surfaceElevated))
                        .overlay(Capsule().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
                    }
                }
            }
        }
    }

    func recommendedTrainingOptions(plan: SkillTrainingPlan, targetText: String) -> [TrainingExercise] {
        let normalizedTarget = targetText.lowercased()
        let candidates = plan.regressions + plan.accessories
        let matching = candidates.filter { exercise in
            let name = exercise.name.lowercased()
            let simplifiedName = name
                .replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: "pull-up", with: "pullup")
            return normalizedTarget.contains(name)
                || normalizedTarget.contains(simplifiedName)
        }
        if !matching.isEmpty { return Array(matching.prefix(3)) }
        return Array(candidates.prefix(3))
    }

    func criterion(for tier: SkillTier) -> TierCriterion? {
        node.tierCriteria[tier]
    }

    func fallbackRankCriterion(for tier: SkillTier) -> String {
        switch tier {
        case .initiate:
            return "Unlock and begin training this skill"
        case .novice:
            return "First clean exposure"
        case .apprentice:
            return "Build repeatable control"
        case .forged:
            return "Own the core standard"
        case .veteran:
            return "Add volume or difficulty"
        case .master:
            return "High-quality repeatability"
        case .vessel, .unbound, .ascendant:
            return "Advanced standard coming soon"
        }
    }

}
