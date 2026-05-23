import SwiftUI

// MARK: - BlockProgressRevealView
//
// Sheet shown from the block-complete state when the user has a fresh
// `ScanDeltaReport`. Renders a 6-cell before/after grid (shoulders, chest,
// arms, core, legs, overall), a short narrative, and a share affordance.
//
// Style follows `Step_Verdict.swift`'s `gradeCell` — large monospaced score,
// thin colored bar at the bottom. Two columns side by side: BEFORE on the
// left, AFTER on the right, with a delta chip between them.
//
// Sharing: the card body is rendered to a UIImage via SwiftUI's
// `ImageRenderer` and exposed through `ShareLink`. This is the viral moment
// of the rollover flow — keep the surface clean and shareable.
//
// Constraint per `project_unbound_no_match_percent` and
// `project_unbound_scans_never_show_setbacks`:
//   - No match-percent UI.
//   - Lagging areas are reframed as "FOCUS NEXT" tags, never as a regression.

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
            Text("Side-by-side")
                .font(Font.unbound.titleL)
                .foregroundStyle(Color.unbound.textPrimary)
        }
    }

    // MARK: - Shareable card

    private var shareableCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            scoreGrid
            if !deltaReport.narrative.isEmpty {
                narrativeBlock
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var scoreGrid: some View {
        let cells: [(String, BodyPartDelta)] = [
            ("SHOULDERS", deltaReport.shoulders),
            ("CHEST",     deltaReport.chest),
            ("ARMS",      deltaReport.arms),
            ("CORE",      deltaReport.core),
            ("LEGS",      deltaReport.legs),
            ("OVERALL",   deltaReport.overall)
        ]
        return VStack(spacing: 10) {
            HStack(spacing: 8) {
                Text("BEFORE")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer().frame(width: 28)
                Text("AFTER")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.accent)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            VStack(spacing: 10) {
                ForEach(cells, id: \.0) { label, delta in
                    deltaRow(label: label, delta: delta)
                }
            }
        }
    }

    private func deltaRow(label: String, delta: BodyPartDelta) -> some View {
        HStack(spacing: 8) {
            scoreCell(
                label: label,
                value: delta.before,
                accent: Color.unbound.textSecondary,
                isAfter: false
            )
            deltaChip(delta: delta.delta)
                .frame(width: 28)
            scoreCell(
                label: label,
                value: delta.after,
                accent: Color.unbound.accent,
                isAfter: true
            )
        }
    }

    private func scoreCell(
        label: String,
        value: Int,
        accent: Color,
        isAfter: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 6)
            Text("\(value)")
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1)
                .monospacedDigit()
            Spacer(minLength: 10)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.unbound.borderSubtle)
                        .frame(height: 3)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(accent)
                        .frame(
                            width: max(0, min(CGFloat(value) / 10.0, 1.0)) * proxy.size.width,
                            height: 3
                        )
                        .shadow(color: accent.opacity(isAfter ? 0.55 : 0.0), radius: 4)
                }
            }
            .frame(height: 3)
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isAfter ? Color.unbound.accent.opacity(0.32) : Color.unbound.borderSubtle,
                    lineWidth: 1
                )
        )
    }

    private func deltaChip(delta: Int) -> some View {
        // Per scans-never-show-setbacks: if delta is zero or negative we
        // surface "→" (held the line) instead of a negative number. Only
        // positive deltas read as numeric gains.
        let label: String
        let tint: Color
        if delta > 0 {
            label = "+\(delta)"
            tint = Color.unbound.success
        } else {
            label = "→"
            tint = Color.unbound.textTertiary
        }
        return Text(label)
            .font(.system(size: 13, weight: .heavy, design: .monospaced))
            .tracking(0.8)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(0.12))
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
