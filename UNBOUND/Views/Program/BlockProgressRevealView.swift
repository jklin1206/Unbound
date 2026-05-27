import SwiftUI

// MARK: - BlockProgressRevealView
//
// Sheet shown from the block-complete state when the user has a fresh
// `ScanDeltaReport`. Renders checkpoint proof signals, a short narrative,
// and a share affordance.
//
// Sharing: the card body is rendered to a UIImage via SwiftUI's
// `ImageRenderer` and exposed through `ShareLink`. This is the viral moment
// of the rollover flow — keep the surface clean and shareable.
//
// Constraint per `project_unbound_no_match_percent` and
// `project_unbound_scans_never_show_setbacks`:
//   - No match-percent UI.
//   - No body-part grading or negative setback numbers.

struct BlockProgressRevealView: View {
    let deltaReport: ScanDeltaReport
    let blockNumber: Int
    let nextBlockNumber: Int
    let onBuildNextBlock: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var renderedShareURL: URL?

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    shareableCard
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(Color.unbound.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .strokeBorder(Color.unbound.border, lineWidth: 1)
                        )
                    actions
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 32)
            }
        }
        .task { renderedShareURL = renderShareImage() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("BLOCK \(blockNumber) COMPLETE")
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .tracking(2.4)
                .foregroundStyle(Color.unbound.accent)
            Text("Checkpoint recap")
                .font(Font.unbound.titleL)
                .foregroundStyle(Color.unbound.textPrimary)
        }
    }

    // MARK: - Shareable card

    private var shareableCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            proofSignals
            if !deltaReport.narrative.isEmpty {
                narrativeBlock
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var proofSignals: some View {
        let signals = deltaReport.improvements.isEmpty
            ? ["Training proof logged"]
            : deltaReport.improvements.map { $0.capitalized }
        return VStack(alignment: .leading, spacing: 12) {
            Text("PROOF SIGNALS")
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .tracking(1.8)
                .foregroundStyle(Color.unbound.textTertiary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(signals, id: \.self) { signal in
                    proofCell(signal)
                }
            }

            Text(deltaReport.recommendedFocus)
                .font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
    }

    private func proofCell(_ title: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.unbound.success)
            Text(title.uppercased())
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.1)
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.unbound.success.opacity(0.24), lineWidth: 1)
        )
    }

    private var narrativeBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR ARC")
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .tracking(1.8)
                .foregroundStyle(Color.unbound.textTertiary)
            Text(deltaReport.narrative)
                .font(Font.unbound.bodyL)
                .foregroundStyle(Color.unbound.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
        }
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 12) {
            if let url = renderedShareURL {
                ShareLink(
                    item: url,
                    preview: SharePreview("Block \(blockNumber) — UNBOUND", image: Image(systemName: "bolt.fill"))
                ) {
                    actionLabel(
                        title: "SHARE PROGRESS",
                        systemImage: "square.and.arrow.up",
                        background: Color.unbound.surface,
                        border: Color.unbound.borderSubtle,
                        textColor: Color.unbound.textPrimary
                    )
                }
                .buttonStyle(.plain)
            }

            Button {
                UnboundHaptics.soft()
                onBuildNextBlock()
            } label: {
                actionLabel(
                    title: "BUILD BLOCK \(nextBlockNumber)",
                    systemImage: "bolt.fill",
                    background: Color.unbound.accent,
                    border: nil,
                    textColor: Color.unbound.textPrimary
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func actionLabel(
        title: String,
        systemImage: String,
        background: Color,
        border: Color?,
        textColor: Color
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .bold))
            Text(title)
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .tracking(1.6)
        }
        .foregroundStyle(textColor)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(border ?? .clear, lineWidth: border == nil ? 0 : 1)
        )
    }

    // MARK: - Share image render

    @MainActor
    private func renderShareImage() -> URL? {
        let card = shareableCardForRender
            .frame(width: 1080)
            .background(Color.unbound.bg)
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 2.0
        guard let image = renderer.uiImage,
              let data = image.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("unbound-block-\(blockNumber)-\(Int(Date().timeIntervalSince1970)).png")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    /// Render-only variant: identical layout, but with a banner header so the
    /// shared image is self-contained when it lands on someone's feed.
    private var shareableCardForRender: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("UNBOUND · BLOCK \(blockNumber)")
                    .font(.system(size: 14, weight: .heavy, design: .monospaced))
                    .tracking(2.4)
                    .foregroundStyle(Color.unbound.accent)
                Text("28 days. Logged.")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(Color.unbound.textPrimary)
            }
            shareableCard
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.unbound.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.unbound.border, lineWidth: 1)
                )
        }
        .padding(40)
    }
}
