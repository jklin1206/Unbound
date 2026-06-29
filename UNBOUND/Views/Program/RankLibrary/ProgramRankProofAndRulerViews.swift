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
    case sevenDays
    case thirtyDays
    case ninetyDays

    var id: Self { self }

    var days: Int {
        switch self {
        case .sevenDays: return 7
        case .thirtyDays: return 30
        case .ninetyDays: return 90
        }
    }

    var label: String {
        switch self {
        case .sevenDays: return "7D"
        case .thirtyDays: return "30D"
        case .ninetyDays: return "90D"
        }
    }

    func cutoff(relativeTo date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: date) ?? date
    }
}

struct ProgramRankProofGraphPoint: Identifiable {
    let id: String
    let date: Date
    let value: Double
}

struct ProgramRankProofHistoryLineGraph: View {
    let entries: [ProgramRankExerciseHistoryEntry]
    let historyValue: (ProgramRankExerciseHistoryEntry) -> Double?
    let valueFormatter: (Double) -> String
    @Binding var selectedRange: ProgramRankRepGraphRange
    let tint: Color
    let accessibilityUnit: String

    @State private var selectedPointId: String?

    private let plotHeight: CGFloat = 218
    private let yAxisWidth: CGFloat = 44
    private let topInset: CGFloat = 16
    private let bottomInset: CGFloat = 8
    private let levelCount = 5   // horizontal gridlines / Y labels
    private let xTickCount = 5   // vertical gridlines / X date labels

    // MARK: - Derived data

    /// Best value per calendar day across the full history.
    private var dailyPoints: [ProgramRankProofGraphPoint] {
        let calendar = Calendar.autoupdatingCurrent
        var bestByDay: [Date: ProgramRankProofGraphPoint] = [:]
        for entry in entries {
            guard let value = historyValue(entry) else { continue }
            let day = calendar.startOfDay(for: entry.occurredAt)
            if let existing = bestByDay[day], value <= existing.value { continue }
            bestByDay[day] = ProgramRankProofGraphPoint(
                id: "day-\(Int(day.timeIntervalSince1970))",
                date: day,
                value: value
            )
        }
        return bestByDay.values.sorted { $0.date < $1.date }
    }

    private var windowStart: Date {
        Calendar.autoupdatingCurrent.startOfDay(for: selectedRange.cutoff(relativeTo: Date()))
    }

    private var windowEnd: Date { Date() }

    /// Logged days inside the selected window — no synthetic "today" point.
    private var points: [ProgramRankProofGraphPoint] {
        let start = windowStart
        return dailyPoints.filter { $0.date >= start }
    }

    /// A clean Y scale snapped so the gridlines land on tidy values.
    private var valueBounds: (min: Double, max: Double) {
        let values = points.map(\.value)
        let rawMin = values.min() ?? 0
        let rawMax = values.max() ?? 1
        let pad = max((rawMax - rawMin) * 0.15, 1)
        let lower = max(0, (rawMin - pad).rounded(.down))
        let divisor = Double(levelCount - 1)
        let rawUpper = max(rawMax + pad, lower + divisor)
        let step = ((rawUpper - lower) / divisor).rounded(.up)
        return (lower, lower + step * divisor)
    }

    private var selectedPoint: ProgramRankProofGraphPoint? {
        guard let id = selectedPointId else { return nil }
        return points.first { $0.id == id }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            rangePicker
                .frame(maxWidth: .infinity, alignment: .trailing)

            if points.isEmpty {
                emptyState
            } else {
                HStack(alignment: .top, spacing: 6) {
                    yAxis
                        .frame(width: yAxisWidth, height: plotHeight)
                    VStack(spacing: 6) {
                        plot.frame(height: plotHeight)
                        xAxis.frame(height: 14)
                    }
                }
            }
        }
        .padding(.top, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress over time")
        .accessibilityValue(accessibilitySummary)
    }

    // MARK: - Range picker

    private var rangePicker: some View {
        HStack(spacing: 14) {
            ForEach(ProgramRankRepGraphRange.allCases) { range in
                Button {
                    selectedRange = range
                    selectedPointId = nil
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
                    .frame(minWidth: 34)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Y axis (value labels aligned to gridlines)

    private var yAxis: some View {
        GeometryReader { proxy in
            let usable = max(proxy.size.height - topInset - bottomInset, 1)
            let bounds = valueBounds
            ForEach(0..<levelCount, id: \.self) { index in
                let frac = Double(index) / Double(levelCount - 1)
                let value = bounds.max - (bounds.max - bounds.min) * frac
                Text(valueFormatter(value))
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.unbound.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(width: yAxisWidth - 4, alignment: .trailing)
                    .position(x: (yAxisWidth - 4) / 2, y: topInset + usable * CGFloat(frac))
            }
        }
    }

    // MARK: - Plot

    private var plot: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let bounds = valueBounds
            let usableH = max(size.height - topInset - bottomInset, 1)
            let span = max(bounds.max - bounds.min, 1)
            let timeSpan = max(windowEnd.timeIntervalSince(windowStart), 1)
            let xPos: (Date) -> CGFloat = { date in
                CGFloat(min(max(date.timeIntervalSince(windowStart) / timeSpan, 0), 1)) * size.width
            }
            let yPos: (Double) -> CGFloat = { value in
                topInset + usableH * CGFloat(1 - (value - bounds.min) / span)
            }
            let locations = points.map { CGPoint(x: xPos($0.date), y: yPos($0.value)) }

            ZStack {
                // Horizontal gridlines
                ForEach(0..<levelCount, id: \.self) { index in
                    let gy = topInset + usableH * CGFloat(index) / CGFloat(levelCount - 1)
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: gy))
                        path.addLine(to: CGPoint(x: size.width, y: gy))
                    }
                    .stroke(Color.unbound.borderSubtle.opacity(index == levelCount - 1 ? 0.42 : 0.16), lineWidth: 1)
                }
                // Vertical gridlines
                ForEach(0..<xTickCount, id: \.self) { index in
                    let gx = size.width * CGFloat(index) / CGFloat(xTickCount - 1)
                    Path { path in
                        path.move(to: CGPoint(x: gx, y: topInset))
                        path.addLine(to: CGPoint(x: gx, y: topInset + usableH))
                    }
                    .stroke(Color.unbound.borderSubtle.opacity(0.10), lineWidth: 1)
                }
                // Area fill under the line
                if locations.count >= 2 {
                    Path { path in
                        path.move(to: CGPoint(x: locations[0].x, y: topInset + usableH))
                        for loc in locations { path.addLine(to: loc) }
                        path.addLine(to: CGPoint(x: locations[locations.count - 1].x, y: topInset + usableH))
                        path.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [tint.opacity(0.22), tint.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                }
                // Trend line
                if locations.count >= 2 {
                    Path { path in
                        path.move(to: locations[0])
                        for loc in locations.dropFirst() { path.addLine(to: loc) }
                    }
                    .stroke(
                        LinearGradient(colors: [tint.opacity(0.5), tint], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                    )
                }
                // Selection guide line
                if let selected = selectedPoint {
                    let sx = xPos(selected.date)
                    Path { path in
                        path.move(to: CGPoint(x: sx, y: topInset))
                        path.addLine(to: CGPoint(x: sx, y: topInset + usableH))
                    }
                    .stroke(tint.opacity(0.55), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
                // Nodes + tap targets
                ForEach(points) { point in
                    let location = CGPoint(x: xPos(point.date), y: yPos(point.value))
                    let isSelected = point.id == selectedPointId
                    Circle()
                        .fill(isSelected ? tint : Color.unbound.bg)
                        .frame(width: isSelected ? 13 : 8, height: isSelected ? 13 : 8)
                        .overlay(Circle().strokeBorder(tint, lineWidth: 2))
                        .shadow(color: isSelected ? tint.opacity(0.5) : .clear, radius: 7)
                        .position(location)
                    Color.clear
                        .frame(width: 40, height: 40)
                        .contentShape(Circle())
                        .position(location)
                        .onTapGesture {
                            UnboundHaptics.soft()
                            selectedPointId = isSelected ? nil : point.id
                        }
                }
                // Tapped-day callout
                if let selected = selectedPoint {
                    let bubbleWidth: CGFloat = 108
                    let cx = min(max(xPos(selected.date), bubbleWidth / 2), size.width - bubbleWidth / 2)
                    let cy = max(yPos(selected.value) - 40, 22)
                    calloutBody(for: selected)
                        .frame(width: bubbleWidth)
                        .position(x: cx, y: cy)
                }
            }
        }
    }

    private func calloutBody(for point: ProgramRankProofGraphPoint) -> some View {
        VStack(spacing: 2) {
            Text(valueFormatter(point.value))
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(tint)
                .monospacedDigit()
            Text(point.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.unbound.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.unbound.surfaceElevated))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(tint.opacity(0.45), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.4), radius: 8, y: 3)
    }

    // MARK: - X axis (date labels)

    private var xAxis: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let timeSpan = max(windowEnd.timeIntervalSince(windowStart), 1)
            ForEach(0..<xTickCount, id: \.self) { index in
                let frac = Double(index) / Double(xTickCount - 1)
                let date = windowStart.addingTimeInterval(timeSpan * frac)
                Text(date.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.unbound.textTertiary)
                    .fixedSize()
                    .position(x: min(max(CGFloat(frac) * width, 16), width - 16), y: 7)
            }
        }
    }

    private var emptyState: some View {
        Text("No attempts in this range.")
            .font(Font.unbound.bodyS)
            .foregroundStyle(Color.unbound.textTertiary)
            .frame(maxWidth: .infinity, minHeight: 130)
    }

    private var accessibilitySummary: String {
        guard let latest = points.last else { return "No data in range" }
        return "\(valueFormatter(latest.value)) \(accessibilityUnit) latest, \(points.count) sessions"
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
                                reps: set.reps.flatMap { $0 > 0 ? $0 : nil },
                                holdSeconds: set.holdSeconds ?? set.durationSeconds
                            )
                        )
                    }
                }
            }
        }
        return Array(entries.prefix(80))
    }

    /// Attempt history for a SKILL, gathered from blocks the skill itself logged
    /// (`block.skillId`). Skills rank on their own criterion, so their history is
    /// keyed by skill identity — independent of whatever movement twin a reps
    /// template might resolve. A hold set's reps==0 sentinel is dropped so it
    /// reads as a hold, not "0 reps".
    static func entries(
        from logs: [PerformanceLog],
        skillId: String
    ) -> [ProgramRankExerciseHistoryEntry] {
        var entries: [ProgramRankExerciseHistoryEntry] = []
        for log in logs.sorted(by: { $0.completedAt > $1.completedAt }) {
            for block in log.blocks where block.skillId == skillId {
                for exercise in block.exercises where !exercise.skipped {
                    for set in exercise.sets where !set.isWarmup {
                        guard let summary = ProgramRankExerciseFormatter.summary(for: set) else { continue }
                        entries.append(
                            ProgramRankExerciseHistoryEntry(
                                id: "\(log.id):\(exercise.id):\(set.id)",
                                occurredAt: log.completedAt,
                                summary: summary,
                                oneRepMaxKg: estimatedOneRepMaxKg(weightKg: set.weightKg, reps: set.reps),
                                reps: set.reps.flatMap { $0 > 0 ? $0 : nil },
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
        if let weight = set.weightKg, let reps = set.reps, reps > 0 {
            return "\(WeightPlatePolicy.formatLoggedWeight(weight, unit: unit))\(unit.shortLabel) x \(reps)"
        }
        // A hold set may carry reps == 0 as a sentinel; treat that as "no reps"
        // so the summary falls through to the hold instead of printing "0 reps".
        if let reps = set.reps, reps > 0 {
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
