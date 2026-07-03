import SwiftUI

/// The grid's weight column header: renders "WEIGHT LB" (or a custom prefix,
/// e.g. "LOAD") following the app-wide unit default. Historically this was a
/// tappable "WEIGHT LB ⇆" toggle; the unit switch now lives in each
/// exercise's overflow (…) menu, so the header is a plain unit-aware label.
/// Inherits the surrounding header font/color.
struct WeightUnitHeaderLabel: View {
    var prefix: String = "WEIGHT"

    @AppStorage(WeightPlatePolicy.unitDefaultsKey)
    private var weightUnitRaw = TrainingWeightUnit.localeDefault.rawValue

    private var unit: TrainingWeightUnit {
        TrainingWeightUnit(rawValue: weightUnitRaw) ?? .localeDefault
    }

    var body: some View {
        Text("\(prefix) \(unit.shortLabel.uppercased())")
            .accessibilityLabel("Weight in \(unit.displayName)")
    }
}

/// The unit switch itself, as a row for any exercise overflow `Menu`
/// (active-workout grid, session editor). Flips the app-wide default.
struct WeightUnitMenuButton: View {
    @AppStorage(WeightPlatePolicy.unitDefaultsKey)
    private var weightUnitRaw = TrainingWeightUnit.localeDefault.rawValue

    private var unit: TrainingWeightUnit {
        TrainingWeightUnit(rawValue: weightUnitRaw) ?? .localeDefault
    }

    var body: some View {
        Button {
            UnboundHaptics.tick()
            weightUnitRaw = (unit == .kilograms ? TrainingWeightUnit.pounds : .kilograms).rawValue
        } label: {
            Label(
                unit == .kilograms ? "Switch to pounds" : "Switch to kilograms",
                systemImage: "scalemass"
            )
        }
    }
}
