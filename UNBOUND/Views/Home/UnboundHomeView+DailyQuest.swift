import Foundation
import SwiftUI
import UIKit

extension UnboundHomeView {

    /// Swaps the card's label from PHOTO +5 to SCAN +25 using the same
    /// monthly cadence rule as the scan gate.
    var shouldShowScanEligibility: Bool {
        scanCadence.isUnlocked
    }

    func dayWord(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "TODAY" }
        if cal.isDateInYesterday(date) { return "YESTERDAY" }
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date).uppercased()
    }

    func shortDayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: Date()).uppercased()
    }

    // MARK: - Daily Quest
    //
    // Bite-sized side activity — walks, mobility, stretch, alt circuits.
    // Shown alongside Today's Session to motivate movement on rest days
    // or as a lighter add-on on program days. Placeholder content until
    // QuestLibrary + QuestService ship.

    /// On rest days (or when no program is scheduled), the quest is the
    /// primary CTA — ordered above the session card. On program days,
    /// the session CTA stays primary and the quest appears below.
    var isQuestPrimary: Bool {
        guard let day = todayProgramDay else { return true }
        return day.isRestDay || day.workout == nil
    }

    func dailyQuestCard(isHero: Bool) -> some View {
        let categoryColor = questColor

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("DAILY QUEST")
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.8)
                    .foregroundStyle(categoryColor)
                Text("·")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text(activeRoutine.category.label)
                    .font(Font.unbound.captionS)
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textTertiary)
                Spacer()
                Text("PROOF-GATED XP")
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(categoryColor)
                    .monospacedDigit()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(activeRoutine.title.uppercased())
                    .font(Font.unbound.titleM)
                    .tracking(0.4)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text(activeRoutine.subtitle)
                    .font(Font.unbound.monoS)
                    .tracking(0.4)
                    .foregroundStyle(Color.unbound.textSecondary)
            }

            Button {
                UnboundHaptics.medium()
                activeRoutine = Self.defaultDailyQuestRoutine
                showRoutinePlayer = true
            } label: {
                HStack(spacing: 10) {
                    Text("ACCEPT")
                        .font(Font.unbound.bodyMStrong)
                        .tracking(1.6)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(categoryColor)
                )
                .shadow(color: categoryColor.opacity(0.45), radius: isHero ? 14 : 6, y: 2)
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.unbound.surface)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                categoryColor.opacity(isHero ? 0.14 : 0.06),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(categoryColor.opacity(isHero ? 0.40 : 0.22), lineWidth: 1)
        )
    }

    var dailyQuestCompletionOverlay: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                    .tint(questColor)
                    .scaleEffect(1.12)
                Text("LOCKING IN")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(2.0)
                    .foregroundStyle(questColor)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(questColor.opacity(0.32), lineWidth: 1)
            )
        }
        .accessibilityIdentifier("home.dailyQuest.completing")
    }

    func dailyQuestRetryOverlay(record: RoutineCompletionRecord) -> some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(questColor)
                Text("COULD NOT LOCK IN")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(2.0)
                    .foregroundStyle(questColor)
                if let dailyQuestCompletionError {
                    Text(dailyQuestCompletionError)
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button {
                    Task { await completeDailyQuest(record) }
                } label: {
                    Text("TRY AGAIN")
                        .font(Font.unbound.bodyMStrong)
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .frame(width: 180, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(questColor)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(questColor.opacity(0.32), lineWidth: 1)
            )
            .padding(.horizontal, 28)
        }
        .accessibilityIdentifier("home.dailyQuest.retry")
    }

    @MainActor
    func completeDailyQuest(_ record: RoutineCompletionRecord) async {
        guard !isCompletingDailyQuest, dailyQuestRewardSequence == nil else { return }
        pendingDailyQuestCompletionRecord = pendingDailyQuestCompletionRecord ?? record
        dailyQuestCompletionError = nil
        isCompletingDailyQuest = true

        guard let userId = services.auth.currentUserId else {
            LoggingService.shared.log(
                "Daily Quest completion skipped without authenticated user",
                level: .warning,
                context: ["routineId": activeRoutine.id, "recordId": record.id]
            )
            isCompletingDailyQuest = false
            pendingDailyQuestCompletionRecord = nil
            showRoutinePlayer = false
            return
        }

        let routine = activeRoutine
        let canClaimDailyReward = RoutineHistoryStore.shared.canComplete(routineId: routine.id)

        let performanceLog = TrainingSessionAdapters.performanceLogForRoutine(
            routine,
            record: record,
            userId: userId
        )

        do {
            let completionResult = try await TrainingCompletionService.shared.complete(
                performanceLog,
                services: services
            )
            RoutineHistoryStore.shared.record(record)
            if canClaimDailyReward, completionResult.overallLevelXPGained > 0 {
                RoutineHistoryStore.shared.complete(routine)
            }

            var rewardSummary = RewardSummary()
            rewardSummary.progression = completionResult.progressionReceipt

            dailyQuestRewardSequence = WorkoutRewardSequenceSummary.trainingReceipt(
                performanceLog: performanceLog,
                completionResult: completionResult,
                rewardSummary: rewardSummary,
                fallbackXP: 0,
                sourceName: "Daily Quest"
            )
            pendingDailyQuestCompletionRecord = nil
            dailyQuestCompletionError = nil
            isCompletingDailyQuest = false
        } catch {
            LoggingService.shared.log(
                "Daily Quest canonical completion failed",
                level: .warning,
                context: ["routineId": routine.id, "recordId": record.id, "error": "\(error)"]
            )
            isCompletingDailyQuest = false
            dailyQuestCompletionError = "Unable to save this quest. Try again."
        }
    }

    // MARK: - Ambient animations

    func startAmbientAnimations() {
        // Rank letter glow — bigger swing so it's perceptible, not subliminal.
        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
            rankGlowRadius = 22
        }

        // XP bar shimmer — traveling highlight.
        withAnimation(.linear(duration: 2.6).repeatForever(autoreverses: false)) {
            xpShimmerPhase = 1.2
        }

        // Stat bars sweep from 0 → value on load.
        withAnimation(.easeOut(duration: 1.0)) {
            statsRendered = true
        }
    }
}
