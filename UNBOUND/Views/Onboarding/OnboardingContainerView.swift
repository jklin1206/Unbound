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
                            flow = OnboardingFlowViewModel(userService: services.user)
                        }
                }
            }

            #if DEBUG
            devSkipButton
                .padding(.top, 54)
                .padding(.trailing, 16)
            #endif
        }
    }

    // MARK: - Dev skip (DEBUG only)
    //
    // Grants full entitlement (dev unlock flag), marks calibration done, and
    // fires onComplete so the user lands directly on Home with every feature
    // — Coach included — immediately available. Useful for UI iteration.
    #if DEBUG
    @ViewBuilder
    private var devSkipButton: some View {
        Button {
            DevFlags.shared.unlockAllFeatures = true
            UserDefaults.standard.set(true, forKey: "unbound.calibration.completed")
            let gen = UIImpactFeedbackGenerator(style: .heavy)
            gen.impactOccurred()
            onComplete()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("DEV · SKIP")
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
                case .arc01Opening:
                    Step_Arc01_Opening(onBegin: advance)
                        .transition(.opacity)

                case .arc02Problem:
                    Step_Arc02_Problem(onContinue: advance)
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

                case .buildSeed:
                    Step_BuildSeed(flow: flow, progress: flow.progress, onBack: back, onContinue: advance)
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

                case .trajectory:
                    Step28_Trajectory(flow: flow, progress: flow.progress, onBack: back, onContinue: advance)
                        .transition(screenTransition)

                case .skillTreePreview:
                    Step_SkillTreePreview(flow: flow, progress: flow.progress, onBack: back, onContinue: advance)
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

                case .rpeTeach:
                    RPEOnboardingStep(onContinue: advance)
                        .transition(.opacity)

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

    private var baselineRank: String { flow.derivedRank }
    private var projectedRank90: String { advanceRank(flow.derivedRank, by: 2) }
    private var focusZone: String {
        flow.targetAreas.first?.displayName ?? "Full Body"
    }

    var body: some View {
        OnboardingScaffold(
            title: "Your baseline is mapped.",
            subtitle: "This is your current profile before protocol execution.",
            progress: progress,
            primaryTitle: "See how we fix it",
            primaryIcon: "arrow.right",
            hudStep: .resultsSnapshot,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            VStack(spacing: 12) {
                UnboundCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Text("RESULTS SNAPSHOT")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .tracking(1.1)
                                .foregroundStyle(Color.unbound.accent)
                            Spacer(minLength: 0)
                            Text("PRE-PROTOCOL")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.unbound.textSecondary)
                        }

                        HStack(alignment: .center, spacing: 14) {
                            OnboardingGeneratedArt(
                                candidateAssets: ["onboarding_results_snapshot_hero", "body_unbound_front"],
                                fallbackSymbol: "figure.strengthtraining.functional",
                                tint: Color.unbound.accent
                            )
                            .frame(width: 112, height: 190)

                            VStack(alignment: .leading, spacing: 9) {
                                snapshotPill(label: "CURRENT RANK", value: baselineRank, tint: rankTint(baselineRank))
                                snapshotPill(label: "FOCUS ZONE", value: focusZone.uppercased(), tint: Color.unbound.warnOrange)
                                snapshotPill(label: "90-DAY POTENTIAL", value: projectedRank90, tint: rankTint(projectedRank90))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                HStack(spacing: 8) {
                    miniTag(icon: "flame.fill", text: "\(flow.targetFrequency?.displayName ?? "4 days / week") target")
                    miniTag(icon: "timer", text: flow.sessionLength?.displayName ?? "45 minutes")
                }

                infoCallout
            }
        }
    }

    private var infoCallout: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.unbound.accent)
                .padding(.top, 1)
            Text("Most users at this baseline fail because their training isn't mapped to their exact profile. Yours is.")
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

    private func snapshotPill(label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(Color.unbound.textTertiary)
            Text(value)
                .font(Font.unbound.monoM.weight(.bold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tint.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(tint.opacity(0.30), lineWidth: 1)
        )
    }

    private func miniTag(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.unbound.accent)
            Text(text.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.7)
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

    private func advanceRank(_ rank: String, by amount: Int) -> String {
        let ladder = ["E", "D", "C", "B", "A", "S"]
        guard let idx = ladder.firstIndex(of: rank.uppercased()) else { return "B" }
        return ladder[min(ladder.count - 1, idx + amount)]
    }

    private func rankTint(_ rank: String) -> Color {
        switch rank.uppercased() {
        case "S": return Color.unbound.rankGold
        case "A": return Color.unbound.accent
        case "B": return Color.unbound.rankGreen
        case "C": return Color.unbound.rankAmber
        case "D": return Color.unbound.rankOrange
        default: return Color.unbound.rankRed
        }
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
        flow.sessionLength?.displayName ?? "45 minutes"
    }

    private var planTitle: String {
        // TODO(Phase 17): wire to BuildIdentity once archetype is fully removed
        "UNBOUND PROTOCOL"
    }

    var body: some View {
        OnboardingScaffold(
            title: "Your custom plan is ready.",
            subtitle: "Built from your profile, scan, and commitment inputs.",
            progress: progress,
            primaryTitle: "Unlock my plan",
            primaryIcon: "lock.open.fill",
            hudStep: .planReady,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            VStack(spacing: 12) {
                UnboundCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Text("PLAN READY")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .tracking(1.1)
                                .foregroundStyle(Color.unbound.accent)
                            Spacer(minLength: 0)
                            Text("GENERATED")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.unbound.textSecondary)
                        }

                        Text(planTitle)
                            .font(Font.unbound.titleM)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)

                        OnboardingGeneratedArt(
                            candidateAssets: ["onboarding_plan_ready_hero", "body_unbound_front"],
                            fallbackSymbol: "figure.mixed.cardio",
                            tint: Color.unbound.accent
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 148)

                        HStack(spacing: 9) {
                            planStat(label: "WEEKLY", value: "\(sessionsPerWeek)x")
                            planStat(label: "SESSION", value: sessionLengthLabel.uppercased())
                            planStat(label: "START", value: "ARC 1")
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
                    insightChip(icon: "target", text: (flow.targetAreas.first?.displayName ?? "Full Body").uppercased())
                    insightChip(icon: "flag.fill", text: (flow.goals.first?.displayName ?? "Build Muscle").uppercased())
                    Spacer(minLength: 0)
                }

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.unbound.accent)
                        .padding(.top, 1)
                    Text("You can start today. The paywall unlocks the full protocol, weekly progression, and coach guidance.")
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
            return "\(area.displayName) Focus"
        }
        return "Upper Focus"
    }

    private var secondaryWorkoutLabel: String {
        // TODO(Phase 17): key this off BuildIdentity once archetype is fully removed
        return "Lower + Core Foundation"
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
