import Foundation

@MainActor
final class PTContextBuilder {
    static let shared = PTContextBuilder()
    private let userService = UserService.shared
    private let workoutLog = WorkoutLogService.shared
    private let preferenceService = ExercisePreferenceService.shared
    private let workingWeight = WorkingWeightService.shared
    private let progressionStore = ProgressionStateStore.shared

    private init() {}

    func buildCompact(userId: String) async -> String {
        let profile = try? await userService.fetchProfile(userId: userId)
        let logs = (try? await workoutLog.fetchRecentLogs(userId: userId, limit: 5)) ?? []
        let states = await progressionStore.fetchAll(userId: userId)
        let plateaus = await PlateauDetector.shared.detect(userId: userId, states: states)

        var md = "# Athlete context (compact)\n\n"
        md += renderProfile(profile, full: false)
        md += "\n## Last 5 sessions\n"
        md += renderLogs(logs)
        md += "\n## Active progression\n"
        md += renderStates(states.prefix(8).map { $0 })
        if !plateaus.isEmpty {
            md += "\n## Plateaus\n"
            for p in plateaus {
                md += "- \(p.displayName): \(p.stalledSessions) stalled sessions at \(formatWeight(p.currentWeightKg))kg\n"
            }
        }
        return md
    }

    func buildFull(userId: String) async -> String {
        let profile = try? await userService.fetchProfile(userId: userId)
        let logs = (try? await workoutLog.fetchRecentLogs(userId: userId, limit: 20)) ?? []
        let states = await progressionStore.fetchAll(userId: userId)
        let preferences = (try? await preferenceService.fetchPreferences(userId: userId)) ?? []
        let plateaus = await PlateauDetector.shared.detect(userId: userId, states: states)

        var md = "# Athlete context (full)\n\n"
        md += renderProfile(profile, full: true)
        md += "\n## Last 20 sessions\n"
        md += renderLogs(logs)
        md += "\n## Progression states (\(states.count))\n"
        md += renderStates(states)
        md += "\n## Exercise preferences\n"
        let avail = preferences.filter { $0.status == .available }
        let subs = preferences.filter { $0.status == .substitute }
        let avoids = preferences.filter { $0.status == .avoid }
        md += "- Available: \(avail.map(\.displayName).joined(separator: ", "))\n"
        md += "- Substitute: \(subs.map { "\($0.displayName)→\($0.substitutePreference ?? "?")" }.joined(separator: ", "))\n"
        md += "- Avoid: \(avoids.map(\.displayName).joined(separator: ", "))\n"
        if !plateaus.isEmpty {
            md += "\n## Plateaus\n"
            for p in plateaus {
                md += "- \(p.displayName): \(p.stalledSessions) stalled sessions at \(formatWeight(p.currentWeightKg))kg\n"
            }
        }
        return md
    }

    // MARK: Renderers

    private func renderProfile(_ profile: UserProfile?, full: Bool) -> String {
        guard let p = profile else { return "## Profile\n- (unknown)\n" }
        var md = "## Profile\n"
        md += "- Archetype: \(p.preferredArchetype?.rawValue ?? "unset")\n"
        if let f = p.targetFrequency { md += "- Target frequency: \(f.rawValue)\n" }
        if let e = p.experience { md += "- Experience: \(e.rawValue)\n" }
        if let w = p.weightKg { md += "- Bodyweight: \(formatWeight(w))kg\n" }
        if let h = p.heightCm { md += "- Height: \(Int(h))cm\n" }
        if full {
            if let eq = p.equipment, !eq.isEmpty {
                md += "- Equipment: \(eq.map(\.rawValue).joined(separator: ", "))\n"
            }
            if let ta = p.targetAreas, !ta.isEmpty {
                md += "- Target areas: \(ta.map(\.rawValue).joined(separator: ", "))\n"
            }
            if let o = p.obstacles, !o.isEmpty {
                md += "- Obstacles: \(o.map(\.rawValue).joined(separator: ", "))\n"
            }
            if let c = p.commitment { md += "- Commitment: \(c)/10\n" }
            if let d = p.dietQuality { md += "- Diet quality: \(d)/10\n" }
        }
        return md
    }

    private func renderLogs(_ logs: [WorkoutLog]) -> String {
        guard !logs.isEmpty else { return "- No sessions logged yet.\n" }
        var md = ""
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        for log in logs {
            md += "- **\(df.string(from: log.startedAt)) · \(log.plannedWorkoutName)**"
            if let rpe = log.overallRPE { md += " · session RPE \(rpe)" }
            md += "\n"
            for entry in log.exerciseEntries.prefix(5) where !entry.skipped {
                let top = entry.sets.filter { !$0.isWarmup }.max { ($0.weightKg ?? 0) < ($1.weightKg ?? 0) }
                if let top, let w = top.weightKg {
                    md += "    - \(entry.exerciseName): \(formatWeight(w))kg × \(top.reps)"
                    if let rpe = top.rpe { md += " @\(rpe)" }
                    md += "\n"
                } else {
                    md += "    - \(entry.exerciseName)\n"
                }
            }
        }
        return md
    }

    private func renderStates(_ states: [ProgressionState]) -> String {
        guard !states.isEmpty else { return "- No progression state yet.\n" }
        var md = ""
        for s in states {
            md += "- \(s.displayName): \(formatWeight(s.currentWorkingWeightKg))kg × \(s.targetRepMin)-\(s.targetRepMax) @RPE\(s.targetRPE) · \(s.blockType.displayName) wk\(s.weekInBlock) · streak \(s.consecutiveSessionsAtTarget)\n"
        }
        return md
    }

    private func formatWeight(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", v)
            : String(format: "%.1f", v)
    }
}
