import SwiftUI

/// Calm scope filter: a single horizontally-scrollable segmented control whose
/// selected item raises to a fill-only surface (no capsule, no border, no pill).
/// One control, not a rail of chips - the selection cue is the raised surface +
/// luminance, per the calm-list language.
struct SegmentedFilterBar<Item: Hashable>: View {
    let items: [Item]
    let title: (Item) -> String
    @Binding var selection: Item

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(items, id: \.self) { item in
                    let isSelected = item == selection
                    Button {
                        guard !isSelected else { return }
                        UnboundHaptics.soft()
                        withAnimation(.snappy(duration: 0.22)) { selection = item }
                    } label: {
                        Text(title(item))
                            .font(Font.unbound.bodyMStrong)
                            .foregroundStyle(isSelected ? Color.unbound.textPrimary : Color.unbound.textTertiary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(isSelected ? Color.unbound.surfaceElevated : Color.clear)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(title(item))
                    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(.horizontal, 1)
        }
    }
}

#Preview("Segmented filter") {
    struct Demo: View {
        @State private var selection: ProgramRankLibraryFilter = .all
        var body: some View {
            VStack(spacing: 24) {
                SegmentedFilterBar(
                    items: ProgramRankLibraryFilter.allCases,
                    title: { $0.displayName },
                    selection: $selection
                )
                Text(selection.displayName).font(Font.unbound.titleM).foregroundStyle(Color.unbound.textPrimary)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.unbound.bg)
        }
    }
    return Demo()
}
