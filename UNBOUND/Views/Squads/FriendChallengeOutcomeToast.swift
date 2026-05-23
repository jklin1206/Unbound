// UNBOUND/Views/Squads/FriendChallengeOutcomeToast.swift
//
// Bottom-of-screen toast fired when `.friendChallengeExpired` is posted.
// Follows the same pattern as TrialCapstoneToast — slide up, hold, fade out.
//
// Usage:
//   .friendChallengeOutcomeToast()
//
// Beat timeline (~3.2s total):
//   0.0-0.45s  slide up + opacity in, heavy haptic
//   0.45-2.8s  hold with subtle pulse on outcome label
//   2.8-3.2s   fade + slide out
import SwiftUI

struct FriendChallengeOutcomeToast: View {
    let challenge: FriendChallenge
    let currentUserId: UUID
    let opponentName: String
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var present: Bool = false
    @State private var pulse: Bool = false
    @State private var haptic: Int = 0

    private var isWinner: Bool { challenge.winnerUserId == currentUserId }
    private var tint: Color { isWinner ? Color.unbound.accent : Color.unbound.textSecondary }
    private var outcomeLabel: String { isWinner ? "You won" : "\(opponentName) won" }
    private var outcomeIcon: String { isWinner ? "trophy.fill" : "flag.fill" }

    var body: some View {
        HStack(spacing: 14) {
            // Outcome icon circle
            ZStack {
                Circle()
                    .fill(tint.opacity(0.18))
                    .frame(width: 40, height: 40)
                Circle()
                    .strokeBorder(tint, lineWidth: 1)
                    .frame(width: 40, height: 40)
                Image(systemName: outcomeIcon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .scaleEffect(pulse ? 1.06 : 1.0)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(challenge.kind.displayName.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary ?? Color.unbound.textSecondary)
                    .lineLimit(1)
                Text(outcomeLabel)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
            }

            Spacer(minLength: 12)

            // Score
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(challenge.challengerProgress)–\(challenge.challengedProgress)")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundStyle(tint)
                Text("FINAL")
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(Color.unbound.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.surfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [tint.opacity(0.15), .clear],
                                center: .leading,
                                startRadius: 8,
                                endRadius: 200
                            )
                        )
                        .blendMode(.screen)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(tint.opacity(0.28), lineWidth: 1)
                )
                .shadow(color: tint.opacity(0.22), radius: 16, y: -5)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .opacity(present ? 1 : 0)
        .offset(y: present ? 0 : 60)
        .sensoryFeedback(.impact(weight: .heavy), trigger: haptic)
        .contentShape(Rectangle())
        .onTapGesture { dismiss(animated: true) }
        .task { await runSequence() }
    }

    // MARK: - Timing

    private func runSequence() async {
        if reduceMotion {
            present = true
            haptic &+= 1
            try? await Task.sleep(nanoseconds: 2_800_000_000)
            onDismiss()
            return
        }

        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            present = true
        }
        haptic &+= 1

        withAnimation(.easeInOut(duration: 1.0).repeatCount(2, autoreverses: true)) {
            pulse = true
        }

        try? await Task.sleep(nanoseconds: 2_800_000_000)
        dismiss(animated: true)
    }

    private func dismiss(animated: Bool) {
        if animated {
            withAnimation(.easeIn(duration: 0.35)) {
                present = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: onDismiss)
        } else {
            onDismiss()
        }
    }
}

// MARK: - Modifier

private struct FriendChallengeOutcomeToastModifier: ViewModifier {
    @EnvironmentObject var services: ServiceContainer
    @State private var pendingChallenge: FriendChallenge?
    @State private var opponentName: String = "Opponent"

    private var currentUserId: UUID? {
        services.auth.currentUserId.flatMap(UUID.init)
    }

    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content
            if let challenge = pendingChallenge, let me = currentUserId {
                FriendChallengeOutcomeToast(
                    challenge: challenge,
                    currentUserId: me,
                    opponentName: opponentName,
                    onDismiss: { pendingChallenge = nil }
                )
                .id(challenge.id)
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .friendChallengeExpired)) { note in
            guard let challenge = note.object as? FriendChallenge else { return }
            // opponentName resolved at call site; fallback to "Opponent" here
            pendingChallenge = challenge
        }
    }
}

extension View {
    /// Overlay a FriendChallengeOutcomeToast at the bottom of the view
    /// when a friend challenge expires. Listens for `.friendChallengeExpired`.
    func friendChallengeOutcomeToast() -> some View {
        modifier(FriendChallengeOutcomeToastModifier())
    }
}

// MARK: - Preview

#Preview("Winner") {
    let me = UUID()
    let opponent = UUID()
    ZStack {
        Color.unbound.bg.ignoresSafeArea()
        FriendChallengeOutcomeToast(
            challenge: FriendChallenge(
                id: UUID(),
                challengerId: me,
                challengedId: opponent,
                squadId: UUID(),
                kind: .mostSessions,
                startedAt: .now,
                expiresAt: .now,
                acceptedAt: Date(),
                challengerProgress: 6,
                challengedProgress: 4,
                winnerUserId: me
            ),
            currentUserId: me,
            opponentName: "Toji",
            onDismiss: {}
        )
        .frame(maxHeight: .infinity, alignment: .bottom)
    }
    .environmentObject(ServiceContainer.mock)
}
