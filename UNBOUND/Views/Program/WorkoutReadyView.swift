import SwiftUI

struct WorkoutReadyView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var services: ServiceContainer

    @State var draft: TrainingSessionDraft
    @State var activeWorkoutDraft: TrainingSessionDraft?
    @State var activeSkillSession: SkillLaunch?
    @State var showingBlockBuilder = false
    @State var editingBlock: BlockEditDraft?
    @State var recentDrafts: [TrainingSessionDraft] = []
    @State var isLaunchingWorkout = false

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

    var hasWorkoutCompatibleBlocks: Bool {
        !draft.blocks.isEmpty
    }

    var isFixedProtocolDraft: Bool {
        draft.isWeeklyVowDraft || isRankTrialDraft
    }

    var isRankTrialDraft: Bool {
        draft.source == .overallRankTrial
    }

    var isDeckTrialDraft: Bool {
        rankTrialDefinition?.format == .deckOfProof
    }

    var isTowerTrialDraft: Bool {
        rankTrialDefinition?.format == .theAscent
    }

    var rankTrialDefinition: OverallRankTrialDefinition? {
        draft.programId.flatMap(OverallRankTrialDefinitions.definition)
    }

    var rankTrialHeaderIconName: String {
        switch rankTrialDefinition?.format {
        case .firstLight:
            return "checkmark.seal.fill"
        case .theCount:
            return "scope"
        case .theForging:
            return "timer"
        case .deckOfProof:
            return "rectangle.stack.fill"
        case .theAscent:
            return "building.columns.fill"
        case .sevenSeals:
            return "flame.fill"
        case .theThreshold:
            return "point.3.connected.trianglepath.dotted"
        case .theLastGate:
            return "graduationcap.fill"
        default:
            return "seal.fill"
        }
    }

    var rankTrialHeaderSubtitle: String {
        switch rankTrialDefinition?.format {
        case .firstLight:
            return "Hit every checkpoint. One clean hundred earns the gate."
        case .theCount:
            return "Clear the screen lane by lane under field-test standards."
        case .theForging:
            return "Descend the rounds fast, clean, and without form breaks."
        case .deckOfProof:
            return "Flip each card, do the reps, then tap into the next draw."
        case .theAscent:
            return "Climb floor by floor. Clear every station; Floor 10 is the boss hold."
        case .sevenSeals:
            return "Take down each encounter in order. No skipped bosses."
        case .theThreshold:
            return "Breach each phase: engine, work, then control."
        case .theLastGate:
            return "Pass every part. The final verdict comes from the full session."
        default:
            return "Fixed trial protocol. Clear every station; pain or form-break flags fail the station."
        }
    }

    var rankTrialHowItWorksText: String {
        switch rankTrialDefinition?.format {
        case .firstLight:
            return "Clear five checkpoints: lower, push, pull, step, and trunk. Each one needs clean logged work before the trial closes."
        case .theCount:
            return "Complete every event lane: engine, lower, push, pull, and carry/core. A missed lane means the rank gate stays closed."
        case .theForging:
            return "Work through three descending rounds. Each round tests engine, hinge, push, pull, and carry under the same clock."
        case .deckOfProof:
            return "Draw a card, do the reps, then tap into the next draw. The suit picks the movement and the card value picks the reps."
        case .theAscent:
            return "Climb floor by floor. Clear every floor, then finish the boss hold to seal the gate."
        case .sevenSeals:
            return "Clear each boss under its station clock. Engine, lower, power, push, pull, control, and carry all have to pass."
        case .theThreshold:
            return "Clear three stages in order: engine repeats, work-set gates, then the final control hold."
        case .theLastGate:
            return "Pass all three parts: explosive control, engine capacity, then the final volume block."
        case nil:
            return "Clear every station with clean logged work. Pain or form-break flags fail the station."
        }
    }

    var blockListTitle: String {
        if draft.isWeeklyVowDraft { return "VOW BLOCKS" }
        switch rankTrialDefinition?.format {
        case .firstLight: return "CHECKPOINTS"
        case .theCount: return "READINESS LANES"
        case .theForging: return "DESCENDING ROUNDS"
        case .deckOfProof: return "EXAMPLE DRAWS"
        case .theAscent: return "TOWER ASCENT"
        case .sevenSeals: return "ENCOUNTERS"
        case .theThreshold: return "RAID PHASES"
        case .theLastGate: return "EXAM PARTS"
        case nil: break
        }
        if isRankTrialDraft { return "TRIAL STATIONS" }
        return "BLOCKS"
    }

    func movementDefinition(for block: TrainingBlock) -> MovementDefinition? {
        block.prescriptions.compactMap { movementDefinition(for: $0) }.first
    }

    func movementDefinition(for prescription: TrainingBlockPrescription) -> MovementDefinition? {
        MovementCatalog.resolvedTrainingMovement(
            name: prescription.exerciseName,
            movementId: prescription.movementId,
            rankStandardMovementId: prescription.rankStandardMovementId
        )?.exact
    }

    func primaryExerciseName(for block: TrainingBlock) -> String {
        block.prescriptions.first?.exerciseName ?? block.title
    }

    func deckCardTitle(for block: TrainingBlock, index: Int) -> String {
        if let descriptor = deckCardDescriptor(for: block) {
            return descriptor.title
        }
        return block.subtitle ?? block.title
    }

    func originalDeckCardNumber(for block: TrainingBlock) -> String? {
        deckCardDescriptor(for: block)?.number
    }

    func deckCardDescriptor(for block: TrainingBlock) -> (number: String, title: String)? {
        let prefix = "Card "
        guard block.title.hasPrefix(prefix) else { return nil }

        let remainder = block.title.dropFirst(prefix.count)
        let parts = remainder.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard let number = parts.first else { return nil }
        let title = parts.dropFirst().first.map(String.init) ?? block.title
        return (String(number), title)
    }

    func cardNumber(for index: Int) -> String {
        let value = index + 1
        return value < 10 ? "0\(value)" : "\(value)"
    }

    func deckSuitSymbol(for index: Int) -> String {
        switch index % 4 {
        case 0: return "suit.spade.fill"
        case 1: return "suit.heart.fill"
        case 2: return "suit.diamond.fill"
        default: return "suit.club.fill"
        }
    }

    func deckSuitTint(for index: Int) -> Color {
        switch index % 4 {
        case 0, 3:
            return Color.unbound.coachCyan
        default:
            return Color.unbound.emberGlow
        }
    }

    func deckSuitSymbol(forCardCode cardCode: String, fallbackIndex: Int) -> String {
        switch deckSuitCode(for: cardCode) {
        case "S": return "suit.spade.fill"
        case "H": return "suit.heart.fill"
        case "D": return "suit.diamond.fill"
        case "C": return "suit.club.fill"
        default:
            return deckSuitSymbol(for: fallbackIndex)
        }
    }

    func deckSuitTint(forCardCode cardCode: String, fallbackIndex: Int) -> Color {
        switch deckSuitCode(for: cardCode) {
        case "S", "C":
            return Color.unbound.coachCyan
        case "H", "D":
            return Color.unbound.emberGlow
        default:
            return deckSuitTint(for: fallbackIndex)
        }
    }

    func deckSuitCode(for cardCode: String) -> String? {
        guard let last = cardCode.last else { return nil }
        let code = String(last).uppercased()
        return ["S", "H", "D", "C"].contains(code) ? code : nil
    }

    var startButtonTitle: String {
        if draft.isWeeklyVowDraft { return "Start Binding Vow" }
        if isRankTrialDraft { return "Start Rank Trial" }
        return "Start Workout"
    }

    var nextScheduledSkillId: String? {
        let existing = Set(draft.blocks.compactMap(\.skillId))
        return ProgramScheduler.shared.skillIds(forDate: draft.date).first { !existing.contains($0) }
    }

    func addNextScheduledSkill() {
        guard let next = nextScheduledSkillId,
              let node = SkillGraph.shared.node(id: next)
        else { return }
        draft.blocks.append(TrainingSessionAdapters.skillBlock(skillId: node.id, title: node.title))
        refreshDraftEstimate()
    }

    func removeBlock(id: String) {
        draft.blocks.removeAll { $0.id == id }
        refreshDraftEstimate()
    }

    func refreshDraftEstimate() {
        draft.estimatedMinutes = estimatedMinutes(for: draft.blocks)
    }

    func moveBlock(from index: Int, by delta: Int) {
        let target = index + delta
        guard draft.blocks.indices.contains(index), draft.blocks.indices.contains(target) else { return }
        draft.blocks.swapAt(index, target)
    }

    func applyBlockEdit(_ edit: BlockEditDraft) {
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

    static func target(from text: String) -> TrainingTarget {
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

    func saveRecentDraft() {
        var saved = draft
        saved.source = .custom
        saved.date = Date()
        saved.estimatedMinutes = estimatedMinutes(for: saved.blocks)
        TrainingSessionDraftStore().saveRecent(saved)
        recentDrafts = TrainingSessionDraftStore().loadRecent()
    }

    func saveRecentDraftIfCustom() {
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

    func estimatedMinutes(for blocks: [TrainingBlock]) -> Int {
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

    func prescriptionSummary(_ block: TrainingBlock) -> String {
        block.prescriptions.prefix(3).map {
            "\($0.exerciseName) · \($0.sets)x \($0.displayTargetText)"
        }
        .joined(separator: " / ")
    }

    func readyChip(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(Font.unbound.captionS.weight(.bold))
            .foregroundStyle(Color.unbound.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.unbound.surfaceElevated))
    }

    func icon(for kind: TrainingBlockKind) -> String {
        switch kind {
        case .strength, .custom: return "dumbbell.fill"
        case .bodyweight: return "figure.strengthtraining.traditional"
        case .skill: return "figure.gymnastics"
        case .cardio: return "figure.run"
        case .carry: return "shippingbox.fill"
        case .routine: return "timer"
        }
    }

    func color(for kind: TrainingBlockKind) -> Color {
        switch kind {
        case .strength, .custom: return Color.unbound.accent
        case .bodyweight: return Color.unbound.rankGreen
        case .skill: return Color.unbound.coachCyan
        case .cardio: return Color.unbound.warnOrange
        case .carry: return Color.unbound.warnOrange
        case .routine: return Color.unbound.textSecondary
        }
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.unbound.surface)
    }

    struct SkillLaunch: Identifiable {
        let skillId: String
        let title: String
        var id: String { skillId }
    }

    struct BlockEditDraft: Identifiable {
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

}
extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
