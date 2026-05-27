import SwiftUI

struct NutritionDayView: View {
    let plan: NutritionPlan
    let override: DayNutrition?
    private let overrideAppliesToRestDay: Bool

    @State private var showTrainingDay: Bool

    init(plan: NutritionPlan, override: DayNutrition?, initialIsRestDay: Bool = false) {
        self.plan = plan
        self.override = override
        self.overrideAppliesToRestDay = initialIsRestDay
        _showTrainingDay = State(initialValue: !initialIsRestDay)
    }

    private var selectedIsRestDay: Bool { !showTrainingDay }

    private var activeOverride: DayNutrition? {
        selectedIsRestDay == overrideAppliesToRestDay ? override : nil
    }

    private var activeTarget: NutritionDayTarget {
        plan.target(isRestDay: selectedIsRestDay, override: activeOverride)
    }

    private var approximatePrefix: String {
        plan.usesNutritionDefaults ? "~" : ""
    }

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    targetHero
                    dayToggle
                    macroTargetsCard
                    hydrationCard
                    notesCard
                    mealsSection
                }
                .padding(20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Nutrition")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var targetHero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: showTrainingDay ? "flame.fill" : "leaf.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(showTrainingDay ? Color.unbound.emberGlow : Color.unbound.success)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill((showTrainingDay ? Color.unbound.emberGlow : Color.unbound.success).opacity(0.14))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("FUEL TARGET")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.8)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text(activeTarget.modeLabel.uppercased())
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                }

                Spacer(minLength: 0)

                HStack(spacing: 5) {
                    Image(systemName: plan.usesNutritionDefaults ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text(plan.confidenceLabel.uppercased())
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .tracking(1.0)
                }
                .foregroundStyle(plan.usesNutritionDefaults ? Color.unbound.warnOrange : Color.unbound.success)
                .padding(.horizontal, 8)
                .frame(height: 24)
                .background(
                    Capsule()
                        .fill((plan.usesNutritionDefaults ? Color.unbound.warnOrange : Color.unbound.success).opacity(0.12))
                )
            }

            HStack(alignment: .bottom, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(approximatePrefix)\(activeTarget.calories)")
                        .font(.system(size: 48, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.unbound.coachCyan)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("KCAL")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(Color.unbound.textTertiary)
                }

                Rectangle()
                    .fill(Color.unbound.border)
                    .frame(width: 1, height: 52)

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(approximatePrefix)\(activeTarget.proteinGrams)g")
                        .font(.system(size: 34, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.unbound.rankGold)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text("PROTEIN")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
            }

            Text(activeTarget.guidanceLine)
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(plan.confidenceDetail)
                .font(Font.unbound.captionS)
                .foregroundStyle(plan.usesNutritionDefaults ? Color.unbound.warnOrange : Color.unbound.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.unbound.coachCyan.opacity(showTrainingDay ? 0.34 : 0.18), lineWidth: 1)
        )
    }

    private var dayToggle: some View {
        HStack(spacing: 6) {
            toggleButton(title: "TRAIN", icon: "bolt.fill", isActive: showTrainingDay) {
                withAnimation(.easeInOut(duration: 0.18)) { showTrainingDay = true }
            }
            toggleButton(title: "RECOVER", icon: "moon.zzz.fill", isActive: !showTrainingDay) {
                withAnimation(.easeInOut(duration: 0.18)) { showTrainingDay = false }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.unbound.surfaceElevated)
        )
    }

    private func toggleButton(title: String, icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                Text(title)
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.3)
            }
            .foregroundStyle(isActive ? Color.unbound.textPrimary : Color.unbound.textTertiary)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isActive ? Color.unbound.accent.opacity(0.22) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private var macroTargetsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("MACRO SPLIT")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.textTertiary)
                Spacer()
                Text("\(approximatePrefix)\(activeTarget.carbsGrams)C / \(approximatePrefix)\(activeTarget.fatGrams)F")
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .monospacedDigit()
            }

            macroRow(
                name: "Protein",
                grams: activeTarget.proteinGrams,
                caloriesPerGram: 4,
                tint: Color.unbound.rankGold
            )
            macroRow(
                name: "Carbs",
                grams: activeTarget.carbsGrams,
                caloriesPerGram: 4,
                tint: Color.unbound.coachCyan
            )
            macroRow(
                name: "Fat",
                grams: activeTarget.fatGrams,
                caloriesPerGram: 9,
                tint: Color.unbound.emberGlow
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private func macroRow(name: String, grams: Int, caloriesPerGram: Int, tint: Color) -> some View {
        let kcal = grams * caloriesPerGram
        let progress = activeTarget.calories > 0 ? min(1, Double(kcal) / Double(activeTarget.calories)) : 0

        return VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(name)
                    .font(Font.unbound.bodyS.weight(.semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
                Spacer()
                Text("\(approximatePrefix)\(grams)g")
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(tint)
                    .monospacedDigit()
                Text("\(kcal) kcal")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .monospacedDigit()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.unbound.surfaceElevated)
                    Capsule()
                        .fill(tint)
                        .frame(width: geo.size.width * CGFloat(progress))
                }
            }
            .frame(height: 7)
        }
    }

    private var hydrationCard: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "drop.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.unbound.coachCyan)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.unbound.coachCyan.opacity(0.12)))

            VStack(alignment: .leading, spacing: 2) {
                Text("HYDRATION")
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .tracking(1.3)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text("\(String(format: "%.1f", plan.hydrationLiters))L daily")
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var notesCard: some View {
        if !plan.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text(plan.notes)
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.unbound.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                )
        }
    }

    @ViewBuilder
    private var mealsSection: some View {
        if plan.meals.isEmpty {
            noMealTemplateCard
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("MEAL SHAPE")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.textTertiary)

                ForEach(plan.meals) { meal in
                    MealTemplateCard(meal: meal)
                }
            }
        }
    }

    private var noMealTemplateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MEAL SHAPE")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.6)
                .foregroundStyle(Color.unbound.textTertiary)
            Text("Build each plate around protein first, then use carbs around training and fats to fill the rest.")
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }
}

private struct MealTemplateCard: View {
    let meal: MealTemplate
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(meal.name)
                            .font(Font.unbound.bodyMStrong)
                            .foregroundStyle(Color.unbound.textPrimary)
                        Text(meal.timing)
                            .font(Font.unbound.captionS)
                            .foregroundStyle(Color.unbound.textTertiary)
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("\(meal.calories) kcal")
                            .font(Font.unbound.monoS.weight(.bold))
                            .foregroundStyle(Color.unbound.coachCyan)
                        HStack(spacing: 5) {
                            macroTag(value: "\(meal.protein)P", color: Color.unbound.rankGold)
                            macroTag(value: "\(meal.carbs)C", color: Color.unbound.coachCyan)
                            macroTag(value: "\(meal.fat)F", color: Color.unbound.emberGlow)
                        }
                    }
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.unbound.textTertiary)
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            if isExpanded && !meal.examples.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Rectangle()
                        .fill(Color.unbound.borderSubtle)
                        .frame(height: 1)
                    FlowLayout(items: meal.examples) { item in
                        Text(item)
                            .font(Font.unbound.captionS)
                            .foregroundStyle(Color.unbound.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(Color.unbound.surfaceElevated)
                            )
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private func macroTag(value: String, color: Color) -> some View {
        Text(value)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(color)
    }
}

private struct FlowLayout<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    init(items: [Item], @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            let rows = stride(from: 0, to: items.count, by: 3).map { Array(items[$0..<min($0 + 3, items.count)]) }
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 6) {
                    ForEach(row, id: \.self) { item in
                        content(item)
                    }
                }
            }
        }
    }
}
