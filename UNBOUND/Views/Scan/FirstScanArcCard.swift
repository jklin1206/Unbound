// UNBOUND/Views/Scan/FirstScanArcCard.swift
import SwiftUI
import UIKit

/// First-scan payoff. "Your arc begins" — photo + seeded hex + narrative +
/// 30-day cadence anchor. NO grading, NO strengths/weaknesses, NO focus
/// pills. See spec section "FirstScanArcCard."
struct FirstScanArcCard: View {
    let checkpoint: ScanCheckpoint
    let photoImage: UIImage?
    let buildAxisValues: [AttributeKey: Double]
    let onPrimary: () -> Void
    let onShare: () -> Void

    @State private var photoOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var hexAppeared = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                heroPhoto
                titleBlock
                hexBlock
                narrativeBlock
                cadenceAnchor
                ctaBlock
            }
            .padding(.bottom, 32)
        }
        .background(Color.unbound.bg.ignoresSafeArea())
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { photoOpacity = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeOut(duration: 0.45)) { titleOpacity = 1 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                hexAppeared = true
            }
        }
    }

    // MARK: - Subviews

    private var heroPhoto: some View {
        Group {
            if let photoImage {
                Image(uiImage: photoImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 360)
                    .frame(maxWidth: .infinity)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.unbound.surface)
                    .frame(height: 360)
            }
        }
        .opacity(photoOpacity)
    }

    private var titleBlock: some View {
        Text(L10n.string(.scanFirstArcTitle, defaultValue: "YOUR ARC BEGINS"))
            .font(Font.unbound.displayM)
            .foregroundStyle(Color.unbound.textPrimary)
            .tracking(3)
            .animeGlow(color: Color.unbound.accent, radius: 14, intensity: 0.5)
            .opacity(titleOpacity)
    }

    private var hexBlock: some View {
        AttributeHex(
            current: buildAxisValues,
            peak: nil,
            showLabels: true,
            radius: 130
        )
        .scaleEffect(hexAppeared ? 1.0 : 0.85)
        .opacity(hexAppeared ? 1.0 : 0.0)
        .animation(.spring(response: 0.55, dampingFraction: 0.75), value: hexAppeared)
    }

    private var narrativeBlock: some View {
        Text(checkpoint.narrative)
            .font(.system(size: 15))
            .foregroundStyle(Color.unbound.textSecondary)
            .multilineTextAlignment(.leading)
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .padding(.horizontal, 20)
    }

    private var cadenceAnchor: some View {
        Text(L10n.string(.scanFirstArcCadence, defaultValue: "Come back in 30 days to see how your arc evolves."))
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.unbound.textTertiary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
    }

    private var ctaBlock: some View {
        VStack(spacing: 12) {
            UnboundButton(title: L10n.string(.scanFirstArcPrimaryCTA, defaultValue: "BEGIN TRAINING"), action: onPrimary)
                .padding(.horizontal, 20)
            Button(action: onShare) {
                Text(L10n.string(.scanFirstArcShare, defaultValue: "Share your start"))
                    .font(.system(size: 13))
                    .foregroundStyle(Color.unbound.textTertiary)
                    .underline()
            }
        }
    }
}
