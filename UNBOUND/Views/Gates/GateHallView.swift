import SwiftUI

/// Entry sheet (spec §6.2): full-bleed banner + centered JRPG title stack (the
/// entry ceremony), stations preview in world language, loadout pick, past
/// attempt, BEGIN.
struct GateHallView: View {
    let world: GateWorld
    let resolvedTrial: ResolvedRankTrial?     // station list for the default loadout
    let latestAttempt: OverallRankTrialAttempt?
    @State var loadout: TrialLoadout
    /// Live re-resolve the station list when the picker changes (live flow). When
    /// nil (demo fixtures) the preview falls back to `resolvedTrial`.
    var resolveStations: ((TrialLoadout) -> [ResolvedTrialStation])? = nil
    var onBegin: (TrialLoadout) -> Void
    var onClose: (() -> Void)? = nil

    private var previewStations: [ResolvedTrialStation] {
        resolveStations?(loadout) ?? resolvedTrial?.stations ?? []
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.unbound.bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 22) {
                    titleCard
                    loadoutPicker
                    stationsPreview
                    if let latestAttempt { attemptRow(latestAttempt) }
                }
                .padding(.horizontal, 18).padding(.bottom, 120)
            }
            beginBar
            if let onClose {
                Button { onClose() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.black.opacity(0.45)))
                }
                .buttonStyle(.plain)
                .padding(.top, 8).padding(.leading, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("gate-hall-close")
            }
        }
    }

    private var titleCard: some View {
        Color.clear
            .frame(height: 320)
            .overlay(Image(world.bannerAssetName).resizable().scaledToFill())
            .clipped()
            .overlay(RadialGradient(colors: [Color.black.opacity(0.1), Color.black.opacity(0.72)],
                center: .center, startRadius: 40, endRadius: 260))
            .overlay(GateEntryCeremony(world: world, onComplete: {}))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var loadoutPicker: some View {
        HStack(spacing: 8) {
            ForEach(TrialLoadout.allCases, id: \.self) { option in
                Button { loadout = option } label: {
                    Text(option.displayName.uppercased())
                        .font(Font.unbound.captionS.weight(.heavy)).tracking(1)
                        .foregroundStyle(loadout == option ? Color.unbound.bg : Color.unbound.textSecondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(Capsule().fill(loadout == option ? world.fillTint : Color.unbound.surfaceElevated))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var stationsPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("THE STATIONS").font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(1.6).foregroundStyle(Color.unbound.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Array(previewStations.enumerated()), id: \.element.id) { idx, station in
                HStack(spacing: 12) {
                    Text("\(idx + 1)").font(Font.unbound.monoS.weight(.bold))
                        .foregroundStyle(world.tint).frame(width: 20)
                    Text(station.station.title).font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Spacer(minLength: 0)
                    Text(station.selectedMovement.displayName).font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary).lineLimit(1)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.unbound.surface))
            }
        }
    }

    private func attemptRow(_ attempt: OverallRankTrialAttempt) -> some View {
        HStack(spacing: 8) {
            Image(systemName: attempt.passed ? "checkmark.seal.fill" : "xmark.seal.fill")
                .foregroundStyle(attempt.passed ? Color.unbound.success : Color.unbound.warnOrange)
            Text(attempt.passed ? "LAST: PASSED" : "LAST: HELD")
                .font(Font.unbound.captionS.weight(.heavy)).tracking(1.2)
                .foregroundStyle(attempt.passed ? Color.unbound.success : Color.unbound.warnOrange)
            Spacer(minLength: 0)
            Text(attempt.completedAt, style: .date).font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.unbound.surface))
    }

    private var beginBar: some View {
        VStack {
            Spacer()
            Button { UnboundHaptics.success(); onBegin(loadout) } label: {
                Text("BEGIN").font(Font.unbound.titleS.weight(.heavy)).tracking(2)
                    .foregroundStyle(Color.unbound.bg)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Capsule().fill(world.fillTint))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 18).padding(.bottom, 28)
            .accessibilityIdentifier("gate-hall-begin")
        }
    }
}
