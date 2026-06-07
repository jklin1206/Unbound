import SwiftUI

extension WorkoutReadyView {
    var blockList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(blockListTitle)
                .font(Font.unbound.captionS.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textTertiary)

            if isDeckTrialDraft {
                deckExampleGrid
            } else if let rankTrialDefinition {
                rankTrialReadyPreview(for: rankTrialDefinition)
            } else {
                ForEach(Array(draft.blocks.enumerated()), id: \.element.id) { index, block in
                    blockRow(block, index: index)
                }
            }
        }
    }

    @ViewBuilder
    func rankTrialReadyPreview(for definition: OverallRankTrialDefinition) -> some View {
        let tint = definition.targetRank.rewardTextTint
        switch definition.format {
        case .daily100:
            Daily100TrialReadyPreview(blocks: draft.blocks, tint: tint)
        case .operatorScreen:
            OperatorScreenTrialReadyPreview(blocks: draft.blocks, tint: tint)
        case .finisher:
            FinisherTrialReadyPreview(blocks: draft.blocks, tint: tint)
        case .fixedDeck:
            deckExampleGrid
        case .tower:
            TowerTrialReadyPreview(blocks: draft.blocks, tint: tint)
        case .bossRush:
            BossRushTrialReadyPreview(blocks: draft.blocks, tint: tint)
        case .raid:
            ThresholdRaidTrialReadyPreview(blocks: draft.blocks, tint: tint)
        case .finalExam:
            FinalExamTrialReadyPreview(blocks: draft.blocks, tint: tint)
        }
    }

    var deckExampleGrid: some View {
        LazyVGrid(columns: deckColumns, alignment: .center, spacing: 10) {
            ForEach(Array(deckExampleCards.enumerated()), id: \.element.block.id) { exampleIndex, item in
                deckCard(
                    item.block,
                    index: item.index,
                    label: "EXAMPLE \(cardNumber(for: exampleIndex))"
                )
            }
        }
        .accessibilityIdentifier("workoutReady.deckExamples")
    }

    var deckExampleCards: [(index: Int, block: TrainingBlock)] {
        let cards = Array(draft.blocks.enumerated()).map { (index: $0.offset, block: $0.element) }
        let preferredSuits = ["H", "D", "C", "S"]
        let examples = preferredSuits.compactMap { suit in
            cards.first { item in
                let cardCode = originalDeckCardNumber(for: item.block) ?? cardNumber(for: item.index)
                return deckSuitCode(for: cardCode) == suit
            }
        }
        return examples.count == preferredSuits.count ? examples : Array(cards.prefix(4))
    }

    var deckColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]
    }

    @ViewBuilder
    var recentDraftsSection: some View {
        if !recentDrafts.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("RECENT CUSTOM")
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(recentDrafts) { recent in
                            Button {
                                draft = recent
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(recent.title)
                                        .font(Font.unbound.bodyS.weight(.bold))
                                        .foregroundStyle(Color.unbound.textPrimary)
                                        .lineLimit(1)
                                    Text("\(recent.blocks.count) blocks · \(recent.estimatedMinutes) min")
                                        .font(Font.unbound.captionS)
                                        .foregroundStyle(Color.unbound.textSecondary)
                                }
                                .frame(width: 170, alignment: .leading)
                                .padding(12)
                                .background(cardBackground)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    func blockRow(_ block: TrainingBlock, index: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            blockVisual(for: block, size: 54)

            VStack(alignment: .leading, spacing: 5) {
                Text(block.title)
                    .font(Font.unbound.bodyM.weight(.semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
                Text(block.subtitle ?? prescriptionSummary(block))
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if !isFixedProtocolDraft {
                VStack(spacing: 4) {
                    Button {
                        moveBlock(from: index, by: -1)
                    } label: {
                        Image(systemName: "chevron.up")
                            .frame(width: 28, height: 24)
                    }
                    .disabled(index == 0)
                    .accessibilityLabel("Move \(block.title) up")
                    .accessibilityIdentifier("workoutReady.block.\(index).moveUp")

                    Button {
                        moveBlock(from: index, by: 1)
                    } label: {
                        Image(systemName: "chevron.down")
                            .frame(width: 28, height: 24)
                    }
                    .disabled(index >= draft.blocks.count - 1)
                    .accessibilityLabel("Move \(block.title) down")
                    .accessibilityIdentifier("workoutReady.block.\(index).moveDown")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.unbound.textTertiary)

                Button {
                    editingBlock = BlockEditDraft(block: block)
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.unbound.textSecondary)
                .accessibilityLabel("Edit \(block.title)")
                .accessibilityIdentifier("workoutReady.block.\(index).edit")
            }

            if !isFixedProtocolDraft, block.kind == .skill, let skillId = block.skillId {
                Button {
                    activeSkillSession = SkillLaunch(skillId: skillId, title: block.title)
                } label: {
                    Image(systemName: "play.fill")
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.unbound.accent)
                .accessibilityLabel("Start \(block.title)")
                .accessibilityIdentifier("workoutReady.block.\(index).startSkill")
            }

            if !isFixedProtocolDraft {
                Button {
                    removeBlock(id: block.id)
                } label: {
                    Image(systemName: "minus.circle")
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.unbound.textTertiary)
                .accessibilityLabel("Remove \(block.title)")
                .accessibilityIdentifier("workoutReady.block.\(index).remove")
            }
        }
        .padding(14)
        .background(cardBackground)
        .accessibilityIdentifier("workoutReady.block.\(block.kind.rawValue).\(index)")
    }

    func deckCard(_ block: TrainingBlock, index: Int, label: String? = nil) -> some View {
        let originalNumber = originalDeckCardNumber(for: block) ?? cardNumber(for: index)
        let tint = deckSuitTint(forCardCode: originalNumber, fallbackIndex: index)
        let title = deckCardTitle(for: block, index: index)

        return VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label ?? "DRAW \(cardNumber(for: index))")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.4)
                    Text("CARD \(originalNumber)")
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .tracking(1.1)
                        .foregroundStyle(tint.opacity(0.88))
                }
                Spacer(minLength: 8)
                Image(systemName: deckSuitSymbol(forCardCode: originalNumber, fallbackIndex: index))
                    .font(.system(size: 14, weight: .black))
            }
            .foregroundStyle(tint)

            deckCardVisual(for: block)

            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased())
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1)
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(primaryExerciseName(for: block))
                    .font(Font.unbound.bodyS.weight(.bold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.74)

                Text(prescriptionSummary(block))
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textPrimary.opacity(0.78))
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 210, alignment: .topLeading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.unbound.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(tint.opacity(0.62), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("workoutReady.deckCard.\(index)")
    }

    @ViewBuilder
    func deckCardVisual(for block: TrainingBlock) -> some View {
        if let definition = movementDefinition(for: block) {
            ExerciseVisualView(definition: definition, size: .thumbnail)
                .frame(height: 92)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.unbound.surfaceElevated)
                Image(systemName: icon(for: block.kind))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(color(for: block.kind))
            }
            .frame(height: 92)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    func blockVisual(for block: TrainingBlock, size: CGFloat) -> some View {
        if let definition = movementDefinition(for: block) {
            ExerciseVisualView(definition: definition, size: .thumbnail)
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.unbound.surfaceElevated)
                Image(systemName: icon(for: block.kind))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(color(for: block.kind))
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    func prescriptionVisual(for prescription: TrainingBlockPrescription, tint: Color, size: CGFloat) -> some View {
        if let definition = movementDefinition(for: prescription) {
            ExerciseVisualView(definition: definition, size: .thumbnail)
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        } else {
            Image(systemName: "target")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(Circle().fill(tint.opacity(0.12)))
                .accessibilityHidden(true)
        }
    }

}
