import SwiftUI

struct HomeTopBarSection: View {
    let level: Int
    let rank: RankTier
    let avatarImage: UIImage?
    let avatarLetter: String
    let arcBalance: Int
    let profileBorder: ShopProfileBorderID?
    let onNotifications: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            HomeAvatarBadge(
                level: level,
                rank: rank,
                image: avatarImage,
                letterFallback: avatarLetter,
                profileBorder: profileBorder
            )

            Text("UNBOUND")
                .font(Font.unbound.captionS.weight(.black))
                .tracking(2.0)
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .allowsHitTesting(false)

            Spacer(minLength: 10)

            HomeArcWalletAmount(balance: arcBalance)

            Button {
                onNotifications()
            } label: {
                Image(systemName: "bell")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .unboundTextShadow(strength: 0.70)
    }
}

private struct HomeAvatarBadge: View {
    let level: Int
    let rank: RankTier
    let image: UIImage?
    let letterFallback: String
    let profileBorder: ShopProfileBorderID?

    var body: some View {
        HStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                CosmeticAvatar(
                    tier: rank,
                    size: 44,
                    image: image,
                    letterFallback: letterFallback,
                    shopBorder: profileBorder
                )

                Text("\(level)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .monospacedDigit()
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(Color.unbound.accent))
                    .offset(x: 4, y: 4)
            }
            .shadow(color: Color.unbound.accent.opacity(0.35), radius: 6)
        }
    }
}

private struct HomeArcWalletAmount: View {
    let balance: Int

    var body: some View {
        ArcCurrencyAmount(
            amount: balance,
            label: nil,
            iconSize: 18,
            spacing: 5,
            compact: true,
            iconPlacement: .trailing,
            valueFont: .system(size: 17, weight: .black, design: .rounded),
            valueColor: Color.unbound.textPrimary
        )
        .fixedSize(horizontal: true, vertical: false)
        .padding(.leading, 10)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.unbound.rankGold.opacity(0.38))
                .frame(width: 0.5, height: 22)
        }
        .accessibilityLabel("\(balance.formatted()) Arcs")
    }
}

struct HomeBriefingSection: View {
    let title: String
    let copy: String
    let dayText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(title)
                    .font(.system(size: 31, weight: .black))
                    .lineLimit(2)
                    .minimumScaleFactor(0.68)
                    .unboundAdaptiveBackdropForeground(
                        candidates: .unboundBackdropPrimary,
                        minimumContrast: 3.1,
                        brightPreference: .heroTitle,
                        shadowStrength: 1.04
                    )

                Spacer(minLength: 10)

                Text(dayText)
                    .font(Font.unbound.monoS)
                    .monospacedDigit()
                    .unboundAdaptiveBackdropForeground(
                        candidates: .unboundBackdropPrimary,
                        minimumContrast: 3.0,
                        brightPreference: .heroTitle,
                        shadowStrength: 0.92
                    )
            }

            Text(copy)
                .font(Font.unbound.bodyM)
                .lineLimit(2)
                .minimumScaleFactor(0.76)
                .frame(maxWidth: 330, alignment: .leading)
                .unboundAdaptiveBackdropForeground(
                    candidates: .unboundBackdropBody,
                    minimumContrast: 2.9,
                    brightPreference: .heroBody,
                    shadowStrength: 0.92
                )
        }
        .padding(.top, 2)
    }
}

struct HomeTrainingConsoleSection: View {
    let day: ProgramDay?
    let programDayCount: Int
    let hasPlateaus: Bool
    let shouldShowCalibrationCard: Bool
    let onPrimary: (_ canStart: Bool, _ isRest: Bool) -> Void

    var body: some View {
        let workout = day?.workout
        let isRest = day?.isRestDay ?? false
        let canStart = workout != nil && !isRest
        let tint = Self.protocolTint(canStart: canStart, isRest: isRest)
        let title = workout?.name ?? (isRest ? "Recovery Protocol" : "Plan Session")
        let minutes = workout?.estimatedMinutes ?? (isRest ? 18 : 30)
        let focus = workout?.targetMuscleGroups.first?.displayName.uppercased() ?? (isRest ? "RECOVERY" : "CUSTOM")
        let planValue = workout.map { "\($0.mainExercises.count) MOVES" } ?? (isRest ? "REST" : "OPEN")
        let metrics = [
            UnboundNativeMetric(label: "Day", value: programDayLabel),
            UnboundNativeMetric(label: "Time", value: "\(minutes)M"),
            UnboundNativeMetric(label: "Plan", value: planValue)
        ]

        return VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(todayStatusValue)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .tracking(1.6)
                        .foregroundStyle(tint)
                    Text("·")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.unbound.textSecondary)
                    Text(focus)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .tracking(1.6)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
                .unboundTextShadow(strength: 0.82)

                Text(title)
                    .font(.system(size: 35, weight: .black))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.62)
                    .fixedSize(horizontal: false, vertical: true)
                    .unboundTextShadow(strength: 0.82)

                Text(Self.protocolHeroSubtitle(workout: workout, isRest: isRest))
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.76)
                    .unboundTextShadow(strength: 0.82)
            }

            UnboundNativeMetricRail(metrics: metrics)
                .padding(.top, 2)
                .unboundTextShadow(strength: 0.72)

            Button {
                onPrimary(canStart, isRest)
            } label: {
                HStack(spacing: 11) {
                    Text(Self.protocolPrimaryLabel(canStart: canStart, isRest: isRest).uppercased())
                        .font(Font.unbound.bodyMStrong)
                        .tracking(1.4)
                    Image(systemName: canStart ? "arrow.right" : (isRest ? "camera.fill" : "calendar.badge.plus"))
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(tint)
                )
                .shadow(color: tint.opacity(0.20), radius: 16, y: 8)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 24)
        .background {
            ProtocolHeroBackground(tint: tint)
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.18),
                            .init(color: .black, location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
    }

    private var todayStatusValue: String {
        if hasPlateaus { return "WATCH" }
        if shouldShowCalibrationCard { return "CALIBRATE" }
        if day?.isRestDay == true { return "REST" }
        if day?.workout != nil { return "TRAIN" }
        return "PLAN"
    }

    private var programDayLabel: String {
        guard let day else { return "No program" }
        if day.dayNumber > 0 {
            return "Day \(day.dayNumber) / \(max(programDayCount, day.dayNumber))"
        }
        return "Travel day"
    }

    private static func protocolTint(canStart: Bool, isRest: Bool) -> Color {
        canStart ? Color.unbound.accent : (isRest ? Color.unbound.coachCyan : Color.unbound.ember)
    }

    private static func protocolHeroSubtitle(workout: Workout?, isRest: Bool) -> String {
        if let workout {
            return "\(workout.mainExercises.count) movements are queued. Start clean and log the sets that matter."
        }
        if isRest {
            return "Recovery is scheduled. Keep the check-in light and come back fresh."
        }
        return "No session is queued. Pick today's work before you train."
    }

    private static func protocolPrimaryLabel(canStart: Bool, isRest: Bool) -> String {
        if canStart { return "Begin Session" }
        return isRest ? "Log Check-In" : "Plan Session"
    }
}

struct HomeWeekPathSection: View {
    let currentStreak: Int
    let weekSessionDays: Set<Int>
    let countdown: (text: String, urgent: Bool, safe: Bool)?
    let reduceMotion: Bool

    private let weekdayLabels = ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]
    private var todayIndex: Int { ((Calendar.current.component(.weekday, from: Date()) + 5) % 7) + 1 }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text("\(currentStreak)")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                Text(currentStreak == 1 ? "DAY" : "DAYS")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.ember)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
            .layoutPriority(1)

            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Text("\(weekSessionDays.count)/7")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    if let countdown {
                        HomeCountdownLabel(countdown: countdown)
                    }
                }

                HStack(alignment: .bottom, spacing: 5) {
                    ForEach(0..<7, id: \.self) { index in
                        HomeWeekHeatFlame(
                            dayLabel: weekdayLabels[index],
                            hasSession: weekSessionDays.contains(index + 1),
                            isToday: (index + 1) == todayIndex,
                            reduceMotion: reduceMotion
                        )
                    }
                }
                .frame(height: 44, alignment: .bottom)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
    }
}

private struct HomeCountdownLabel: View {
    let countdown: (text: String, urgent: Bool, safe: Bool)

    private var tint: Color {
        countdown.urgent ? Color.unbound.alert : (countdown.safe ? Color.unbound.rankGreen : Color.unbound.ember)
    }

    var body: some View {
        Text(countdown.text)
            .font(.system(size: 9, weight: .heavy, design: .monospaced))
            .tracking(1.0)
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

private struct HomeWeekHeatFlame: View {
    let dayLabel: String
    let hasSession: Bool
    let isToday: Bool
    let reduceMotion: Bool

    var body: some View {
        let flameColor = hasSession
            ? Color.unbound.ember
            : (isToday ? Color.unbound.ember.opacity(0.82) : Color.unbound.textTertiary.opacity(0.48))
        let labelColor = isToday ? Color.unbound.textPrimary : Color.unbound.textTertiary
        let shouldAnimate = hasSession && !reduceMotion

        VStack(spacing: 3) {
            TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: !shouldAnimate)) { timeline in
                let pulse = CGFloat(shouldAnimate ? HomeAnimationMath.flamePulse(at: timeline.date) : 0)

                ZStack {
                    Circle()
                        .fill(isToday ? Color.unbound.ember.opacity(0.12 + (0.03 * Double(pulse))) : Color.clear)
                        .frame(width: 28, height: 28)

                    Image(systemName: hasSession ? "flame.fill" : "flame")
                        .font(.system(size: hasSession ? 22 : 19, weight: .black))
                        .foregroundStyle(flameColor)
                        .scaleEffect(shouldAnimate ? 0.985 + (0.03 * pulse) : 1, anchor: .bottom)
                        .brightness(shouldAnimate ? Double(0.012 * pulse) : 0)
                }
                .frame(width: 28, height: 28)
            }
            .frame(width: 28, height: 28)

            Text(dayLabel)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(0.7)
                .foregroundStyle(labelColor)
                .lineLimit(1)
        }
        .frame(width: 28)
        .accessibilityLabel("\(dayLabel) \(hasSession ? "lit" : "unlit")")
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: hasSession)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: isToday)
    }
}

enum HomeAnimationMath {
    static func flamePulse(at date: Date, duration: TimeInterval = 1.65) -> Double {
        let progress = (date.timeIntervalSinceReferenceDate / duration) * Double.pi * 2
        return (sin(progress) + 1) / 2
    }
}

private struct ProtocolHeroBackground: View {
    let tint: Color

    var body: some View {
        UnboundPosterScrim(
            tint: tint,
            topOpacity: 0.24,
            midOpacity: 0.34,
            bottomOpacity: 0.68,
            sideOpacity: 0.34,
            tintOpacity: 0.035
        )
    }
}
