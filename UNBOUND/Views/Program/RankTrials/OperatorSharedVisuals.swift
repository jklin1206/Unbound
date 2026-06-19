import SwiftUI

struct OperatorLaneBeacon: View {
    let label: String
    let tint: Color
    var filled: Bool = false

    var body: some View {
        ZStack {
            OperatorBeaconShape()
                .fill(filled ? tint : Color.unbound.bg.opacity(0.82))
            OperatorBeaconShape()
                .stroke(tint.opacity(0.72), lineWidth: 1.2)

            VStack(spacing: 3) {
                Text(label)
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(filled ? Color.unbound.bg : Color.unbound.textPrimary)
                    .monospacedDigit()
                Capsule()
                    .fill(filled ? Color.unbound.bg.opacity(0.8) : tint)
                    .frame(width: 16, height: 3)
            }
        }
    }
}

struct OperatorLaneMicroGauge: View {
    let value: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(Color.unbound.bg.opacity(0.9))
                    .frame(width: 6)
                Capsule()
                    .fill(tint)
                    .frame(width: 6, height: max(6, proxy.size.height * CGFloat(min(max(value, 0), 1))))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

enum OperatorIcon {
    static func icon(for blockKind: TrainingBlockKind) -> String {
        switch blockKind {
        case .strength, .custom: return "dumbbell.fill"
        case .bodyweight: return "figure.strengthtraining.traditional"
        case .skill: return "figure.gymnastics"
        case .cardio: return "figure.run"
        case .carry: return "shippingbox.fill"
        case .routine: return "timer"
        }
    }
}

enum OperatorText {
    static func twoDigit(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }

    static func mmss(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        let remainingSeconds = max(0, seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

struct OperatorScannerShell: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cut: CGFloat = min(rect.width, rect.height) * 0.12
        path.move(to: CGPoint(x: rect.minX + cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cut))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cut * 1.4))
        path.addLine(to: CGPoint(x: rect.maxX - cut * 1.4, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + cut * 0.7, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cut * 0.7))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cut))
        path.closeSubpath()
        return path
    }
}

struct OperatorLanePlateShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cut: CGFloat = min(18, rect.height * 0.28)
        path.move(to: CGPoint(x: rect.minX + cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cut))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cut))
        path.closeSubpath()
        return path
    }
}

struct OperatorBeaconShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cut = rect.width * 0.18
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY + rect.height * 0.2))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cut))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cut))
        path.addLine(to: CGPoint(x: rect.minX + cut, y: rect.minY + rect.height * 0.2))
        path.closeSubpath()
        return path
    }
}
