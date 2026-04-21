import SwiftUI

struct ExerciseLibraryView: View {
    @StateObject private var viewModel: ExerciseLibraryViewModel
    @EnvironmentObject private var services: ServiceContainer

    init(services: ServiceContainer) {
        _viewModel = StateObject(wrappedValue: ExerciseLibraryViewModel(services: services))
    }

    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                searchBar
                categoryFilter
                summaryBar
                exerciseList
            }
        }
        .navigationTitle("Exercise Library")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadPreferences()
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.caption(14))
                .foregroundColor(.theme.textMuted)

            TextField("Search exercises...", text: $viewModel.searchText)
                .font(.bodyText(15))
                .foregroundColor(.theme.textPrimary)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryChip(title: "All", category: nil)
                ForEach(ExerciseCategory.allCases, id: \.self) { category in
                    categoryChip(title: category.displayName, category: category)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func categoryChip(title: String, category: ExerciseCategory?) -> some View {
        let isSelected = viewModel.selectedCategory == category
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.selectedCategory = category
            }
        } label: {
            Text(title)
                .font(.caption(13))
                .foregroundColor(isSelected ? .white : .theme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.theme.primary : Color.theme.surface)
                .clipShape(Capsule())
        }
    }

    // MARK: - Summary Bar

    private var summaryBar: some View {
        HStack(spacing: 0) {
            summaryItem(count: viewModel.availableCount, label: "Available", color: .theme.success)
            summaryDivider
            summaryItem(count: viewModel.substituteCount, label: "Substitute", color: .theme.warning)
            summaryDivider
            summaryItem(count: viewModel.avoidCount, label: "Avoid", color: .theme.danger)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
    }

    private func summaryItem(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .font(.bodyMedium(14))
                .foregroundColor(count > 0 ? color : .theme.textMuted)
            Text(label)
                .font(.caption(13))
                .foregroundColor(.theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var summaryDivider: some View {
        Rectangle()
            .fill(Color.theme.surfaceLight)
            .frame(width: 1, height: 20)
    }

    // MARK: - Exercise List

    private var exerciseList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20, pinnedViews: []) {
                ForEach(viewModel.filteredGroups, id: \.0) { title, items in
                    exerciseSection(title: title, items: items)
                }
            }
            .padding(16)
            .padding(.bottom, 32)
        }
    }

    private func exerciseSection(title: String, items: [ExerciseLibraryItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline(16))
                .foregroundColor(.theme.textPrimary)

            VStack(spacing: 8) {
                ForEach(items) { item in
                    ExercisePreferenceRow(item: item, viewModel: viewModel)
                }
            }
        }
    }
}
