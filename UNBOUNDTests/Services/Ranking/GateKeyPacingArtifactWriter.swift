import Foundation
@testable import UNBOUND

// MARK: - GateKeyPacingArtifactWriter
//
// Writes the pacing simulation's data bundle to LocalArtifacts (same root
// resolution pattern as BaselineYearSimulationArtifactWriter):
//
//   LocalArtifacts/gatekey-pacing-<timestamp>/
//     monthly-curves.csv    — per persona/month: level + attribute counts +
//                             movement counts under both pools
//     gate-turns.csv        — per persona/gate: month each requirement turns
//     candidate-grid.csv    — per persona: month each candidate
//                             movementsAtRank(count, rank) key would turn,
//                             under both pools
//     gatekey-pacing-summary.md — model assumptions + per-persona tables
//
// Root override: UNBOUND_GATEKEY_PACING_EXPORT_DIR.

struct GateKeyPacingArtifactWriter {

    func write(_ results: [PersonaPacingResult], tuning: GateKeyPacingTuning, horizonMonths: Int) throws -> URL {
        let root = try writableRoot()
        try monthlyCurvesCSV(results).write(
            to: root.appendingPathComponent("monthly-curves.csv"), atomically: true, encoding: .utf8)
        try gateTurnsCSV(results).write(
            to: root.appendingPathComponent("gate-turns.csv"), atomically: true, encoding: .utf8)
        try candidateGridCSV(results).write(
            to: root.appendingPathComponent("candidate-grid.csv"), atomically: true, encoding: .utf8)
        try summaryMarkdown(results, tuning: tuning, horizonMonths: horizonMonths).write(
            to: root.appendingPathComponent("gatekey-pacing-summary.md"), atomically: true, encoding: .utf8)
        return root
    }

    // MARK: CSVs

    private func monthlyCurvesCSV(_ results: [PersonaPacingResult]) -> String {
        var rows = [
            "persona,month,level,total_xp,"
                + "attrs_ge_veteran,attrs_ge_master,attrs_ge_vessel,"
                + "cur_movements_ge_master,cur_movements_ge_vessel,cur_movements_ge_ascendant,"
                + "wide_movements_ge_master,wide_movements_ge_vessel,wide_movements_ge_ascendant"
        ]
        for result in results {
            for row in result.months {
                rows.append([
                    result.spec.id,
                    "\(row.month)",
                    "\(row.level)",
                    String(format: "%.0f", row.totalXP),
                    "\(row.attributeCounts[.veteran] ?? 0)",
                    "\(row.attributeCounts[.master] ?? 0)",
                    "\(row.attributeCounts[.vessel] ?? 0)",
                    "\(row.currentPoolCounts[.master] ?? 0)",
                    "\(row.currentPoolCounts[.vessel] ?? 0)",
                    "\(row.currentPoolCounts[.ascendant] ?? 0)",
                    "\(row.widenedPoolCounts[.master] ?? 0)",
                    "\(row.widenedPoolCounts[.vessel] ?? 0)",
                    "\(row.widenedPoolCounts[.ascendant] ?? 0)"
                ].joined(separator: ","))
            }
        }
        return rows.joined(separator: "\n") + "\n"
    }

    private func gateTurnsCSV(_ results: [PersonaPacingResult]) -> String {
        var rows = ["persona,gate_id,gate_name,target_rank,min_level,level_month,key_id,key_label,key_month,gate_ready_month"]
        for result in results {
            for gate in result.gates {
                for key in gate.keyTurns {
                    rows.append([
                        result.spec.id,
                        gate.gateId,
                        csvEscape(gate.gateName),
                        gate.targetRank.token,
                        "\(gate.minOverallLevel)",
                        "\(gate.levelMonth)",
                        key.keyId,
                        csvEscape(key.label),
                        "\(key.month)",
                        "\(gate.readyMonth)"
                    ].joined(separator: ","))
                }
                if gate.keyTurns.isEmpty {
                    rows.append([
                        result.spec.id, gate.gateId, csvEscape(gate.gateName), gate.targetRank.token,
                        "\(gate.minOverallLevel)", "\(gate.levelMonth)", "-", "level only", "\(gate.levelMonth)",
                        "\(gate.readyMonth)"
                    ].joined(separator: ","))
                }
            }
        }
        return rows.joined(separator: "\n") + "\n"
    }

    private func candidateGridCSV(_ results: [PersonaPacingResult]) -> String {
        var rows = ["persona,pool,count,rank,month"]
        for result in results {
            for candidate in result.candidates {
                rows.append([
                    result.spec.id,
                    candidate.pool,
                    "\(candidate.count)",
                    candidate.rank.token,
                    "\(candidate.month)"
                ].joined(separator: ","))
            }
        }
        return rows.joined(separator: "\n") + "\n"
    }

    private func csvEscape(_ value: String) -> String {
        value.contains(",") ? "\"\(value)\"" : value
    }

    // MARK: Markdown summary

    private func summaryMarkdown(
        _ results: [PersonaPacingResult],
        tuning: GateKeyPacingTuning,
        horizonMonths: Int
    ) -> String {
        var lines: [String] = [
            "# Gate-Key Pacing Simulation",
            "",
            "- Generated: \(Date())",
            "- Horizon: \(horizonMonths) months, month granularity. `\(tuning.neverMonth)` = never turned within horizon.",
            "- Personas: \(results.map(\.spec.id).joined(separator: ", "))",
            "",
            "## Model assumptions and sources",
            "",
            "- Tier thresholds are the app's REAL tables, read at runtime:",
            "  `StrengthStandards.ratio/rank` (compounds + accessory families + weighted pull-up)",
            "  and each skill node's generated `tierCriteria` (SkillGraph), walked highest-first",
            "  with the app's MovementProofMatcher name gate (so variant ladders like pistol /",
            "  nordic only clear tiers this movement proves).",
            "  This harness supplies only the TIMING of when a realistic trainee reaches them.",
            "- Overall level: `OverallLevelCurve.level(forXP:)` on ~\(Int(tuning.sessionAP)) AP/session",
            "  (the curve's own year-sim calibration), sessions = trainingDays x adherence.",
            "- Attributes: monthly AP fanned through `AttributeCatalog` weight vectors into",
            "  `AttributeIngest.applyXPDeltas` (real catch-up factor + AttributeLevelCurve).",
            "  Novelty multiplier held at 1.0; whole-point quantization skipped (monthly scale).",
            "- Gate keys: `GateKeys.keys(for:)` + the real `GateKeyHistory.satisfies` logic.",
            "  Current pool mirrors `TrialReadinessService.gateKeyMovementTierPool` (2026-07-09",
            "  retune): all skill-graph skills + everything StrengthStandards ranks — compounds",
            "  incl. barbell row (variants collapse to canonical: DB bench counts as bench),",
            "  weighted pull-up, accessory FAMILIES (one family = one movement).",
            "  Widened pool: identical since the retune; kept for schema stability.",
            "- Equipment requirement assumed satisfied; `gatesAnswered` (final gate) is",
            "  structural (attempt behavior, not training) and reported as \(tuning.neverMonth).",
            "- Persona movement sets: STATIC mapping (`GateKeyPacingPersonas.movements`) of the",
            "  staples the generator prescribes per equipment/style, reusing the 7 baseline",
            "  year-sim personas' schedule/equipment/experience. The full program generator is",
            "  not run — see GateKeyPacingModel.swift for the documented mapping.",
            "- Lift timing milestones (training-age months to the app's ratio anchors):",
            "  " + milestoneLine(tuning.liftMilestoneMonths),
            "- Skill timing milestones: " + milestoneLine(tuning.skillMilestoneMonths)
                + "; feat skills (no Novice rung) shift +\(Int(tuning.featDelayMonths))mo.",
            "- Experience head start (performance only — level/attributes always start at 0):",
            "  never=0, tried=\(Int(tuning.experienceHeadStartMonths[.tried] ?? 0)),"
                + " used=\(Int(tuning.experienceHeadStartMonths[.used] ?? 0)),"
                + " current=\(Int(tuning.experienceHeadStartMonths[.current] ?? 0)) months.",
            "- Adherence: steady=\(fmt(tuning.adherenceRate[.steady])), aggressive=\(fmt(tuning.adherenceRate[.aggressive])),"
                + " inconsistent=\(fmt(tuning.adherenceRate[.inconsistent])), stressed=\(fmt(tuning.adherenceRate[.stressed])).",
            "- Emphasis training-age rate: primary=\(fmt(tuning.emphasisAgeRate[.primary])),"
                + " secondary=\(fmt(tuning.emphasisAgeRate[.secondary])), occasional=\(fmt(tuning.emphasisAgeRate[.occasional])).",
            ""
        ]

        for result in results {
            let spec = result.spec
            lines.append("## \(spec.displayName) (`\(spec.id)`)")
            lines.append("")
            lines.append("- \(Int(spec.sessionsPerWeek))x/week, adherence \(spec.adherence.rawValue), experience \(spec.experience.rawValue), \(Int(spec.bodyweightKg))kg")
            lines.append("- Movements: \(spec.movements.count) (\(spec.movements.filter { if case .lift = $0.kind { return true }; return false }.count) lifts, \(spec.movements.filter { if case .skill = $0.kind { return true }; return false }.count) skills)")
            lines.append("")
            lines.append("| Gate | Target | Level floor (mo) | Attribute key (mo) | Movement key (mo) | Ready (mo) |")
            lines.append("| --- | --- | --- | --- | --- | --- |")
            for gate in result.gates {
                let attrKey = gate.keyTurns.first { $0.keyId.hasPrefix("key-attrs") }
                let moveKey = gate.keyTurns.first { $0.keyId.hasPrefix("key-movements") }
                lines.append("| \(gate.gateName) (L\(gate.minOverallLevel)) | \(gate.targetRank.displayName) | \(gate.levelMonth) | \(keyCell(attrKey)) | \(keyCell(moveKey)) | \(gate.readyMonth) |")
            }
            lines.append("")
            lines.append("Candidate movement keys (month each `count @ rank` would turn):")
            lines.append("")
            lines.append("| Pool | " + tuning.candidateCounts.map { "\($0)" }.joined(separator: " | ") + " |")
            lines.append("| --- | " + tuning.candidateCounts.map { _ in "---" }.joined(separator: " | ") + " |")
            for rank in tuning.candidateRanks {
                for pool in ["current", "widened"] {
                    let cells = tuning.candidateCounts.map { count in
                        let month = result.candidates.first { $0.pool == pool && $0.count == count && $0.rank == rank }?.month
                        return month.map(String.init) ?? "-"
                    }
                    lines.append("| \(pool) @ \(rank.displayName) | " + cells.joined(separator: " | ") + " |")
                }
            }
            lines.append("")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private func keyCell(_ turn: PacingKeyTurn?) -> String {
        guard let turn else { return "-" }
        return "\(turn.month) (\(turn.label))"
    }

    private func milestoneLine(_ milestones: [RankTier: Double]) -> String {
        milestones
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map { "\($0.key.displayName)=\(Int($0.value))mo" }
            .joined(separator: ", ")
    }

    private func fmt(_ value: Double?) -> String {
        String(format: "%.2f", value ?? 0)
    }

    // MARK: Root resolution (BaselineYearSimulationArtifactWriter pattern)

    private func writableRoot() throws -> URL {
        let candidates = [overrideRoot(), sourceRoot(), temporaryRoot()].compactMap { $0 }
        var lastError: Error?
        for candidate in candidates {
            do {
                try FileManager.default.createDirectory(at: candidate, withIntermediateDirectories: true)
                return candidate
            } catch {
                lastError = error
            }
        }
        throw lastError ?? CocoaError(.fileWriteUnknown)
    }

    private func overrideRoot() -> URL? {
        guard let path = ProcessInfo.processInfo.environment["UNBOUND_GATEKEY_PACING_EXPORT_DIR"],
              !path.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: path, isDirectory: true)
            .appendingPathComponent("gatekey-pacing-\(timestamp())", isDirectory: true)
    }

    private func sourceRoot() -> URL {
        let sourceFile = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceFile
            .deletingLastPathComponent()   // Ranking
            .deletingLastPathComponent()   // Services
            .deletingLastPathComponent()   // UNBOUNDTests
            .deletingLastPathComponent()   // repo root
        return projectRoot
            .appendingPathComponent("LocalArtifacts", isDirectory: true)
            .appendingPathComponent("gatekey-pacing-\(timestamp())", isDirectory: true)
    }

    private func temporaryRoot() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("gatekey-pacing-\(timestamp())", isDirectory: true)
    }

    private func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}
