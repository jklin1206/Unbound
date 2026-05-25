import SwiftUI

struct SkillBlockPickerSheet: View {
    var activeGoalIDs: [String]
    var onPick: (SkillNode, SkillBlockKind) -> Void
    var onDismiss: () -> Void

    @State private var searchText = ""
    @State private var selectedKind: SkillBlockKind = .primer

    var body: some View {
        NavigationStack {
            ZStack {
                Color.unbound.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    controls
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .padding(.bottom, 10)

                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredNodes) { node in
                                skillRow(node)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 28)
                    }
                }
            }
            .navigationTitle("Add Skill Block")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", action: onDismiss)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.unbound.bg)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pick a skill and where it belongs in the session. UNBOUND inserts it as a real workout block.")
                .font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            TextField("Search skills", text: $searchText)
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textPrimary)
                .textInputAutocapitalization(.never)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.unbound.surfaceElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                )
                .accessibilityIdentifier("skillBlockPicker.search")

            Picker("Block type", selection: $selectedKind) {
                ForEach(SkillBlockKind.allCases, id: \.self) { kind in
                    Text(shortLabel(for: kind)).tag(kind)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var filteredNodes: [SkillNode] {
        let normalized = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return sortedNodes.filter { node in
            guard !normalized.isEmpty else { return true }
            return node.title.lowercased().contains(normalized)
                || node.cluster.displayName.lowercased().contains(normalized)
                || node.target.displayName.lowercased().contains(normalized)
        }
    }

    private var sortedNodes: [SkillNode] {
        let active = Set(activeGoalIDs)
        return SkillGraph.shared.nodes.sorted { lhs, rhs in
            let lhsActive = active.contains(lhs.id)
            let rhsActive = active.contains(rhs.id)
            if lhsActive != rhsActive { return lhsActive && !rhsActive }
            if lhs.cluster.displayName != rhs.cluster.displayName {
                return lhs.cluster.displayName < rhs.cluster.displayName
            }
            if lhs.tier != rhs.tier { return lhs.tier < rhs.tier }
            return lhs.title < rhs.title
        }
    }

    private func skillRow(_ node: SkillNode) -> some View {
        Button {
            UnboundHaptics.soft()
            onPick(node, selectedKind)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: node.glyph)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(rowTint(for: node))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(rowTint(for: node).opacity(0.13)))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(node.title)
                            .font(Font.unbound.bodyS.weight(.heavy))
                            .foregroundStyle(Color.unbound.textPrimary)
                            .lineLimit(1)
                        if activeGoalIDs.contains(node.id) {
                            Text("ACTIVE")
                                .font(Font.unbound.captionS.weight(.black))
                                .tracking(0.8)
                                .foregroundStyle(Color.unbound.bg)
                                .padding(.horizontal, 6)
                                .frame(height: 18)
                                .background(Capsule().fill(Color.unbound.coachCyan))
                        }
                    }
                    Text("\(node.cluster.displayName) - \(node.target.displayName)")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(shortLabel(for: selectedKind).uppercased())
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add \(node.title) as \(selectedKind.displayName)")
    }

    private func rowTint(for node: SkillNode) -> Color {
        activeGoalIDs.contains(node.id) ? Color.unbound.coachCyan : Color.unbound.accent
    }

    private func shortLabel(for kind: SkillBlockKind) -> String {
        switch kind {
        case .primer: return "Primer"
        case .main: return "Main"
        case .accessory: return "Accessory"
        case .mobility: return "Mobility"
        }
    }
}
