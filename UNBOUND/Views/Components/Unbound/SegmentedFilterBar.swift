import SwiftUI

/// Calm scope filter: a single horizontally-scrollable segmented control whose
/// selected item raises to a fill-only surface (no capsule, no border, no pill).
/// One control, not a rail of chips - the selection cue is the raised surface +
/// luminance, per the calm-list language.
struct SegmentedFilterBar<Item: Hashable>: View {
    let items: [Item]
    let title: (Item) -> String
    @Binding var selection: Item
    /// When true the segments split the full width evenly (equal-width, roomier
    /// gaps) instead of packing left inside a horizontal scroll. Use for a small,
    /// fixed set of segments (e.g. Form / Assist / Tips / Fixes) that should span
    /// the screen; leave false for longer, scrollable filter rails.
    var fillEqually: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if fillEqually {
            HStack(spacing: 10) {
                ForEach(items, id: \.self) { item in
                    segment(item).frame(maxWidth: .infinity)
                }
            }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(items, id: \.self) { item in
                        segment(item)
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }

    @ViewBuilder
    private func segment(_ item: Item) -> some View {
        let isSelected = item == selection
        Button {
            guard !isSelected else { return }
            UnboundHaptics.soft()
            // Reduce Motion: skip the snappy crossfade, select instantly.
            if reduceMotion {
                selection = item
            } else {
                withAnimation(.snappy(duration: 0.22)) { selection = item }
            }
        } label: {
            Text(title(item))
                .font(Font.unbound.bodyMStrong)
                .foregroundStyle(isSelected ? Color.unbound.textPrimary : Color.unbound.textTertiary)
                .frame(maxWidth: fillEqually ? .infinity : nil)
                .padding(.horizontal, fillEqually ? 8 : 14)
                .padding(.vertical, fillEqually ? 10 : 8)
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
