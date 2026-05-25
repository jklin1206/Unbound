import Foundation

struct ArcContext: Equatable, Sendable {
    var arc: Arc
    var dayNumber: Int
    var wave: Wave
    var daysRemaining: Int

    var displayText: String {
        "Arc day \(dayNumber) · \(wave == .wave1 ? "Wave 1" : "Wave 2") · \(daysRemaining)d left"
    }
}

enum ArcScheduler {
    static func context(
        for program: TrainingProgram,
        asOf date: Date = Date(),
        calendar: Calendar = .current
    ) -> ArcContext? {
        guard let arc = program.currentArc,
              let dayNumber = arc.dayNumber(asOf: date, calendar: calendar),
              let wave = arc.currentWave(asOf: date, calendar: calendar)
        else {
            return nil
        }

        return ArcContext(
            arc: arc,
            dayNumber: dayNumber,
            wave: wave,
            daysRemaining: max(0, Arc.durationDays - dayNumber)
        )
    }

    static func shouldOfferCheckpoint(
        program: TrainingProgram,
        asOf date: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard let arc = program.currentArc else {
            return BlockRolloverScheduler.shouldRollover(program: program, now: date)
        }
        let target = calendar.startOfDay(for: date)
        return target >= calendar.startOfDay(for: arc.endDate)
    }

    static func nextArc(
        after arc: Arc,
        programId: String,
        checkpoint: CheckpointOutcome?
    ) -> Arc {
        var next = Arc(
            programId: programId,
            startDate: arc.endDate,
            state: .planned,
            sourceArcID: arc.id
        )
        if checkpoint?.wasSkipped == true {
            next.state = .active
        }
        return next
    }
}
