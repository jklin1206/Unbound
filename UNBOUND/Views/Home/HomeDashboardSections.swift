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
    let level: Int
    let xpInLevel: Int
    let xpForLevel: Int
    let levelFraction: CGFloat
    let aggregateTier: SkillTier
    let aggregateRank: RankTier
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
            UnboundNativeMetric(label: "Day", value: programDayLabel, tint: tint),
            UnboundNativeMetric(label: "Time", value: "\(minutes)M", tint: tint),
            UnboundNativeMetric(label: "Plan", value: planValue, tint: tint)
        ]

        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 7) {
                        HomeProtocolStatusLine(
                            label: "STATUS",
                            value: todayStatusValue,
                            tint: tint
                        )
                        HomeProtocolSignalTag(text: focus, tint: tint)
                    }

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

                Spacer(minLength: 0)

                HomeTrainingRankRail(
                    level: level,
                    xpInLevel: xpInLevel,
                    xpForLevel: xpForLevel,
                    fraction: levelFraction,
                    aggregateTier: aggregateTier,
                    rankColor: aggregateRank.rewardTint
                )
                .unboundTextShadow(strength: 0.72)
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
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
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

private struct HomeTrainingRankRail: View {
    let level: Int
    let xpInLevel: Int
    let xpForLevel: Int
    let fraction: CGFloat
    let aggregateTier: SkillTier
    let rankColor: Color

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Text(aggregateTier.displayName.uppercased())
                .font(Font.unbound.captionS.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(rankColor)
            Text("LVL \(level)")
                .font(Font.unbound.monoM.weight(.semibold))
                .foregroundStyle(Color.unbound.textPrimary)
                .monospacedDigit()
            GeometryReader { proxy in
                ZStack(alignment: .bottom) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(rankColor)
                        .frame(height: max(8, proxy.size.height * fraction))
                        .shadow(color: rankColor.opacity(0.35), radius: 8)
                }
            }
            .frame(width: 5, height: 58)
            Text("\(xpInLevel)/\(xpForLevel) XP")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.unbound.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(width: 76, alignment: .trailing)
    }
}

private struct HomeProtocolStatusLine: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 7) {
            Text(label)
                .font(Font.unbound.captionS.weight(.semibold))
                .tracking(1.6)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
                .unboundAdaptiveBackdropForeground(
                    candidates: .unboundBackdropMeta,
                    minimumContrast: 2.7,
                    shadowStrength: 0.78
                )
            HomeProtocolSignalTag(text: value, tint: tint)
        }
    }
}

private struct HomeProtocolSignalTag: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .black, design: .monospaced))
            .tracking(1.2)
            .foregroundStyle(Color.unbound.textPrimary)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .allowsTightening(true)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(0.62),
                                tint.opacity(0.38)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
            }
            .shadow(color: tint.opacity(0.24), radius: 10, y: 4)
            .unboundTextShadow(strength: 0.48)
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
            ZStack(alignment: .leading) {
                StreakSlashShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.unbound.ember.opacity(0.36),
                                Color.unbound.ember.opacity(0.08)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 108, height: 62)
                    .offset(x: -12)

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
            }

            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Text("\(weekSessionDays.count)/7")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(Color.unbound.ember)
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
                        .shadow(
                            color: hasSession ? Color.unbound.ember.opacity(0.42 + (0.10 * Double(pulse))) : Color.clear,
                            radius: shouldAnimate ? 5 + (1.5 * pulse) : (hasSession ? 6 : 0),
                            y: hasSession ? 2 : 0
                        )

                    if hasSession {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(Color.unbound.rankGold.opacity(0.86 + (0.08 * Double(pulse))))
                            .scaleEffect(shouldAnimate ? 0.99 + (0.025 * pulse) : 1, anchor: .bottom)
                            .offset(y: 4)
                    }
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

struct HomeShimmerProgressBar: View {
    let fraction: CGFloat
    let tint: Color
    let track: Color
    let height: CGFloat
    let minFillWidth: CGFloat
    let shimmerWidth: CGFloat
    let shimmerPhase: CGFloat
    var usesImpactGradient = false

    var body: some View {
        GeometryReader { proxy in
            let fillWidth = max(minFillWidth, proxy.size.width * fraction)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(track)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                tint,
                                usesImpactGradient ? Color.unbound.impact.opacity(0.9) : tint
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: fillWidth)
                    .overlay(
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, .white.opacity(0.45), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: shimmerWidth)
                            .offset(x: shimmerPhase * fillWidth)
                            .blendMode(.plusLighter)
                    )
                    .clipShape(Capsule())
            }
        }
        .frame(height: height)
    }
}

private struct ProtocolHeroBackground: View {
    let tint: Color

    var body: some View {
        ZStack {
            UnboundPosterScrim(
                tint: tint,
                topOpacity: 0.24,
                midOpacity: 0.34,
                bottomOpacity: 0.68,
                sideOpacity: 0.34,
                tintOpacity: 0.035
            )

            TopographicLines()
                .stroke(Color.white.opacity(0.024), lineWidth: 1)

            DiagonalAccentShape()
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.12),
                            tint.opacity(0.04),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 210)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [tint.opacity(0.10), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 140
                    )
                )
                .frame(width: 230, height: 230)
                .offset(x: 126, y: -96)
                .allowsHitTesting(false)
        }
    }
}

struct DiagonalAccentShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.38, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct StreakSlashShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let lean = rect.width * 0.42
        path.move(to: CGPoint(x: rect.minX + lean, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - lean, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct TopographicLines: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let rows = 8
        for row in 0..<rows {
            let baseY = rect.minY + CGFloat(row) * rect.height / CGFloat(rows - 1)
            path.move(to: CGPoint(x: rect.minX - 20, y: baseY))
            for step in 0...8 {
                let x = rect.minX + CGFloat(step) * rect.width / 8
                let wave = sin(CGFloat(step) * 0.95 + CGFloat(row) * 0.72) * 13
                let next = CGPoint(x: x, y: baseY + wave)
                path.addLine(to: next)
            }
        }
        return path
    }
}
