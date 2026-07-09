import SwiftUI
import UIKit

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
