#if DEBUG
import SwiftUI

/// Launch-arg harness for the rank-gate experience spine (spec §12). Renders any
/// gate in any spine state for screenshots — the only way the spine is reachable
/// in Plan 2 (live cutover is Plan 4). Drive headlessly with env vars
/// `UNBOUND_OPEN_GATE=<1…8>` and `UNBOUND_GATE_STAGE=<stage>`, or tap the controls.
struct GateExperienceDemoView: View {
    enum Stage: String, CaseIterable {
        case sealed, open, hall, active, beat, verdictPass, card, verdictFail, records, crossing, flow
    }
    /// The end-to-end user journey, simulated by tapping the real CTAs.
    /// Each gate plays a clip on the way IN (entrance) and on success (crossing).
    /// Pass goes straight into the animation — no separate "verdict" screen.
    enum FlowStep { case discovery, hall, entrance, active, crossing }

    @State private var format: RankTrialFormat = Self.initialFormat()
    @State private var stage: Stage = Self.initialStage()
    @State private var showCrossing = false
    @State private var flowStep: FlowStep = .discovery

    private var world: GateWorld { GateWorldCatalog.world(for: format) }
    private var definition: OverallRankTrialDefinition? {
        OverallRankTrialDefinitions.all.first { $0.format == format }
    }
    private var resolvedStations: [ResolvedTrialStation] { fixtureResolved()?.stations ?? [] }
    private var currentStationTitle: String { resolvedStations.first?.station.title ?? "The Station" }
    private var activeIndex: Int { min(1, max(resolvedStations.count - 1, 0)) }
    private var activeStationTitle: String {
        resolvedStations.indices.contains(activeIndex) ? resolvedStations[activeIndex].station.title : currentStationTitle
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            stageContent.id("\(format.rawValue)-\(stage.rawValue)")
            if stage != .flow { controls }   // flow drives itself via the real CTAs
        }
        .accessibilityIdentifier("gateExperienceDemo")
    }

    @ViewBuilder private var stageContent: some View {
        switch stage {
        case .sealed:
            scrolled { NextGateCard(readiness: fixtureReadiness(open: false), world: world) }
        case .open:
            scrolled { NextGateCard(readiness: fixtureReadiness(open: true), world: world, onBegin: {}) }
        case .hall:
            GateHallView(world: world, resolvedTrial: fixtureResolved(),
                         latestAttempt: fixtureAttempt(passed: false), loadout: .homeKit, onBegin: { _ in })
        case .active:
            GateActiveView(world: world, stationIndex: activeIndex, stationCount: max(resolvedStations.count, 1),
                           stationsCleared: activeIndex, currentStationTitle: activeStationTitle) { sampleSurface }
        case .beat:
            GateBeatOverlay(world: world, stationTitle: currentStationTitle)
        case .verdictPass:
            GateVerdictView(evaluation: fixtureEvaluation(passed: true), world: world,
                            onMintedCardTapped: { showCrossing = true })
                .fullScreenCover(isPresented: $showCrossing) {
                    TheCrossingView(crossing: GateCrossingCatalog.crossing(for: format),
                                    dateText: "Jun 13, 2026",
                                    definingNumber: "\(resolvedStations.count)/\(resolvedStations.count)",
                                    onShare: {}, onReplay: {}, onDismiss: { showCrossing = false })
                }
        case .crossing:
            TheCrossingView(crossing: GateCrossingCatalog.crossing(for: format),
                            dateText: "Jun 13, 2026",
                            definingNumber: "\(resolvedStations.count)/\(resolvedStations.count)",
                            onShare: {}, onReplay: {}, onDismiss: {})
        case .card:
            scrolled { GateCardView(world: world, dateText: "Jun 13, 2026",
                                    definingNumber: "\(resolvedStations.count)/\(resolvedStations.count)", stamped: true) }
        case .verdictFail:
            GateVerdictView(evaluation: fixtureEvaluation(passed: false), world: world)
        case .records:
            TrialRecordsShelf(progress: fixtureProgress())
        case .flow:
            flowContent
        }
    }

    /// The whole journey, end to end — each step advances on the screen's own CTA.
    @ViewBuilder private var flowContent: some View {
        switch flowStep {
        case .discovery:
            ZStack {
                Color.unbound.bg.ignoresSafeArea()
                NextGateCard(readiness: fixtureReadiness(open: true), world: world,
                             onBegin: { advance(.hall) })
                    .padding(.horizontal, 18)
            }
        case .hall:
            GateHallView(world: world, resolvedTrial: fixtureResolved(),
                         latestAttempt: nil, loadout: .homeKit, onBegin: { _ in advance(.entrance) })
        case .entrance:
            GateEntranceView(crossing: GateCrossingCatalog.crossing(for: format),
                             onFinished: { advance(.active) })
        case .active:
            GateActiveView(world: world, stationIndex: activeIndex, stationCount: max(resolvedStations.count, 1),
                           stationsCleared: activeIndex, currentStationTitle: activeStationTitle) {
                VStack(spacing: 16) {
                    sampleSurface
                    Button { advance(.crossing) } label: {
                        Text("COMPLETE TRIAL").font(Font.unbound.captionS.weight(.heavy)).tracking(1.5)
                            .foregroundStyle(Color.unbound.bg).frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Capsule().fill(world.fillTint))
                    }.buttonStyle(.plain)
                }
            }
        case .crossing:
            TheCrossingView(crossing: GateCrossingCatalog.crossing(for: format),
                            dateText: "Jun 13, 2026",
                            definingNumber: "\(resolvedStations.count)/\(resolvedStations.count)",
                            onShare: {}, onReplay: {}, onDismiss: { advance(.discovery) })
        }
    }

    private func advance(_ step: FlowStep) {
        withAnimation(.easeInOut(duration: 0.35)) { flowStep = step }
    }

    @ViewBuilder private func scrolled<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            ScrollView { content().padding(18).padding(.bottom, 120) }
        }
    }

    @ViewBuilder private var sampleSurface: some View {
        VStack(spacing: 12) {
            ForEach(resolvedStations.prefix(2), id: \.id) { rs in
                GateDemoLogCard(movement: rs.selectedMovement.displayName,
                                target: "\(rs.standard.minimumValue)", metric: metricLabel(rs.standard.metric))
            }
        }
    }

    private func metricLabel(_ m: TrainingMetricKind) -> String {
        switch m {
        case .reps: return "reps"
        case .holdSeconds, .durationSeconds: return "sec"
        case .distanceMeters: return "m"
        case .calories: return "cal"
        }
    }

    // MARK: - Fixtures (built from the real engine definitions)

    private func fixtureResolved() -> ResolvedRankTrial? {
        guard let def = definition else { return nil }
        let variant = def.loadoutVariants.first { $0.loadout == .homeKit } ?? def.loadoutVariants.first
        guard let stations = variant?.stations else { return nil }
        let resolved = stations.map {
            ResolvedTrialStation(id: $0.id, station: $0, selectedMovement: $0.primaryMovement)
        }
        return ResolvedRankTrial(id: "demo-\(format.rawValue)", definitionId: def.id, userId: "demo",
                                 selectedLoadout: variant?.loadout ?? .homeKit, stations: resolved,
                                 generatedAt: Date(), version: 1)
    }

    private func fixtureReadiness(open: Bool) -> OverallRankTrialReadiness {
        let origin = RankTier(rawValue: world.destinationRank.rawValue - 1) ?? .initiate
        var reqs: [OverallRankTrialRequirementLine] = [
            .init(id: "lvl", kind: .overallLevel, label: "Reach the level floor",
                  current: open ? "Lv 24" : "Lv 19", required: "Lv 24", isMet: open),
            .init(id: "rank", kind: .rank, label: "Build to \(world.destinationRank.displayName)",
                  current: open ? world.destinationRank.displayName : origin.displayName,
                  required: world.destinationRank.displayName, isMet: open)
        ]
        for (i, key) in GateKeys.keys(for: format).enumerated() {
            let lit = open || i == 0   // sealed: one lit fragment for contrast
            reqs.append(.init(id: key.id, kind: .gateKey, label: key.label,
                              current: lit ? "Proven" : "Unproven", required: key.label, isMet: lit))
        }
        return OverallRankTrialReadiness(
            status: open ? .ready : .locked, currentRank: origin, targetRank: world.destinationRank,
            definition: definition, resolvedTrial: fixtureResolved(),
            blockerSummary: open ? nil : "Keep training — the gate is close.",
            requirements: reqs, latestAttempt: nil)
    }

    private func fixtureEvaluation(passed: Bool) -> OverallRankTrialEvaluation {
        let stations = resolvedStations
        let lastScored = stations.lastIndex(where: { $0.station.isScored })
        let results = stations.enumerated().map { idx, rs -> OverallRankTrialStationResult in
            let fail = !passed && (lastScored.map { $0 == idx } ?? false)
            let req = rs.standard.minimumValue
            return OverallRankTrialStationResult(
                id: rs.id, title: rs.station.title, category: rs.category,
                movementId: rs.selectedMovement.movementId, required: req,
                qualifyingSetsRequired: rs.standard.minimumQualifyingSets,
                qualifyingSetsCompleted: fail ? 0 : rs.standard.minimumQualifyingSets,
                totalValue: fail ? max(0, req - 3) : req,
                failedQualityFlags: [], status: fail ? .failed : .passed,
                failureReason: fail ? "Short of the floor" : nil, isScored: rs.station.isScored)
        }
        return OverallRankTrialEvaluation(definitionId: definition?.id ?? "demo", passed: passed, stationResults: results)
    }

    private func fixtureAttempt(passed: Bool) -> OverallRankTrialAttempt? {
        guard let def = definition else { return nil }
        return OverallRankTrialAttempt(
            id: "demo-attempt-\(format.rawValue)", userId: "demo", definitionId: def.id,
            targetRank: def.targetRank, startedAt: Date(), completedAt: Date(),
            performanceLogId: "demo-log", passed: passed, movementAPGained: 0, overallLevelXPGained: 0)
    }

    private func fixtureProgress() -> OverallRankTrialProgress {
        let passedFormats: Set<RankTrialFormat> = [.firstLight, .theCount, .theForging]
        let recorded: Set<RankTrialFormat> = passedFormats.union([.deckOfProof])
        let attempts = OverallRankTrialDefinitions.all.compactMap { def -> OverallRankTrialAttempt? in
            guard recorded.contains(def.format) else { return nil }
            return OverallRankTrialAttempt(
                id: "demo-rec-\(def.format.rawValue)", userId: "demo", definitionId: def.id,
                targetRank: def.targetRank, startedAt: Date(), completedAt: Date(),
                performanceLogId: "demo-rec-log-\(def.format.rawValue)",
                passed: passedFormats.contains(def.format), movementAPGained: 0, overallLevelXPGained: 0)
        }
        return OverallRankTrialProgress(highestPassedRank: .forged, attempts: attempts)
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 8) {
            Picker("Stage", selection: $stage) {
                ForEach(Stage.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.menu)
            HStack {
                Button("◀") { cycle(-1) }
                Spacer(minLength: 0)
                Text("GATE \(world.numeral) — \(world.trialName)")
                    .font(Font.unbound.captionS.weight(.bold)).foregroundStyle(Color.unbound.textPrimary)
                Spacer(minLength: 0)
                Button("▶") { cycle(1) }
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(12)
    }

    private func cycle(_ d: Int) {
        let all = RankTrialFormat.allCases
        let i = ((all.firstIndex(of: format) ?? 0) + d + all.count) % all.count
        format = all[i]
    }

    private static func initialFormat() -> RankTrialFormat {
        let env = ProcessInfo.processInfo.environment
        if let raw = env["UNBOUND_OPEN_GATE"] ?? env["UNBOUND_OPEN_CROSSING"] ?? env["UNBOUND_GATE_FLOW"],
           let n = Int(raw), (1...8).contains(n) { return RankTrialFormat.allCases[n - 1] }
        return .firstLight
    }

    private static func initialStage() -> Stage {
        let env = ProcessInfo.processInfo.environment
        if let raw = env["UNBOUND_GATE_STAGE"], let s = Stage(rawValue: raw) { return s }
        if env["UNBOUND_GATE_FLOW"] != nil { return .flow }
        if env["UNBOUND_OPEN_CROSSING"] != nil { return .crossing }
        return .sealed
    }
}

/// Lightweight stand-in for the calm true-black logging surface, just for Plan 2
/// screenshots. Plan 4 injects the real ExerciseLogCard grid into GateActiveView.
private struct GateDemoLogCard: View {
    let movement: String
    let target: String
    let metric: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(movement).font(Font.unbound.bodyLStrong).foregroundStyle(Color.unbound.textPrimary)
            HStack {
                Text("TARGET").font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.4).foregroundStyle(Color.unbound.textTertiary)
                Spacer(minLength: 0)
                Text("\(target) \(metric)").font(Font.unbound.monoL).foregroundStyle(Color.unbound.textPrimary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.unbound.surface))
    }
}
#endif
