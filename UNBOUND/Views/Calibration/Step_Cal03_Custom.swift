import SwiftUI

struct Step_Cal03_Custom: View {
    @Bindable var vm: CalibrationViewModel
    let onBack: () -> Void
    let onContinue: () -> Void

    @State private var showingBuilder = false

    var body: some View {
        CalibrationScaffold(
            eyebrow: "CALIBRATION · 03 / 03",
            title: "Have a lift we don't?",
            subtitle: "Add it. We'll program around it.",
            primaryTitle: vm.didAddCustom ? "Continue" : "Add custom exercise",
            onBack: onBack,
            onPrimary: {
                if vm.didAddCustom {
                    onContinue()
                } else {
                    UnboundHaptics.medium()
                    showingBuilder = true
                }
            }
        ) {
            VStack(spacing: 18) {
                summaryCard

                Button {
                    UnboundHaptics.soft()
                    onContinue()
                } label: {
                    Text(vm.didAddCustom ? "Skip — I'm done" : "No thanks, continue")
                        .font(Font.unbound.monoS)
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showingBuilder) {
            CustomExerciseBuilderView(onSaved: { _ in
                vm.didAddCustom = true
            })
        }
    }

    private var summaryCard: some View {
        HUDPanel(isActive: vm.didAddCustom, pulse: false) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: vm.didAddCustom ? "checkmark.seal.fill" : "sparkles")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.unbound.accent)
                    Text(vm.didAddCustom ? "LIFT LOCKED" : "OPTIONAL")
                        .font(Font.unbound.monoS)
                        .tracking(2.0)
                        .foregroundStyle(Color.unbound.accent)
                    Spacer()
                }
                Text(vm.didAddCustom
                    ? "Your custom exercise is slotted into the program."
                    : "A signature lift you already own — Zercher, atlas carry, landmine press, whatever."
                )
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
