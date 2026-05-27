// UNBOUND/Views/Scan/NthScanEvolutionCard.swift
import SwiftUI
import UIKit

/// Nth-scan payoff. Before/after photo split + ScanBuildDeltaCard +
/// checkpoint evolution narrative. Setbacks NEVER appear as negative numbers —
/// regressed axes become quiet "Watch signal" pills via BuildIdentityDelta.
struct NthScanEvolutionCard: View {
    let priorCheckpoint: ScanCheckpoint
    let currentCheckpoint: ScanCheckpoint
    let priorImage: UIImage?
    let currentImage: UIImage?
    let priorAttributeProfile: AttributeProfile
    let currentAttributeProfile: AttributeProfile
    let onPrimary: () -> Void
    let onShare: () -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                photoSplit
                titleBlock
                ScanBuildDeltaCard(
                    firstScan: priorAttributeProfile,
                    latestScan: currentAttributeProfile
                )
                .padding(.horizontal, 20)
                focusAreaPills
                narrativeBlock
                cadenceAnchor
                ctaBlock
            }
            .padding(.bottom, 32)
        }
        .background(Color.unbound.bg.ignoresSafeArea())
    }

    private var photoSplit: some View {
        VStack(spacing: 0) {
            photoRow(
                image: priorImage,
                label: L10n.string(.scanEvolutionPriorPhotoLabel, defaultValue: "30 DAYS AGO")
            )
            photoRow(
                image: currentImage,
                label: L10n.string(.scanEvolutionCurrentPhotoLabel, defaultValue: "TODAY")
            )
        }
    }

    private func photoRow(image: UIImage?, label: String) -> some View {
        ZStack(alignment: .topLeading) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                    .clipped()
            } else {
                Rectangle().fill(Color.unbound.surface).frame(height: 220)
            }
            Text(label)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(Color.unbound.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.unbound.bg.opacity(0.7)))
                .padding(12)
        }
    }

    private var titleBlock: some View {
        Text(L10n.string(.scanEvolutionTitle, defaultValue: "YOUR ARC EVOLVED"))
            .font(Font.unbound.displayM)
            .foregroundStyle(Color.unbound.textPrimary)
            .tracking(3)
            .animeGlow(color: Color.unbound.accent, radius: 14, intensity: 0.5)
    }

    @ViewBuilder
    private var focusAreaPills: some View {
        let regressed = currentCheckpoint.deltaFromPrior?.regressedAxes ?? []
        if !regressed.isEmpty {
            HStack(spacing: 8) {
                ForEach(regressed, id: \.self) { axis in
                    Text(L10n.format(.scanEvolutionFocusArea, defaultValue: "Watch signal · %@", axis.buildVocab))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.unbound.textTertiary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.unbound.surface))
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var narrativeBlock: some View {
        Text(currentCheckpoint.narrative)
            .font(.system(size: 15))
            .foregroundStyle(Color.unbound.textSecondary)
            .multilineTextAlignment(.leading)
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.unbound.surface))
            .padding(.horizontal, 20)
    }

    private var cadenceAnchor: some View {
        Text(L10n.string(.scanEvolutionCadence, defaultValue: "Next checkpoint in 30 days."))
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.unbound.textTertiary)
    }

    private var ctaBlock: some View {
        VStack(spacing: 12) {
            UnboundButton(title: L10n.string(.scanEvolutionPrimaryCTA, defaultValue: "BACK TO TRAINING"), action: onPrimary)
                .padding(.horizontal, 20)
            Button(action: onShare) {
                Text(L10n.string(.scanEvolutionShare, defaultValue: "Share evolution"))
                    .font(.system(size: 13))
                    .foregroundStyle(Color.unbound.textTertiary)
                    .underline()
            }
        }
    }
}
