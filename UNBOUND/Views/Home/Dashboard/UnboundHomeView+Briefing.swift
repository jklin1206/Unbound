import Foundation
import SwiftUI
import UIKit

extension UnboundHomeView {
    var homeHeroStack: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar
                .padding(.horizontal, 20)
                .padding(.top, 8)

            // The System opens the screen — quest-window voice, not a casual
            // greeting. The console below carries the day's quest itself.
            // Keep the System directive close to the quest console so the
            // first viewport starts with action instead of empty art.
            HomeSystemDirectiveLine(
                message: systemDirectiveText,
                dayText: shortDayString()
            )
            .padding(.top, 16)

            trainingConsole
                .padding(.top, 8)
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

    // MARK: - Premium Home Concept

    var trainingConsole: some View {
        HomeTrainingConsoleSection(
            day: model.todayProgramDay,
            programDayCount: model.program?.days.count ?? 28,
            level: model.lvlValue,
            xpInLevel: model.lvlXPInLevel,
            xpForLevel: model.lvlXPForLevel,
            levelFraction: model.lvlFraction,
            aggregateTier: model.aggregateTier,
            aggregateRank: model.aggregateRank,
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

    /// What the System announces above the quest console. Varied + deterministic
    /// per day via HomeSystemVoice, including the "just cleared it" streak beat.
    var systemDirectiveText: String {
        let ctx = HomeSystemVoice.Context(
            hasProgramDay: model.todayProgramDay != nil,
            isRestDay: model.todayProgramDay?.isRestDay == true,
            hasWorkout: model.todayProgramDay?.workout != nil,
            loggedToday: model.sessionXP?.loggedToday() ?? false,
            currentStreak: model.sessionXP?.currentStreak ?? 0,
            daySeed: HomeSystemVoice.daySeed()
        )
        return HomeSystemVoice.line(for: ctx)
    }

    var avatarInitial: String {
        if let name = model.profile?.displayName, let first = name.first {
            return String(first).uppercased()
        }
        return "U"
    }

    // MARK: - Bodyweight quick log

}
