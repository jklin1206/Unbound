import Foundation
import SwiftUI
import UIKit

extension UnboundHomeView {
    var topBar: some View {
        HomeTopBarSection(
            level: lvlValue,
            archetypeName: archetypeName,
            rank: aggregateRank,
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
        GeometryReader { proxy in
            Image(activeHomeBackgroundAssetName)
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
                .saturation(1.12)
                .contrast(1.08)
                .overlay {
                    HomeBackgroundContrastScrim(size: proxy.size)
                }
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
            day: todayProgramDay,
            programDayCount: program?.days.count ?? 28,
            level: lvlValue,
            xpInLevel: lvlXPInLevel,
            xpForLevel: lvlXPForLevel,
            levelFraction: lvlFraction,
            aggregateTier: aggregateTier,
            aggregateRank: aggregateRank,
            hasPlateaus: !plateaus.isEmpty,
            shouldShowCalibrationCard: shouldShowCalibrationCard
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
        guard let xp = sessionXP, xp.currentStreak > 0 else { return nil }
        if xp.loggedToday() { return ("LOGGED TODAY", false, true) }
        guard let left = xp.streakDaysRemaining() else { return nil }
        if left <= 0 { return ("LOG TODAY", true, false) }
        return ("\(left)D LEFT", left <= 1, false)
    }

    var weekPath: some View {
        HomeWeekPathSection(
            currentStreak: sessionXP?.currentStreak ?? streakDays,
            weekSessionDays: weekSessionDays,
            countdown: streakCountdown,
            reduceMotion: reduceMotion
        )
    }

    var dailyQuestBand: some View {
        let categoryColor = questColor

        return Button {
            UnboundHaptics.medium()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(categoryColor.opacity(0.16))
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(categoryColor)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text("DAILY QUEST")
                        .font(Font.unbound.captionS.weight(.bold))
                        .tracking(1.6)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text(activeRoutine.title)
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

                Spacer(minLength: 0)

                Text("PROOF-GATED XP")
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(categoryColor)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(categoryColor.opacity(0.24), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    var questColor: Color {
        activeRoutine.category.color
    }

    var briefingTitle: String {
        if let name = profile?.displayName,
           !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Move, \(name.components(separatedBy: " ").first ?? name)"
        }
        return "Move today"
    }

    var briefingCopy: String {
        if let day = todayProgramDay {
            if day.isRestDay {
                return "Recovery is scheduled. Keep the arc alive with a scan, a photo, or a low-friction quest."
            }
            if let workout = day.workout {
                return "\(workout.name) is ready. \(workout.mainExercises.count) main lifts, about \(workout.estimatedMinutes) minutes."
            }
        }
        return "No session is queued. Open Program to plan today's work or use a quick action below."
    }

    var avatarInitial: String {
        if let name = profile?.displayName, let first = name.first {
            return String(first).uppercased()
        }
        return "U"
    }

    // MARK: - Bodyweight quick log

}
