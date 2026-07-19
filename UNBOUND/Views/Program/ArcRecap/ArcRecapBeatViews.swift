import SwiftUI
import UIKit

// MARK: - Arc recap beat pages
//
// One view per beat of ArcRecapSequenceView. Visual language mirrors the
// post-workout reward sequence: dark backdrop, mono numerals, count-ups,
// the shared hex, and real exercise art.

// MARK: Photo (before / now)

struct ArcRecapPhotoBeat: View {
    let summary: ArcRecapSummary
    let photoTaken: Bool
    let onAddPhoto: () -> Void

    @EnvironmentObject private var services: ServiceContainer
    @State private var beforeImage: UIImage?
    @State private var nowImage: UIImage?

    private var hasBefore: Bool { beforeImage != nil }

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            beatKicker("ARC \(summary.blockNumber) COMPLETE")
            Text("Mark the moment.")
                .font(Font.unbound.titleM)
                .foregroundStyle(Color.unbound.textPrimary)
                .multilineTextAlignment(.center)
            Text(hasBefore ? "30 days between these frames." : "Capture where you stand.")
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)

            HStack(spacing: 14) {
                if let beforeImage {
                    photoPane(
                        image: beforeImage,
                        label: beforeLabel,
                        tint: Color.unbound.textTertiary
                    )
                }
                Button(action: photoTaken ? {} : onAddPhoto) {
                    if let nowImage {
                        photoPane(image: nowImage, label: "TODAY", tint: Color.unbound.success)
                    } else {
                        capturePane
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 6)
            Spacer()
        }
        .padding(.horizontal, 24)
        .onAppear(perform: loadBeforeImage)
        .onChange(of: photoTaken) { _, taken in
            guard taken else { return }
            Task { await loadNowImage() }
        }
    }

    private var beforeLabel: String {
        guard let date = summary.beforePhotoDate else { return "BEFORE" }
        return date.formatted(.dateTime.month(.abbreviated).day()).uppercased()
    }

    private var paneSize: CGSize { CGSize(width: hasBefore ? 148 : 168, height: hasBefore ? 196 : 214) }

    private func photoPane(image: UIImage, label: String, tint: Color) -> some View {
        VStack(spacing: 8) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: paneSize.width, height: paneSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                )
            Text(label)
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.2)
                .foregroundStyle(tint)
        }
    }

    private var capturePane: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        photoTaken ? Color.unbound.success.opacity(0.6) : Color.white.opacity(0.22),
                        style: StrokeStyle(lineWidth: 1.5, dash: photoTaken ? [] : [6, 5])
                    )
                    .frame(width: paneSize.width, height: paneSize.height)
                VStack(spacing: 10) {
                    Image(systemName: photoTaken ? "checkmark.circle.fill" : "camera.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(photoTaken ? Color.unbound.success : Color.unbound.textSecondary)
                    Text(photoTaken ? "SAVED" : "ADD TODAY")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.2)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
            }
            Text("NOW")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.2)
                .foregroundStyle(Color.unbound.textTertiary)
        }
    }

    private func loadBeforeImage() {
        guard beforeImage == nil, let path = summary.beforePhotoPath else { return }
        beforeImage = UIImage(contentsOfFile: URL(fileURLWithPath: path).path)
            ?? UIImage(contentsOfFile: path)
    }

    private func loadNowImage() async {
        let photos: [ProgressPhoto] = (try? await services.database.query(
            collection: "progressPhotos",
            field: "userId",
            isEqualTo: summary.userId,
            orderBy: "capturedAt",
            descending: true,
            limit: 1
        )) ?? []
        guard let latest = photos.first else { return }
        nowImage = UIImage(contentsOfFile: URL(fileURLWithPath: latest.storageUrl).path)
            ?? UIImage(contentsOfFile: latest.storageUrl)
    }
}

// MARK: What the Arc built (hex + stats)

struct ArcRecapBuildBeat: View {
    let summary: ArcRecapSummary
    @State private var progress: Double = 0
    @State private var revealed = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            beatKicker("WHAT ARC \(summary.blockNumber) BUILT")

            AnimatedRewardAttributeHex(
                previous: summary.attributeHexBefore ?? summary.attributeHexAfter,
                current: summary.attributeHexAfter,
                progress: progress,
                radius: 100
            )
            .frame(height: 230)

            if let deltas = summary.attributeLevelDeltas {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    ForEach(AttributeKey.allCases, id: \.self) { key in
                        attributeDeltaCell(key: key, delta: deltas[key] ?? 0)
                    }
                }
                .padding(.horizontal, 8)
            }

            HStack(spacing: 12) {
                recapReadout(
                    label: "SESSIONS",
                    value: revealed ? Double(summary.trainedSessions) : 0,
                    suffix: nil
                )
                recapReadout(
                    label: "VOLUME",
                    value: revealed ? WeightPlatePolicy.currentUnit.displayValue(fromKilograms: summary.totalVolumeKg) : 0,
                    suffix: WeightPlatePolicy.currentUnit.shortLabel.uppercased()
                )
                recapReadout(
                    label: "XP",
                    value: revealed ? summary.xpGained : 0,
                    suffix: nil
                )
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).delay(0.35)) { progress = 1 }
            withAnimation(.easeOut(duration: 1.1).delay(0.3)) { revealed = true }
        }
    }

    private func attributeDeltaCell(key: AttributeKey, delta: Int) -> some View {
        VStack(spacing: 4) {
            Text(key.shortCode)
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.1)
                .foregroundStyle(Color.unbound.textTertiary)
            Text(delta > 0 ? "+\(delta)" : "HELD")
                .font(Font.unbound.monoM.weight(.heavy))
                .foregroundStyle(delta > 0 ? Color.unbound.accent : Color.unbound.textTertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(delta > 0 ? 0.08 : 0.04))
        )
    }
}

// MARK: Highlights

struct ArcRecapHighlightsBeat: View {
    let summary: ArcRecapSummary
    @State private var revealedCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            beatKicker("NOTABLE")
            Text("Arc \(summary.blockNumber)'s best work.")
                .font(Font.unbound.titleM)
                .foregroundStyle(Color.unbound.textPrimary)

            VStack(spacing: 10) {
                ForEach(Array(summary.highlights.enumerated()), id: \.element.id) { index, highlight in
                    highlightRow(highlight)
                        .opacity(index < revealedCount ? 1 : 0)
                        .offset(y: index < revealedCount ? 0 : 14)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .onAppear {
            for index in summary.highlights.indices {
                withAnimation(.easeOut(duration: 0.4).delay(0.25 + Double(index) * 0.22)) {
                    revealedCount = index + 1
                }
            }
        }
    }

    private func highlightRow(_ highlight: ArcRecapHighlight) -> some View {
        HStack(spacing: 14) {
            highlightArt(highlight)

            VStack(alignment: .leading, spacing: 2) {
                Text(highlight.title)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                Text(highlight.detail)
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(0.6)
                    .foregroundStyle(Color.rewardBlue)
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    /// Movement highlights show the real exercise art; trials and streaks
    /// keep their emblem icons.
    @ViewBuilder
    private func highlightArt(_ highlight: ArcRecapHighlight) -> some View {
        if highlight.kind == .loadUp || highlight.kind == .repUp,
           let definition = MovementCatalog.canonicalExercise(named: highlight.title) {
            ExerciseVisualView(definition: definition, size: .thumbnail)
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            Image(systemName: highlight.icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(highlight.kind == .trialPassed ? Color.unbound.rankGold : Color.unbound.ember)
                .frame(width: 52, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
        }
    }
}

// MARK: System calibration (difficulty offer)

struct ArcRecapSystemCalibrationBeat: View {
    let summary: ArcRecapSummary
    /// Non-nil when a harder tier exists above the current one.
    let raisedExperience: Experience?
    @Binding var escalate: Bool
    let canAdjustSetup: Bool
    let onAdjustSetup: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("[ SYSTEM ]")
                .font(Font.unbound.monoS.weight(.heavy))
                .tracking(2.4)
                .foregroundStyle(Color.unbound.coachCyan)
            Text("Arc \(summary.blockNumber) cleared.")
                .font(Font.unbound.titleM)
                .foregroundStyle(Color.unbound.textPrimary)

            if raisedExperience != nil {
                Text("Calibrate Arc \(summary.nextArcNumber).")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)

                VStack(spacing: 10) {
                    calibrationCard(
                        title: "RAISE THE DIFFICULTY",
                        detail: "Harder variations enter. Loads still ramp at your pace.",
                        icon: "arrow.up.circle.fill",
                        selected: escalate
                    ) { escalate = true }
                    calibrationCard(
                        title: "HOLD CALIBRATION",
                        detail: "Keep the current pace.",
                        icon: "equal.circle.fill",
                        selected: !escalate
                    ) { escalate = false }
                }
            }

            if canAdjustSetup {
                Button(action: onAdjustSetup) {
                    HStack(spacing: 8) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 13, weight: .bold))
                        Text("Adjust setup")
                            .font(Font.unbound.captionS.weight(.bold))
                            .tracking(0.6)
                    }
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func calibrationCard(
        title: String,
        detail: String,
        icon: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            UnboundHaptics.soft()
            action()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(selected ? Color.unbound.coachCyan : Color.unbound.textTertiary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.1)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text(detail)
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(selected ? Color.unbound.coachCyan : Color.unbound.textTertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selected ? Color.unbound.coachCyan.opacity(0.10) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        selected ? Color.unbound.coachCyan.opacity(0.5) : Color.white.opacity(0.1),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: Building

struct ArcRecapBuildingBeat: View {
    let nextBlockNumber: Int

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            ArcWritingSigil()
            Text("[ SYSTEM ]")
                .font(Font.unbound.monoS.weight(.heavy))
                .tracking(2.4)
                .foregroundStyle(Color.unbound.coachCyan)
            Text("Writing Arc \(nextBlockNumber).")
                .font(Font.unbound.titleM)
                .foregroundStyle(Color.unbound.textPrimary)
            Text("Thirty days, built from what you logged.")
                .font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textTertiary)
            Spacer()
        }
    }
}

/// The recap's own loading mark — twin counter-rotating arcs echoing the
/// backdrop's sigil ring, with a breathing core. No system spinner.
private struct ArcWritingSigil: View {
    @State private var spinOuter = false
    @State private var spinInner = false
    @State private var breathe = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.unbound.rankGold.opacity(0.14), lineWidth: 1.5)
                .frame(width: 92, height: 92)

            Circle()
                .trim(from: 0, to: 0.34)
                .stroke(
                    AngularGradient(
                        colors: [Color.unbound.rankGold.opacity(0), Color.unbound.rankGold],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                .frame(width: 92, height: 92)
                .rotationEffect(.degrees(spinOuter ? 360 : 0))
                .animation(.linear(duration: 2.6).repeatForever(autoreverses: false), value: spinOuter)

            Circle()
                .trim(from: 0, to: 0.22)
                .stroke(
                    AngularGradient(
                        colors: [Color.unbound.accent.opacity(0), Color.unbound.accent],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .frame(width: 64, height: 64)
                .rotationEffect(.degrees(spinInner ? -360 : 0))
                .animation(.linear(duration: 1.9).repeatForever(autoreverses: false), value: spinInner)

            Image(systemName: "bolt.fill")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Color.unbound.rankGold)
                .scaleEffect(breathe ? 1.12 : 0.9)
                .opacity(breathe ? 1 : 0.55)
                .animation(.easeInOut(duration: 1.05).repeatForever(autoreverses: true), value: breathe)
        }
        .onAppear {
            spinOuter = true
            spinInner = true
            breathe = true
        }
    }
}

// MARK: Shared bits

private func beatKicker(_ text: String) -> some View {
    Text(text)
        .font(Font.unbound.captionS.weight(.heavy))
        .tracking(2.2)
        .foregroundStyle(Color.rewardBlue)
        .frame(maxWidth: .infinity, alignment: .center)
}

private func recapReadout(
    label: String,
    value: Double,
    suffix: String?
) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(label)
            .font(Font.unbound.captionS.weight(.heavy))
            .tracking(1.2)
            .foregroundStyle(Color.unbound.textTertiary)
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            CountUpNumberText(value: value)
                .font(Font.unbound.monoM.weight(.heavy))
                .foregroundStyle(Color.unbound.textPrimary)
            if let suffix {
                Text(suffix)
                    .font(Font.unbound.captionS.weight(.heavy))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
        }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.white.opacity(0.06))
    )
}
