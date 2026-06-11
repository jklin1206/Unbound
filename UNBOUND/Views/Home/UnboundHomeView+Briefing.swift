import Foundation
import SwiftUI
import UIKit

extension UnboundHomeView {
    var homeHeroStack: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar
                .padding(.horizontal, 20)
                .padding(.top, 8)

            homeBriefing
                .padding(.horizontal, 20)
                .padding(.top, 24)

            trainingConsole
                .padding(.top, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 2)
        .unboundAdaptiveBackdropScope(assetName: activeHomeBackgroundAssetName, role: .homePoster)
        .background {
            UnboundBackdropArt(
                assetName: activeHomeBackgroundAssetName,
                role: .homePoster,
                tint: model.aggregateRank.rewardTint
            )
            .ignoresSafeArea(edges: .top)
        }
    }

    var topBar: some View {
        HomeTopBarSection(
            level: model.lvlValue,
            rank: model.aggregateRank,
            avatarImage: photoStore.image(userId: services.auth.currentUserId ?? ""),
            avatarLetter: avatarInitial,
            arcBalance: walletStore.balance,
            profileBorder: equippedShopProfileBorder
        ) {
            UnboundHaptics.soft()
            showingNotificationSettings = true
        }
    }

    var homeBackground: some View {
        ZStack {
            Color.unbound.bg

            LinearGradient(
                stops: [
                    .init(color: Color.unbound.surface.opacity(0.10), location: 0),
                    .init(color: Color.unbound.bg.opacity(0.88), location: 0.48),
                    .init(color: Color.black.opacity(0.22), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    model.aggregateRank.rewardTint.opacity(0.035),
                    .clear
                ],
                center: UnitPoint(x: 0.88, y: 0.12),
                startRadius: 0,
                endRadius: 320
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    var activeHomeBackgroundAssetName: String {
        if let assetName = equippedHomeBackdrop?.backdropAssetName,
           UIImage(named: assetName) != nil {
            return assetName
        }
        return "home_background_chalk"
    }

    // MARK: - Briefing

    var homeBriefing: some View {
        HomeBriefingSection(
            title: briefingTitle,
            copy: briefingCopy,
            dayText: shortDayString()
        )
    }

    // MARK: - Premium Home Concept

    var trainingConsole: some View {
        HomeTrainingConsoleSection(
            day: model.todayProgramDay,
            programDayCount: model.program?.days.count ?? 28,
            hasPlateaus: !model.plateaus.isEmpty,
            shouldShowCalibrationCard: model.shouldShowCalibrationCard
        ) { canStart, isRest in
            UnboundHaptics.medium()
            if canStart {
                beginTodaySession()
            } else if isRest {
                captureMode = .photo
            } else {
                NotificationCenter.default.post(name: .requestNavigateToProgramTab, object: nil)
            }
        }
    }

    /// Streak countdown chip: how long until the streak breaks (Liftoff rule —
    /// log a workout within 3 days). nil when there's no active streak.
    var streakCountdown: (text: String, urgent: Bool, safe: Bool)? {
        guard let xp = model.sessionXP, xp.currentStreak > 0 else { return nil }
        if xp.loggedToday() { return ("LOGGED TODAY", false, true) }
        guard let left = xp.streakDaysRemaining() else { return nil }
        if left <= 0 { return ("LOG TODAY", true, false) }
        return ("\(left)D LEFT", left <= 1, false)
    }

    var weekPath: some View {
        HomeWeekPathSection(
            currentStreak: model.sessionXP?.currentStreak ?? streakDays,
            weekSessionDays: model.weekSessionDays,
            countdown: streakCountdown,
            reduceMotion: reduceMotion
        )
    }

    var briefingTitle: String {
        let greeting = homeGreetingText

        if let firstName = profileFirstName {
            return "\(greeting), \(firstName)"
        }

        return greeting
    }

    private var homeGreetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())

        switch hour {
        case 5..<12:
            return "Morning"
        case 12..<17:
            return "Afternoon"
        case 17..<22:
            return "Evening"
        default:
            return "Tonight"
        }
    }

    private var profileFirstName: String? {
        guard let displayName = model.profile?.displayName else {
            return nil
        }

        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            return nil
        }

        return name.components(separatedBy: .whitespacesAndNewlines)
            .first { !$0.isEmpty }
    }

    var briefingCopy: String {
        homeMotivationLine
    }

    private var homeMotivationLine: String {
        let trainingLines = [
            "You are closer than yesterday. Prove it today.",
            "Become the proof you keep looking for.",
            "The next version of you is built one session at a time.",
            "Make today something your future self can stand on.",
            "Strength follows the standard you refuse to drop."
        ]
        let recoveryLines = [
            "Recovery is where tomorrow's strength takes root.",
            "Rest with purpose. Return with more than you left with.",
            "Protect the rhythm. The work is still working.",
            "Let the body rebuild what the mind already believes."
        ]
        let lines = model.todayProgramDay?.isRestDay == true ? recoveryLines : trainingLines
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        return lines[dayOfYear % lines.count]
    }

    var avatarInitial: String {
        if let name = model.profile?.displayName, let first = name.first {
            return String(first).uppercased()
        }
        return "U"
    }

    // MARK: - Bodyweight quick log

}
