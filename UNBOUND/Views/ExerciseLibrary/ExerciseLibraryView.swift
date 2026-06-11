import SwiftUI

struct ExerciseLibraryView: View {
    @StateObject private var viewModel: ExerciseLibraryViewModel
    @EnvironmentObject private var services: ServiceContainer

    init(services: ServiceContainer) {
        _viewModel = StateObject(wrappedValue: ExerciseLibraryViewModel(services: services))
    }

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                searchBar
                progressOverview
                sortControl
                categoryFilter
                statusFilter
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
        ExerciseLibrarySearchField(text: $viewModel.searchText)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
    }

    private var progressOverview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ExerciseLibraryStatCard(label: "RESULTS", value: "\(viewModel.resultCount)", tint: Color.unbound.textPrimary)
                ExerciseLibraryStatCard(label: "RANKED", value: "\(viewModel.rankedCount)", tint: Color.unbound.accent)
                ExerciseLibraryStatCard(label: "WITH XP", value: "\(viewModel.withAPCount)", tint: Color.unbound.success)
            }

            if !viewModel.topProgressRows.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.topProgressRows) { row in
                            ExerciseLibraryProgressChip(row: row)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var sortControl: some View {
        Picker("Sort", selection: $viewModel.selectedSort) {
            ForEach(ExerciseLibrarySort.allCases) { sort in
                Text(sort.displayName).tag(sort)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
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

    private var statusFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ExerciseLibraryStatusFilter.allCases) { filter in
                    statusChip(filter)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }

    private func statusChip(_ filter: ExerciseLibraryStatusFilter) -> some View {
        let isSelected = viewModel.selectedStatusFilter == filter
        return ExerciseLibraryFilterChip(
            title: filter.displayName,
            isSelected: isSelected,
            fontSize: 12,
            horizontalPadding: 12
        ) {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.selectedStatusFilter = filter
            }
        }
    }

    private func categoryChip(title: String, category: ExerciseCategory?) -> some View {
        let isSelected = viewModel.selectedCategory == category
        return ExerciseLibraryFilterChip(title: title, isSelected: isSelected) {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.selectedCategory = category
            }
        }
    }

    // MARK: - Summary Bar

    private var summaryBar: some View {
        HStack(spacing: 0) {
            ExerciseLibrarySummaryItem(count: viewModel.availableCount, label: "Available", tint: Color.unbound.success)
            summaryDivider
            ExerciseLibrarySummaryItem(count: viewModel.substituteCount, label: "Substitute", tint: Color.unbound.rankAmber)
            summaryDivider
            ExerciseLibrarySummaryItem(count: viewModel.avoidCount, label: "Avoid", tint: Color.unbound.alert)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
    }

    private var summaryDivider: some View {
        Rectangle()
            .fill(Color.unbound.surfaceElevated)
            .frame(width: 1, height: 20)
    }

    // MARK: - Exercise List

    private var exerciseList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20, pinnedViews: []) {
                ForEach(viewModel.filteredGroups, id: \.0) { title, items in
                    exerciseSection(title: title, items: items)
                }
                if viewModel.filteredGroups.isEmpty {
                    emptyState
                }
            }
            .padding(16)
            .padding(.bottom, 32)
        }
    }

    private func exerciseSection(title: String, items: [ExerciseLibraryDisplayRow]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.subheadline(16))
                    .foregroundColor(Color.unbound.textPrimary)
                Spacer()
                Text("\(items.count)")
                    .font(.caption(12))
                    .foregroundColor(Color.unbound.textTertiary)
                    .monospacedDigit()
            }

            VStack(spacing: 8) {
                ForEach(items) { row in
                    ExercisePreferenceRow(row: row, viewModel: viewModel)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(Color.unbound.textTertiary)
            Text("No exercises match those filters.")
                .font(.bodyMedium(15))
                .foregroundColor(Color.unbound.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }
}
