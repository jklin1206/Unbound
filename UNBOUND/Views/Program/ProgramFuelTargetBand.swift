import SwiftUI

struct ProgramFuelTargetBand: View {
    let plan: NutritionPlan
    let day: ProgramDay

    private var target: NutritionDayTarget {
        plan.target(for: day)
    }

    var body: some View {
        NavigationLink {
            NutritionDayView(
                plan: plan,
                override: day.nutritionOverride,
                initialIsRestDay: day.isRestDay
            )
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Rectangle()
                    .fill(Color.unbound.borderSubtle)
                    .frame(height: 1)

                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: day.isRestDay ? "leaf.fill" : "flame.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(day.isRestDay ? Color.unbound.success : Color.unbound.emberGlow)
                        .frame(width: 26, height: 26)
                        .background(
                            Circle()
                                .fill((day.isRestDay ? Color.unbound.success : Color.unbound.emberGlow).opacity(0.13))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("FUEL TARGET")
                            .font(Font.unbound.captionS.weight(.heavy))
                            .tracking(1.5)
                            .foregroundStyle(Color.unbound.textTertiary)
                        Text(target.modeLabel.uppercased())
                            .font(Font.unbound.monoS.weight(.bold))
                            .tracking(0.4)
                            .foregroundStyle(Color.unbound.textSecondary)
                    }

                    Spacer(minLength: 8)

                    fuelStat(value: "\(target.calories)", label: "KCAL", tint: Color.unbound.coachCyan)
                    fuelStat(value: "\(target.proteinGrams)g", label: "PRO", tint: Color.unbound.rankGold)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.unbound.textTertiary)
                        .accessibilityHidden(true)
                }

                Text(target.guidanceLine)
                    .font(Font.unbound.captionS)
                    .tracking(0.2)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Fuel target, \(target.calories) calories, \(target.proteinGrams) grams protein")
    }

    private func fuelStat(value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(value)
                .font(Font.unbound.monoM.weight(.black))
                .foregroundStyle(tint)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(label)
                .font(.system(size: 7, weight: .heavy, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .frame(minWidth: 48, alignment: .trailing)
    }
}
