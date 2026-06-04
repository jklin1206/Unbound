import SwiftUI

struct ScheduleSavedWorkoutSheet: View {
    let savedWorkout: SavedWorkout
    let program: TrainingProgram
    let minimumDayNumber: Int?
    let preselectedDayNumbers: Set<Int>
    let onSchedule: ([Int]) -> Void
    let onDismiss: () -> Void

    @State private var selectedDayNumbers: Set<Int> = []

    init(
        savedWorkout: SavedWorkout,
        program: TrainingProgram,
        minimumDayNumber: Int? = nil,
        preselectedDayNumbers: Set<Int> = [],
        onSchedule: @escaping ([Int]) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.savedWorkout = savedWorkout
        self.program = program
        self.minimumDayNumber = minimumDayNumber
        self.preselectedDayNumbers = preselectedDayNumbers
        self.onSchedule = onSchedule
        self.onDismiss = onDismiss
        let allowedSelections = preselectedDayNumbers.filter { dayNumber in
            guard let day = program.days.first(where: { $0.dayNumber == dayNumber }) else { return false }
            let isPast = minimumDayNumber.map { day.dayNumber < $0 } ?? false
            return !day.isRestDay && !isPast
        }
        _selectedDayNumbers = State(initialValue: Set(allowedSelections))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.unbound.bg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        header
                        dayGrid
                        scheduleButton
                    }
                    .padding(20)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Plan")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", action: onDismiss)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text(savedWorkout.title.uppercased())
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.coachCyan)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Spacer()
            Text("\(savedWorkout.exerciseCount)")
                .font(Font.unbound.monoS.weight(.bold))
                .foregroundStyle(Color.unbound.bg)
                .padding(.horizontal, 9)
                .frame(height: 24)
                .background(Capsule().fill(Color.unbound.coachCyan))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surface)
        )
    }

    private var dayGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            ForEach(program.days) { day in
                dayButton(day)
            }
        }
    }

    private func dayButton(_ day: ProgramDay) -> some View {
        let selected = selectedDayNumbers.contains(day.dayNumber)
        let isPast = minimumDayNumber.map { day.dayNumber < $0 } ?? false
        let disabled = day.isRestDay || isPast
        return Button {
            if selected {
                selectedDayNumbers.remove(day.dayNumber)
            } else {
                selectedDayNumbers.insert(day.dayNumber)
            }
        } label: {
            VStack(spacing: 4) {
                Text("D\(day.dayNumber)")
                    .font(Font.unbound.monoS.weight(.black))
                Text(day.sessionRole.displayName.uppercased())
                    .font(Font.unbound.captionS.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .foregroundStyle(disabled ? Color.unbound.textTertiary : (selected ? Color.unbound.bg : Color.unbound.textSecondary))
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selected ? Color.unbound.coachCyan : Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(selected ? Color.unbound.coachCyan : Color.unbound.borderSubtle, lineWidth: 1)
            )
            .opacity(disabled ? 0.45 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private var scheduleButton: some View {
        Button {
            onSchedule(Array(selectedDayNumbers).sorted())
        } label: {
            Text(selectedDayNumbers.isEmpty ? "PICK DAY" : "SCHEDULE")
                .font(Font.unbound.bodyMStrong)
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(selectedDayNumbers.isEmpty ? Color.unbound.surfaceElevated : Color.unbound.accent)
                )
        }
        .buttonStyle(.plain)
        .disabled(selectedDayNumbers.isEmpty)
    }
}
