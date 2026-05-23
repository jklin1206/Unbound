import SwiftUI

struct WhyThisProgramView: View {
    let rationale: ProgramRationale
    var onDismiss: (() -> Void)? = nil

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    hero
                    summaryBlock
                    decisionList

                    if onDismiss != nil {
                        Spacer().frame(height: 8)
                        primaryAction
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                appeared = true
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("WHY THIS PROGRAM")
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.accent)

                Text("\(rationale.decisions.count) DECISIONS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(0.9)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(Color.unbound.surface.opacity(0.9))
                    )
                    .overlay(
                        Capsule().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                    )
            }

            Text(rationale.headline)
                .font(Font.unbound.titleL)
                .foregroundStyle(Color.unbound.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    private var summaryBlock: some View {
        Text(rationale.summaryCopy)
            .font(Font.unbound.bodyL)
            .foregroundStyle(Color.unbound.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
    }

    private var decisionList: some View {
        VStack(spacing: 12) {
            ForEach(Array(rationale.decisions.enumerated()), id: \.element.id) { (idx, decision) in
                DecisionCard(decision: decision, index: idx)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animation(
                        .spring(response: 0.55, dampingFraction: 0.82).delay(Double(idx) * 0.06),
                        value: appeared
                    )
            }
        }
    }

    private var primaryAction: some View {
        UnboundButton(
            title: "Got it",
            variant: .primary,
            isEnabled: true,
            action: { onDismiss?() }
        )
    }
}

// MARK: - Decision card

private struct DecisionCard: View {
    let decision: ProgramRationale.Decision
    let index: Int

    var body: some View {
        UnboundCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.unbound.accent.opacity(0.12))
                        Image(systemName: decision.iconSystemName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.unbound.accent)
                    }
                    .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("INPUT \(index + 1)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(1.0)
                            .foregroundStyle(Color.unbound.textTertiary)

                        Text(decision.inputSummary.uppercased())
                            .font(Font.unbound.captionS.weight(.bold))
                            .tracking(1.1)
                            .foregroundStyle(Color.unbound.textSecondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }

                Rectangle()
                    .fill(Color.unbound.borderSubtle)
                    .frame(height: 0.5)

                VStack(alignment: .leading, spacing: 6) {
                    Text("PROGRAM DECISION")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text(decision.decisionApplied)
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

#Preview {
    WhyThisProgramView(
        rationale: ProgramRationale(
            headline: "Built for you, Justin.",
            summaryCopy: "4 bodyweight sessions a week, 45 minutes each, hypertrophy-biased — time-efficient because you said busy schedule was your biggest blocker.",
            decisions: [
                .init(inputSummary: "SLEEPER archetype", decisionApplied: "Bodyweight-first progressions: pushup → pike → archer. Every lift has a ladder.", iconSystemName: "figure.strengthtraining.functional"),
                .init(inputSummary: "4 days/week · 45 minutes", decisionApplied: "Upper / lower split — each zone recovers while the other works.", iconSystemName: "calendar"),
                .init(inputSummary: "Goal: Build muscle", decisionApplied: "Rep ranges: 8–12 on compounds, 10–12 on accessories.", iconSystemName: "figure.strengthtraining.traditional"),
                .init(inputSummary: "Time is your biggest obstacle", decisionApplied: "Each session built for 45 minutes. No fluff — drop sets, straight to work.", iconSystemName: "timer"),
                .init(inputSummary: "Sleep quality: 4/10", decisionApplied: "Starting Arc 1 at RPE 6 — intensity climbs as your recovery stabilizes.", iconSystemName: "moon.zzz"),
                .init(inputSummary: "Bodyweight only", decisionApplied: "Every movement has a bodyweight variant with a progression path — no gym required.", iconSystemName: "figure.strengthtraining.functional")
            ]
        ),
        onDismiss: {}
    )
}
