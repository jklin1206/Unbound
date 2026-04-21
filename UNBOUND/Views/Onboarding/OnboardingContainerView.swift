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

                case .archetype:
                    Step04_PickArchetype(flow: flow, progress: flow.progress, onBack: back, onContinue: advance)
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
