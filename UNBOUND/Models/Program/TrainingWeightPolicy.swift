import Foundation

enum TrainingWeightUnit: String, Codable, CaseIterable, Identifiable {
    case kilograms = "kg"
    case pounds = "lb"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .kilograms:
            return L10n.string(.trainingWeightUnitKilograms, defaultValue: "Kilograms")
        case .pounds:
            return L10n.string(.trainingWeightUnitPounds, defaultValue: "Pounds")
        }
    }

    var shortLabel: String { rawValue }

    static var localeDefault: TrainingWeightUnit {
        guard let region = Locale.current.region?.identifier else {
            return .kilograms
        }
        return ["US", "LR", "MM"].contains(region) ? .pounds : .kilograms
    }

    func displayValue(fromKilograms kilograms: Double) -> Double {
        switch self {
        case .kilograms: return kilograms
        case .pounds: return kilograms * WeightPlatePolicy.poundsPerKilogram
        }
    }

    func kilograms(fromDisplayValue value: Double) -> Double {
        switch self {
        case .kilograms: return value
        case .pounds: return value / WeightPlatePolicy.poundsPerKilogram
        }
    }
}

enum WeightPlatePolicy {
    static let unitDefaultsKey = "unbound.trainingWeightUnit.v2"
    static let microloadingDefaultsKey = "unbound.microloadingEnabled.v1"
    static let poundsPerKilogram = 2.20462262185

    static var currentUnit: TrainingWeightUnit {
        if let raw = UserDefaults.standard.string(forKey: unitDefaultsKey),
           let unit = TrainingWeightUnit(rawValue: raw) {
            return unit
        }
        return .localeDefault
    }

    static var isMicroloadingEnabled: Bool {
        UserDefaults.standard.bool(forKey: microloadingDefaultsKey)
    }

    static func formatLoggedWeight(
        _ kilograms: Double,
        unit: TrainingWeightUnit = currentUnit
    ) -> String {
        formatDisplayValue(unit.displayValue(fromKilograms: kilograms))
    }

    static func formatLoggedWeightWithUnit(
        _ kilograms: Double,
        unit: TrainingWeightUnit = currentUnit,
        separator: String = ""
    ) -> String {
        "\(formatLoggedWeight(kilograms, unit: unit))\(separator)\(unit.shortLabel)"
    }

    static func formatSuggestionWeight(
        _ kilograms: Double,
        unit: TrainingWeightUnit = currentUnit,
        microloadingEnabled: Bool = isMicroloadingEnabled
    ) -> String {
        let snappedKg = snappedSuggestionKilograms(
            kilograms,
            unit: unit,
            microloadingEnabled: microloadingEnabled
        )
        return formatDisplayValue(unit.displayValue(fromKilograms: snappedKg))
    }

    static func formatSuggestionWeightWithUnit(
        _ kilograms: Double,
        unit: TrainingWeightUnit = currentUnit,
        microloadingEnabled: Bool = isMicroloadingEnabled,
        separator: String = ""
    ) -> String {
        "\(formatSuggestionWeight(kilograms, unit: unit, microloadingEnabled: microloadingEnabled))\(separator)\(unit.shortLabel)"
    }

    static func formatDeltaWeight(
        _ kilograms: Double,
        unit: TrainingWeightUnit = currentUnit
    ) -> String {
        formatDisplayValue(unit.displayValue(fromKilograms: kilograms))
    }

    static func formatDeltaWeightWithUnit(
        _ kilograms: Double,
        unit: TrainingWeightUnit = currentUnit,
        separator: String = ""
    ) -> String {
        "\(formatDeltaWeight(kilograms, unit: unit))\(separator)\(unit.shortLabel)"
    }

    static func formatVolume(
        _ kilograms: Double,
        unit: TrainingWeightUnit = currentUnit
    ) -> String {
        let display = unit.displayValue(fromKilograms: kilograms)
        if display >= 1_000 {
            return "\(formatDisplayValue(display / 1_000))k \(unit.shortLabel)"
        }
        return "\(formatDisplayValue(display))\(unit.shortLabel)"
    }

    static func editingValue(
        fromKilograms kilograms: Double,
        unit: TrainingWeightUnit = currentUnit
    ) -> Double {
        roundedForDisplay(unit.displayValue(fromKilograms: kilograms))
    }

    static func kilograms(
        fromDisplayValue value: Double,
        unit: TrainingWeightUnit = currentUnit
    ) -> Double {
        unit.kilograms(fromDisplayValue: value)
    }

    static func loadIncrement(
        unit: TrainingWeightUnit = currentUnit,
        microloadingEnabled: Bool = isMicroloadingEnabled
    ) -> Double {
        switch (unit, microloadingEnabled) {
        case (.pounds, false): return 5.0
        case (.pounds, true): return 2.5
        case (.kilograms, false): return 2.5
        case (.kilograms, true): return 1.25
        }
    }

    /// Snap pitch in display units for a specific implement. Machine stacks
    /// move in coarser steps than plates; kettlebells are handled separately
    /// in kilogram space (see `snappedSuggestionKilograms`).
    static func loadIncrement(
        for implement: LoadImplement,
        unit: TrainingWeightUnit = currentUnit,
        microloadingEnabled: Bool = isMicroloadingEnabled
    ) -> Double {
        switch implement {
        case .machine:
            return unit == .pounds
                ? (microloadingEnabled ? 5.0 : 10.0)
                : (microloadingEnabled ? 2.5 : 5.0)
        case .barbell, .dumbbell, .bodyweightLoad, .kettlebell:
            return loadIncrement(unit: unit, microloadingEnabled: microloadingEnabled)
        }
    }

    /// Kettlebells exist on a fixed 4 kg ladder in either unit system.
    static let kettlebellIncrementKilograms = 4.0

    static func progressionJump(
        for classification: ExerciseClassification,
        implement: LoadImplement = .barbell,
        unit: TrainingWeightUnit = currentUnit,
        microloadingEnabled: Bool = isMicroloadingEnabled
    ) -> Double {
        guard classification != .bodyweightSkill else { return 0 }

        switch implement {
        case .machine:
            return loadIncrement(for: .machine, unit: unit, microloadingEnabled: microloadingEnabled)
        case .dumbbell, .bodyweightLoad:
            // Hand-held loads jump one size regardless of movement pattern.
            return loadIncrement(unit: unit, microloadingEnabled: microloadingEnabled)
        case .kettlebell:
            // Handled in kilogram space by progressedWeightKilograms.
            return kettlebellIncrementKilograms
        case .barbell:
            break
        }

        switch (unit, microloadingEnabled, classification) {
        case (.pounds, false, .lowerCompound): return 10.0
        case (.pounds, false, _): return 5.0
        case (.pounds, true, .lowerCompound): return 5.0
        case (.pounds, true, _): return 2.5
        case (.kilograms, false, .lowerCompound): return 5.0
        case (.kilograms, false, _): return 2.5
        case (.kilograms, true, .lowerCompound): return 2.5
        case (.kilograms, true, _): return 1.25
        }
    }

    static func progressionJumpKilograms(
        for classification: ExerciseClassification,
        unit: TrainingWeightUnit = currentUnit,
        microloadingEnabled: Bool = isMicroloadingEnabled
    ) -> Double {
        unit.kilograms(fromDisplayValue: progressionJump(
            for: classification,
            unit: unit,
            microloadingEnabled: microloadingEnabled
        ))
    }

    static func snappedSuggestionKilograms(
        _ kilograms: Double,
        implement: LoadImplement = .barbell,
        unit: TrainingWeightUnit = currentUnit,
        microloadingEnabled: Bool = isMicroloadingEnabled
    ) -> Double {
        guard kilograms > 0 else { return kilograms }
        if implement == .kettlebell {
            return max(kettlebellIncrementKilograms, snap(kilograms, to: kettlebellIncrementKilograms))
        }
        let display = unit.displayValue(fromKilograms: kilograms)
        let snapped = snap(display, to: loadIncrement(
            for: implement,
            unit: unit,
            microloadingEnabled: microloadingEnabled
        ))
        return unit.kilograms(fromDisplayValue: snapped)
    }

    /// Snap a suggestion using the implement resolved from the exercise itself.
    static func snappedSuggestionKilograms(
        _ kilograms: Double,
        exerciseKey: String,
        unit: TrainingWeightUnit = currentUnit,
        microloadingEnabled: Bool = isMicroloadingEnabled
    ) -> Double {
        snappedSuggestionKilograms(
            kilograms,
            implement: LoadImplement.resolve(exerciseKey: exerciseKey),
            unit: unit,
            microloadingEnabled: microloadingEnabled
        )
    }

    static func progressedWeightKilograms(
        from currentKilograms: Double,
        classification: ExerciseClassification,
        implement: LoadImplement = .barbell,
        unit: TrainingWeightUnit = currentUnit,
        microloadingEnabled: Bool = isMicroloadingEnabled
    ) -> Double {
        guard currentKilograms > 0, classification != .bodyweightSkill else {
            return currentKilograms
        }

        let nextKilograms: Double
        if implement == .kettlebell {
            let base = snap(currentKilograms, to: kettlebellIncrementKilograms)
            nextKilograms = base + kettlebellIncrementKilograms
        } else {
            let increment = loadIncrement(
                for: implement,
                unit: unit,
                microloadingEnabled: microloadingEnabled
            )
            let currentDisplay = unit.displayValue(fromKilograms: currentKilograms)
            let baseDisplay = snap(currentDisplay, to: increment)
            let nextDisplay = baseDisplay + progressionJump(
                for: classification,
                implement: implement,
                unit: unit,
                microloadingEnabled: microloadingEnabled
            )
            nextKilograms = unit.kilograms(fromDisplayValue: snap(nextDisplay, to: increment))
        }

        // Never auto-prescribe past what the implement physically offers.
        if let cap = implement.automaticCapKilograms, nextKilograms > cap {
            return currentKilograms
        }
        return nextKilograms
    }

    static func snap(_ value: Double, to increment: Double) -> Double {
        guard increment > 0, value.isFinite else { return value }
        return (value / increment).rounded() * increment
    }

    static func formatDisplayValue(_ value: Double) -> String {
        let rounded = roundedForDisplay(value)
        if abs(rounded - rounded.rounded()) < 0.005 {
            return String(format: "%.0f", rounded)
        }
        if abs((rounded * 2).rounded() - rounded * 2) < 0.005 {
            return String(format: "%.1f", rounded)
        }
        if abs((rounded * 4).rounded() - rounded * 4) < 0.005 {
            return String(format: "%.2f", rounded)
        }
        return String(format: "%.1f", rounded)
    }

    private static func roundedForDisplay(_ value: Double) -> Double {
        guard value.isFinite else { return value }
        let nearestQuarter = (value * 4).rounded() / 4
        if abs(value - nearestQuarter) < 0.005 {
            return nearestQuarter
        }
        return (value * 10).rounded() / 10
    }
}
