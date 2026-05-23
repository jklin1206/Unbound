import SwiftUI
import UIKit

// MARK: - RewardShareCard
//
// 9:16 portrait card rendered to UIImage for sharing on social.
// Different layouts based on what's celebrated:
//   - Rank-up: hero rank title + skill (cinematic backdrop for top tiers)
//   - First-set: skill + "JOURNEY BEGINS"
//   - PR: trophy + value + skill
//   - Badge: badge art + title
//
// Reuses RewardSummary so the on-screen celebration and the shareable
// asset stay perfectly in sync — there is no separate authoring surface.

struct RewardShareCard: View {
    let summary: RewardSummary

    var body: some View {
        ZStack {
            // Backdrop — rank-tier cosmetic for cinematic moments,
            // brand violet bloom otherwise.
            backdropLayer

            VStack(spacing: 28) {
                // Brand mark
                Text("UNBOUND")
                    .font(.system(size: 22, weight: .black, design: .default))
                    .tracking(6)
                    .foregroundStyle(Color.white.opacity(0.85))

                Spacer(minLength: 0)

                hero

                Spacer(minLength: 0)

                // Footer copy
                VStack(spacing: 8) {
                    Text(footerKicker.uppercased())
                        .font(.system(size: 12, weight: .heavy, design: .monospaced))
                        .tracking(2.4)
                        .foregroundStyle(Color.unbound.accent)
                    Text("@unbound.app")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.55))
                }
            }
            .padding(.vertical, 60)
            .padding(.horizontal, 36)
        }
        .frame(width: 1080, height: 1920)
    }

    // MARK: - Hero (varies by reward)

    @ViewBuilder
    private var hero: some View {
        if let rankUp = summary.rankUp {
            rankUpHero(rankUp)
        } else if let firstSet = summary.firstSet {
            firstSetHero(firstSet)
        } else if let pr = summary.personalRecord {
            prHero(pr)
        } else if let badge = summary.badgeUnlocks.first {
            badgeHero(badge)
        }
    }

    private func rankUpHero(_ rankUp: RankUp) -> some View {
        VStack(spacing: 22) {
            Text("REACHED")
                .font(.system(size: 16, weight: .heavy, design: .monospaced))
                .tracking(3.4)
                .foregroundStyle(Color.unbound.accent)

            if UIImage(named: rankUp.toTier.assetName) != nil {
                Image(rankUp.toTier.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 480, height: 480)
                    .shadow(color: Color.unbound.accent.opacity(0.65), radius: 60)
            } else {
                Text(rankUp.toTier.displayName.uppercased())
                    .font(.system(size: 96, weight: .black, design: .default))
                    .tracking(2)
                    .foregroundStyle(Color.unbound.accent)
            }

            Text(rankUp.toTier.displayName.uppercased())
                .font(.system(size: 64, weight: .black, design: .default))
                .tracking(2.5)
                .foregroundStyle(Color.white)

            Text(rankUp.skillTitle.uppercased())
                .font(.system(size: 22, weight: .heavy, design: .monospaced))
                .tracking(2)
                .foregroundStyle(Color.white.opacity(0.65))
        }
    }

    private func firstSetHero(_ first: FirstSet) -> some View {
        VStack(spacing: 24) {
            Text("FIRST REP")
                .font(.system(size: 16, weight: .heavy, design: .monospaced))
                .tracking(3.4)
                .foregroundStyle(Color.unbound.accent)

            ZStack {
                Circle()
                    .fill(Color.unbound.accent.opacity(0.22))
                    .frame(width: 360, height: 360)
                    .blur(radius: 60)
                Image(systemName: "flag.checkered.circle.fill")
                    .font(.system(size: 220, weight: .regular))
                    .foregroundStyle(Color.unbound.accent)
            }
            .frame(height: 380)

            Text(first.skillTitle.uppercased())
                .font(.system(size: 56, weight: .black, design: .default))
                .tracking(2)
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text("THE PATH BEGINS.")
                .font(.system(size: 22, weight: .heavy, design: .monospaced))
                .tracking(2.6)
                .foregroundStyle(Color.white.opacity(0.55))
        }
    }

    private func prHero(_ pr: PersonalRecord) -> some View {
        VStack(spacing: 22) {
            Text("PERSONAL RECORD")
                .font(.system(size: 16, weight: .heavy, design: .monospaced))
                .tracking(3.4)
                .foregroundStyle(Color.unbound.impact)

            ZStack {
                Circle()
                    .fill(Color.unbound.impact.opacity(0.22))
                    .frame(width: 360, height: 360)
                    .blur(radius: 60)
                Image(systemName: "trophy.fill")
                    .font(.system(size: 220, weight: .regular))
                    .foregroundStyle(Color.unbound.impact)
            }
            .frame(height: 380)

            Text(pr.displayValue.uppercased())
                .font(.system(size: 88, weight: .black, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(Color.white)

            Text(pr.exerciseName.uppercased())
                .font(.system(size: 22, weight: .heavy, design: .monospaced))
                .tracking(2)
                .foregroundStyle(Color.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
    }

    private func badgeHero(_ badge: BadgeUnlock) -> some View {
        VStack(spacing: 22) {
            Text("BADGE UNLOCKED")
                .font(.system(size: 16, weight: .heavy, design: .monospaced))
                .tracking(3.4)
                .foregroundStyle(Color.unbound.accent)

            if UIImage(named: badge.assetName) != nil {
                Image(badge.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 400, height: 400)
                    .shadow(color: Color.unbound.accent.opacity(0.55), radius: 50)
            } else {
                Image(systemName: "rosette")
                    .font(.system(size: 220, weight: .regular))
                    .foregroundStyle(Color.unbound.accent)
            }

            Text(badge.title.uppercased())
                .font(.system(size: 56, weight: .black, design: .default))
                .tracking(2)
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
    }

    // MARK: - Backdrop

    @ViewBuilder
    private var backdropLayer: some View {
        if let rankUp = summary.rankUp,
           rankUp.toTier.deservesCinematic,
           let asset = RankCosmetics.profileBackgroundAsset(for: rankUp.toTier) {
            Image(asset)
                .resizable()
                .scaledToFill()
                .frame(width: 1080, height: 1920)
                .clipped()
                .overlay(Color.black.opacity(0.35))
        } else {
            ZStack {
                Color.black

                RadialGradient(
                    colors: [
                        Color.unbound.accent.opacity(0.45),
                        Color.black.opacity(0)
                    ],
                    center: .top,
                    startRadius: 60,
                    endRadius: 1100
                )
            }
            .ignoresSafeArea()
        }
    }

    private var footerKicker: String {
        if summary.rankUp != nil { return "Rank Up" }
        if summary.firstSet != nil { return "Journey Begins" }
        if summary.personalRecord != nil { return "PR Locked In" }
        if !summary.badgeUnlocks.isEmpty { return "Badge Unlocked" }
        return "Logged"
    }
}

// MARK: - Renderer + Share helper

enum RewardShareRenderer {

    /// Renders the share card to a UIImage at @3x for social-clean
    /// resolution. Returns nil if SwiftUI's renderer fails (typically
    /// only happens if the view tree references an unloaded asset).
    @MainActor
    static func render(summary: RewardSummary) -> UIImage? {
        let card = RewardShareCard(summary: summary)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0
        return renderer.uiImage
    }

    /// Caption auto-built from the summary. Tuned per reward type so
    /// the user never has to edit the post copy from scratch.
    static func caption(summary: RewardSummary) -> String {
        if let rankUp = summary.rankUp {
            return """
            Hit \(rankUp.toTier.displayName) on \(rankUp.skillTitle). The arc continues. — UNBOUND

            #UNBOUND #RankUp #\(rankUp.toTier.displayName)
            """
        }
        if let pr = summary.personalRecord {
            return """
            New PR — \(pr.displayValue) on \(pr.exerciseName). — UNBOUND

            #UNBOUND #PR
            """
        }
        if let firstSet = summary.firstSet {
            return """
            Day one on \(firstSet.skillTitle). The path begins. — UNBOUND

            #UNBOUND #JourneyBegins
            """
        }
        if let badge = summary.badgeUnlocks.first {
            return """
            Unlocked: \(badge.title). — UNBOUND

            #UNBOUND
            """
        }
        return "Logging the work. — UNBOUND  #UNBOUND"
    }

    /// Presents the system share sheet anchored to the current key
    /// window. UIActivityViewController takes the rendered card image
    /// + the auto-caption.
    @MainActor
    static func presentShareSheet(summary: RewardSummary) {
        guard let image = render(summary: summary) else { return }
        let caption = caption(summary: summary)

        let activity = UIActivityViewController(
            activityItems: [image, caption],
            applicationActivities: nil
        )

        guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
              let root = scene.keyWindow?.rootViewController else { return }

        // iPad popover anchor
        if let pop = activity.popoverPresentationController {
            pop.sourceView = root.view
            pop.sourceRect = CGRect(x: root.view.bounds.midX,
                                    y: root.view.bounds.midY,
                                    width: 0, height: 0)
            pop.permittedArrowDirections = []
        }

        // Present from the topmost view controller
        var top = root
        while let presented = top.presentedViewController { top = presented }
        top.present(activity, animated: true)
    }
}
