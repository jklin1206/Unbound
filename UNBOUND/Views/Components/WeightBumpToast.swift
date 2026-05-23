import SwiftUI

struct WeightBumpToastModifier: ViewModifier {
    @State private var event: ProgressionAdvance?
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let event, visible {
                    WeightBumpToast(event: event)
                        .padding(.top, 12)
                        .padding(.horizontal, 20)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(20)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: visible)
            .onReceive(NotificationCenter.default.publisher(for: .progressionAdvanced)) { note in
                guard let incoming = note.userInfo?["event"] as? ProgressionAdvance else { return }
                present(incoming)
            }
    }

    private func present(_ incoming: ProgressionAdvance) {
        event = incoming
        UnboundHaptics.success()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            visible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeOut(duration: 0.35)) {
                visible = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                if !visible { event = nil }
            }
        }
    }
}

struct WeightBumpToast: View {
    let event: ProgressionAdvance
    @AppStorage(WeightPlatePolicy.unitDefaultsKey) private var weightUnitRaw = TrainingWeightUnit.localeDefault.rawValue

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.unbound.impact)
                .shadow(color: Color.unbound.impact.opacity(0.6), radius: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.displayName)
                    .font(Font.unbound.bodyLStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(formattedWeight(event.newWeightKg) + " " + weightUnit.shortLabel)
                        .font(Font.unbound.monoS)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text("+\(formattedDelta(event.incrementKg)) \(weightUnit.shortLabel)")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.impact)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(Color.unbound.impact.opacity(0.15))
                        )
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.surface.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.unbound.impact.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: Color.unbound.impact.opacity(0.35), radius: 22, x: 0, y: 6)
    }

    private var weightUnit: TrainingWeightUnit {
        TrainingWeightUnit(rawValue: weightUnitRaw) ?? .localeDefault
    }

    private func formattedWeight(_ kilograms: Double) -> String {
        WeightPlatePolicy.formatLoggedWeight(kilograms, unit: weightUnit)
    }

    private func formattedDelta(_ kilograms: Double) -> String {
        WeightPlatePolicy.formatDeltaWeight(kilograms, unit: weightUnit)
    }
}

extension View {
    func weightBumpToast() -> some View {
        modifier(WeightBumpToastModifier())
    }
}
