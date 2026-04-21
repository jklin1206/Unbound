import SwiftUI

struct HUDProgressBar: View {
    let currentStep: Int
    let totalSteps: Int
    let category: StepCategory

    private let tileCount: Int = 20

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow)
                .font(Font.unbound.monoS)
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textSecondary)

            HStack(spacing: 3) {
                ForEach(0..<tileCount, id: \.self) { idx in
                    tile(at: idx)
                }
            }
            .frame(height: 6)
        }
        .onChange(of: currentStep) { oldValue, newValue in
            let oldBucket = bucket(for: oldValue)
            let newBucket = bucket(for: newValue)
            if newBucket != oldBucket {
                UnboundHaptics.soft()
            }
        }
    }

    private var eyebrow: String {
        let n = String(format: "%02d", max(1, currentStep))
        let total = String(format: "%02d", max(1, totalSteps))
        return "STAGE \(n) / \(total) · \(category.displayName)"
    }

    private func bucket(for step: Int) -> Int {
        guard totalSteps > 0 else { return 0 }
        let clamped = max(0, min(step, totalSteps))
        return min(tileCount - 1, (clamped * tileCount) / max(1, totalSteps))
    }

    @ViewBuilder
    private func tile(at idx: Int) -> some View {
        let current = bucket(for: currentStep)
        let shape = ChamferedRectangle(inset: 2)

        if idx < current {
            shape
                .fill(Color.unbound.accent)
                .frame(height: 4)
        } else if idx == current {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                let p = 0.5 + 0.5 * (sin(t * 2.0) + 1.0) / 2.0
                shape
                    .fill(Color.unbound.accent)
                    .frame(height: 4)
                    .shadow(color: Color.unbound.accent.opacity(0.6 * p), radius: 6 * p)
            }
        } else {
            shape
                .stroke(Color.unbound.borderSubtle, lineWidth: 1)
                .frame(height: 4)
        }
    }
}

#Preview("Progress") {
    ZStack {
        Color.unbound.bg.ignoresSafeArea()
        VStack(spacing: 32) {
            HUDProgressBar(currentStep: 7, totalSteps: 40, category: .body)
            HUDProgressBar(currentStep: 12, totalSteps: 40, category: .training)
            HUDProgressBar(currentStep: 22, totalSteps: 40, category: .lifestyle)
            HUDProgressBar(currentStep: 38, totalSteps: 40, category: .commit)
        }
        .padding()
    }
}
