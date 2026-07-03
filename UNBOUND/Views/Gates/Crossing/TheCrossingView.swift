import SwiftUI

/// The Crossing — the rank-up cinematic for an overall-rank gate (spec §8).
/// Replaces the static RankUpCinematic for gate crossings. Build-alongside in
/// Plan 3: reachable via the demo harness + the verdict's minted-card tap; the
/// live cutover (presenting on a real gate pass) is Plan 4.
///
/// Runs on the resolved threshold still (CrossingAssetResolver) with a Ken Burns
/// push-in + native particles — also the spec's reduced-motion/offline fallback,
/// so it is fully functional with zero generated assets. The Seedance i2v clip
/// "walk" is a Plan-4 seam.
struct TheCrossingView: View {
    let crossing: GateCrossing
    var dateText: String? = nil
    var definingNumber: String? = nil
    var onReplay: (() -> Void)? = nil
    var onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Beat { case hush, walk, investiture, spoils }
    @State private var beat: Beat = .hush
    @State private var kenBurns = false
    @State private var titleShown = false
    @State private var montageIndex = 0
    @State private var shareSheetItems: [Any]? = nil

    private var still: String { CrossingAssetResolver.thresholdStill(for: crossing) }
    private var clipURL: URL? { CrossingAssetResolver.crossingClipURL(for: crossing) }
    private var b: (hush: Double, walk: Double, arrival: Double, investiture: Double) { crossing.tier.beats }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if beat != .hush {
                if beat == .walk, !reduceMotion, let url = clipURL {
                    stillLayer   // base, revealed when the clip crossfades out
                    CrossingClipLayer(url: url).ignoresSafeArea().transition(.opacity)
                } else if beat == .walk, crossing.tier == .finale {
                    montageLayer
                } else {
                    stillLayer
                }
            }

            if beat == .investiture || beat == .spoils {
                CrossingParticles(tint: crossing.tint, reduceMotion: reduceMotion)
            }

            // Center scrim — keeps the badge + title legible over any world hue.
            if beat == .investiture || beat == .spoils {
                RadialGradient(colors: [Color.black.opacity(0.6), .clear],
                               center: .center, startRadius: 40, endRadius: 380)
                    .ignoresSafeArea().allowsHitTesting(false)
            }

            content
        }
        .contentShape(Rectangle())
        .onTapGesture { if beat == .spoils { onDismiss() } }
        .task { await run() }
        .accessibilityIdentifier("the-crossing")
        .sheet(isPresented: Binding(
            get: { shareSheetItems != nil },
            set: { if !$0 { shareSheetItems = nil } }
        )) {
            if let items = shareSheetItems {
                ShareSheet(items: items)
            }
        }
    }

    // MARK: Layers

    private var stillLayer: some View {
        Image(still).resizable().scaledToFill()
            .scaleEffect(reduceMotion ? 1.0 : (kenBurns ? 1.15 : 1.0))
            .ignoresSafeArea()
            .clipped()
            .overlay(LinearGradient(colors: [.clear, Color.black.opacity(0.55), Color.black.opacity(0.9)],
                                    startPoint: .top, endPoint: .bottom).ignoresSafeArea())
            .overlay(RadialGradient(colors: [crossing.tint.opacity(0.14), .clear],
                                    center: .center, startRadius: 30, endRadius: 320)
                        .blendMode(.screen).ignoresSafeArea())
    }

    /// Finale: flash through all eight stamped gate cards, then the gold flood.
    private var montageLayer: some View {
        let cards = GateWorldCatalog.allOrdered
        return ZStack {
            Color.black.ignoresSafeArea()
            if montageIndex < cards.count {
                GateCardView(world: cards[montageIndex], dateText: nil,
                             definingNumber: cards[montageIndex].numeral, stamped: true)
                    .padding(.horizontal, 36)
                    .transition(.opacity)
                    .id(montageIndex)
            }
        }
    }

    private var showsReveal: Bool { beat == .investiture || beat == .spoils }

    private var content: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            // Hero + spoils centered as ONE group so the badge stays centered
            // even after the card appears.
            VStack(spacing: 22) {
                if showsReveal && titleShown {
                    VStack(spacing: 14) {
                        Text("RANK GATE \(crossing.world.numeral)")
                            .font(Font.unbound.captionS.weight(.heavy)).tracking(4)
                            .foregroundStyle(crossing.tint)
                            .shadow(color: .black.opacity(0.9), radius: 5, y: 1)
                        Image(crossing.world.destinationRank.assetName)
                            .resizable().scaledToFit()
                            .frame(width: 168, height: 168)
                            .shadow(color: .black.opacity(0.5), radius: 12, y: 3)
                            .shadow(color: crossing.fillTint.opacity(0.85), radius: 34)
                            .shadow(color: crossing.fillTint.opacity(0.45), radius: 72)
                        Text(crossing.investitureTitle)
                            .font(.system(size: 54, weight: .black)).tracking(6)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .minimumScaleFactor(0.5).lineLimit(1)
                            .shadow(color: .black.opacity(0.9), radius: 10, y: 2)
                            .shadow(color: crossing.fillTint.opacity(0.6), radius: 30)
                        Text(crossing.dwellLine)
                            .font(Font.unbound.bodyMStrong).foregroundStyle(crossing.tint)
                            .multilineTextAlignment(.center)
                            .shadow(color: .black.opacity(0.9), radius: 5, y: 1)
                    }
                    .frame(maxWidth: .infinity)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.85).combined(with: .opacity))
                }

                if beat == .spoils {
                    spoils.transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24).padding(.vertical, 40)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var spoils: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                Text(crossing.unlockChip).font(Font.unbound.captionS.weight(.heavy)).tracking(1.4)
            }
            .foregroundStyle(crossing.tint)
            .shadow(color: .black.opacity(0.6), radius: 3, y: 1)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Capsule().fill(Color.unbound.surface))

            GateCardView(world: crossing.world, dateText: dateText,
                         definingNumber: definingNumber, stamped: true)
                .frame(maxWidth: 360)

            HStack(spacing: 12) {
                if let onReplay {
                    Button { onReplay(); Task { await run() } } label: {
                        Label("REPLAY", systemImage: "arrow.counterclockwise")
                            .font(Font.unbound.captionS.weight(.bold)).tracking(1)
                            .foregroundStyle(Color.unbound.textSecondary)
                    }.buttonStyle(.plain)
                }
                Button { presentShare() } label: {
                    Label("SHARE", systemImage: "square.and.arrow.up")
                        .font(Font.unbound.captionS.weight(.heavy)).tracking(1)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .padding(.horizontal, 18).padding(.vertical, 10)
                        .background(Capsule().fill(Color.unbound.surface))
                        .overlay(Capsule().strokeBorder(crossing.tint.opacity(0.5), lineWidth: 1))
                }.buttonStyle(.plain)
                .accessibilityIdentifier("crossing-share")
            }

            Button { onDismiss() } label: {
                Text("CONTINUE")
                    .font(Font.unbound.captionS.weight(.heavy)).tracking(1.5)
                    .foregroundStyle(Color.unbound.bg)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Capsule().fill(crossing.fillTint))
            }
            .buttonStyle(.plain)
            .frame(maxWidth: 360)
            .accessibilityIdentifier("crossing-continue")
        }
    }

    /// Renders the minted gate card into a 2:3 share image + caption. The card
    /// stamps today's date when the presenter didn't pass one (the live pass
    /// path presents The Crossing the moment the gate is answered).
    private func presentShare() {
        let mintDate = dateText ?? Date().formatted(date: .abbreviated, time: .omitted)
        var items: [Any] = []
        if let image = CrossingShareCardRenderer.render(
            crossing: crossing,
            dateText: mintDate,
            definingNumber: definingNumber
        ) {
            items.append(image)
        }
        items.append(CrossingShareCardRenderer.caption(crossing: crossing))
        shareSheetItems = items
    }

    // MARK: Beat timeline

    @MainActor private func run() async {
        beat = .hush; kenBurns = false; titleShown = false; montageIndex = 0
        UnboundHaptics.soft()
        await sleep(b.hush)

        withAnimation(.easeOut(duration: 0.4)) { beat = .walk }
        if !reduceMotion, clipURL != nil {
            await sleep(4.1)   // the Seedance walk clip (~4s) plays, then we settle
        } else if crossing.tier == .finale {
            await runMontage()
        } else if !reduceMotion {
            withAnimation(.easeOut(duration: b.walk)) { kenBurns = true }
            await sleep(b.walk)
        } else {
            await sleep(b.walk * 0.5)
        }

        withAnimation(.easeInOut(duration: 0.5)) { beat = .investiture }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.68).delay(0.15)) { titleShown = true }
        UnboundHaptics.heavy()
        await sleep(b.arrival + b.investiture)

        withAnimation(.easeInOut(duration: 0.5)) { beat = .spoils }
        UnboundHaptics.success()
    }

    @MainActor private func runMontage() async {
        for i in 0..<GateWorldCatalog.allOrdered.count {
            withAnimation(.easeInOut(duration: 0.18)) { montageIndex = i }
            if i % 2 == 0 { UnboundHaptics.soft() }
            await sleep(crossing.tier.montageCardInterval)
        }
    }

    private func sleep(_ seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
    }
}

// MARK: - Share sheet bridge

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
