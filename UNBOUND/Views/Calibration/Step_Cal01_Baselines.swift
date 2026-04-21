import SwiftUI

struct Step_Cal01_Baselines: View {
    @Bindable var vm: CalibrationViewModel
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        CalibrationScaffold(
            eyebrow: "CALIBRATION · 01 / 03",
            title: "Calibrate your baseline",
            subtitle: "What can you move today? Skip what you don't know.",
            primaryTitle: "Continue",
            onBack: onBack,
            onPrimary: onContinue
        ) {
            VStack(spacing: 14) {
                ForEach(Array(vm.baselines.enumerated()), id: \.element.id) { idx, baseline in
                    if let binding = vm.binding(for: baseline.id) {
                        HUDBaselineCard(index: idx, baseline: binding)
                    }
                }
            }
        }
    }
}
