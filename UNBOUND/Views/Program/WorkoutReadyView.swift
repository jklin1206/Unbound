import SwiftUI

struct WorkoutReadyView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var services: ServiceContainer

    @State private var draft: TrainingSessionDraft
    @State private var activeWorkoutDraft: TrainingSessionDraft?
    @State private var activeSkillSession: SkillLaunch?
    @State private var showingBlockBuilder = false
    @State private var editingBlock: BlockEditDraft?
    @State private var recentDrafts: [TrainingSessionDraft] = []
    @State private var isLaunchingWorkout = false

    init(draft: TrainingSessionDraft) {
        _draft = State(initialValue: draft)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.unbound.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        if draft.isWeeklyVowDraft {
                            weeklyProofWorkSummary
                        } else if isRankTrialDraft {
                            rankTrialProtocolSummary
                        } else {
                            recentDraftsSection
                        }
                        blockList
                        if !isFixedProtocolDraft {
                            addControls
                        }
                        startControls
                    }
                    .padding(20)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle(draft.isWeeklyVowDraft ? "Binding Vow" : isRankTrialDraft ? "Rank Trial" : "Workout Ready")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.unbound.textSecondary)
                }
            }
            .onAppear {
                recentDrafts = TrainingSessionDraftStore().loadRecent()
            }
            .sheet(isPresented: $showingBlockBuilder) {
                BlockBuilderSheet { block in
                    draft.blocks.append(block)
                    refreshDraftEstimate()
                    showingBlockBuilder = false
                }
            }
            .sheet(item: $editingBlock) { edit in
                BlockEditSheet(edit: edit) { updated in
                    applyBlockEdit(updated)
                }
            }
            .sheet(item: $activeSkillSession) { launch in
                SkillSessionView(skillId: launch.skillId, skillTitle: launch.title)
                    .environmentObject(services)
            }
            .fullScreenCover(item: $activeWorkoutDraft, onDismiss: {
                isLaunchingWorkout = false
            }) { draft in
                ActiveWorkoutContainerView(
                    draft: draft,
                    services: services,
                    onFinished: {
                        UserDefaults.standard.set(0, forKey: "unbound.shortSessionDate")
                        activeWorkoutDraft = nil
                        dismiss()
                    }
                )
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        if draft.isWeeklyVowDraft {
            weeklyProofHeader
        } else if isRankTrialDraft {
            rankTrialHeader
        } else {
            workoutHeader
        }
    }

    private var workoutHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(draft.source.rawValue.uppercased())
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.6)
                .foregroundStyle(Color.unbound.accent)
            Text(draft.title)
                .font(.system(.title2).weight(.bold))
                .foregroundStyle(Color.unbound.textPrimary)
            HStack(spacing: 10) {
                readyChip("\(draft.blocks.count) blocks", icon: "square.stack.3d.up")
                readyChip("\(draft.estimatedMinutes) min", icon: "clock")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(cardBackground)
    }

    private var weeklyProofHeader: some View {
        let kind = weeklyVowKind
        let tint = weeklyProofTint
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                WeeklyVowProofAsset(kind: kind, tint: tint)
                    .frame(width: 72, height: 72)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 7) {
                    Text("BINDING VOW")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.8)
                        .foregroundStyle(tint)
                    Text(weeklyProofTitle)
                        .font(.system(.title2).weight(.black))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                    HStack(spacing: 8) {
                        readyChip(kind.displayName, icon: "checkmark.seal.fill")
                        readyChip("\(draft.estimatedMinutes) min", icon: "clock")
                    }
                }
                .layoutPriority(1)
            }

            WeeklyVowCoachValidationStrip(tint: tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(cardBackground)
    }

    private var weeklyProofWorkSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("YOU'LL DO")
                .font(Font.unbound.captionS.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textTertiary)

            ForEach(Array(weeklyProofPrescriptions.prefix(4))) { prescription in
                HStack(spacing: 10) {
                    prescriptionVisual(for: prescription, tint: weeklyProofTint, size: 42)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(prescription.exerciseName)
                            .font(Font.unbound.bodyS.weight(.semibold))
                            .foregroundStyle(Color.unbound.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.74)
                        Text("\(prescription.sets)x \(prescription.displayTargetText) · \(prescription.restSeconds)s rest\(rpeLabel(for: prescription))")
                            .font(Font.unbound.captionS)
                            .foregroundStyle(Color.unbound.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(cardBackground)
            }
        }
    }

    private var rankTrialHeader: some View {
        let definition = rankTrialDefinition
        let tint = definition?.targetRank.rewardTextTint ?? Color.unbound.rankGold

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tint.opacity(0.14))
                    Image(systemName: rankTrialHeaderIconName)
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(tint)
                }
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 7) {
                    Text("OVERALL RANK TRIAL")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.8)
                        .foregroundStyle(tint)
                    Text(draft.title)
                        .font(.system(.title2).weight(.black))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                    HStack(spacing: 8) {
                        readyChip(definition?.format.displayName ?? "Official", icon: "flag.checkered")
                        readyChip("\(draft.blocks.count) stations", icon: "square.stack.3d.up")
                        readyChip("\(draft.estimatedMinutes) min", icon: "clock")
                    }
                }
                .layoutPriority(1)
            }

            Text(rankTrialHeaderSubtitle)
                .font(Font.unbound.captionS.weight(.semibold))
                .foregroundStyle(Color.unbound.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(cardBackground)
    }

    private var rankTrialProtocolSummary: some View {
        let tint = rankTrialDefinition?.targetRank.rewardTextTint ?? Color.unbound.rankGold
        let categories = Array(
            draft.blocks
                .compactMap(\.subtitle)
                .reduce(into: [String]()) { result, subtitle in
                    guard !result.contains(subtitle) else { return }
                    result.append(subtitle)
                }
                .prefix(6)
        )

        return VStack(alignment: .leading, spacing: 10) {
            Text("OFFICIAL VERSION")
                .font(Font.unbound.captionS.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textTertiary)

            HStack(spacing: 8) {
                if let loadout = rankTrialLoadoutLabel {
                    readyChip(loadout, icon: "scope")
                }
                readyChip("Every station", icon: "checkmark.seal.fill")
                readyChip("Clean reps", icon: "sparkles")
            }

            if !categories.isEmpty {
                Text(rankTrialMovementSummary(categories))
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(tint)
                Text("Stations are locked for rank validation.")
                    .font(Font.unbound.captionS.weight(.semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
            }
            .padding(10)
            .background(cardBackground)
        }
    }

    private func rankTrialMovementSummary(_ categories: [String]) -> String {
        if isDeckTrialDraft {
            return deckExampleSummary
        }
        if isTowerTrialDraft {
            return "10-floor ascent / 11 official stations / Floor 10 boss hold"
        }

        return categories.joined(separator: " / ")
    }

    private var deckExampleSummary: String {
        "A♥ 11 pushups · 7♦ 7 squats · J♣ 10 pullups · 4♠ 4 sit-ups"
    }

    private var weeklyVowKind: WeeklyVowKind {
        WeeklyVowKind.kind(fromWeeklyVowRoute: draft.weeklyVowId)
            ?? WeeklyVowKind.kind(fromWeeklyVowRoute: draft.id)
            ?? .overdrive
    }

    private var weeklyProofTint: Color {
        switch weeklyVowKind {
        case .ember:
            return Color.unbound.rankGreen
        case .overdrive:
            return Color.unbound.accent
        case .apex:
            return Color.unbound.rankGold
        }
    }

    private var weeklyProofTitle: String {
        draft.title
            .replacingOccurrences(of: "Binding Vow - ", with: "")
            .replacingOccurrences(of: "Weekly Proof - ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var weeklyProofPrescriptions: [TrainingBlockPrescription] {
        draft.blocks.flatMap(\.prescriptions)
    }

    private func rpeLabel(for prescription: TrainingBlockPrescription) -> String {
        guard let rpe = prescription.rpe else { return "" }
        return " · RPE \(rpe)"
    }

    private var blockList: some View {
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
    private func rankTrialReadyPreview(for definition: OverallRankTrialDefinition) -> some View {
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

    private var deckExampleGrid: some View {
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

    private var deckExampleCards: [(index: Int, block: TrainingBlock)] {
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

    private var deckColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]
    }

    @ViewBuilder
    private var recentDraftsSection: some View {
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

    private func blockRow(_ block: TrainingBlock, index: Int) -> some View {
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

    private func deckCard(_ block: TrainingBlock, index: Int, label: String? = nil) -> some View {
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
    private func deckCardVisual(for block: TrainingBlock) -> some View {
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
    private func blockVisual(for block: TrainingBlock, size: CGFloat) -> some View {
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
    private func prescriptionVisual(for prescription: TrainingBlockPrescription, tint: Color, size: CGFloat) -> some View {
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

    private var addControls: some View {
        let nextSkill = nextScheduledSkillId
        return VStack(spacing: 10) {
            Button {
                addNextScheduledSkill()
            } label: {
                Label(nextSkill == nil ? "All Scheduled Skills Added" : "Add Scheduled Skill", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(nextSkill == nil)
            .accessibilityIdentifier("workoutReady.addScheduledSkill")

            Button {
                showingBlockBuilder = true
            } label: {
                Label("Add Mixed Block", systemImage: "plus.square.on.square")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("workoutReady.addMixedBlock")
        }
    }

    private var startControls: some View {
        VStack(spacing: 10) {
            if !isFixedProtocolDraft {
                Button {
                    saveRecentDraft()
                } label: {
                    Label("Save Custom Draft", systemImage: "tray.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(draft.blocks.isEmpty)
                .accessibilityIdentifier("workoutReady.saveDraft")
            }

            Button {
                guard hasWorkoutCompatibleBlocks, !isLaunchingWorkout else { return }
                isLaunchingWorkout = true
                saveRecentDraftIfCustom()
                let launchDraft = draft
                DispatchQueue.main.async {
                    activeWorkoutDraft = launchDraft
                }
            } label: {
                Label(startButtonTitle, systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!hasWorkoutCompatibleBlocks)
            .opacity(hasWorkoutCompatibleBlocks ? 1 : 0.45)
            .accessibilityIdentifier("workoutReady.startWorkout")

            if !isFixedProtocolDraft,
               !hasWorkoutCompatibleBlocks,
               let skillBlock = draft.blocks.first(where: { $0.kind == .skill }),
               let skillId = skillBlock.skillId {
                Button {
                    activeSkillSession = SkillLaunch(skillId: skillId, title: skillBlock.title)
                } label: {
                    Label("Start Skill Session", systemImage: "figure.gymnastics")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var hasWorkoutCompatibleBlocks: Bool {
        !draft.blocks.isEmpty
    }

    private var isFixedProtocolDraft: Bool {
        draft.isWeeklyVowDraft || isRankTrialDraft
    }

    private var isRankTrialDraft: Bool {
        draft.source == .overallRankTrial
    }

    private var isDeckTrialDraft: Bool {
        rankTrialDefinition?.format == .fixedDeck
    }

    private var isTowerTrialDraft: Bool {
        rankTrialDefinition?.format == .tower
    }

    private var rankTrialDefinition: OverallRankTrialDefinition? {
        draft.programId.flatMap(OverallRankTrialDefinitions.definition)
    }

    private var rankTrialHeaderIconName: String {
        switch rankTrialDefinition?.format {
        case .daily100:
            return "checkmark.seal.fill"
        case .operatorScreen:
            return "scope"
        case .finisher:
            return "timer"
        case .fixedDeck:
            return "rectangle.stack.fill"
        case .tower:
            return "building.columns.fill"
        case .bossRush:
            return "flame.fill"
        case .raid:
            return "point.3.connected.trianglepath.dotted"
        case .finalExam:
            return "graduationcap.fill"
        default:
            return "seal.fill"
        }
    }

    private var rankTrialHeaderSubtitle: String {
        switch rankTrialDefinition?.format {
        case .daily100:
            return "Hit every checkpoint. One clean hundred earns the gate."
        case .operatorScreen:
            return "Clear the screen lane by lane under field-test standards."
        case .finisher:
            return "Descend the rounds fast, clean, and without form breaks."
        case .fixedDeck:
            return "Flip each card, do the reps, then tap into the next draw."
        case .tower:
            return "Climb floor by floor. Clear every station; Floor 10 is the boss hold."
        case .bossRush:
            return "Take down each encounter in order. No skipped bosses."
        case .raid:
            return "Breach each phase: engine, work, then control."
        case .finalExam:
            return "Pass every part. The final verdict comes from the full session."
        default:
            return "Official fixed protocol. Clear every station; pain or form-break flags fail the station."
        }
    }

    private var blockListTitle: String {
        if draft.isWeeklyVowDraft { return "VOW BLOCKS" }
        switch rankTrialDefinition?.format {
        case .daily100: return "CHECKPOINTS"
        case .operatorScreen: return "READINESS LANES"
        case .finisher: return "DESCENDING ROUNDS"
        case .fixedDeck: return "EXAMPLE DRAWS"
        case .tower: return "TOWER ASCENT"
        case .bossRush: return "ENCOUNTERS"
        case .raid: return "RAID PHASES"
        case .finalExam: return "EXAM PARTS"
        case nil: break
        }
        if isRankTrialDraft { return "TRIAL STATIONS" }
        return "BLOCKS"
    }

    private func movementDefinition(for block: TrainingBlock) -> MovementDefinition? {
        block.prescriptions.compactMap { movementDefinition(for: $0) }.first
    }

    private func movementDefinition(for prescription: TrainingBlockPrescription) -> MovementDefinition? {
        MovementCatalog.resolvedTrainingMovement(
            name: prescription.exerciseName,
            movementId: prescription.movementId,
            rankStandardMovementId: prescription.rankStandardMovementId
        )?.exact
    }

    private func primaryExerciseName(for block: TrainingBlock) -> String {
        block.prescriptions.first?.exerciseName ?? block.title
    }

    private func deckCardTitle(for block: TrainingBlock, index: Int) -> String {
        if let descriptor = deckCardDescriptor(for: block) {
            return descriptor.title
        }
        return block.subtitle ?? block.title
    }

    private func originalDeckCardNumber(for block: TrainingBlock) -> String? {
        deckCardDescriptor(for: block)?.number
    }

    private func deckCardDescriptor(for block: TrainingBlock) -> (number: String, title: String)? {
        let prefix = "Card "
        guard block.title.hasPrefix(prefix) else { return nil }

        let remainder = block.title.dropFirst(prefix.count)
        let parts = remainder.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard let number = parts.first else { return nil }
        let title = parts.dropFirst().first.map(String.init) ?? block.title
        return (String(number), title)
    }

    private func cardNumber(for index: Int) -> String {
        let value = index + 1
        return value < 10 ? "0\(value)" : "\(value)"
    }

    private func deckSuitSymbol(for index: Int) -> String {
        switch index % 4 {
        case 0: return "suit.spade.fill"
        case 1: return "suit.heart.fill"
        case 2: return "suit.diamond.fill"
        default: return "suit.club.fill"
        }
    }

    private func deckSuitTint(for index: Int) -> Color {
        switch index % 4 {
        case 0, 3:
            return Color.unbound.coachCyan
        default:
            return Color.unbound.emberGlow
        }
    }

    private func deckSuitSymbol(forCardCode cardCode: String, fallbackIndex: Int) -> String {
        switch deckSuitCode(for: cardCode) {
        case "S": return "suit.spade.fill"
        case "H": return "suit.heart.fill"
        case "D": return "suit.diamond.fill"
        case "C": return "suit.club.fill"
        default:
            return deckSuitSymbol(for: fallbackIndex)
        }
    }

    private func deckSuitTint(forCardCode cardCode: String, fallbackIndex: Int) -> Color {
        switch deckSuitCode(for: cardCode) {
        case "S", "C":
            return Color.unbound.coachCyan
        case "H", "D":
            return Color.unbound.emberGlow
        default:
            return deckSuitTint(for: fallbackIndex)
        }
    }

    private func deckSuitCode(for cardCode: String) -> String? {
        guard let last = cardCode.last else { return nil }
        let code = String(last).uppercased()
        return ["S", "H", "D", "C"].contains(code) ? code : nil
    }

    private var rankTrialLoadoutLabel: String? {
        draft.blocks
            .flatMap(\.prescriptions)
            .compactMap(\.notes)
            .first { $0.contains(" official station:") }?
            .components(separatedBy: " official station:")
            .first
    }

    private var startButtonTitle: String {
        if draft.isWeeklyVowDraft { return "Start Binding Vow" }
        if isRankTrialDraft { return "Start Rank Trial" }
        return "Start Workout"
    }

    private var nextScheduledSkillId: String? {
        let existing = Set(draft.blocks.compactMap(\.skillId))
        return ProgramScheduler.shared.skillIds(forDate: draft.date).first { !existing.contains($0) }
    }

    private func addNextScheduledSkill() {
        guard let next = nextScheduledSkillId,
              let node = SkillGraph.shared.node(id: next)
        else { return }
        draft.blocks.append(TrainingSessionAdapters.skillBlock(skillId: node.id, title: node.title))
        refreshDraftEstimate()
    }

    private func removeBlock(id: String) {
        draft.blocks.removeAll { $0.id == id }
        refreshDraftEstimate()
    }

    private func refreshDraftEstimate() {
        draft.estimatedMinutes = estimatedMinutes(for: draft.blocks)
    }

    private func moveBlock(from index: Int, by delta: Int) {
        let target = index + delta
        guard draft.blocks.indices.contains(index), draft.blocks.indices.contains(target) else { return }
        draft.blocks.swapAt(index, target)
    }

    private func applyBlockEdit(_ edit: BlockEditDraft) {
        guard let blockIndex = draft.blocks.firstIndex(where: { $0.id == edit.id }) else { return }
        let trimmedTitle = edit.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = edit.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = trimmedTitle.isEmpty ? draft.blocks[blockIndex].title : trimmedTitle
        let shouldMirrorTitleToPrescription = draft.blocks[blockIndex].kind != .skill
            && draft.blocks[blockIndex].prescriptions.count == 1

        draft.blocks[blockIndex].title = title
        draft.blocks[blockIndex].notes = trimmedNotes.nilIfEmpty

        guard !draft.blocks[blockIndex].prescriptions.isEmpty else {
            refreshDraftEstimate()
            editingBlock = nil
            return
        }

        for prescriptionIndex in draft.blocks[blockIndex].prescriptions.indices {
            if shouldMirrorTitleToPrescription {
                draft.blocks[blockIndex].prescriptions[prescriptionIndex].exerciseName = title
            }
            draft.blocks[blockIndex].prescriptions[prescriptionIndex].sets = edit.sets
            draft.blocks[blockIndex].prescriptions[prescriptionIndex].target = Self.target(from: edit.targetText)
            draft.blocks[blockIndex].prescriptions[prescriptionIndex].notes = trimmedNotes.nilIfEmpty
        }
        refreshDraftEstimate()
        editingBlock = nil
    }

    private static func target(from text: String) -> TrainingTarget {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = trimmed.lowercased()
        if lowered.isEmpty || lowered.contains("amrap") { return .amrap }
        if lowered.contains(":") {
            let parts = lowered.split(separator: ":").compactMap { Int($0) }
            if parts.count == 2 {
                return .timedSeconds((parts[0] * 60) + parts[1])
            }
        }
        if lowered.contains("-") || lowered.contains("–") {
            let parts = lowered
                .replacingOccurrences(of: "–", with: "-")
                .split(separator: "-")
                .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            if parts.count >= 2 { return .repsRange(parts[0], parts[1]) }
        }
        if lowered.contains("cal"), let calories = RepRange.lowerBound(lowered) { return .calories(calories) }
        if lowered.contains("s"), let seconds = RepRange.lowerBound(lowered) { return .holdSeconds(seconds) }
        if lowered.contains("m"), let meters = RepRange.lowerBound(lowered) { return .distanceMeters(meters) }
        if let reps = RepRange.lowerBound(lowered) { return .reps(reps) }
        return .amrap
    }

    private func saveRecentDraft() {
        var saved = draft
        saved.source = .custom
        saved.date = Date()
        saved.estimatedMinutes = estimatedMinutes(for: saved.blocks)
        TrainingSessionDraftStore().saveRecent(saved)
        recentDrafts = TrainingSessionDraftStore().loadRecent()
    }

    private func saveRecentDraftIfCustom() {
        guard !isFixedProtocolDraft else { return }
        let hasMixedCustomBlock = draft.blocks.contains { block in
            switch block.kind {
            case .custom, .cardio, .carry, .routine:
                return true
            case .strength, .bodyweight, .skill:
                return false
            }
        }
        guard draft.source == .custom || hasMixedCustomBlock else { return }
        saveRecentDraft()
    }

    private func estimatedMinutes(for blocks: [TrainingBlock]) -> Int {
        guard !blocks.isEmpty else { return 0 }
        return max(10, blocks.reduce(0) { total, block in
            let blockMinutes = block.prescriptions.reduce(0) { subtotal, prescription in
                let workSeconds: Int
                switch prescription.target {
                case .holdSeconds(let seconds), .timedSeconds(let seconds):
                    workSeconds = seconds
                default:
                    workSeconds = 45
                }
                return subtotal + ((workSeconds + prescription.restSeconds) * max(1, prescription.sets))
            }
            return total + max(5, Int(ceil(Double(blockMinutes) / 60.0)))
        })
    }

    private func prescriptionSummary(_ block: TrainingBlock) -> String {
        block.prescriptions.prefix(3).map {
            "\($0.exerciseName) · \($0.sets)x \($0.displayTargetText)"
        }
        .joined(separator: " / ")
    }

    private func readyChip(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(Font.unbound.captionS.weight(.bold))
            .foregroundStyle(Color.unbound.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.unbound.surfaceElevated))
    }

    private func icon(for kind: TrainingBlockKind) -> String {
        switch kind {
        case .strength, .custom: return "dumbbell.fill"
        case .bodyweight: return "figure.strengthtraining.traditional"
        case .skill: return "figure.gymnastics"
        case .cardio: return "figure.run"
        case .carry: return "shippingbox.fill"
        case .routine: return "timer"
        }
    }

    private func color(for kind: TrainingBlockKind) -> Color {
        switch kind {
        case .strength, .custom: return Color.unbound.accent
        case .bodyweight: return Color.unbound.rankGreen
        case .skill: return Color.unbound.coachCyan
        case .cardio: return Color.unbound.warnOrange
        case .carry: return Color.unbound.warnOrange
        case .routine: return Color.unbound.textSecondary
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.unbound.surface)
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
    }

    private struct SkillLaunch: Identifiable {
        let skillId: String
        let title: String
        var id: String { skillId }
    }

    private struct BlockEditDraft: Identifiable {
        let id: String
        var title: String
        var sets: Int
        var targetText: String
        var notes: String

        init(block: TrainingBlock) {
            id = block.id
            title = block.title
            sets = block.prescriptions.first?.sets ?? 1
            targetText = block.prescriptions.first?.displayTargetText ?? "AMRAP"
            notes = block.notes ?? ""
        }
    }

    private struct BlockEditSheet: View {
        @Environment(\.dismiss) private var dismiss

        let onSave: (BlockEditDraft) -> Void

        @State private var working: BlockEditDraft

        init(edit: BlockEditDraft, onSave: @escaping (BlockEditDraft) -> Void) {
            self.onSave = onSave
            _working = State(initialValue: edit)
        }

        var body: some View {
            NavigationStack {
                ZStack {
                    Color.unbound.bg.ignoresSafeArea()
                    ScrollView {
                        VStack(spacing: 16) {
                            TextField("Block title", text: $working.title)
                                .textInputAutocapitalization(.words)
                                .padding(14)
                                .background(cardBackground)
                                .accessibilityIdentifier("blockEdit.title")

                            Stepper("Sets: \(working.sets)", value: $working.sets, in: 1...12)
                                .font(Font.unbound.bodyM.weight(.semibold))
                                .foregroundStyle(Color.unbound.textPrimary)
                                .padding(14)
                                .background(cardBackground)
                                .accessibilityIdentifier("blockEdit.sets")

                            TextField("Target (8-12, 30s, AMRAP)", text: $working.targetText)
                                .textInputAutocapitalization(.characters)
                                .padding(14)
                                .background(cardBackground)
                                .accessibilityIdentifier("blockEdit.target")

                            TextField("Notes", text: $working.notes, axis: .vertical)
                                .lineLimit(3...5)
                                .padding(14)
                                .background(cardBackground)
                                .accessibilityIdentifier("blockEdit.notes")

                            Button {
                                onSave(working)
                                dismiss()
                            } label: {
                                Text("Save Changes")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("blockEdit.save")
                        }
                        .padding(20)
                    }
                }
                .navigationTitle("Edit Block")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                            .foregroundStyle(Color.unbound.textSecondary)
                    }
                }
            }
        }

        private var cardBackground: some View {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.unbound.surface)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
        }
    }

    private struct BlockBuilderSheet: View {
        @Environment(\.dismiss) private var dismiss

        let onAdd: (TrainingBlock) -> Void

        @State private var kind: TrainingBlockKind = .custom
        @State private var title = "Accessory Block"
        @State private var sets = 3
        @State private var targetText = "8-12"
        @State private var restSeconds = 90
        @State private var selectedSkillId = SkillGraph.shared.nodes.first?.id ?? ""
        @State private var cardioType: CardioType = .run
        @State private var notes = ""

        private let supportedKinds: [TrainingBlockKind] = [.custom, .skill, .cardio, .carry, .routine]

        var body: some View {
            NavigationStack {
                ZStack {
                    Color.unbound.bg.ignoresSafeArea()
                    ScrollView {
                        VStack(spacing: 16) {
                            Picker("Block Type", selection: $kind) {
                                ForEach(supportedKinds, id: \.self) { kind in
                                    Text(kindLabel(kind)).tag(kind)
                                }
                            }
                            .pickerStyle(.segmented)
                            .accessibilityIdentifier("blockBuilder.kindPicker")

                            kindSpecificFields

                            Stepper("Sets: \(sets)", value: $sets, in: 1...12)
                                .font(Font.unbound.bodyM.weight(.semibold))
                                .foregroundStyle(Color.unbound.textPrimary)
                                .padding(14)
                                .background(cardBackground)

                            TextField("Target (8-12, 30s, 10:00, 400m, 20 cal)", text: $targetText)
                                .textInputAutocapitalization(.characters)
                                .padding(14)
                                .background(cardBackground)

                            Stepper("Rest: \(restSeconds)s", value: $restSeconds, in: 0...300, step: 15)
                                .font(Font.unbound.bodyM.weight(.semibold))
                                .foregroundStyle(Color.unbound.textPrimary)
                                .padding(14)
                                .background(cardBackground)

                            TextField("Notes", text: $notes, axis: .vertical)
                                .lineLimit(3...5)
                                .padding(14)
                                .background(cardBackground)

                            Button {
                                onAdd(makeBlock())
                                dismiss()
                            } label: {
                                Text("Add Block")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(resolvedTitle.isEmpty)
                            .accessibilityIdentifier("blockBuilder.addBlock")
                        }
                        .padding(20)
                    }
                }
                .navigationTitle("Add Block")
                .navigationBarTitleDisplayMode(.inline)
                .onChange(of: kind) { _, newKind in
                    applyDefaults(for: newKind)
                }
            }
        }

        @ViewBuilder
        private var kindSpecificFields: some View {
            switch kind {
            case .skill:
                Picker("Skill", selection: $selectedSkillId) {
                    ForEach(SkillGraph.shared.nodes.sorted { $0.title < $1.title }) { node in
                        Text(node.title).tag(node.id)
                    }
                }
                .pickerStyle(.navigationLink)
                .padding(14)
                .background(cardBackground)
            case .cardio:
                Picker("Cardio", selection: $cardioType) {
                    ForEach(CardioType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.navigationLink)
                .padding(14)
                .background(cardBackground)
            default:
                TextField("Block title", text: $title)
                    .textInputAutocapitalization(.words)
                    .padding(14)
                    .background(cardBackground)
            }
        }

        private var resolvedTitle: String {
            switch kind {
            case .skill:
                return SkillGraph.shared.node(id: selectedSkillId)?.title ?? "Skill Practice"
            case .cardio:
                return cardioType.displayName
            default:
                return title.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        private func makeBlock() -> TrainingBlock {
            if kind == .skill, let node = SkillGraph.shared.node(id: selectedSkillId) {
                var block = TrainingSessionAdapters.skillBlock(skillId: node.id, title: node.title)
                if !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    block.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                return block
            }

            return TrainingBlock(
                kind: kind,
                title: resolvedTitle,
                subtitle: subtitle(for: kind),
                cardioType: kind == .cardio ? cardioType : nil,
                prescriptions: [
                    TrainingBlockPrescription(
                        exerciseName: resolvedTitle,
                        sets: sets,
                        target: WorkoutReadyView.target(from: targetText),
                        restSeconds: restSeconds,
                        notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                    )
                ],
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            )
        }

        private func applyDefaults(for kind: TrainingBlockKind) {
            switch kind {
            case .custom:
                title = "Accessory Block"
                sets = 3
                targetText = "8-12"
                restSeconds = 90
            case .skill:
                sets = 3
                targetText = "30s"
                restSeconds = 90
            case .cardio:
                sets = 1
                targetText = "10:00"
                restSeconds = 0
            case .carry:
                title = "Farmer Carry"
                sets = 4
                targetText = "40m"
                restSeconds = 90
            case .routine:
                title = "Mobility Routine"
                sets = 1
                targetText = "5:00"
                restSeconds = 0
            case .strength, .bodyweight:
                break
            }
        }

        private func kindLabel(_ kind: TrainingBlockKind) -> String {
            switch kind {
            case .custom: return "Lift"
            case .skill: return "Skill"
            case .cardio: return "Cardio"
            case .carry: return "Carry"
            case .routine: return "Routine"
            case .strength: return "Strength"
            case .bodyweight: return "Bodyweight"
            }
        }

        private func subtitle(for kind: TrainingBlockKind) -> String? {
            switch kind {
            case .cardio: return "\(cardioType.displayName) · \(targetText)"
            case .carry: return "Load, posture, distance, or time"
            case .routine: return "Timer-based sequence"
            default: return nil
            }
        }

        private var cardBackground: some View {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.unbound.surface)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
        }
    }
}

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
