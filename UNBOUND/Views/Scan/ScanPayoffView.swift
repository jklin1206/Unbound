import SwiftUI
import UIKit

struct ScanPayoffView: View {
    let image: UIImage
    let analysis: BodyScanAnalysis
    let onDismiss: () -> Void

    @State private var photoAppeared = false
    @State private var scoresRevealed = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.unbound.bg.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    photoSection
                    if let scores = analysis.scores {
                        overallHero(scores.overall)
                        statCards(scores)
                    }
                    narrativeSection
                    Spacer().frame(height: 110)
                }
            }

            bottomBar
        }
        .navigationBarHidden(true)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05)) {
                photoAppeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation { scoresRevealed = true }
            }
        }
    }

    // MARK: - Photo

    private var photoSection: some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 380)
                .clipped()
                .overlay(
                    LinearGradient(
                        colors: [.clear, Color.unbound.bg],
                        startPoint: .init(x: 0.5, y: 0.65),
                        endPoint: .bottom
                    )
                )
                .scaleEffect(photoAppeared ? 1.0 : 1.04)
                .opacity(photoAppeared ? 1.0 : 0.0)

            // Share button
            Button(action: sharePhoto) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.black.opacity(0.55)))
                    .overlay(Circle().strokeBorder(Color.unbound.border.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.top, 14)
            .padding(.trailing, 20)
            .opacity(photoAppeared ? 1 : 0)
        }
    }

    // MARK: - Overall hero

    private func overallHero(_ score: Int) -> some View {
        VStack(spacing: 4) {
            Text("\(score)")
                .font(.system(size: 72, weight: .black, design: .default))
                .foregroundStyle(scoreColor(score))
                .shadow(color: scoreColor(score).opacity(0.45), radius: 20)
                .contentTransition(.numericText(value: Double(score)))

            Text("AESTHETIC")
                .font(Font.unbound.captionS.weight(.bold))
                .tracking(2.2)
                .foregroundStyle(Color.unbound.textSecondary)

            HStack(spacing: 6) {
                Text("PHYSIQUE READ")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.accent)
                Text("·")
                    .foregroundStyle(Color.unbound.textTertiary)
                Text(dateLabel)
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .opacity(scoresRevealed ? 1 : 0)
        .animation(.easeOut(duration: 0.4), value: scoresRevealed)
    }

    // MARK: - Stat cards

    private func statCards(_ scores: AestheticScores) -> some View {
        VStack(spacing: 10) {
            statRow(label: "LEANNESS",  score: scores.leanness,    index: 0)
            statRow(label: "MASS",      score: scores.muscleMass,  index: 1)
            statRow(label: "CUTS",      score: scores.definition,  index: 2)
            statRow(label: "SHAPE",     score: scores.proportions, index: 3)
            statRow(label: "SYMMETRY",  score: scores.symmetry,    index: 4)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    private func statRow(label: String, score: Int, index: Int) -> some View {
        let delay = Double(index) * 0.08
        let color = scoreColor(score)

        return HStack(spacing: 14) {
            Text(label)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(Color.unbound.textSecondary)
                .frame(width: 76, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.unbound.surface)
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(
                            width: scoresRevealed ? geo.size.width * CGFloat(score) / 10.0 : 0,
                            height: 8
                        )
                        .shadow(color: color.opacity(0.55), radius: 6)
                        .animation(
                            .spring(response: 0.65, dampingFraction: 0.72).delay(delay),
                            value: scoresRevealed
                        )
                }
            }
            .frame(height: 8)

            Text("\(score)")
                .font(.system(size: 15, weight: .black, design: .default))
                .foregroundStyle(color)
                .frame(width: 22, alignment: .trailing)
                .opacity(scoresRevealed ? 1 : 0)
                .animation(.easeOut(duration: 0.25).delay(delay + 0.35), value: scoresRevealed)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(color.opacity(scoresRevealed ? 0.20 : 0), lineWidth: 1)
                        .animation(.easeOut(duration: 0.4).delay(delay + 0.3), value: scoresRevealed)
                )
        )
        .opacity(scoresRevealed ? 1 : 0)
        .offset(y: scoresRevealed ? 0 : 10)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(delay), value: scoresRevealed)
    }

    // MARK: - Narrative

    private var narrativeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .bold))
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
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.unbound.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.unbound.accent.opacity(0.25), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
        .opacity(scoresRevealed ? 1 : 0)
        .animation(.easeOut(duration: 0.4).delay(0.55), value: scoresRevealed)
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

    // MARK: - Helpers

    private var dateLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: analysis.createdAt).uppercased()
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 8...10: return Color.unbound.success
        case 5...7:  return Color.unbound.accent
        default:     return Color.unbound.warnOrange
        }
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
            .background(Capsule().fill(color.opacity(0.15)))
            .overlay(Capsule().strokeBorder(color.opacity(0.45), lineWidth: 0.8))
    }

    private func sharePhoto() {
        UnboundHaptics.medium()
        let vc = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = windowScene.windows.first?.rootViewController else { return }
        // On iPad the share sheet needs a source rect
        vc.popoverPresentationController?.sourceView = root.view
        vc.popoverPresentationController?.sourceRect = CGRect(
            x: UIScreen.main.bounds.width - 60, y: 60, width: 1, height: 1
        )
        root.present(vc, animated: true)
    }
}
