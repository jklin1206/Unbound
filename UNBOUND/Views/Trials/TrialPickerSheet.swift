import SwiftUI

// MARK: - TrialPickerSheet
//
// Bottom sheet that presents the 3 weekly Binding Vow cards as a horizontal
// swipeable TabView (.page style).
//
// The sheet does NOT dismiss itself — the parent is responsible for
// dismissing after `onPick` returns.

struct TrialPickerSheet: View {
    let cards: [TrialCard]
    let onPick: (TrialCard) -> Void
    var onSkip: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var selectedIndex: Int = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Color.unbound.bg.ignoresSafeArea()

                if cards.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        header
                        cardPager
                        pageIndicator
                        commitButton
                        skipButton
                        Spacer().frame(height: 20)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.unbound.bg)
    }

    // MARK: - Sub-views

    private var header: some View {
        VStack(spacing: 6) {
            Text("BINDING VOW")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(2.0)
                .foregroundStyle(Color.unbound.textTertiary)
            Text("Choose your vow")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(Color.unbound.textPrimary)
            Text("Log toward the target all week — hit it and the vow seals.")
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
        .padding(.top, 24)
        .padding(.bottom, 20)
    }

    private var cardPager: some View {
        TabView(selection: $selectedIndex) {
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                TrialCardView(card: card)
                    .padding(.horizontal, 20)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 480)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: selectedIndex)
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<cards.count, id: \.self) { index in
                Capsule()
                    .fill(index == selectedIndex
                          ? currentTint
                          : Color.unbound.borderSubtle)
                    .frame(width: index == selectedIndex ? 20 : 7, height: 7)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedIndex)
            }
        }
        .padding(.top, 14)
        .padding(.bottom, 20)
    }

    @ViewBuilder
    private var commitButton: some View {
        if let card = selectedCard {
            let tint = card.lane.tintColor
            Button {
                UnboundHaptics.medium()
                onPick(card)
                dismiss()
            } label: {
                HStack(spacing: 10) {
                    Text("BIND - \(card.displayName.uppercased())")
                        .font(Font.unbound.bodyMStrong)
                        .tracking(1.2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(tint)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                )
                .shadow(color: tint.opacity(0.30), radius: 18, y: 8)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private var skipButton: some View {
        if let onSkip {
            Button {
                UnboundHaptics.soft()
                onSkip()
                dismiss()
            } label: {
                Text("Skip this week")
                    .font(Font.unbound.bodyS.weight(.semibold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 44))
                .foregroundStyle(Color.unbound.textTertiary)
            Text("No vows this week")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.unbound.textPrimary)
            Text("Pull to refresh or wait for the next week rollover.")
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private var selectedCard: TrialCard? {
        guard cards.indices.contains(selectedIndex) else { return cards.first }
        return cards[selectedIndex]
    }

    private var currentTint: Color {
        selectedCard?.lane.tintColor ?? Color.unbound.accent
    }
}

// MARK: - Previews

#Preview("With cards") {
    TrialPickerSheet(
        cards: [
            TrialCard(
                id: "weekly-vow-W20-recovery",
                lane: .recovery,
                bet: .small,
                displayName: "Iron Reset",
                blurb: "A low-day reset that protects recovery.",
                target: VowTarget(count: 1, noun: "recovery reset")
            ),
            TrialCard(
                id: "weekly-vow-W20-fuel",
                lane: .fuel,
                bet: .medium,
                displayName: "Fuel Anchor",
                blurb: "Hit your fuel anchors this week.",
                target: VowTarget(count: 3, noun: "fuel anchor")
            ),
            TrialCard(
                id: "weekly-vow-W20-engine",
                lane: .engine,
                bet: .large,
                displayName: "Engine Build",
                blurb: "A dedicated weekend conditioning push.",
                target: VowTarget(count: 2, noun: "engine session")
            )
        ],
        onPick: { _ in }
    )
}
