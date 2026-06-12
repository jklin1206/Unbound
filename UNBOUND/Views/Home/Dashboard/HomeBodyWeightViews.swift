import Foundation
import SwiftUI
import UIKit

struct BodyWeightOverTimeChart: View {
    let logs: [BodyWeightLog]
    let unit: TrainingWeightUnit

    private var orderedLogs: [BodyWeightLog] {
        Array(logs.prefix(30).reversed())
    }

    private var values: [Double] {
        orderedLogs.map { unit.displayValue(fromKilograms: $0.weightKg) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text("OVER TIME")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(Color.unbound.textTertiary)

                Text(changeSummary)
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(0.7)
                    .foregroundStyle(changeColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }

            GeometryReader { proxy in
                chartBody(size: proxy.size)
            }

            HStack {
                Text(startDateText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Spacer()
                Text(endDateText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .tracking(0.7)
            .foregroundStyle(Color.unbound.textTertiary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.bg.opacity(0.28))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle.opacity(0.72), lineWidth: 1)
        )
        .accessibilityLabel("Bodyweight over time")
    }

    private var changeSummary: String {
        guard values.count >= 2,
              let first = values.first,
              let latest = values.last
        else {
            let count = values.count
            if count == 1 { return "1 LOG" }
            return "NO LOGS"
        }

        let delta = latest - first
        if abs(delta) < 0.05 {
            return "STEADY · \(values.count) LOGS"
        }
        let sign = delta > 0 ? "+" : "-"
        let formatted = WeightPlatePolicy.formatDisplayValue(abs(delta))
        return "\(sign)\(formatted) \(unit.shortLabel.uppercased()) · \(values.count) LOGS"
    }

    private var changeColor: Color {
        guard values.count >= 2,
              let first = values.first,
              let latest = values.last,
              abs(latest - first) >= 0.05
        else { return Color.unbound.textSecondary }

        return latest > first ? Color.unbound.success : Color.unbound.coachCyan
    }

    private var startDateText: String {
        guard let first = orderedLogs.first else { return "START" }
        return Self.shortDateFormatter.string(from: first.loggedAt).uppercased()
    }

    private var endDateText: String {
        guard let latest = orderedLogs.last else { return "NOW" }
        return Self.shortDateFormatter.string(from: latest.loggedAt).uppercased()
    }

    private func chartBody(size: CGSize) -> some View {
        let points = chartPoints(in: size)
        return ZStack {
            gridPath(in: size)
                .stroke(Color.unbound.borderSubtle.opacity(0.65), style: StrokeStyle(lineWidth: 0.6, dash: [3, 5]))

            if points.count >= 2 {
                linePath(points: points)
                    .stroke(
                        LinearGradient(
                            colors: [Color.unbound.coachCyan, Color.unbound.accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                    )

                ForEach(points.indices, id: \.self) { index in
                    Circle()
                        .fill(index == points.count - 1 ? Color.unbound.accent : Color.unbound.textSecondary)
                        .frame(width: index == points.count - 1 ? 7 : 4, height: index == points.count - 1 ? 7 : 4)
                        .position(points[index])
                        .shadow(color: Color.unbound.accent.opacity(index == points.count - 1 ? 0.38 : 0), radius: 5)
                }
            } else {
                Text(values.isEmpty ? "NO CHECK-INS" : "ONE CHECK-IN")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.0)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
    }

    private func chartPoints(in size: CGSize) -> [CGPoint] {
        guard !values.isEmpty else { return [] }
        guard let minValue = values.min(), let maxValue = values.max() else { return [] }

        let padding = max((maxValue - minValue) * 0.14, 0.5)
        let lowerBound = minValue - padding
        let upperBound = maxValue + padding
        let span = max(upperBound - lowerBound, 1)

        return values.enumerated().map { index, value in
            let x = values.count == 1
                ? size.width / 2
                : CGFloat(index) / CGFloat(values.count - 1) * size.width
            let normalized = (value - lowerBound) / span
            let y = size.height - CGFloat(normalized) * size.height
            return CGPoint(x: x, y: y)
        }
    }

    private func gridPath(in size: CGSize) -> Path {
        Path { path in
            for row in 0...2 {
                let y = size.height * CGFloat(row) / 2
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
        }
    }

    private func linePath(points: [CGPoint]) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            points.dropFirst().forEach { path.addLine(to: $0) }
        }
    }

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
}

struct BodyWeightHistoryScreen: View {
    let logs: [BodyWeightLog]
    let latestWeightKg: Double?
    let unit: TrainingWeightUnit
    let didJustLog: Bool
    let onLog: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var latestLog: BodyWeightLog? {
        logs.first
    }

    private var recentLogs: [BodyWeightLog] {
        Array(logs.prefix(8))
    }

    private var latestValueText: String {
        guard let latestWeightKg else { return "--" }
        return WeightPlatePolicy.formatLoggedWeight(latestWeightKg, unit: unit)
    }

    private var latestDateText: String {
        guard let loggedAt = latestLog?.loggedAt else { return "FROM PROFILE" }
        if Calendar.current.isDateInToday(loggedAt) { return "TODAY" }
        if Calendar.current.isDateInYesterday(loggedAt) { return "YESTERDAY" }
        return Self.dateFormatter.string(from: loggedAt).uppercased()
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                if didJustLog {
                    loggedConfirmation
                }

                latestPanel

                BodyWeightOverTimeChart(logs: logs, unit: unit)
                    .frame(height: 250)

                recentLogsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 34)
        }
        .background(Color.unbound.bg.ignoresSafeArea())
        .navigationTitle("Bodyweight")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
                .foregroundStyle(Color.unbound.textSecondary)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    onLog()
                } label: {
                    Label("Log", systemImage: "plus")
                }
                .foregroundStyle(Color.unbound.accent)
            }
        }
    }

    private var loggedConfirmation: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Color.unbound.success)

            VStack(alignment: .leading, spacing: 2) {
                Text("LOGGED")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.success)
                Text("Your bodyweight trend updated below.")
                    .font(Font.unbound.monoS.weight(.semibold))
                    .foregroundStyle(Color.unbound.textSecondary)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.success.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.unbound.success.opacity(0.28), lineWidth: 1)
        )
    }

    private var latestPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(latestValueText)
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                Text(unit.shortLabel.uppercased())
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(Color.unbound.textSecondary)

                Spacer()
            }

            HStack(spacing: 8) {
                metricPill(title: latestDateText, icon: "calendar")
                metricPill(title: "\(logs.count) LOG\(logs.count == 1 ? "" : "S")", icon: "list.bullet")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private var recentLogsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("RECENT CHECK-INS")
                    .font(Font.unbound.captionS.weight(.black))
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.textTertiary)
                Spacer()
            }

            if logs.isEmpty {
                Text("Log your first bodyweight to start the graph.")
                    .font(Font.unbound.monoS.weight(.semibold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(recentLogs.indices, id: \.self) { index in
                        recentLogRow(recentLogs[index])

                        if index < recentLogs.count - 1 {
                            Rectangle()
                                .fill(Color.unbound.borderSubtle)
                                .frame(height: 0.5)
                                .padding(.leading, 2)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.unbound.surface.opacity(0.66))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                )
            }
        }
    }

    private func recentLogRow(_ log: BodyWeightLog) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(Self.dateFormatter.string(from: log.loggedAt).uppercased())
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.0)
                    .foregroundStyle(Color.unbound.textSecondary)
                if let note = log.note, !note.isEmpty {
                    Text(note)
                        .font(Font.unbound.monoS)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text("\(WeightPlatePolicy.formatLoggedWeight(log.weightKg, unit: unit)) \(unit.shortLabel.uppercased())")
                .font(Font.unbound.monoS.weight(.bold))
                .foregroundStyle(Color.unbound.textPrimary)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func metricPill(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .black))
            Text(title)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(0.8)
        }
        .foregroundStyle(Color.unbound.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(Color.unbound.surfaceElevated)
        )
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
}

struct BodyWeightLogSheet: View {
    let unit: TrainingWeightUnit
    let isSaving: Bool
    let errorMessage: String?
    let onSave: (Double, String?) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var weightText: String
    @State private var note: String = ""

    private let fallbackDisplayWeight: Double

    init(
        initialWeightKg: Double?,
        unit: TrainingWeightUnit,
        isSaving: Bool,
        errorMessage: String?,
        onSave: @escaping (Double, String?) async -> Void
    ) {
        self.unit = unit
        self.isSaving = isSaving
        self.errorMessage = errorMessage
        self.onSave = onSave

        let displayWeight = initialWeightKg.map {
            WeightPlatePolicy.editingValue(fromKilograms: $0, unit: unit)
        } ?? Self.defaultDisplayWeight(for: unit)
        self.fallbackDisplayWeight = displayWeight
        _weightText = State(initialValue: WeightPlatePolicy.formatDisplayValue(displayWeight))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("LOG BODYWEIGHT")
                        .font(Font.unbound.captionS.weight(.black))
                        .tracking(1.8)
                        .foregroundStyle(Color.unbound.accent)
                    Text("TODAY")
                        .font(Font.unbound.monoS.weight(.bold))
                        .tracking(1.0)
                        .foregroundStyle(Color.unbound.textTertiary)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.unbound.surfaceElevated))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }

            HStack(alignment: .center, spacing: 12) {
                adjustmentButton(systemName: "minus", delta: -stepSize)

                VStack(spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        TextField("0", text: $weightText)
                            .font(.system(size: 44, weight: .black, design: .rounded))
                            .foregroundStyle(Color.unbound.textPrimary)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .monospacedDigit()
                            .frame(minWidth: 104, maxWidth: 170)

                        Text(unit.shortLabel.uppercased())
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .tracking(1.0)
                            .foregroundStyle(Color.unbound.textSecondary)
                    }

                    Text(validityText)
                        .font(Font.unbound.monoS.weight(.semibold))
                        .tracking(0.5)
                        .foregroundStyle(parsedWeightKg == nil ? Color.unbound.alert : Color.unbound.textTertiary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)

                adjustmentButton(systemName: "plus", delta: stepSize)
            }
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
            )

            TextField("Optional note", text: $note)
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textPrimary)
                .tint(Color.unbound.accent)
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.unbound.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                )

            if let errorMessage {
                Text(errorMessage)
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(Color.unbound.alert)
                    .lineLimit(2)
            }

            Button {
                guard let parsedWeightKg else { return }
                Task { await onSave(parsedWeightKg, note) }
            } label: {
                HStack(spacing: 10) {
                    if isSaving {
                        ProgressView()
                            .tint(Color.unbound.textPrimary)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .black))
                    }
                    Text(isSaving ? "SAVING" : "SAVE WEIGHT")
                        .font(Font.unbound.bodyMStrong)
                        .tracking(1.5)
                }
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(parsedWeightKg == nil ? Color.unbound.border : Color.unbound.accent)
                )
            }
            .buttonStyle(.plain)
            .disabled(parsedWeightKg == nil || isSaving)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.unbound.bg.ignoresSafeArea())
    }

    private var stepSize: Double {
        unit == .pounds ? 0.5 : 0.25
    }

    private var displayWeightRange: ClosedRange<Double> {
        unit == .pounds ? 40...700 : 20...320
    }

    private var parsedDisplayWeight: Double? {
        let raw = weightText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }

        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal

        let fallback = Double(raw.replacingOccurrences(of: ",", with: "."))
        guard let value = formatter.number(from: raw)?.doubleValue ?? fallback,
              displayWeightRange.contains(value)
        else { return nil }
        return value
    }

    private var parsedWeightKg: Double? {
        parsedDisplayWeight.map { unit.kilograms(fromDisplayValue: $0) }
    }

    private var validityText: String {
        parsedWeightKg == nil ? "OUT OF RANGE" : "READY TO LOG"
    }

    private static func defaultDisplayWeight(for unit: TrainingWeightUnit) -> Double {
        unit == .pounds ? 180 : 82
    }

    private func adjustmentButton(systemName: String, delta: Double) -> some View {
        Button {
            adjust(by: delta)
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(width: 46, height: 46)
                .background(
                    Circle()
                        .fill(Color.unbound.surfaceElevated)
                )
                .overlay(
                    Circle()
                        .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func adjust(by delta: Double) {
        let current = parsedDisplayWeight ?? fallbackDisplayWeight
        let next = min(max(current + delta, displayWeightRange.lowerBound), displayWeightRange.upperBound)
        weightText = WeightPlatePolicy.formatDisplayValue(next)
    }
}
