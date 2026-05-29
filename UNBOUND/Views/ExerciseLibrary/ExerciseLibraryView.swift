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

    private var progressOverview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                libraryStat("RESULTS", "\(viewModel.resultCount)", .theme.textPrimary)
                libraryStat("RANKED", "\(viewModel.rankedCount)", .theme.primary)
                libraryStat("WITH XP", "\(viewModel.withAPCount)", .theme.success)
            }

            if !viewModel.topProgressRows.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.topProgressRows) { row in
                            topLiftChip(row)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func libraryStat(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption(10))
                .foregroundColor(.theme.textMuted)
            Text(value)
                .font(.bodyMedium(16))
                .foregroundColor(color)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func topLiftChip(_ row: ExerciseLibraryDisplayRow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Text(row.tier?.displayName.uppercased() ?? "LOGGED")
                    .font(.caption(9))
                    .foregroundColor((row.tier?.rewardTint ?? .theme.success))
                if row.totalAP > 0 {
                    Text("\(Int(row.totalAP.rounded())) XP")
                        .font(.caption(9))
                        .foregroundColor(.theme.textMuted)
                        .monospacedDigit()
                }
            }

            Text(row.item.name)
                .font(.caption(12))
                .foregroundColor(.theme.textPrimary)
                .lineLimit(1)

            if let summary = row.bestMetricSummary {
                Text(summary)
                    .font(.caption(10))
                    .foregroundColor(.theme.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 148, alignment: .leading)
        .padding(10)
        .background(Color.theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
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
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.selectedStatusFilter = filter
            }
        } label: {
            Text(filter.displayName)
                .font(.caption(12))
                .foregroundColor(isSelected ? .white : .theme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? Color.theme.primary : Color.theme.surface)
                .clipShape(Capsule())
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
                    .foregroundColor(.theme.textPrimary)
                Spacer()
                Text("\(items.count)")
                    .font(.caption(12))
                    .foregroundColor(.theme.textMuted)
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
                .foregroundColor(.theme.textMuted)
            Text("No exercises match those filters.")
                .font(.bodyMedium(15))
                .foregroundColor(.theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }
}
