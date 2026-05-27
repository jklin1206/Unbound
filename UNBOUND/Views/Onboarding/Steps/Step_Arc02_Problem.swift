import SwiftUI

struct Step_Arc02_Problem: View {
    let onContinue: () -> Void

    @State private var profileIn: Bool = false
    @State private var copyIn: Bool = false

    private let dormantLevels: [AttributeKey: Int] = Dictionary(uniqueKeysWithValues: AttributeKey.allCases.map { ($0, 1) })
    private let dormantTiers: [AttributeKey: RankTitle] = Dictionary(uniqueKeysWithValues: AttributeKey.allCases.map { ($0, .initiate) })
    private let dormantHex: [AttributeKey: Double] = Dictionary(uniqueKeysWithValues: AttributeKey.allCases.map { ($0, 8.0) })

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            AnimeBackdrop(variant: .desaturated, intensity: 0.94)
                .ignoresSafeArea()
            TechGridBackground(opacity: 0.12)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 42)

                dormantProfileCard
                    .padding(.horizontal, 20)
                    .opacity(profileIn ? 1 : 0)
                    .offset(y: profileIn ? 0 : 18)

                Spacer(minLength: 16)

                VStack(spacing: 12) {
                    Text(L10n.onboarding("arcProblem.title", defaultValue: "Your profile is still unclaimed."))
                        .font(Font.unbound.titleL)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .multilineTextAlignment(.center)
                        .tracking(0.2)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(L10n.onboarding("arcProblem.subtitle", defaultValue: "The potential is there. It just needs a system that turns training into proof."))
                        .font(Font.unbound.bodyM)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 28)
                .opacity(copyIn ? 1 : 0)
                .offset(y: copyIn ? 0 : 12)

                HStack(spacing: 8) {
                    mutedTag(L10n.onboarding("arcProblem.tag.noMap", defaultValue: "NO MAP"))
                    mutedTag(L10n.onboarding("arcProblem.tag.noRanks", defaultValue: "NO RANKS"))
                    mutedTag(L10n.onboarding("arcProblem.tag.noProof", defaultValue: "NO PROOF"))
                }
                .padding(.top, 12)
                .opacity(copyIn ? 1 : 0)

                Spacer().frame(height: 24)

                UnboundButton(title: L10n.onboarding("common.continue", defaultValue: "Continue"), icon: "arrow.right", action: onContinue)
                    .opacity(copyIn ? 1 : 0)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
            }
        }
        .statusBarHidden()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            withAnimation(.spring(response: 0.62, dampingFraction: 0.84).delay(0.1)) {
                profileIn = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.55)) {
                copyIn = true
            }
        }
    }

    private var dormantProfileCard: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.onboarding("arcProblem.eyebrow", defaultValue: "DAY ZERO PROFILE"))
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(Color.unbound.accent)
                    Text(L10n.onboarding("arcProblem.profileName", defaultValue: "UNCLAIMED"))
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .tracking(0)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)
                    Text(L10n.onboarding("arcProblem.profileHandle", defaultValue: "@PLAYER"))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(Color.unbound.textTertiary)
                }

                Spacer(minLength: 8)

                Image(RankTitle.initiate.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 54, height: 54)
                    .opacity(0.88)
                    .shadow(color: Color.unbound.textSecondary.opacity(0.18), radius: 10)
            }

            ZStack {
                Circle()
                    .fill(Color.unbound.accent.opacity(0.08))
                    .frame(width: 190, height: 190)
                    .blur(radius: 24)
                AttributeHex(
                    current: dormantHex,
                    peak: nil,
                    levels: dormantLevels,
                    tiers: dormantTiers,
                    showLabels: true,
                    labelVariant: .profile,
                    radius: 68
                )
                .padding(.horizontal, 40)
                .padding(.vertical, 40)
            }
            .frame(height: 212)

            HStack(spacing: 10) {
                profileMetric(label: L10n.onboarding("arcProblem.metric.rank", defaultValue: "RANK"), value: L10n.onboarding("common.rank.initiate", defaultValue: "INITIATE"))
                profileMetric(label: L10n.onboarding("arcProblem.metric.hex", defaultValue: "HEX"), value: L10n.onboarding("arcProblem.metric.hex.value", defaultValue: "LOCKED"))
                profileMetric(label: L10n.onboarding("arcProblem.metric.arc", defaultValue: "ARC"), value: L10n.onboarding("arcProblem.metric.arc.value", defaultValue: "0%"))
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.surface.opacity(0.76))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle.opacity(0.75), lineWidth: 1)
        )
    }

    private func profileMetric(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(Color.unbound.textTertiary)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(0.4)
                .foregroundStyle(Color.unbound.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.bg.opacity(0.52))
        )
    }

    private func mutedTag(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .tracking(0.9)
            .foregroundStyle(Color.unbound.textTertiary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(Color.unbound.surface.opacity(0.75))
            )
            .overlay(
                Capsule().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
            )
    }
}

#Preview {
    Step_Arc02_Problem(onContinue: {})
}
