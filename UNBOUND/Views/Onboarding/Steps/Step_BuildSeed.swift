import SwiftUI

struct Step_BuildSeed: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            title: "You have more in you.",
            subtitle: "UNBOUND reads your goals and marks the first sparks. The rest comes from what you earn.",
            progress: progress,
            primaryTitle: "Continue",
            primaryEnabled: true,
            hudStep: .resultsSnapshot,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            VStack(spacing: 10) {
                ForEach(AttributeKey.allCases, id: \.self) { key in
                    chip(for: key)
                }
            }
            .padding(.top, 4)
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private func chip(for key: AttributeKey) -> some View {
        let isOn = flow.seededAttributes.contains(key)
        let atLimit = flow.seededAttributes.count >= 2 && !isOn

        Button {
            if isOn { flow.seededAttributes.remove(key) }
            else if !atLimit { flow.seededAttributes.insert(key) }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(key.shortCode)
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(isOn ? Color.unbound.accent : Color.unbound.textSecondary)
                    .frame(width: 44, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(key.displayName.uppercased())
                        .font(.system(size: 13, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(isOn ? Color.unbound.textPrimary : Color.unbound.textSecondary)
                    Text(key.trainsCopy)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.unbound.textTertiary)
                }
                Spacer()
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isOn ? Color.unbound.accent : Color.unbound.textTertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isOn ? Color.unbound.accent : Color.unbound.border, lineWidth: 1)
            )
            .opacity(atLimit ? 0.45 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(atLimit)
    }
}
