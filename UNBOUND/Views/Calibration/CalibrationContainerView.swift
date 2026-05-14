import SwiftUI

struct CalibrationContainerView: View {
    let onComplete: () -> Void

    @EnvironmentObject var services: ServiceContainer
    @State private var vm: CalibrationViewModel?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let vm {
                router(vm: vm)
            } else if isLoading {
                ZStack {
                    Color.unbound.bg.ignoresSafeArea()
                    ProgressView()
                        .tint(Color.unbound.accent)
                }
            } else {
                ZStack { Color.unbound.bg.ignoresSafeArea() }
            }
        }
        .task {
            await bootstrap()
        }
    }

    @ViewBuilder
    private func router(vm: CalibrationViewModel) -> some View {
        ZStack {
            switch vm.currentStep {
            case .intro:
                Step_Cal00_Intro(onContinue: { vm.advance() })
                    .transition(.opacity)
            case .baselines:
                Step_Cal01_Baselines(
                    vm: vm,
                    onBack: { vm.back() },
                    onContinue: { vm.advance() }
                )
                .transition(.opacity)
            case .preferences:
                Step_Cal02_Preferences(
                    vm: vm,
                    onBack: { vm.back() },
                    onContinue: { vm.advance() }
                )
                .transition(.opacity)
            case .custom:
                Step_Cal03_Custom(
                    vm: vm,
                    onBack: { vm.back() },
                    onContinue: { vm.advance() }
                )
                .transition(.opacity)
            case .complete:
                Step_Cal04_Complete(onContinue: {
                    Task {
                        await vm.finish()
                        onComplete()
                    }
                })
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: vm.currentStep)
    }

    @MainActor
    private func bootstrap() async {
        guard vm == nil else { return }
        let userId = services.auth.currentUserId ?? "anonymous"

        var equipment: Set<Equipment> = [.bodyweight]
        var experience: Experience? = nil

        if let profile = try? await services.user.fetchProfile(userId: userId) {
            equipment = Set(profile.equipment ?? [.bodyweight])
            experience = profile.experience
        }

        vm = CalibrationViewModel(
            userId: userId,
            equipment: equipment,
            experience: experience,
            useMetricWeight: false,
            calibrationService: services.calibration,
            preferenceService: services.exercisePreference
        )
        isLoading = false
    }
}
