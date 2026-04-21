import SwiftUI

// MARK: - BodyAlignmentGuide
//
// Shared live-scan overlay used by both Step_ScanLive (onboarding first
// scan) and CameraView (re-scan / progress photo). Renders:
//   - A prominent dashed frame rectangle aligned to the detector's actual
//     thresholds (head band top 22%, feet band bottom 22%, horizontal
//     tolerance ±18%). Lining up inside this rectangle WILL satisfy the
//     alignment detector.
//   - Corner brackets for visual anchoring.
//   - HEAD / FEET arrow labels so the user knows where each end of their
//     body needs to land.
//   - A centered figure silhouette for rough positioning.
//   - Status chip color + pulse shift with alignment state.
//
// Frame coordinates are kept in lockstep with BodyAlignmentThresholds.default
// so the visible guide and the detector never disagree.

struct BodyAlignmentGuide: View {
    let alignment: BodyAlignment

    // Frame rectangle derived from detector thresholds. These stay in sync
    // with BodyAlignmentThresholds.default.
    private let topBand: CGFloat = 0.22            // head band fraction
    private let bottomBand: CGFloat = 0.22         // feet band fraction
    private let horizontalInsetFraction: CGFloat = 0.16  // ≈ ±18% tolerance → frame ≈ 68% wide

    var body: some View {
        GeometryReader { geo in
            let horizontalInset = geo.size.width * horizontalInsetFraction
            let frameRect = CGRect(
                x: horizontalInset,
                y: geo.size.height * topBand,
                width: geo.size.width - horizontalInset * 2,
                height: geo.size.height * (1 - topBand - bottomBand)
            )

            ZStack {
                // Main frame outline — dashed, thick, bright.
                frameOutline
                    .stroke(
                        frameColor,
                        style: StrokeStyle(lineWidth: alignment == .aligned ? 3.5 : 2.5,
                                           dash: alignment == .aligned ? [] : [10, 6])
                    )
                    .frame(width: frameRect.width, height: frameRect.height)
                    .position(x: frameRect.midX, y: frameRect.midY)
                    .shadow(color: frameColor.opacity(alignment == .aligned ? 0.9 : 0.35),
                            radius: alignment == .aligned ? 18 : 10)

                // Corner brackets — sit OUTSIDE the dashed line so both are visible.
                ForEach(Corner.allCases, id: \.self) { corner in
                    CornerBracket(corner: corner, frame: frameRect.insetBy(dx: -10, dy: -10))
                        .stroke(frameColor, lineWidth: 3)
                }

                // Silhouette figure in the center.
                Image(systemName: "figure.stand")
                    .font(.system(size: frameRect.height * 0.62, weight: .ultraLight))
                    .foregroundStyle(silhouetteColor)
                    .position(x: frameRect.midX, y: frameRect.midY)

                // HEAD / FEET labels with arrows pointing into the frame band.
                labelChip(text: "HEAD", glyph: "arrow.down")
                    .position(x: frameRect.midX, y: frameRect.minY - 16)
                labelChip(text: "FEET", glyph: "arrow.up")
                    .position(x: frameRect.midX, y: frameRect.maxY + 16)
            }
            .animation(.easeInOut(duration: 0.25), value: alignment)
        }
    }

    // MARK: Frame outline shape (rounded rectangle)

    private var frameOutline: some Shape {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
    }

    // MARK: Label chip

    private func labelChip(text: String, glyph: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: glyph)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(1.5)
        }
        .foregroundStyle(frameColor)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(Color.unbound.bg.opacity(0.8))
        )
        .overlay(
            Capsule().strokeBorder(frameColor.opacity(0.7), lineWidth: 1)
        )
    }

    // MARK: Color states

    private var frameColor: Color {
        switch alignment {
        case .noBody, .outOfFrame: return Color.unbound.textPrimary   // bone white — always visible
        case .closeToAligned:      return Color.unbound.accent        // violet — in range
        case .aligned:             return Color.unbound.success       // green — locked in
        }
    }

    private var silhouetteColor: Color {
        switch alignment {
        case .noBody, .outOfFrame: return Color.unbound.textPrimary.opacity(0.18)
        case .closeToAligned:      return Color.unbound.accent.opacity(0.42)
        case .aligned:             return Color.unbound.success.opacity(0.5)
        }
    }

    // MARK: Corner bracket geometry

    private enum Corner: CaseIterable { case topLeft, topRight, bottomLeft, bottomRight }

    private struct CornerBracket: Shape {
        let corner: Corner
        let frame: CGRect

        func path(in rect: CGRect) -> Path {
            var p = Path()
            let len: CGFloat = 34
            switch corner {
            case .topLeft:
                p.move(to: CGPoint(x: frame.minX, y: frame.minY + len))
                p.addLine(to: CGPoint(x: frame.minX, y: frame.minY))
                p.addLine(to: CGPoint(x: frame.minX + len, y: frame.minY))
            case .topRight:
                p.move(to: CGPoint(x: frame.maxX - len, y: frame.minY))
                p.addLine(to: CGPoint(x: frame.maxX, y: frame.minY))
                p.addLine(to: CGPoint(x: frame.maxX, y: frame.minY + len))
            case .bottomLeft:
                p.move(to: CGPoint(x: frame.minX, y: frame.maxY - len))
                p.addLine(to: CGPoint(x: frame.minX, y: frame.maxY))
                p.addLine(to: CGPoint(x: frame.minX + len, y: frame.maxY))
            case .bottomRight:
                p.move(to: CGPoint(x: frame.maxX - len, y: frame.maxY))
                p.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY))
                p.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY - len))
            }
            return p
        }
    }
}

// MARK: - AlignmentStatusChip
//
// Prominent status readout. Used above the capture controls. Pulses on
// close-to-aligned, solid-locked on aligned.

struct AlignmentStatusChip: View {
    let alignment: BodyAlignment
    @State private var pulse: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 9, height: 9)
                .scaleEffect(pulse)
                .shadow(color: statusColor.opacity(0.85), radius: 6)
            Text(alignment.statusLabel)
                .font(Font.unbound.monoS)
                .tracking(1.8)
                .foregroundStyle(Color.unbound.textPrimary)
                .contentTransition(.identity)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().strokeBorder(statusColor.opacity(0.6), lineWidth: 1))
        .onAppear { startPulse() }
        .onChange(of: alignment) { _, _ in startPulse() }
    }

    private var statusColor: Color {
        switch alignment {
        case .noBody, .outOfFrame: return Color.unbound.textTertiary
        case .closeToAligned:      return Color.unbound.accent
        case .aligned:             return Color.unbound.success
        }
    }

    private func startPulse() {
        pulse = 1.0
        guard alignment == .closeToAligned else { return }
        withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
            pulse = 1.25
        }
    }
}

// MARK: - AutoSnapCountdown
//
// Huge number overlay driven by a local countdown. Extracted so both scan
// surfaces render the same "3 → 2 → 1 → flash" beat.

struct AutoSnapCountdown: View {
    let seconds: Int

    var body: some View {
        Text("\(seconds)")
            .font(.system(size: 220, weight: .black, design: .default))
            .foregroundStyle(Color.unbound.textPrimary)
            .shadow(color: Color.unbound.accent.opacity(0.6), radius: 30)
            .contentTransition(.numericText(value: Double(seconds)))
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: seconds)
    }
}
