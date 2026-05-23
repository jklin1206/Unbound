import SwiftUI

struct WorkoutLogSummaryView: View {
    let log: WorkoutLog
    @AppStorage(WeightPlatePolicy.unitDefaultsKey) private var weightUnitRaw = TrainingWeightUnit.localeDefault.rawValue

    private var totalWorkSets: Int {
        log.exerciseEntries
            .filter { !$0.skipped }
            .flatMap(\.sets)
            .filter { !$0.isWarmup }
            .count
    }

    private var totalReps: Int {
        log.exerciseEntries
            .filter { !$0.skipped }
            .flatMap(\.sets)
            .filter { !$0.isWarmup }
            .reduce(0) { $0 + $1.reps }
    }

    private var estimatedTonnage: Double {
        log.exerciseEntries
            .filter { !$0.skipped }
            .flatMap(\.sets)
            .filter { !$0.isWarmup }
            .reduce(0.0) { total, set in
                total + ((set.weightKg ?? 0) * Double(set.reps))
            }
    }

    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    summaryHeader
                    volumeSummaryCard
                    exerciseList
                    sessionNotesCard
                }
                .padding(16)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Workout Summary")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Summary Header

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(log.plannedWorkoutName)
                        .font(.subheadline(20))
                        .foregroundColor(.theme.textPrimary)
                    Text(log.startedAt.formatted(date: .long, time: .omitted))
                        .font(.caption(13))
                        .foregroundColor(.theme.textMuted)
                }
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.theme.success)
            }

            HStack(spacing: 0) {
                statCell(
                    value: log.durationMinutes.map { "\($0)m" } ?? "--",
                    label: "Duration"
                )
                Divider().frame(height: 36).background(Color.theme.surfaceLight)
                statCell(value: "\(totalWorkSets)", label: "Work Sets")
                Divider().frame(height: 36).background(Color.theme.surfaceLight)
                statCell(
                    value: log.startedAt.formatted(.dateTime.hour().minute()),
                    label: "Started"
                )
            }
            .padding(.vertical, 12)
            .background(Color.theme.background)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(16)
        .background(Color.theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.stat(18))
                .foregroundColor(.theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption(11))
                .foregroundColor(.theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Volume Summary

    private var volumeSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Volume", systemImage: "chart.bar.fill")
                .font(.bodyMedium(15))
                .foregroundColor(.theme.primary)

            HStack(spacing: 0) {
                volumeCell(value: "\(totalWorkSets)", label: "Sets")
                Divider().frame(height: 36).background(Color.theme.surfaceLight)
                volumeCell(value: "\(totalReps)", label: "Reps")
                Divider().frame(height: 36).background(Color.theme.surfaceLight)
                volumeCell(
                    value: formattedTonnage,
                    label: "Tonnage"
                )
                if let rpe = log.overallRPE {
                    Divider().frame(height: 36).background(Color.theme.surfaceLight)
                    volumeCell(value: "\(rpe)/10", label: "RPE")
                }
            }
        }
        .padding(16)
        .background(Color.theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func volumeCell(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.stat(16))
                .foregroundColor(.theme.textPrimary)
            Text(label)
                .font(.caption(11))
                .foregroundColor(.theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Exercise List

    private var exerciseList: some View {
        VStack(spacing: 10) {
            ForEach(log.exerciseEntries) { entry in
                exerciseCard(entry: entry)
            }
        }
    }

    private func exerciseCard(entry: ExerciseLogEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(entry.exerciseName)
                    .font(.bodyMedium(15))
                    .foregroundColor(entry.skipped ? .theme.textMuted : .theme.textPrimary)
                    .strikethrough(entry.skipped)

                Spacer()

                if entry.skipped {
                    Text("Skipped")
                        .font(.caption(11))
                        .fontWeight(.semibold)
                        .foregroundColor(.theme.textMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.theme.surfaceLight)
                        .clipShape(Capsule())
                } else {
                    Text("\(entry.sets.filter { !$0.isWarmup }.count) sets")
                        .font(.caption(12))
                        .foregroundColor(.theme.textSecondary)
                }
            }

            if !entry.skipped {
                Divider().background(Color.theme.surfaceLight)

                let workSets = entry.sets.filter { !$0.isWarmup }
                let warmupSets = entry.sets.filter { $0.isWarmup }

                if !warmupSets.isEmpty {
                    Text("Warmup")
                        .font(.caption(11))
                        .foregroundColor(.theme.warning)

                    ForEach(warmupSets) { set in
                        setRow(set: set, isWarmup: true)
                    }
                }

                ForEach(workSets) { set in
                    setRow(set: set, isWarmup: false)
                }

                if let notes = entry.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption(12))
                        .foregroundColor(.theme.textMuted)
                        .padding(.top, 2)
                }
            }
        }
        .padding(14)
        .background(Color.theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func setRow(set: SetLog, isWarmup: Bool) -> some View {
        HStack(spacing: 10) {
            Text("Set \(set.setNumber)")
                .font(.caption(12))
                .foregroundColor(.theme.textMuted)
                .frame(width: 42, alignment: .leading)

            if let weight = set.weightKg {
                Text("\(WeightPlatePolicy.formatLoggedWeight(weight, unit: weightUnit))\(weightUnit.shortLabel)")
                    .font(.bodyMedium(14))
                    .foregroundColor(.theme.textPrimary)
            } else {
                Text("BW")
                    .font(.bodyMedium(14))
                    .foregroundColor(.theme.textSecondary)
            }

            Text("×")
                .font(.caption(12))
                .foregroundColor(.theme.textMuted)

            Text("\(set.reps) reps")
                .font(.bodyMedium(14))
                .foregroundColor(.theme.textPrimary)

            if let rpe = set.rpe {
                Spacer()
                Text("@ RPE \(rpe)")
                    .font(.caption(12))
                    .foregroundColor(.theme.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.theme.surfaceLight)
                    .clipShape(Capsule())
            }
        }
    }

    private var weightUnit: TrainingWeightUnit {
        TrainingWeightUnit(rawValue: weightUnitRaw) ?? .localeDefault
    }

    private var formattedTonnage: String {
        let value = weightUnit.displayValue(fromKilograms: estimatedTonnage)
        if value >= 1000 {
            return "\(WeightPlatePolicy.formatDisplayValue(value / 1000))k \(weightUnit.shortLabel)"
        }
        return "\(WeightPlatePolicy.formatDisplayValue(value)) \(weightUnit.shortLabel)"
    }

    // MARK: - Session Notes Card

    @ViewBuilder
    private var sessionNotesCard: some View {
        if let notes = log.overallNotes, !notes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label("Session Notes", systemImage: "note.text")
                    .font(.bodyMedium(14))
                    .foregroundColor(.theme.textSecondary)

                Text(notes)
                    .font(.bodyText(14))
                    .foregroundColor(.theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
