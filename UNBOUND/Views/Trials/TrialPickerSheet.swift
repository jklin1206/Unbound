import SwiftUI

// MARK: - TrialPickerSheet
//
// Bottom sheet that presents the 3 weekly trial cards as a horizontal
// swipeable TabView (.page style). User swipes between Aligned / Growth /
// Prestige cards then taps "COMMIT" to lock in their pick.
//
// The sheet does NOT dismiss itself — the parent is responsible for
// dismissing after `onPick` returns.

struct TrialPickerSheet: View {
    let cards: [TrialCard]
    let onPick: (TrialCard) -> Void

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
                        Spacer().frame(height: 20)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.unbound.bg)
    }

    // MARK: - Sub-views

    private var header: some View {
        VStack(spacing: 6) {
            Text("WEEKLY TRIAL")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(2.0)
                .foregroundStyle(Color.unbound.textTertiary)
            Text("Choose your path")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(Color.unbound.textPrimary)
            Text("One pick. Locks in Mon–Fri. Capstone window opens Saturday.")
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
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
            let tint = card.theme.tintColor
            Button {
                UnboundHaptics.medium()
                onPick(card)
                dismiss()
            } label: {
                HStack(spacing: 10) {
                    Text("COMMIT — \(card.displayName.uppercased())")
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

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 44))
                .foregroundStyle(Color.unbound.textTertiary)
            Text("No cards this week")
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
        selectedCard?.theme.tintColor ?? Color.unbound.accent
    }
}

// MARK: - Previews

#Preview("With cards") {
    TrialPickerSheet(
        cards: [
            TrialCard(
                id: "trial-W20-aligned",
                kind: .aligned,
                theme: .axis(.power),
                displayName: "Power Focus",
                blurb: "Double down on heavy compound work this week.",
                capstone: TrialCapstone(displayName: "Top-Set PR", description: "Hit a squat or deadlift PR.", evaluation: .manualClaim)
            ),
            TrialCard(
                id: "trial-W20-growth",
                kind: .growth,
                theme: .axis(.mobility),
                displayName: "Mobility Block",
                blurb: "Expose the gap. Add 10 min of targeted range-of-motion work each day.",
                capstone: TrialCapstone(displayName: "Flow Session", description: "Complete a 20-min unbroken mobility circuit.", evaluation: .manualClaim)
            ),
            TrialCard(
                id: "trial-W20-prestige",
                kind: .prestige,
                theme: .wildcard,
                displayName: "Open Circuit",
                blurb: "No axis bias. Pick one weakness and hammer it for 7 days.",
                capstone: TrialCapstone(displayName: "Circuit Finisher", description: "20-min AMRAP, 4 movements.", evaluation: .manualClaim)
            )
        ],
        onPick: { _ in }
    )
}
