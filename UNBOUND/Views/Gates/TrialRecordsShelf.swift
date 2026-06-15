import SwiftUI

/// Trial Records (spec §6.8): every gate card + attempt history. Reads
/// `OverallRankTrialProgress.attempts`; one `GateCardView` per gate at its best
/// state (stamped if any passing attempt). Replayable Crossings are Plan 3.
struct TrialRecordsShelf: View {
    let progress: OverallRankTrialProgress
    var onSelectGate: ((RankTrialFormat) -> Void)? = nil

    private func definition(for format: RankTrialFormat) -> OverallRankTrialDefinition? {
        OverallRankTrialDefinitions.all.first { $0.format == format }
    }

    private func attempts(for format: RankTrialFormat) -> [OverallRankTrialAttempt] {
        guard let def = definition(for: format) else { return [] }
        return progress.attempts.filter { def.matchesAttemptDefinitionId($0.definitionId) }
    }

    private func bestAttempt(for format: RankTrialFormat) -> OverallRankTrialAttempt? {
        let all = attempts(for: format)
        return all.first(where: \.passed) ?? all.sorted { $0.completedAt > $1.completedAt }.first
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("TRIAL RECORDS").font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(2).foregroundStyle(Color.unbound.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(RankTrialFormat.allCases, id: \.self) { format in
                    let world = GateWorldCatalog.world(for: format)
                    let attempt = bestAttempt(for: format)
                    Button { onSelectGate?(format) } label: {
                        GateCardView(
                            world: world,
                            dateText: attempt.map { DateFormatter.gateShort.string(from: $0.completedAt) },
                            definingNumber: nil,
                            stamped: attempt?.passed ?? false,
                            attemptCount: attempt == nil ? nil : attempts(for: format).count)
                    }
                    .buttonStyle(.plain)
                    .opacity(attempt == nil ? 0.5 : 1)
                }
            }
            .padding(18)
        }
        .background(Color.unbound.bg.ignoresSafeArea())
        .accessibilityIdentifier("trial-records-shelf")
    }
}

private extension DateFormatter {
    static let gateShort: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none; return f
    }()
}
