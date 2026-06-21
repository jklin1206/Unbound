import XCTest
@testable import UNBOUND

struct BaselineYearSimulationArtifactWriter {
    func write(_ report: YearSimulationReport) throws -> URL {
        let root = try writableRoot()

        try writeJSON(report, to: root.appendingPathComponent("\(report.simulationDays)-day-program-export.json"))
        try writeJSON(report.personaRuns.map(\.persona), to: root.appendingPathComponent("personas.json"))
        try markdownSummary(report).write(
            to: root.appendingPathComponent("year-simulation-summary.md"),
            atomically: true,
            encoding: .utf8
        )
        try violationsMarkdown(report).write(
            to: root.appendingPathComponent("constraint-violations.md"),
            atomically: true,
            encoding: .utf8
        )
        try weeklyVolumeCSV(report).write(
            to: root.appendingPathComponent("weekly-volume-report.csv"),
            atomically: true,
            encoding: .utf8
        )
        try bodyRegionLoadCSV(report).write(
            to: root.appendingPathComponent("weekly-body-region-load-report.csv"),
            atomically: true,
            encoding: .utf8
        )
        return root
    }

    private func writableRoot() throws -> URL {
        let candidates = [
            overrideRoot(),
            sourceRoot(),
            temporaryRoot()
        ].compactMap { $0 }

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
        guard let path = ProcessInfo.processInfo.environment["UNBOUND_YEAR_SIM_EXPORT_DIR"],
              !path.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: path, isDirectory: true)
            .appendingPathComponent("unbound-year-simulation-\(timestamp())", isDirectory: true)
    }

    private func sourceRoot() -> URL {
        let sourceFile = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return projectRoot
            .appendingPathComponent("LocalArtifacts", isDirectory: true)
            .appendingPathComponent("year-simulation-\(timestamp())", isDirectory: true)
    }

    private func temporaryRoot() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("unbound-year-simulation-\(timestamp())", isDirectory: true)
    }

    private func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(value).write(to: url)
    }

    private func markdownSummary(_ report: YearSimulationReport) -> String {
        var lines: [String] = [
            "# UNBOUND Year Simulation Baseline",
            "",
            "- Generated: \(report.generatedAt)",
            "- Start date: \(report.simulationStartDate)",
            "- Days: \(report.simulationDays)",
            "- Personas: \(report.personaRuns.count)",
            "",
            "## Persona Results"
        ]
        for run in report.personaRuns {
            let completed = run.days.filter { !$0.isRestDay && $0.completed }.count
            let missed = run.days.filter { !$0.isRestDay && !$0.completed }.count
            let critical = run.violations.filter { $0.severity == .critical }.count
            let warnings = run.violations.filter { $0.severity == .warning }.count
            lines.append("")
            lines.append("### \(run.persona.displayName)")
            lines.append("- Lens: \(run.persona.lens)")
            lines.append("- Programs generated: \(run.programs.count)")
            lines.append("- Completed workouts: \(completed)")
            lines.append("- Missed workouts: \(missed)")
            lines.append("- Critical violations: \(critical)")
            lines.append("- Warnings: \(warnings)")
            lines.append("- Weight bumps: \(run.progressionSummary.totalWeightBumps)")
            lines.append("- Grindy RPE bumps: \(run.progressionSummary.grindyRPEBumps)")
            lines.append("- Accessory ceiling warnings: \(run.progressionSummary.accessoryRepCeilingWarnings)")
        }
        lines.append("")
        lines.append("## Static Known Findings")
        for finding in report.staticFindings {
            lines.append("- [\(finding.severity.rawValue)] \(finding.code): \(finding.detail)")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private func violationsMarkdown(_ report: YearSimulationReport) -> String {
        var lines = ["# Constraint Violations", ""]
        for run in report.personaRuns {
            lines.append("## \(run.persona.displayName)")
            if run.violations.isEmpty {
                lines.append("- None")
            } else {
                for violation in run.violations {
                    let location = [violation.day.map { "day \($0)" }, violation.date].compactMap { $0 }.joined(separator: ", ")
                    lines.append("- [\(violation.severity.rawValue)] \(violation.code)\(location.isEmpty ? "" : " (\(location))"): \(violation.detail)")
                }
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    private func weeklyVolumeCSV(_ report: YearSimulationReport) -> String {
        var rows = ["persona_id,week,muscle_group,sets"]
        for run in report.personaRuns {
            for week in run.weeklyVolume {
                for muscle in week.setsByMuscle.keys.sorted() {
                    rows.append("\(run.persona.id),\(week.week),\(muscle),\(week.setsByMuscle[muscle] ?? 0)")
                }
            }
        }
        return rows.joined(separator: "\n") + "\n"
    }

    private func bodyRegionLoadCSV(_ report: YearSimulationReport) -> String {
        var rows = [
            "persona_id,week,body_region,direct_hard_sets,secondary_exposure_sets,skill_practice_sets,mobility_control_sets,joint_tendon_stress_sets,coach_load_score,raw_tagged_sets"
        ]
        for run in report.personaRuns {
            for week in run.weeklyBodyRegionLoad {
                for region in week.loadsByRegion.keys.sorted() {
                    guard let load = week.loadsByRegion[region] else { continue }
                    rows.append([
                        run.persona.id,
                        "\(week.week)",
                        region,
                        format(load.directHardSets),
                        format(load.secondaryExposureSets),
                        format(load.skillPracticeSets),
                        format(load.mobilityControlSets),
                        format(load.jointTendonStressSets),
                        format(load.coachLoadScore),
                        format(load.rawTaggedSets)
                    ].joined(separator: ","))
                }
            }
        }
        return rows.joined(separator: "\n") + "\n"
    }

    private func format(_ value: Double) -> String {
        value.rounded() == value ? "\(Int(value))" : String(format: "%.2f", value)
    }

    private func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}

struct YearSimulationPersona {
    let id: String
    let displayName: String
    let lens: String
    let buildIdentity: BuildIdentity
    let trainingStyle: TrainingStyle
    let equipment: [Equipment]
    let targetFrequency: TargetFrequency
    let trainingDays: Set<Weekday>
    let experience: Experience
    let sessionLengthMinutes: Int
    let goals: [String]
    let obstacles: [String]
    let sleepQuality: Int
    let stressLevel: Int
    let commitment: Int
    let focusAreas: [FocusArea]
    let cutModeActive: Bool
    let adherence: YearAdherenceProfile
    let simulatedSkillIds: [String]
    let simulatedCarryEveryNDays: Int?

    init(
        id: String,
        displayName: String,
        lens: String,
        buildIdentity: BuildIdentity,
        trainingStyle: TrainingStyle,
        equipment: [Equipment],
        targetFrequency: TargetFrequency,
        trainingDays: Set<Weekday>,
        experience: Experience,
        sessionLengthMinutes: Int,
        goals: [String],
        obstacles: [String],
        sleepQuality: Int,
        stressLevel: Int,
        commitment: Int,
        focusAreas: [FocusArea],
        cutModeActive: Bool,
        adherence: YearAdherenceProfile,
        simulatedSkillIds: [String] = [],
        simulatedCarryEveryNDays: Int? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.lens = lens
        self.buildIdentity = buildIdentity
        self.trainingStyle = trainingStyle
        self.equipment = equipment
        self.targetFrequency = targetFrequency
        self.trainingDays = trainingDays
        self.experience = experience
        self.sessionLengthMinutes = sessionLengthMinutes
        self.goals = goals
        self.obstacles = obstacles
        self.sleepQuality = sleepQuality
        self.stressLevel = stressLevel
        self.commitment = commitment
        self.focusAreas = focusAreas
        self.cutModeActive = cutModeActive
        self.adherence = adherence
        self.simulatedSkillIds = simulatedSkillIds
        self.simulatedCarryEveryNDays = simulatedCarryEveryNDays
    }

    var export: YearPersonaExport {
        YearPersonaExport(
            id: id,
            displayName: displayName,
            lens: lens,
            buildIdentity: buildIdentity.displayName,
            trainingStyle: trainingStyle.rawValue,
            equipment: equipment.map(\.rawValue),
            targetFrequency: targetFrequency.rawValue,
            trainingDays: trainingDays.map(\.rawValue).sorted(),
            experience: experience.rawValue,
            sessionLengthMinutes: sessionLengthMinutes,
            goals: goals,
            obstacles: obstacles,
            sleepQuality: sleepQuality,
            stressLevel: stressLevel,
            commitment: commitment,
            focusAreas: focusAreas.map { $0.muscleGroup.rawValue },
            cutModeActive: cutModeActive,
            adherence: adherence.rawValue
        )
    }
}

enum YearAdherenceProfile: String, Codable {
    case steady
    case aggressive
    case inconsistent
    case stressed
}

struct DaySimulationResult {
    let day: YearDayExport
    let violations: [YearConstraintViolation]
    let actions: [YearCoachActionExport]
    let bodyLoads: [BodyRegionTrainingLoad]
}

struct ProgressionLogOutcome {
    let reps: Int
    let rpe: Int
    let weightKg: Double
    let classification: ExerciseClassification
    let targetRepMaxAfter: Int
    let bumpedOnGrindyRPE: Bool
    let accessoryRepCeilingTooHigh: Bool
}

struct StaticTrainingLogicFinding: Codable {
    let severity: YearViolationSeverity
    let code: String
    let detail: String

    static let knownBaselineFindings: [StaticTrainingLogicFinding] = []
}

struct YearSimulationReport: Codable {
    let generatedAt: Date
    let simulationStartDate: String
    let simulationDays: Int
    let staticFindings: [StaticTrainingLogicFinding]
    let personaRuns: [YearPersonaRun]
}

struct YearPersonaExport: Codable {
    let id: String
    let displayName: String
    let lens: String
    let buildIdentity: String
    let trainingStyle: String
    let equipment: [String]
    let targetFrequency: String
    let trainingDays: [String]
    let experience: String
    let sessionLengthMinutes: Int
    let goals: [String]
    let obstacles: [String]
    let sleepQuality: Int
    let stressLevel: Int
    let commitment: Int
    let focusAreas: [String]
    let cutModeActive: Bool
    let adherence: String
}

struct YearPersonaRun: Codable {
    let persona: YearPersonaExport
    let days: [YearDayExport]
    let programs: [YearProgramExport]
    let weeklyVolume: [YearWeeklyVolumeExport]
    let weeklyBodyRegionLoad: [YearWeeklyBodyRegionLoadExport]
    let progressionSummary: YearProgressionSummary
    let coachActionLedger: [YearCoachActionExport]
    let violations: [YearConstraintViolation]
}

struct YearProgramExport: Codable {
    let blockNumber: Int
    let programId: String
    let name: String
    let startedAt: String
    let durationDays: Int
    let hasArc: Bool
    let requiredEquipment: [String]
    let estimatedDailyMinutes: Int
    let trainingDayCount: Int
    let rolloverRotationsSuggested: [String]
}

struct YearDayExport: Codable {
    let absoluteDay: Int
    let date: String
    let blockDay: Int
    let label: String
    let isRestDay: Bool
    let completed: Bool
    let workoutName: String?
    let estimatedMinutes: Int
    let exercises: [YearExerciseExport]
    let notes: [String]
}

struct YearExerciseExport: Codable {
    let name: String
    let sets: Int
    let reps: String
    let rpe: Int?
    let completedSets: Int
    let simulatedTopSetReps: Int
    let simulatedTopSetRPE: Int?
    let simulatedWeightKg: Double
    let classification: String
    let substitution: String?
}

struct YearWeeklyVolumeExport: Codable {
    let week: Int
    let setsByMuscle: [String: Int]
}

struct YearWeeklyBodyRegionLoadExport: Codable {
    let week: Int
    let loadsByRegion: [String: BodyRegionTrainingLoad]
}

struct YearProgressionSummary: Codable {
    let trackedExerciseCount: Int
    let totalWeightBumps: Int
    let grindyRPEBumps: Int
    let accessoryRepCeilingWarnings: Int
    let finalStates: [YearProgressionStateExport]
}

struct YearProgressionStateExport: Codable {
    let exerciseKey: String
    let displayName: String
    let currentWorkingWeightKg: Double
    let targetRepMin: Int
    let targetRepMax: Int
    let targetRPE: Int
    let blockType: String
    let consecutiveSessionsAtTarget: Int
}

struct YearCoachActionExport: Codable {
    let day: Int
    let date: String
    let kind: String
    let detail: String
}

struct YearConstraintViolation: Codable {
    let severity: YearViolationSeverity
    let day: Int?
    let date: String?
    let code: String
    let detail: String
}

enum YearViolationSeverity: String, Codable {
    case info
    case warning
    case critical
}
