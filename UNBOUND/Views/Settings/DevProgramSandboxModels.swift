import SwiftUI
import UserNotifications
import UIKit

enum DevProgramSandboxState: String, CaseIterable, Identifiable {
    case arcDay1 = "arc-day-1"
    case wave2 = "wave-2"
    case checkpointDue = "checkpoint-due"

    var id: String { rawValue }

    var startOffsetDays: Int {
        switch self {
        case .arcDay1: return 0
        case .wave2: return -14
        case .checkpointDue: return -29
        }
    }

    var scanDaysAgo: Int {
        switch self {
        case .arcDay1: return 31
        case .wave2: return 16
        case .checkpointDue: return 31
        }
    }

    var arcState: ArcState {
        switch self {
        case .arcDay1, .wave2: return .active
        case .checkpointDue: return .checkpointDue
        }
    }

    var completedDayCount: Int {
        switch self {
        case .arcDay1: return 0
        case .wave2: return 8
        case .checkpointDue: return 18
        }
    }
}

enum DevDynamicProgramScenario: String, CaseIterable, Identifiable {
    case programQALab = "program-qa-lab"
    case oneSkillLifting = "one-skill-lifting"
    case sixSkillHybrid = "six-skill-hybrid"
    case calisthenicsWeekBands = "calis-week-bands"
    case nextBlockLifting = "next-block-lifting"
    case freeformProtected = "freeform-protected"

    static let activeUserDefaultsKey = "unbound.dev.dynamicProgramScenario"

    var id: String { rawValue }

    static var launchArgumentList: String {
        allCases.map(\.rawValue).joined(separator: "|")
    }

    var title: String {
        switch self {
        case .programQALab: return "Dynamic: Program QA Lab"
        case .oneSkillLifting: return "Dynamic: 1 Skill + Lifting"
        case .sixSkillHybrid: return "Dynamic: 6 Skills + Hybrid"
        case .calisthenicsWeekBands: return "Dynamic: Week Bands Calis"
        case .nextBlockLifting: return "Dynamic: Next Block Lifting"
        case .freeformProtected: return "Dynamic: Freeform Protected"
        }
    }

    var shortTitle: String {
        switch self {
        case .programQALab: return "QA Lab"
        case .oneSkillLifting: return "1 Skill"
        case .sixSkillHybrid: return "6 Skills"
        case .calisthenicsWeekBands: return "Bands Week"
        case .nextBlockLifting: return "Next Lift"
        case .freeformProtected: return "Freeform"
        }
    }

    var systemImage: String {
        switch self {
        case .programQALab: return "checklist.checked"
        case .oneSkillLifting: return "dumbbell.fill"
        case .sixSkillHybrid: return "circle.hexagongrid.fill"
        case .calisthenicsWeekBands: return "figure.strengthtraining.functional"
        case .nextBlockLifting: return "calendar.badge.plus"
        case .freeformProtected: return "square.and.pencil"
        }
    }

    var successMessage: String {
        switch self {
        case .programQALab:
            return "Seeded the Program QA Lab with saved workouts, planned dates, skills, equipment context, and progression fixtures."
        case .oneSkillLifting:
            return "Seeded one Program Focus with a lifting block."
        case .sixSkillHybrid:
            return "Seeded six Program Focuses with a hybrid block stress fixture."
        case .calisthenicsWeekBands:
            return "Seeded a this-week calisthenics bands-only override."
        case .nextBlockLifting:
            return "Queued a next-block return to lifting."
        case .freeformProtected:
            return "Seeded a protected freeform workout under dynamic context."
        }
    }
}

struct DevProgramScanSnapshot: Equatable {
    var programName: String
    var arcStatus: String
    var workoutDays: Int
    var requiredEquipment: String
    var scanStatus: String
    var checkpointCount: Int
    var lastScan: String

    static let empty = DevProgramScanSnapshot(
        programName: "No local program",
        arcStatus: "No active Arc",
        workoutDays: 0,
        requiredEquipment: "None",
        scanStatus: "No scan history",
        checkpointCount: 0,
        lastScan: "Never"
    )
}

struct DevProgramScanSnapshotCard: View {
    let snapshot: DevProgramScanSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "stethoscope")
                    .foregroundColor(.theme.primary)
                Text("Current Sandbox")
                    .font(.caption(12).weight(.semibold))
                    .foregroundColor(.theme.textSecondary)
                Spacer()
            }

            Text(snapshot.programName)
                .font(.bodyText(15))
                .foregroundColor(.theme.textPrimary)
                .lineLimit(2)

            VStack(alignment: .leading, spacing: 6) {
                snapshotLine("Arc", snapshot.arcStatus)
                snapshotLine("Workouts", "\(snapshot.workoutDays) training days")
                snapshotLine("Equipment", snapshot.requiredEquipment)
                snapshotLine("Scans", "\(snapshot.checkpointCount) checkpoints · \(snapshot.lastScan)")
                snapshotLine("Window", snapshot.scanStatus)
            }
        }
        .padding(.vertical, 6)
        .accessibilityIdentifier("dev.programScan.snapshot")
    }

    private func snapshotLine(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.theme.textMuted)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.caption(12))
                .foregroundColor(.theme.textSecondary)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
    }
}
