import SwiftUI

// MARK: - OnboardingContainerView
//
// Routes the 33-step UNBOUND onboarding flow based on `flow.currentStep`.
// Flow shape: answers → scan → cinematic analyzing → verdict → trajectory →
// social proof → paywall → home.
//
// `ServiceContainer` injects user + camera services into the VM / scan views.

struct OnboardingContainerView: View {
    let onComplete: () -> Void

    @EnvironmentObject var services: ServiceContainer
    @State private var flow: OnboardingFlowViewModel?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let flow {
                    OnboardingRouter(flow: flow, onComplete: {
                        Task {
                            let userId = services.auth.currentUserId ?? "anonymous"
                            _ = await flow.finish(userId: userId)
                            onComplete()
                        }
                    })
                } else {
                    Color.unbound.bg
                        .ignoresSafeArea()
                        .onAppear {
                            services.analytics.track(.onboardingStarted)
                            let nextFlow = OnboardingFlowViewModel(userService: services.user)
                            #if DEBUG
                            nextFlow.applyDebugLaunchStepIfPresent()
                            #endif
                            flow = nextFlow
                        }
                }
            }

            #if DEBUG
            if shouldShowDevControls {
                VStack(alignment: .trailing, spacing: 8) {
                    if let flow {
                        devJumpMenu(flow: flow)
                    }
                    devSkipButton
                }
                    .padding(.top, 54)
                    .padding(.trailing, 16)
            }
            #endif
        }
    }

    // MARK: - Dev skip (DEBUG only)
    //
    // Grants full entitlement (dev unlock flag) and fires onComplete so the
    // user lands directly on Home with every feature — Coach included —
    // immediately available. Useful for UI iteration.
    #if DEBUG
    private var shouldShowDevControls: Bool {
        !ProcessInfo.processInfo.arguments.contains("-HideOnboardingDevControls")
    }

    @ViewBuilder
    private func devJumpMenu(flow: OnboardingFlowViewModel) -> some View {
        Menu {
            Section(L10n.onboarding("debug.officialFlow", defaultValue: "Official Flow")) {
                ForEach(OnboardingStep.flowOrder) { step in
                    Button(step.debugDisplayName) {
                        flow.seedDebugAnswers()
                        flow.jump(to: step)
                    }
                }
            }

            if !OnboardingStep.archivedDebugSteps.isEmpty {
                Section(L10n.onboarding("debug.archivedScreens", defaultValue: "Archived Screens")) {
                    ForEach(OnboardingStep.archivedDebugSteps) { step in
                        Button(step.debugDisplayName) {
                            flow.seedDebugAnswers()
                            flow.jump(to: step)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "rectangle.stack.fill")
                    .font(.system(size: 10, weight: .bold))
                Text(L10n.onboarding("debug.devJump", defaultValue: "DEV · JUMP"))
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.4)
            }
            .foregroundStyle(Color.unbound.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(Color.unbound.bg.opacity(0.85))
            )
            .overlay(
                Capsule().strokeBorder(Color.unbound.accent.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var devSkipButton: some View {
        Button {
            DevFlags.shared.unlockAllFeatures = true
            let gen = UIImpactFeedbackGenerator(style: .heavy)
            gen.impactOccurred()
            onComplete()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 10, weight: .bold))
                Text(L10n.onboarding("debug.devSkip", defaultValue: "DEV · SKIP"))
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.4)
            }
            .foregroundStyle(Color.unbound.impact)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(Color.unbound.bg.opacity(0.85))
            )
            .overlay(
                Capsule().strokeBorder(Color.unbound.impact.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    #endif
}

// MARK: - Router

private struct OnboardingRouter: View {
    @Bindable var flow: OnboardingFlowViewModel
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            OnboardingAtmosphere(intensity: atmosphereIntensity)
                .animation(.easeInOut(duration: 0.6), value: atmosphereIntensity)

            Group {
                switch flow.currentStep {
                case .problemFrame:
                    Step_ProblemFrame(onContinue: advance)
                        .transition(.opacity)

                case .restartLoop:
                    Step_RestartLoop(onContinue: advance)
                        .transition(screenTransition)

                case .arc01Opening:
                    Step_Arc01_Opening(onBegin: advance)
                        .transition(.opacity)

                case .arc03Path:
                    Step_Arc03_Path(onBegin: advance)
                        .transition(.opacity)

                case .lifeChangeEnergy:
                    Step_LifeChange(slide: .energy, progress: flow.progress, onBack: back, onContinue: advance)
                        .transition(screenTransition)

                case .lifeChangeStrength:
                    Step_LifeChange(slide: .strength, progress: flow.progress, onBack: back, onContinue: advance)
                        .transition(screenTransition)

                case .lifeChangeConfidence:
                    Step_LifeChange(slide: .confidence, progress: flow.progress, onBack: back, onContinue: advance)
                        .transition(screenTransition)

                case .lifeChangeSleep:
                    Step_LifeChange(slide: .sleep, progress: flow.progress, onBack: back, onContinue: advance)
                        .transition(screenTransition)

                case .lifeChangeLooksFeel:
                    Step_LifeChange(slide: .looksFeel, progress: flow.progress, onBack: back, onContinue: advance)
                        .transition(screenTransition)

                case .chapterMapping:
                    Step_Chapter_Mapping(onContinue: advance)
                        .transition(.opacity)

                case .goals:
                    Step_Goals(flow: flow, progress: flow.progress, onBack: back, onContinue: advance)
                        .transition(screenTransition)

                case .obstacles:
                    Step15_Obstacles(flow: flow, progress: flow.progress, onBack: back, onContinue: advance)
                        .transition(screenTransition)

                case .targetAreas:
                    Step_TargetAreas(flow: flow, progress: flow.progress, onBack: back, onContinue: advance)
                        .transition(screenTransition)

                case .motivation:
                    Step05_Motivation(flow: flow, progress: flow.progress, onBack: back, onContinue: advance)
                        .transition(screenTransition)

                case .age:
                    Step06_Age(flow: flow, progress: flow.progress, onBack: back, onContinue: advance)
                        .transition(screenTransition)

                case .gender:
                    Step07_Gender(flow: flow, progress: flow.progress, onBack: back, onContinue: advance)
                        .transition(screenTransition)

                case .height:
                    Step08_Height(flow: flow, progress: flow.progress, onBack: back, onContinue: advance)
                        .transition(screenTransition)

                case .weight:
                    Step09_Weight(flow: flow, progress: flow.progress, onBack: back, onContinue: advance)
                        .transition(screenTransition)

                case .experience:
                    Step11_Experience(flow: flow, progress: flow.progress, onBack: back, onContinue: advance)
                        .transition(screenTransition)

                case .targetFrequency:
                    Step13_TargetFrequency(flow: flow, progress: flow.progress, onBack: back, onContinue: advance)
                        .transition(screenTransition)

                case .trainingDays:
                    Step_TrainingDays(flow: flow, progress: flow.progress, onBack: back, onContinue: advance)
                        .transition(screenTransition)

                case .workoutTime:
                    Step_WorkoutTime(flow: flow, progress: flow.progress, onBack: back, onContinue: advance)
                        .transition(screenTransition)

                case .equipment:
                    Step14_Equipment(flow: flow, progress: flow.progress, onBack: back, onContinue: advance)
                        .transition(screenTransition)

                case .exerciseStyle:
                    Step_ExerciseStyle(flow: flow, progress: flow.progress, onBack: back, onContinue: advance)
                        .transition(screenTransition)

                case .sessionLength:
                    Step16_SessionLength(flow: flow, progress: flow.progress, onBack: back, onContinue: advance)
                        .transition(screenTransition)

                case .resultsSnapshot:
                    Step_ResultsSnapshot(flow: flow, progress: flow.progress, onBack: back, onContinue: advance)
                        .transition(screenTransition)

                case .diet:
                    Step17_Diet(flow: flow, progress: flow.progress, onBack: back, onContinue: advance)
                        .transition(screenTransition)

                case .sleep:
                    Step18_Sleep(flow: flow, progress: flow.progress, onBack: back, onContinue: advance)
                        .transition(screenTransition)

                case .stress:
                    Step19_Stress(flow: flow, progress: flow.progress, onBack: back, onContinue: advance)
                        .transition(screenTransition)

                case .priorAttempts:
                    Step20_PriorAttempts(flow: flow, progress: flow.progress, onBack: back, onContinue: advance)
                        .transition(screenTransition)

                case .commitment:
                    Step21_Commitment(flow: flow, progress: flow.progress, onBack: back, onContinue: advance)
                        .transition(screenTransition)

                case .name:
                    Step22_Name(flow: flow, progress: flow.progress, onBack: back, onContinue: advance)
                        .transition(screenTransition)

                case .notifications:
                    Step23_Notifications(flow: flow, progress: flow.progress, onBack: back, onContinue: advance)
                        .transition(screenTransition)

                case .chapterScan:
                    Step_Chapter_Scan(onContinue: advance)
                        .transition(.opacity)

                // MARK: Scan flow — single live-preview screen + review + analyze

                case .scanLive:
                    Step_ScanLive(
                        flow: flow,
                        progress: flow.progress,
                        onBack: back,
                        onCaptured: advance
                    )
                    .transition(.opacity)

                case .scanReview:
                    Step_ScanReview(
                        flow: flow,
                        progress: flow.progress,
                        onBack: back,
                        onRetake: { _ in
                            flow.capturedPhotos[.front] = nil
                            flow.jump(to: .scanLive)
                        },
                        onSubmit: advance
                    )
                    .transition(screenTransition)

                case .scanAnalyzing:
                    Step_ScanAnalyzing(flow: flow, onComplete: advance)
                        .transition(.opacity)

                // MARK: Post-scan reveals

                case .verdict:
                    Step_Verdict(flow: flow, onContinue: advance)
                        .transition(.opacity)

                case .appPainSolution:
                    Step_AppPainSolution(flow: flow, progress: flow.progress, onBack: back, onContinue: advance)
                        .transition(screenTransition)

                case .workoutPreviewDemo:
                    Step_WorkoutPreviewDemo(flow: flow, progress: flow.progress, onBack: back, onContinue: advance)
                        .transition(screenTransition)

                case .workoutLogDemo:
                    Step_WorkoutLogDemo(progress: flow.progress, onBack: back, onContinue: advance)
                        .transition(screenTransition)

                case .workoutRewardDemo:
                    Step_WorkoutRewardDemo(progress: flow.progress, onBack: back, onContinue: advance)
                        .transition(screenTransition)

                case .appRatingPrompt:
                    Step_AppRatingPrompt(progress: flow.progress, onBack: back, onContinue: advance)
                        .transition(screenTransition)

                case .trajectory:
                    Step28_Trajectory(flow: flow, progress: flow.progress, onBack: back, onContinue: advance)
                        .transition(screenTransition)

                case .obstacleFix:
                    Step_ObstacleFix(flow: flow, progress: flow.progress, onBack: back, onContinue: advance)
                        .transition(screenTransition)

                case .chapterPath:
                    Step_Chapter_Path(onContinue: advance)
                        .transition(.opacity)

                case .whyThisProgram:
                    Step_WhyThisProgram(flow: flow, progress: flow.progress, onBack: back, onContinue: advance)
                        .transition(screenTransition)

                case .socialProofGallery:
                    Step29_SocialProof(progress: flow.progress, onBack: back, onContinue: advance)
                        .transition(screenTransition)

                case .commitDay30:
                    Step_CommitVision(flow: flow, slide: .day30, progress: flow.progress, onBack: back, onContinue: advance)
                        .transition(screenTransition)

                case .commitDay90:
                    Step_CommitVision(flow: flow, slide: .day90, progress: flow.progress, onBack: back, onContinue: advance)
                        .transition(screenTransition)

                case .commitToday:
                    Step_CommitVision(flow: flow, slide: .today, progress: flow.progress, onBack: back, onContinue: advance)
                        .transition(screenTransition)

                case .planReady:
                    Step_PlanReady(flow: flow, progress: flow.progress, onBack: back, onContinue: advance)
                        .transition(screenTransition)

                case .paywall:
                    Step_Paywall(flow: flow, onUnlock: onComplete)
                        .transition(.opacity)
                }
            }
            .animation(.spring(response: 0.38, dampingFraction: 0.82), value: flow.currentStep)
        }
    }

    // MARK: Navigation helpers

    private func advance() { flow.advance() }
    private func back() { flow.back() }

    // Atmosphere scales 0.7 → 1.4 across onboarding. Early steps stay subtle so
    // the shared layer doesn't fight the content, late steps build pressure
    // going into the scan. Progress is 0...1 from the flow VM.
    private var atmosphereIntensity: Double {
        let p = flow.progress
        return 0.7 + 0.7 * max(0, min(1, p))
    }

    /// Retake the front scan. V1 is front-only — side/back become V1.1
    /// post-paywall unlocks.
    private func retakeFront() {
        flow.capturedPhotos[.front] = nil
        flow.jump(to: .scanLive)
    }

    /// Horizontal swipe feel: new slide comes in from the right, old exits left.
    /// Works cleanly now that `OnboardingScaffold` owns the shared chrome so
    /// only the content slot animates.
    private var screenTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
}

// MARK: - Inserted conversion steps

private struct Step_ResultsSnapshot: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    private var focusZone: String {
        flow.targetAreas.first?.displayName ?? L10n.onboarding("common.fullBody", defaultValue: "Full Body")
    }
    private var frequencyLabel: String {
        flow.targetFrequency?.displayName ?? L10n.onboarding("common.fourDaysPerWeek", defaultValue: "4 days / week")
    }
    private var sessionLabel: String {
        flow.sessionLength?.displayName ?? L10n.onboarding("common.fortyFiveMinutes", defaultValue: "45 minutes")
    }
    private var equipmentLabel: String {
        if flow.equipment.contains(.fullGym) {
            return L10n.onboarding("equipment.fullGym", defaultValue: "Full gym")
        }
        if flow.equipment.contains(.bodyweight), flow.equipment.count == 1 {
            return L10n.onboarding("equipment.bodyweight", defaultValue: "Bodyweight")
        }
        if flow.equipment.isEmpty {
            return L10n.onboarding("equipment.open", defaultValue: "Equipment open")
        }
        return L10n.onboarding("equipment.mixed", defaultValue: "Mixed equipment")
    }
    private var boostedAttributes: [AttributeKey] {
        AttributeKey.allCases.filter { flow.effectiveSeededAttributes.contains($0) }
    }
    private var starterLevels: [AttributeKey: Int] {
        AttributeKey.allCases.reduce(into: [:]) { result, key in
            result[key] = flow.effectiveSeededAttributes.contains(key) ? 3 : 1
        }
    }
    private var starterTiers: [AttributeKey: RankTitle] {
        AttributeKey.allCases.reduce(into: [:]) { result, key in
            result[key] = .initiate
        }
    }
    private var starterHex: [AttributeKey: Double] {
        starterLevels.reduce(into: [:]) { result, entry in
            result[entry.key] = flow.effectiveSeededAttributes.contains(entry.key) ? 24 : 8
        }
    }

    var body: some View {
        OnboardingScaffold(
            title: L10n.onboarding("resultsSnapshot.title", defaultValue: "Your starting point is set."),
            subtitle: L10n.onboarding("resultsSnapshot.subtitle", defaultValue: "Day Zero is marked. The climb starts from here."),
            progress: progress,
            primaryTitle: L10n.onboarding("resultsSnapshot.primary", defaultValue: "Start my arc"),
            primaryIcon: "arrow.right",
            hudStep: .resultsSnapshot,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.unbound.surface.opacity(0.18),
                                    Color.unbound.accent.opacity(0.08),
                                    Color.unbound.surface.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    TechGridBackground(opacity: 0.12)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(spacing: 14) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(L10n.onboarding("resultsSnapshot.entryMap", defaultValue: "ENTRY MAP"))
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                                    .tracking(1.4)
                                    .foregroundStyle(Color.unbound.accent)
                                Text(L10n.onboarding("common.rank.initiate", defaultValue: "INITIATE"))
                                    .font(.system(size: 34, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.unbound.textPrimary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                                    .fixedSize(horizontal: true, vertical: false)
                                Text(L10n.onboarding("resultsSnapshot.entryBody", defaultValue: "This is the first mark. Everything above it has to be earned."))
                                    .font(Font.unbound.bodyS)
                                    .foregroundStyle(Color.unbound.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer(minLength: 10)

                            TierBadge(tier: .initiate)
                                .frame(width: 92, height: 92)
                                .shadow(color: Color.unbound.accent.opacity(0.26), radius: 18)
                        }

                        HStack(alignment: .center, spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.unbound.accent.opacity(0.10))
                                    .frame(width: 118, height: 118)
                                    .blur(radius: 18)
                                AttributeHex(
                                    current: starterHex,
                                    peak: nil,
                                    levels: starterLevels,
                                    tiers: starterTiers,
                                    showLabels: true,
                                    radius: 48
                                )
                            }
                            .frame(width: 118, height: 118)

                            VStack(spacing: 9) {
                                mapMetric(
                                    label: L10n.onboarding("resultsSnapshot.metric.overallLevel", defaultValue: "OVERALL LVL"),
                                    value: L10n.onboardingFormat("common.level", defaultValue: "LVL %d", 0),
                                    tint: Color.unbound.accent
                                )
                                mapMetric(label: L10n.onboarding("common.focus", defaultValue: "FOCUS"), value: focusZone.uppercased(), tint: Color.unbound.warnOrange)
                                mapMetric(label: L10n.onboarding("resultsSnapshot.metric.starterBoost", defaultValue: "STARTER BOOST"), value: boostLabel, tint: Color.unbound.rankGreen)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(16)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 8) {
                    signalRow(
                        icon: "calendar",
                        label: L10n.onboarding("resultsSnapshot.signal.trainingRhythm", defaultValue: "Training rhythm"),
                        value: L10n.onboardingFormat("resultsSnapshot.signal.trainingRhythm.value", defaultValue: "%@ · %@", frequencyLabel, sessionLabel)
                    )
                    signalRow(icon: "dumbbell.fill", label: L10n.onboarding("resultsSnapshot.signal.availableTools", defaultValue: "Available tools"), value: equipmentLabel)
                    signalRow(icon: "hexagon.fill", label: L10n.onboarding("resultsSnapshot.signal.firstSpark", defaultValue: "First spark"), value: L10n.onboarding("resultsSnapshot.signal.firstSpark.value", defaultValue: "A tiny mark on the hex. Enough to begin."))
                    signalRow(icon: "flag.checkered", label: L10n.onboarding("resultsSnapshot.signal.nextGate", defaultValue: "Next gate"), value: L10n.onboarding("resultsSnapshot.signal.nextGate.value", defaultValue: "Show up. Clear the wall. Climb."))
                }

                infoCallout
            }
        }
    }

    private var boostLabel: String {
        let codes = boostedAttributes.prefix(2).map(\.shortCode)
        return codes.isEmpty ? L10n.onboarding("resultsSnapshot.boost.none", defaultValue: "NONE YET") : codes.joined(separator: " + ")
    }

    private var infoCallout: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "scope")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.unbound.accent)
                .padding(.top, 1)
            Text(L10n.onboarding("resultsSnapshot.callout", defaultValue: "The blank parts are the point. Your first sessions start turning this into something real."))
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surface.opacity(0.76))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private func mapMetric(label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(Color.unbound.textTertiary)
            Text(value)
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(tint.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(tint.opacity(0.30), lineWidth: 1)
        )
    }

    private func signalRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.unbound.accent)
                .frame(width: 18)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(Color.unbound.textTertiary)
                .frame(width: 92, alignment: .leading)
            Text(value)
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.unbound.surface.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle.opacity(0.85), lineWidth: 1)
        )
    }
}

private struct Step_PlanReady: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    private var sessionsPerWeek: Int {
        flow.targetFrequency?.numericCount ?? 4
    }

    private var sessionLengthLabel: String {
        flow.sessionLength?.displayName ?? L10n.onboarding("common.fortyFiveMinutes", defaultValue: "45 minutes")
    }

    private var planTitle: String {
        // TODO(Phase 17): wire to BuildIdentity once archetype is fully removed
        L10n.onboarding("common.arcOne", defaultValue: "ARC 1")
    }

    var body: some View {
        OnboardingScaffold(
            title: L10n.onboarding("planReady.title", defaultValue: "Your opening block is ready."),
            subtitle: L10n.onboarding("planReady.subtitle", defaultValue: "Start with honest standards. Use them to unlock the first 28-day Arc."),
            progress: progress,
            primaryTitle: L10n.onboarding("planReady.primary", defaultValue: "Unlock my training"),
            primaryIcon: "lock.open.fill",
            hudStep: .planReady,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            VStack(spacing: 12) {
                UnboundCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Text(L10n.onboarding("planReady.eyebrow", defaultValue: "BLOCK READY"))
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .tracking(1.1)
                                .foregroundStyle(Color.unbound.accent)
                            Spacer(minLength: 0)
                            Text(L10n.onboarding("planReady.generated", defaultValue: "GENERATED"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.unbound.textSecondary)
                        }

                        Text("CALIBRATION WEEK")
                            .font(Font.unbound.titleM)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)

                        OnboardingGeneratedArt(
                            candidateAssets: ["onboarding_path_protocol_dossier", "onboarding_plan_ready_hero", "body_unbound_front"],
                            fallbackSymbol: "figure.mixed.cardio",
                            tint: Color.unbound.accent
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 148)

                        HStack(spacing: 9) {
                            planStat(label: L10n.onboarding("planReady.stat.weekly", defaultValue: "WEEKLY"), value: L10n.onboardingFormat("common.timesPerWeek.compact", defaultValue: "%dx", sessionsPerWeek))
                            planStat(label: L10n.onboarding("planReady.stat.session", defaultValue: "SESSION"), value: sessionLengthLabel.uppercased())
                            planStat(label: L10n.onboarding("common.start", defaultValue: "START"), value: "DAY 1")
                        }

                        Rectangle()
                            .fill(Color.unbound.borderSubtle)
                            .frame(height: 0.5)

                        VStack(alignment: .leading, spacing: 7) {
                            workoutRow(index: 1, name: primaryWorkoutLabel)
                            workoutRow(index: 2, name: secondaryWorkoutLabel)
                        }
                    }
                }

                HStack(spacing: 8) {
                    insightChip(icon: "target", text: (flow.targetAreas.first?.displayName ?? L10n.onboarding("common.fullBody", defaultValue: "Full Body")).uppercased())
                    insightChip(icon: "flag.fill", text: (flow.goals.first?.displayName ?? L10n.onboarding("common.buildMuscle", defaultValue: "Build Muscle")).uppercased())
                    Spacer(minLength: 0)
                }

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.unbound.accent)
                        .padding(.top, 1)
                    Text(L10n.onboarding("planReady.callout", defaultValue: "You can start today. Unlock the calibration week, 28-day Arcs, workout logging, and profile progress that keeps moving with you."))
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.unbound.surface.opacity(0.76))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                )
            }
        }
    }

    private var primaryWorkoutLabel: String {
        if let area = flow.targetAreas.first {
            return L10n.onboardingFormat("planReady.workout.focus", defaultValue: "%@ Focus", area.displayName)
        }
        return L10n.onboarding("planReady.workout.upperFocus", defaultValue: "Upper Focus")
    }

    private var secondaryWorkoutLabel: String {
        // TODO(Phase 17): key this off BuildIdentity once archetype is fully removed
        return L10n.onboarding("planReady.workout.lowerCoreFoundation", defaultValue: "Lower + Core Foundation")
    }

    private func planStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.unbound.textTertiary)
            Text(value)
                .font(Font.unbound.monoS.weight(.bold))
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.unbound.surfaceElevated.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private func workoutRow(index: Int, name: String) -> some View {
        HStack(spacing: 10) {
            Text("\(index)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.unbound.accent)
                .frame(width: 18, height: 18)
                .background(
                    Circle().fill(Color.unbound.accent.opacity(0.16))
                )
            Text(name.uppercased())
                .font(Font.unbound.bodyS.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(Color.unbound.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
    }

    private func insightChip(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.unbound.accent)
            Text(text)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(Color.unbound.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(Color.unbound.surface.opacity(0.9))
        )
        .overlay(
            Capsule().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }
}

private struct OnboardingGeneratedArt: View {
    let candidateAssets: [String]
    let fallbackSymbol: String
    let tint: Color

    private var resolvedImage: UIImage? {
        for name in candidateAssets {
            if let image = UIImage(named: name) {
                return image
            }
        }
        return nil
    }

    var body: some View {
        Group {
            if let image = resolvedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.16), Color.unbound.surfaceElevated.opacity(0.95)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(tint.opacity(0.35), lineWidth: 1)
                    Image(systemName: fallbackSymbol)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(tint.opacity(0.9))
                }
            }
        }
        .shadow(color: tint.opacity(0.22), radius: 12)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }
}
