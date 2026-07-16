import SwiftUI
import UIKit

struct ProgramRankAttemptReveal: Identifiable, Equatable {
    let id = UUID()
    let attemptSummary: String
    let tier: SkillTier
    let previousTier: SkillTier

    var isRankUp: Bool {
        tier > previousTier
    }
}

struct ProgramRankAttemptRevealOverlay: View {
    let reveal: ProgramRankAttemptReveal
    let onDismiss: () -> Void

    @State private var isPresented = false
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var tint: Color {
        reveal.tier.rewardTextTint
    }

    var body: some View {
        ZStack {
            revealBackdrop
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(Color.unbound.textSecondary)
                            .frame(width: 42, height: 42)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss rank result")
                }
                .padding(.top, 24)
                .padding(.horizontal, 20)

                Spacer(minLength: 14)

                ZStack {
                    revealGlow
                    rankBadge
                }
                .frame(height: 238)
                .scaleEffect(isPresented ? 1 : 0.82)
                .opacity(isPresented ? 1 : 0)

                VStack(spacing: 10) {
                    Text(reveal.isRankUp ? "NEW BEST" : "THIS ATTEMPT")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(2.4)
                        .foregroundStyle(reveal.isRankUp ? tint : Color.unbound.textTertiary)

                    Text(reveal.tier.displayName.uppercased())
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundStyle(tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.52)
                        .shadow(color: tint.opacity(0.3), radius: 18)

                    Text(reveal.attemptSummary)
                        .font(Font.unbound.titleS.weight(.black))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .monospacedDigit()
                }
                .padding(.horizontal, 24)
                .offset(y: isPresented ? 0 : 12)
                .opacity(isPresented ? 1 : 0)

                Spacer(minLength: 20)

                revealAction
                    .opacity(isPresented ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.76)) {
                isPresented = true
            }
            if !reduceMotion {
                withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                    pulse = true
                }
            }
        }
    }

    private var revealBackdrop: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    Color.unbound.bg,
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(tint.opacity(0.18))
                .blur(radius: 72)
                .frame(width: 280, height: 280)
                .offset(y: -120)
        }
    }

    private var revealGlow: some View {
        ZStack {
            // Living light behind the badge — breathing bloom + landing shockwave.
            RankRevealBloom(tint: tint, active: isPresented, badgeSize: 196)

            Circle()
                .stroke(tint.opacity(pulse ? 0 : 0.38), lineWidth: 1)
                .frame(width: 210, height: 210)
                .scaleEffect(pulse ? 1.38 : 0.86)
                .opacity(pulse ? 0 : 1)
        }
    }

    private var rankBadge: some View {
        Image(reveal.tier.assetName)
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(width: 188, height: 188)
            .shadow(color: tint.opacity(0.35), radius: 28, y: 8)
            .rotationEffect(.degrees(isPresented ? 0 : -7))
    }

    private var revealAction: some View {
        Button {
            UnboundHaptics.medium()
            onDismiss()
        } label: {
            HStack(spacing: 10) {
                Text("Continue")
                    .font(Font.unbound.bodyLStrong)
                    .tracking(0.2)
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(Color.unbound.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                ZStack {
                    Color.unbound.surfaceElevated
                    Rectangle().fill(.thinMaterial).opacity(0.18)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(tint.opacity(0.72), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.45), radius: 14, y: 8)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background(
            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(0), location: 0),
                    .init(color: Color.black, location: 0.2),
                    .init(color: Color.black, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
