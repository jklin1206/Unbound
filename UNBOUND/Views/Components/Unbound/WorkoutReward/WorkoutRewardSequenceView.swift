import SwiftUI
import UIKit
import PhotosUI

// MARK: - WorkoutRewardSequenceView
//
// Full workout-end payout. Beats are staged, but the user can continue
// immediately once the final yield is visible. Color is deliberate:
// XP uses blue, lift families own their own hues, attributes use axis
// colors, and violet is reserved for major tier/system impact.

struct WorkoutRewardSequenceView: View {
    let summary: WorkoutRewardSequenceSummary
    /// Opt-in post-workout photo. Provided only by the program training-completion
    /// path; nil elsewhere, which (with `summary.workoutPhotoContext`) hides the button.
    var onAddWorkoutPhoto: ((UIImage) -> Void)? = nil
    let onDismiss: () -> Void

    @State var beat: Int = 0
    @State private var showWorkoutCamera = false
    @State private var showWorkoutLibrary = false
    @State private var workoutLibraryItem: PhotosPickerItem?
    @State private var workoutPhotoAdded = false
    @State var animatedXP: Int = 0
    @State var pageRevealed = false
    @State var attributeHexProgress: Double = 0
    @State var hexPrev: [AttributeKey: Double] = [:]   // phase from-map
    @State var hexCur: [AttributeKey: Double] = [:]    // phase to-map
    @State var finishRequested = false
    @AppStorage(WeightPlatePolicy.unitDefaultsKey) var weightUnitRaw = TrainingWeightUnit.localeDefault.rawValue

    enum RewardBeatKind: Equatable {
        case sessionComplete
        case xp
        case proof
        case attributes
        case collection
        case progression
        case rankTrial
        case weeklyVow
        case cosmetic
        case streak
        case final
    }

    var rewardBeats: [RewardBeatKind] {
        var beats: [RewardBeatKind] = summary.showsSessionSummary ? [.sessionComplete] : []

        if summary.xp.total > 0 || !summary.xp.breakdown.isEmpty {
            beats.append(.xp)
        }

        if !summary.exerciseRanks.isEmpty || !summary.beats.isEmpty || summary.tally.hasAnyReward {
            beats.append(.proof)
        }

        if !summary.attributeDeltas.isEmpty {
            beats.append(.attributes)
        }

        if !summary.personalRecords.isEmpty || !summary.badges.isEmpty {
            beats.append(.collection)
        }

        if shouldShowProgressionLedger {
            beats.append(.progression)
        }

        if summary.rankTrialCallout != nil {
            beats.append(.rankTrial)
        }

        if summary.weeklyVowCallout != nil {
            beats.append(.weeklyVow)
        }

        if !summary.cosmeticUnlocks.isEmpty {
            beats.append(.cosmetic)
        }

        if let streak = summary.streak, streak.dayCount > 0 {
            beats.append(.streak)
        }

        if summary.showsFinalSummary || beats.isEmpty {
            beats.append(.final)
        }
        return beats
    }

    var maxBeat: Int {
        max(0, rewardBeats.count - 1)
    }

    var currentBeatKind: RewardBeatKind {
        rewardBeats[min(max(beat, 0), maxBeat)]
    }

    /// Most progression details are implementation spine now. The post-workout
    /// sequence should only surface this page when it is the only meaningful XP
    /// receipt left to show, or when the novelty bonus itself is the reward.
    var shouldShowProgressionLedger: Bool {
        guard let receipt = summary.progression else { return false }
        if summary.xp.total <= 0 && receipt.skillXPGained > 0 {
            return true
        }
        if receipt.noveltyMultiplier > 1.001 && summary.attributeDeltas.isEmpty {
            return true
        }
        return false
    }

    var body: some View {
        ZStack {
            rewardBackdrop
            rewardAtmosphere

            VStack(spacing: 0) {
                topRail

                ScrollView(showsIndicators: false) {
                    currentRewardPage
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: max(420, ScreenMetrics.bounds.height - 250), alignment: .center)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .padding(.bottom, 190)
                        .id(beat)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.96).combined(with: .opacity),
                            removal: .scale(scale: 1.04).combined(with: .opacity)
                        ))
                }
            }

            VStack {
                Spacer()
                bottomActions
            }
        }
        .onAppear { startBeats() }
        .onChange(of: beat) { _, newBeat in
            revealCurrentPage()
            if rewardBeats[min(max(newBeat, 0), maxBeat)] == .xp {
                animateXP()
            }
        }
        .fullScreenCover(isPresented: $showWorkoutCamera) {
            CameraPicker { image in handleWorkoutPhoto(image) }
                .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showWorkoutLibrary, selection: $workoutLibraryItem, matching: .images)
        .onChange(of: workoutLibraryItem) { _, item in
            guard let item else { return }
            Task {
                let image = (try? await item.loadTransferable(type: Data.self)).flatMap(UIImage.init(data:))
                await MainActor.run {
                    if let image { handleWorkoutPhoto(image) }
                    workoutLibraryItem = nil
                }
            }
        }
    }

    // MARK: - Post-workout photo

    /// Opt-in capture on the final beat. Camera when available (device), else the
    /// photo library (simulator / no camera). The actual save is owned by the
    /// presenter via `onAddWorkoutPhoto`, so this view stays free of services.
    @ViewBuilder
    var addPhotoButton: some View {
        if summary.workoutPhotoContext != nil, onAddWorkoutPhoto != nil {
            Button {
                UnboundHaptics.soft()
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    showWorkoutCamera = true
                } else {
                    showWorkoutLibrary = true
                }
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: workoutPhotoAdded ? "checkmark.circle.fill" : "camera.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text(workoutPhotoAdded ? "PHOTO ADDED" : "ADD A PHOTO")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .tracking(1.6)
                }
                .foregroundStyle(workoutPhotoAdded ? Color.unbound.textTertiary : Color.unbound.textPrimary.opacity(0.92))
                .padding(.horizontal, 18)
                .frame(height: 42)
                .background(.ultraThinMaterial.opacity(0.16), in: Capsule())
                .overlay(
                    Capsule().stroke(
                        (workoutPhotoAdded ? Color.unbound.success : Color.rewardBlue).opacity(0.5),
                        lineWidth: 1.3
                    )
                )
            }
            .buttonStyle(.plain)
            .disabled(workoutPhotoAdded)
            .accessibilityIdentifier("workoutRewardAddPhotoButton")
        }
    }

    private func handleWorkoutPhoto(_ image: UIImage) {
        workoutPhotoAdded = true
        UnboundHaptics.medium()
        onAddWorkoutPhoto?(image)
    }

    // MARK: - Chrome

    var topRail: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(0..<rewardBeats.count, id: \.self) { index in
                    Capsule()
                        .fill(index <= beat ? Color.rewardBlue.opacity(0.95) : Color.unbound.textPrimary.opacity(0.18))
                        .frame(width: index == beat ? 22 : 7, height: 3)
                        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: beat)
                }
            }
            Text(summary.workoutName.uppercased())
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(2.0)
                .foregroundStyle(Color.unbound.textTertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    var rewardBackdrop: some View {
        ZStack {
            Image("reward_backdrop_void")
                .resizable()
                .scaledToFill()
                .scaleEffect(1.08)
                .position(x: ScreenMetrics.bounds.width / 2, y: ScreenMetrics.bounds.height / 2)
                .ignoresSafeArea()
            Color.black.opacity(0.72).ignoresSafeArea()
            LinearGradient(
                colors: [Color.black.opacity(0.92), Color.black.opacity(0.42), Color.black.opacity(0.94)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    var rewardAtmosphere: some View {
        ZStack {
            RadialGradient(
                colors: [Color.rewardBlue.opacity(0.20), Color.clear],
                center: .center,
                startRadius: 20,
                endRadius: 360
            )
            RadialGradient(
                colors: [Color.unbound.impact.opacity(0.10), Color.clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }

    var dominantRewardTint: Color {
        if let advance = summary.liftProgress.first(where: \.didAdvanceTier) { return advance.toTier.rewardTint }
        if let pr = summary.personalRecords.first { return pr.family.tint }
        if let attribute = summary.attributeDeltas.first(where: \.didAdvanceTier) { return attribute.tint }
        if let rankTrial = summary.rankTrialCallout { return rankTrial.passed ? Color.unbound.rankGold : Color.unbound.alert }
        if let vow = summary.weeklyVowCallout { return vow.lane.tintColor }
        return Color.rewardBlue
    }

    // MARK: - Beats

    @ViewBuilder
    var currentRewardPage: some View {
        switch currentBeatKind {
        case .sessionComplete:
            sessionCompleteBeat
        case .xp:
            xpBeat
        case .proof:
            ranksBeat
        case .attributes:
            attributeBeat
        case .collection:
            collectionBeat
        case .progression:
            if let progression = summary.progression {
                progressionBeat(progression)
            }
        case .rankTrial:
            rankTrialBeat
        case .weeklyVow:
            weeklyVowBeat
        case .cosmetic:
            cosmeticBeat
        case .streak:
            streakBeat
        case .final:
            finalYield
        }
    }

    var bottomActions: some View {
        VStack(spacing: 10) {
            Button {
                advanceRewardPage()
            } label: {
                HStack(spacing: 10) {
                    Text(finishRequested ? "SAVING" : (beat >= maxBeat ? "FINISH" : "CONTINUE"))
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(2.4)
                    if finishRequested {
                        ProgressView()
                            .controlSize(.small)
                            .tint(Color.unbound.textPrimary)
                    } else {
                        Image(systemName: beat >= maxBeat ? "checkmark" : "chevron.right")
                            .font(.system(size: 11, weight: .black))
                    }
                }
                .foregroundStyle(Color.unbound.textPrimary.opacity(0.92))
                .padding(.horizontal, 20)
                .frame(height: 46)
                .background(.ultraThinMaterial.opacity(0.18), in: Capsule())
                .overlay(Capsule().stroke(Color.rewardBlue.opacity(0.50), lineWidth: 1.5))
                .shadow(color: Color.rewardBlue.opacity(0.22), radius: 16)
            }
            .buttonStyle(.plain)
            .disabled(finishRequested)
            .accessibilityIdentifier("workoutRewardContinueButton")
            .accessibilityLabel(finishRequested ? "SAVING" : (beat >= maxBeat ? "FINISH" : "CONTINUE"))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0), Color.black.opacity(0.88), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    func startBeats() {
        UnboundSound.shared.preloadRewardKit()
        UnboundHaptics.heavy()
        playSound(for: currentBeatKind)
        revealCurrentPage()
        #if DEBUG
        // Reward-demo recording: drive the page advances hands-free so the whole
        // sequence plays autonomously for a screen capture (no tap injection).
        if ProcessInfo.processInfo.arguments.contains("-rewardDemo")
            || ProcessInfo.processInfo.environment["REWARD_DEMO"] == "1" {
            for step in 1...(maxBeat + 1) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.3 * Double(step)) {
                    advanceRewardPage()
                }
            }
        }
        #endif
    }

    func revealCurrentPage() {
        let revealedBeat = currentBeatKind
        if revealedBeat == .attributes { attributeHexProgress = 0 }

        pageRevealed = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.84)) {
                pageRevealed = true
            }
            guard revealedBeat == .attributes else { return }
            runHexSequence()
        }
    }

    /// Attribute-hex reveal. Every axis fills from its prior level-progress to its
    /// new progress; an axis that LEVELED UP this session overshoots to full,
    /// then rolls over (snap to empty) and refills to its new (small) progress —
    /// the same level-up feel as the XP bar, per axis.
    func runHexSequence() {
        let prev = previousAttributeMap
        let cur = currentAttributeMap
        let leveled = Set(summary.attributeDeltas.filter(\.didIncreaseLevel).map(\.key))

        // Phase 1: fill toward current; leveled axes overshoot to full.
        var phase1 = cur
        for key in leveled { phase1[key] = 100 }
        hexPrev = prev
        hexCur = phase1
        attributeHexProgress = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeOut(duration: leveled.isEmpty ? 1.15 : 0.95)) {
                attributeHexProgress = 1
            }
        }

        guard !leveled.isEmpty else { return }

        // Phase 2: leveled axes roll over — snap empty, then refill to real value.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18 + 0.95 + 0.16) {
            var from = cur
            for key in leveled { from[key] = 0 }
            hexPrev = from
            hexCur = cur
            attributeHexProgress = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
                withAnimation(.easeOut(duration: 0.7)) { attributeHexProgress = 1 }
            }
        }
    }

    func animateXP() {
        animatedXP = 0
        let total = summary.xp.total
        for step in 1...12 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65 + Double(step) * 0.055) {
                animatedXP = Int(Double(total) * Double(step) / 12.0)
                // Rising tick zips up with the count (pitch climbs as the bar fills).
                UnboundSound.shared.play(.xpTick, volume: 0.32, rate: 1.0 + Float(step) / 12.0 * 0.7)
            }
        }
    }

    /// Per-beat audio. XP ticks (animateXP), the level-up chord (LevelProgressHero),
    /// and the rank stinger (RankStandardHero) are fired from their own views.
    func playSound(for kind: RewardBeatKind) {
        switch kind {
        case .sessionComplete: UnboundSound.shared.play(.sessionComplete, volume: 0.85)
        case .cosmetic: UnboundSound.shared.play(.rankReveal, volume: 0.7)
        case .streak: UnboundSound.shared.play(.rankReveal, volume: 0.7)
        case .final: UnboundSound.shared.play(.finish)
        default: break
        }
    }

    func advanceRewardPage() {
        if beat >= maxBeat {
            guard !finishRequested else { return }
            finishRequested = true
            UnboundHaptics.medium()
            onDismiss()
            return
        }

        withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
            beat += 1
        }

        playSound(for: currentBeatKind)

        switch currentBeatKind {
        case .xp:
            animatedXP = 0
            UnboundHaptics.heavy()
        case .proof, .attributes, .collection, .progression, .rankTrial, .weeklyVow, .cosmetic, .streak:
            UnboundHaptics.medium()
        case .sessionComplete, .final:
            UnboundHaptics.soft()
        }
    }

    // MARK: - Helpers
}
