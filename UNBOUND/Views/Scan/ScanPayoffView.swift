import SwiftUI
import UIKit

// MARK: - ScanPayoffView
//
// The result surface for a completed bi-weekly scan. Renders the user's
// photo, Gemini's coach-voice narrative, an optional focus-area pill,
// and a retake affordance when confidence is low. Never shows raw
// observations, never numeric deltas, never regression copy.
//
// Presented as a full-screen cover from `PhotoCaptureFlow` after a
// successful `BodyAnalysisService.analyzeScan` call.

struct ScanPayoffView: View {
    let image: UIImage
    let analysis: BodyScanAnalysis
    let onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    photoCard
                    narrativeCard
                    if let focus = analysis.focusArea, !focus.isEmpty {
                        focusPill(focus)
                    }
                    if analysis.confidence == .low {
                        retakeHint
                    }
                    Spacer().frame(height: 28)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }

            VStack {
                Spacer()
                bottomBar
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            withAnimation(.easeOut(duration: 0.35).delay(0.05)) { appeared = true }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("SCAN COMPLETE")
                .font(Font.unbound.titleS)
                .tracking(2.0)
                .foregroundStyle(Color.unbound.textPrimary)
            Text(dateLabel)
                .font(Font.unbound.captionS.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(Color.unbound.accent.opacity(0.15))
                )
                .overlay(
                    Capsule().strokeBorder(Color.unbound.accent.opacity(0.4), lineWidth: 1)
                )
            Spacer()
        }
        .padding(.top, 4)
    }

    private var dateLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: analysis.createdAt).uppercased()
    }

    // MARK: - Photo card

    private var photoCard: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: 360)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.unbound.accent.opacity(0.45), lineWidth: 1.5)
            )
            .shadow(color: Color.unbound.accent.opacity(0.25), radius: 20, y: 4)
            .scaleEffect(appeared ? 1.0 : 0.96)
            .opacity(appeared ? 1.0 : 0.0)
    }

    // MARK: - Narrative card

    private var narrativeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.unbound.accent)
                Text("BODY READ")
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.8)
                    .foregroundStyle(Color.unbound.accent)
                Spacer()
                confidenceBadge
            }

            Text(analysis.narrative)
                .font(Font.unbound.bodyL)
                .foregroundStyle(Color.unbound.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
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
                                Color.unbound.accent.opacity(0.10),
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
                .strokeBorder(Color.unbound.accent.opacity(0.30), lineWidth: 1)
        )
    }

    private var confidenceBadge: some View {
        let (label, color): (String, Color) = {
            switch analysis.confidence {
            case .high:   return ("HIGH",   Color.unbound.success)
            case .medium: return ("MEDIUM", Color.unbound.textSecondary)
            case .low:    return ("LOW",    Color.unbound.warnOrange)
            }
        }()
        return Text(label)
            .font(.system(size: 9, weight: .bold))
            .tracking(1.4)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(color.opacity(0.15))
            )
            .overlay(
                Capsule().strokeBorder(color.opacity(0.45), lineWidth: 0.8)
            )
    }

    // MARK: - Focus pill

    private func focusPill(_ area: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "target")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.unbound.warnOrange)
            Text("FOCUS · \(area.uppercased())")
                .font(Font.unbound.captionS.weight(.bold))
                .tracking(1.6)
                .foregroundStyle(Color.unbound.textPrimary)
            Spacer()
            Text("NEXT BLOCK")
                .font(.system(size: 9, weight: .medium))
                .tracking(1.2)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.unbound.warnOrange.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Retake hint

    private var retakeHint: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.unbound.warnOrange)
            Text("The angle made it tough to read cleanly. Retake in better light when you can.")
                .font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.unbound.surface)
        )
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.unbound.borderSubtle)
                .frame(height: 0.5)

            Button {
                UnboundHaptics.medium()
                onDismiss()
            } label: {
                HStack(spacing: 10) {
                    Text("RETURN HOME")
                        .font(Font.unbound.bodyMStrong)
                        .tracking(1.6)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.unbound.accent)
                )
                .shadow(color: Color.unbound.accent.opacity(0.45), radius: 14, y: 2)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .background(Color.unbound.bg)
    }
}
