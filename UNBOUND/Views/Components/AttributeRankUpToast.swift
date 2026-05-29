// UNBOUND/Views/Components/AttributeRankUpToast.swift
import SwiftUI

// MARK: - AttributeRankUpToast
//
// Cinematic-asymmetry rule:
//   .tier    → this toast, accent border + soft glow
//   .aTier   → this toast, impact border + bright glow (visual differentiation)
//
// .aTier crossings now ALSO fire the chain-shatter cinematic via a
// synthesized .rankAdvanced notification. RankUpCinematicPresenter
// (sub-project #2 Phase 2c) reads BuildIdentity from AttributeProfile so
// it's safe to invoke for an attribute-axis crossing. The toast still
// fires too for the immediate stack-near-the-top affordance — both run.

struct AttributeRankUpToast: ViewModifier {
    @State private var pending: AttributeRankUpEvent?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let pending {
                    toastView(for: pending)
                        .padding(.top, 64)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .attributeRankUp)) { note in
                guard let event = note.object as? AttributeRankUpEvent else { return }
                switch event.level {
                case .tier:
                    show(event)
                case .aTier:
                    show(event)
                    // Also fire chain-shatter cinematic for A-tier crossings.
                    // Synth a RankAdvance from the attribute event so the
                    // existing RankUpCinematicPresenter handles it.
                    let advance = RankAdvance(
                        userId: "current",
                        exerciseKey: event.axis.rawValue,
                        displayName: event.axis.buildVocab,
                        fromRank: event.fromTitle,
                        toRank: event.toTitle,
                        at: event.timestamp
                    )
                    NotificationCenter.default.post(
                        name: .rankAdvanced,
                        object: nil,
                        userInfo: ["event": advance]
                    )
                }
            }
    }

    @ViewBuilder
    private func toastView(for event: AttributeRankUpEvent) -> some View {
        HStack(spacing: 10) {
            Image(event.toTitle.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.axis.shortCode)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(Color.unbound.accent)
                Text(event.toTitle.displayName.uppercased())
                    .font(.system(size: 14, weight: .heavy))
                    .tracking(0.8)
                    .foregroundStyle(Color.unbound.textPrimary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(borderColor(for: event.level), lineWidth: 1)
        )
        .shadow(color: glowColor(for: event.level), radius: 12)
    }

    private func borderColor(for level: AttributeRankUpEvent.Level) -> Color {
        // impact = cinematic violet; falls back to accent if token absent (confirmed present).
        level == .aTier ? Color.unbound.impact : Color.unbound.accent
    }

    private func glowColor(for level: AttributeRankUpEvent.Level) -> Color {
        level == .aTier ? Color.unbound.accent.opacity(0.6) : Color.unbound.accent.opacity(0.25)
    }

    private func show(_ event: AttributeRankUpEvent) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            pending = event
        }
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) { pending = nil }
            }
        }
    }
}

extension View {
    func attributeRankUpToast() -> some View {
        modifier(AttributeRankUpToast())
    }
}
