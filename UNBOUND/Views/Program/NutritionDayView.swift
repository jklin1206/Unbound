import SwiftUI

struct NutritionDayView: View {
    let plan: NutritionPlan
    let override: DayNutrition?

    @State private var showTrainingDay = true

    private var activeCalories: Int { showTrainingDay ? plan.dailyCalories : plan.restDayCalories }
    private var activeProtein: Int { showTrainingDay ? plan.proteinGrams : plan.restDayProteinGrams }
    private var activeCarbs: Int { showTrainingDay ? plan.carbsGrams : plan.restDayCarbsGrams }
    private var activeFat: Int { showTrainingDay ? plan.fatGrams : plan.restDayFatGrams }

    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Toggle
                    dayToggle

                    // Macro targets
                    macroTargetsCard

                    // Hydration & supplements
                    hydrationCard

                    // Meal templates
                    mealsSection
                }
                .padding(16)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Nutrition")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var dayToggle: some View {
        HStack(spacing: 0) {
            toggleButton(title: "Training Day", isActive: showTrainingDay) {
                withAnimation { showTrainingDay = true }
            }
            toggleButton(title: "Rest Day", isActive: !showTrainingDay) {
                withAnimation { showTrainingDay = false }
            }
        }
        .background(Color.theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func toggleButton(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.bodyMedium(14))
                .foregroundColor(isActive ? .theme.background : .theme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isActive ? Color.theme.primary : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private var macroTargetsCard: some View {
        VStack(spacing: 16) {
            // Calorie header
            HStack {
                Text("Daily Macros")
                    .font(.subheadline(16))
                    .foregroundColor(.theme.textPrimary)
                Spacer()
                Text("\(activeCalories) kcal")
                    .font(.bodyMedium(16))
                    .foregroundColor(.theme.primary)
            }

            // Macro bars
            VStack(spacing: 14) {
                macroRow(
                    name: "Protein",
                    grams: activeProtein,
                    totalCalories: activeCalories,
                    caloriesPerGram: 4,
                    color: .theme.secondary
                )
                macroRow(
                    name: "Carbs",
                    grams: activeCarbs,
                    totalCalories: activeCalories,
                    caloriesPerGram: 4,
                    color: Color.yellow
                )
                macroRow(
                    name: "Fat",
                    grams: activeFat,
                    totalCalories: activeCalories,
                    caloriesPerGram: 9,
                    color: Color.orange
                )
            }
        }
        .padding(16)
        .background(Color.theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func macroRow(name: String, grams: Int, totalCalories: Int, caloriesPerGram: Int, color: Color) -> some View {
        let kcal = grams * caloriesPerGram
        let progress = totalCalories > 0 ? CGFloat(kcal) / CGFloat(totalCalories) : 0

        return VStack(spacing: 6) {
            HStack {
                Text(name)
                    .font(.bodyMedium(14))
                    .foregroundColor(.theme.textPrimary)
                Spacer()
                Text("\(grams)g")
                    .font(.bodyMedium(14))
                    .foregroundColor(color)
                Text("· \(kcal) kcal")
                    .font(.caption(12))
                    .foregroundColor(.theme.textMuted)
            }
            AnimatedProgressBar(progress: progress, color: color)
        }
    }

    private var hydrationCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Label("Hydration", systemImage: "drop.fill")
                    .font(.bodyMedium(14))
                    .foregroundColor(Color(hex: "5E8CFF"))
                Text("\(String(format: "%.1f", plan.hydrationLiters))L daily")
                    .font(.subheadline(18))
                    .foregroundColor(.theme.textPrimary)
            }
            Spacer()
            if !plan.supplements.isEmpty {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Supplements")
                        .font(.caption(12))
                        .foregroundColor(.theme.textMuted)
                    Text(plan.supplements.prefix(2).joined(separator: ", "))
                        .font(.bodyText(13))
                        .foregroundColor(.theme.textSecondary)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .padding(16)
        .background(Color.theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var mealsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Meal Plan")
                .font(.subheadline(16))
                .foregroundColor(.theme.textPrimary)

            ForEach(plan.meals) { meal in
                MealTemplateCard(meal: meal)
            }
        }
    }
}

// MARK: - Meal Template Card

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
                            .font(.bodyMedium(15))
                            .foregroundColor(.theme.textPrimary)
                        Text(meal.timing)
                            .font(.caption(12))
                            .foregroundColor(.theme.textMuted)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(meal.calories) kcal")
                            .font(.bodyMedium(13))
                            .foregroundColor(.theme.primary)
                        HStack(spacing: 4) {
                            macroTag(value: "\(meal.protein)g P", color: .theme.secondary)
                            macroTag(value: "\(meal.carbs)g C", color: Color.yellow)
                            macroTag(value: "\(meal.fat)g F", color: Color.orange)
                        }
                    }
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption(12))
                        .foregroundColor(.theme.textMuted)
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            if isExpanded && !meal.examples.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Divider().background(Color.theme.surfaceLight)
                    Text("Example Foods")
                        .font(.caption(12))
                        .foregroundColor(.theme.textMuted)
                        .padding(.top, 4)
                    FlowLayout(items: meal.examples) { item in
                        Text(item)
                            .font(.caption(12))
                            .foregroundColor(.theme.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.theme.surfaceLight)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
        .background(Color.theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func macroTag(value: String, color: Color) -> some View {
        Text(value)
            .font(.caption(10))
            .foregroundColor(color)
    }
}

// MARK: - Flow Layout

private struct FlowLayout<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    init(items: [Item], @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.content = content
    }

    var body: some View {
        // Simple wrapping via fixed rows for now
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
