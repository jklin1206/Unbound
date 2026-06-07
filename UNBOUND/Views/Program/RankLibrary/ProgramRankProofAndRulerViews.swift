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
            Circle()
                .stroke(tint.opacity(pulse ? 0 : 0.38), lineWidth: 1)
                .frame(width: 210, height: 210)
                .scaleEffect(pulse ? 1.38 : 0.86)
                .opacity(pulse ? 0 : 1)

            Circle()
                .fill(tint.opacity(0.12))
                .frame(width: 196, height: 196)
                .blur(radius: 18)
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

enum ProgramRankRepGraphRange: CaseIterable, Identifiable {
    case thirtyDays
    case ninetyDays
    case all

    var id: Self { self }

    var label: String {
        switch self {
        case .thirtyDays: return "30D"
        case .ninetyDays: return "90D"
        case .all: return "ALL"
        }
    }

    func cutoff(relativeTo date: Date) -> Date? {
        let calendar = Calendar.current
        switch self {
        case .thirtyDays:
            return calendar.date(byAdding: .day, value: -30, to: date)
        case .ninetyDays:
            return calendar.date(byAdding: .day, value: -90, to: date)
        case .all:
            return nil
        }
    }
}

struct ProgramRankProofGraphPoint: Identifiable {
    let id: String
    let date: Date
    let value: Double
    let isCurrentAttempt: Bool
}

struct ProgramRankProofHistoryLineGraph: View {
    let entries: [ProgramRankExerciseHistoryEntry]
    let currentValue: Double
    let historyValue: (ProgramRankExerciseHistoryEntry) -> Double?
    let valueFormatter: (Double) -> String
    @Binding var selectedRange: ProgramRankRepGraphRange
    let tint: Color
    let accessibilityUnit: String

    private var dailyHistoryPoints: [ProgramRankProofGraphPoint] {
        let calendar = Calendar.autoupdatingCurrent
        var bestByDay: [Date: ProgramRankProofGraphPoint] = [:]

        for entry in entries {
            guard let value = historyValue(entry) else { continue }
            let day = calendar.startOfDay(for: entry.occurredAt)
            let point = ProgramRankProofGraphPoint(
                id: graphPointId(for: day),
                date: entry.occurredAt,
                value: value,
                isCurrentAttempt: false
            )

            if let existing = bestByDay[day] {
                let isBetterValue = value > existing.value
                let isLaterTie = value == existing.value && entry.occurredAt > existing.date
                if isBetterValue || isLaterTie {
                    bestByDay[day] = point
                }
            } else {
                bestByDay[day] = point
            }
        }

        return bestByDay.values.sorted { $0.date < $1.date }
    }

    private var points: [ProgramRankProofGraphPoint] {
        let now = Date()
        let calendar = Calendar.autoupdatingCurrent
        let cutoff = selectedRange.cutoff(relativeTo: now)
        var filtered = dailyHistoryPoints.filter { point in
            guard let cutoff else { return true }
            return point.date >= cutoff
        }

        let current = max(currentValue, 0)
        guard current > 0 else { return filtered }

        let today = calendar.startOfDay(for: now)
        if let todayIndex = filtered.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: now) }) {
            if current >= filtered[todayIndex].value {
                filtered[todayIndex] = ProgramRankProofGraphPoint(
                    id: graphPointId(for: today),
                    date: now,
                    value: current,
                    isCurrentAttempt: true
                )
            }
            return filtered
        }

        filtered.append(
            ProgramRankProofGraphPoint(
                id: graphPointId(for: today),
                date: now,
                value: current,
                isCurrentAttempt: true
            )
        )
        return filtered
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(valueFormatter(points.last?.value ?? currentValue))
                    .font(Font.unbound.bodyS.weight(.black))
                    .foregroundStyle(tint)
                    .monospacedDigit()
                Spacer(minLength: 10)
                rangePicker
            }

            GeometryReader { proxy in
                let plotPoints = plottedPoints(in: proxy.size)

                ZStack {
                    graphGrid

                    Path { path in
                        guard let first = plotPoints.first else { return }
                        path.move(to: first.location)
                        for point in plotPoints.dropFirst() {
                            path.addLine(to: point.location)
                        }
                    }
                    .stroke(
                        LinearGradient(
                            colors: [tint.opacity(0.45), tint],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                    )
                    .animation(.spring(response: 0.28, dampingFraction: 0.86), value: currentValue)

                    ForEach(plotPoints) { point in
                        Circle()
                            .fill(point.source.isCurrentAttempt ? tint : Color.unbound.bg)
                            .frame(width: point.source.isCurrentAttempt ? 11 : 8, height: point.source.isCurrentAttempt ? 11 : 8)
                            .overlay(
                                Circle()
                                    .strokeBorder(tint.opacity(point.source.isCurrentAttempt ? 1 : 0.7), lineWidth: 2)
                            )
                            .shadow(color: point.source.isCurrentAttempt ? tint.opacity(0.42) : .clear, radius: 8)
                            .position(point.location)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: 130)

            dateAxis
        }
        .padding(.top, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rank proof progress over time")
        .accessibilityValue("\(valueFormatter(currentValue)) \(accessibilityUnit) selected")
    }

    private var rangePicker: some View {
        HStack(spacing: 14) {
            ForEach(ProgramRankRepGraphRange.allCases) { range in
                Button {
                    selectedRange = range
                    UnboundHaptics.soft()
                } label: {
                    VStack(spacing: 4) {
                        Text(range.label)
                            .font(Font.unbound.captionS.weight(.heavy))
                            .foregroundStyle(selectedRange == range ? Color.unbound.textPrimary : Color.unbound.textTertiary)
                        Rectangle()
                            .fill(selectedRange == range ? tint : Color.clear)
                            .frame(height: 2)
                            .clipShape(Capsule())
                    }
                    .frame(minWidth: 32)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var graphGrid: some View {
        VStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { index in
                Rectangle()
                    .fill(Color.unbound.borderSubtle.opacity(index == 3 ? 0.44 : 0.22))
                    .frame(height: 1)
                if index < 3 {
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var dateAxis: some View {
        HStack {
            Text(dateLabel(for: visibleStartDate))
                .font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textTertiary)
            Spacer(minLength: 8)
            Text("Today")
                .font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textTertiary)
        }
    }

    private var visibleStartDate: Date {
        let now = Date()
        if let cutoff = selectedRange.cutoff(relativeTo: now) {
            return cutoff
        }
        return dailyHistoryPoints.first?.date ?? now
    }

    private func graphPointId(for day: Date) -> String {
        "day-\(Int(day.timeIntervalSince1970))"
    }

    private func dateLabel(for date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }

    private struct PlottedPoint: Identifiable {
        let source: ProgramRankProofGraphPoint
        let location: CGPoint

        var id: String { source.id }
    }

    private func plottedPoints(in size: CGSize) -> [PlottedPoint] {
        guard !points.isEmpty, size.width > 0, size.height > 0 else { return [] }

        let now = Date()
        let startDate = visibleStartDate
        let timeSpan = max(now.timeIntervalSince(startDate), 1)
        let values = points.map(\.value)
        let rawMin = values.min() ?? 0
        let rawMax = values.max() ?? 1
        let padding = max((rawMax - rawMin) * 0.18, 1)
        let minValue = max(rawMin - padding, 0)
        let maxValue = max(rawMax + padding, minValue + 1)
        let valueSpan = max(maxValue - minValue, 1)

        return points.map { point in
            let xRatio = min(max(point.date.timeIntervalSince(startDate) / timeSpan, 0), 1)
            let yRatio = CGFloat((point.value - minValue) / valueSpan)
            let location = CGPoint(
                x: CGFloat(xRatio) * size.width,
                y: size.height - (yRatio * size.height)
            )
            return PlottedPoint(source: point, location: location)
        }
    }
}

struct ProgramRankMetricRuler: View {
    let title: String
    let valueText: String
    let range: ClosedRange<Int>
    @Binding var value: Int
    var unitLabel: String = ""
    var format: (Int) -> String
    var tickLabel: (Int) -> String
    var majorEvery: Int
    var tickSpacing: CGFloat = 14
    var caption: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title.uppercased())
                    .font(Font.unbound.bodyS.weight(.heavy))
                    .tracking(0.6)
                    .foregroundStyle(Color.unbound.textTertiary)
                Spacer(minLength: 8)
                Text(valueText)
                    .font(Font.unbound.bodyS.weight(.bold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                    .monospacedDigit()
            }

            RulerPicker(
                range: range,
                value: $value,
                unitLabel: unitLabel,
                format: format,
                tickLabel: tickLabel,
                majorEvery: majorEvery,
                tickSpacing: tickSpacing
            )

            if let caption {
                Text(caption)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct ProgramRankWeightRulerConfig {
    let start: Double
    let end: Double
    let step: Double
    let majorDisplayIncrement: Double

    var range: ClosedRange<Int> {
        0...max(0, Int(((end - start) / step).rounded()))
    }

    var majorEvery: Int {
        max(1, Int((majorDisplayIncrement / step).rounded()))
    }

    func tick(for value: Double) -> Int {
        let rawTick = Int(((value - start) / step).rounded())
        return min(max(rawTick, range.lowerBound), range.upperBound)
    }

    func value(for tick: Int) -> Double {
        let clamped = min(max(tick, range.lowerBound), range.upperBound)
        let rawValue = start + Double(clamped) * step
        return (rawValue * 100).rounded() / 100
    }

    func formatValue(
        _ tick: Int,
        using unit: TrainingWeightUnit,
        isAddedLoad: Bool
    ) -> String {
        let displayValue = value(for: tick)
        if isAddedLoad, displayValue <= 0 {
            return "BW"
        }
        let prefix = isAddedLoad && displayValue > 0 ? "+" : ""
        return "\(prefix)\(WeightPlatePolicy.formatDisplayValue(displayValue))\(unit.shortLabel)"
    }

    func tickLabel(_ tick: Int) -> String {
        let displayValue = value(for: tick)
        if displayValue <= 0 { return "BW" }
        return WeightPlatePolicy.formatDisplayValue(displayValue)
    }
}

enum ProgramRankExerciseLogMode: Equatable {
    case oneRepMax
    case reps
    case hold

    static func mode(for definition: MovementDefinition) -> ProgramRankExerciseLogMode {
        switch definition.rankTemplate {
        case .barbellStrength, .machineStrength, .weightedBodyweight:
            return .oneRepMax
        case .bodyweightReps:
            return .reps
        case .holdControl, .mobilityDuration:
            return .hold
        case .cardioPerformance:
            switch definition.defaultMetric {
            case .reps: return .reps
            case .holdSeconds, .durationSeconds, .distanceMeters, .calories: return .hold
            }
        case .carrySled:
            return .hold
        case .routineCompletion, .unranked:
            switch definition.loggerMode {
            case .strengthSets: return .oneRepMax
            case .bodyweightSets, .skillAttempts: return .reps
            case .hold: return .hold
            case .carry, .cardio, .mobility, .routinePlayer: return .hold
            }
        }
    }

    var recordsReps: Bool {
        switch self {
        case .reps: return true
        case .oneRepMax, .hold: return false
        }
    }

    var recordsOneRepMax: Bool {
        switch self {
        case .oneRepMax: return true
        case .reps, .hold: return false
        }
    }

    var accessibilityUnit: String {
        switch self {
        case .oneRepMax:
            return "one rep max"
        case .reps:
            return "reps"
        case .hold:
            return "hold time"
        }
    }
}

struct ProgramRankExerciseHistoryEntry: Identifiable {
    let id: String
    let occurredAt: Date
    let summary: String
    let oneRepMaxKg: Double?
    let reps: Int?
    let holdSeconds: Int?

    var dateText: String {
        occurredAt.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }

    static func entries(
        from logs: [PerformanceLog],
        rankStandardMovementId: String
    ) -> [ProgramRankExerciseHistoryEntry] {
        var entries: [ProgramRankExerciseHistoryEntry] = []
        for log in logs.sorted(by: { $0.completedAt > $1.completedAt }) {
            for block in log.blocks {
                for exercise in block.exercises where !exercise.skipped {
                    let resolvedStandard = exercise.rankStandardMovementId
                        ?? MovementResolver.resolve(exercise.name).rankStandardMovementId
                    guard resolvedStandard == rankStandardMovementId else { continue }

                    for set in exercise.sets where !set.isWarmup {
                        guard let summary = ProgramRankExerciseFormatter.summary(for: set) else { continue }
                        entries.append(
                            ProgramRankExerciseHistoryEntry(
                                id: "\(log.id):\(exercise.id):\(set.id)",
                                occurredAt: log.completedAt,
                                summary: summary,
                                oneRepMaxKg: estimatedOneRepMaxKg(weightKg: set.weightKg, reps: set.reps),
                                reps: set.reps,
                                holdSeconds: set.holdSeconds ?? set.durationSeconds
                            )
                        )
                    }
                }
            }
        }
        return Array(entries.prefix(80))
    }

    private static func estimatedOneRepMaxKg(weightKg: Double?, reps: Int?) -> Double? {
        guard let weightKg, weightKg > 0 else { return nil }
        let safeReps = max(reps ?? 1, 1)
        guard safeReps > 1 else { return weightKg }
        return weightKg * (1.0 + Double(safeReps) / 30.0)
    }
}

enum ProgramRankExerciseFormatter {
    static func bestSummary(_ progress: MovementProgressState) -> String {
        let unit = WeightPlatePolicy.currentUnit
        if let estimated = progress.bestEstimatedOneRepMaxKg {
            return "1RM \(WeightPlatePolicy.formatLoggedWeight(estimated, unit: unit))\(unit.shortLabel)"
        }
        if let load = progress.bestLoadKg {
            let weight = "\(WeightPlatePolicy.formatLoggedWeight(load, unit: unit))\(unit.shortLabel)"
            if let reps = progress.bestReps {
                return "\(weight) x \(reps)"
            }
            return weight
        }
        if let reps = progress.bestReps {
            return "\(reps) reps"
        }
        if let hold = progress.bestHoldSeconds {
            return "\(seconds(hold)) hold"
        }
        if let duration = progress.bestDurationSeconds {
            return "\(seconds(duration)) hold"
        }
        return progress.rankTemplate.displayName
    }

    static func summary(for set: PerformanceSet) -> String? {
        let unit = WeightPlatePolicy.currentUnit
        if let weight = set.weightKg, let reps = set.reps {
            return "\(WeightPlatePolicy.formatLoggedWeight(weight, unit: unit))\(unit.shortLabel) x \(reps)"
        }
        if let reps = set.reps {
            return "\(reps) reps"
        }
        if let hold = set.holdSeconds {
            return "\(seconds(hold)) hold"
        }
        if let duration = set.durationSeconds {
            return "\(seconds(duration)) hold"
        }
        return nil
    }

    static func seconds(_ value: Int) -> String {
        if value < 60 { return "\(value)s" }
        let minutes = value / 60
        let seconds = value % 60
        if seconds == 0 { return "\(minutes)m" }
        return "\(minutes):" + String(format: "%02d", seconds)
    }

    static func distance(_ meters: Int) -> String {
        if meters >= 1_000 {
            let kilometers = Double(meters) / 1_000.0
            if abs(kilometers.rounded() - kilometers) < 0.001 {
                return "\(Int(kilometers.rounded()))km"
            }
            return String(format: "%.1fkm", kilometers)
        }
        return "\(meters)m"
    }
}
