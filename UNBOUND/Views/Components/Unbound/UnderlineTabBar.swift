import SwiftUI

/// Calm underline tab switcher. The selected label raises to `textPrimary` with a
/// thin accent underline that slides between tabs. No capsules, no pills - the
/// selection cue is the underline + luminance, per the calm-list language.
struct UnderlineTabBar<Tab: Hashable>: View {
    let tabs: [Tab]
    let title: (Tab) -> String
    @Binding var selection: Tab

    @Namespace private var underlineNS
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.self) { tab in
                let isSelected = tab == selection
                Button {
                    guard !isSelected else { return }
                    UnboundHaptics.soft()
                    // No withAnimation here: that transaction would propagate to
                    // the bound content and crossfade panes over each other. The
                    // underline animates locally via `.animation(value:)` below;
                    // the content swap stays instant.
                    selection = tab
                } label: {
                    VStack(spacing: 8) {
                        Text(title(tab))
                            .font(Font.unbound.bodyMStrong)
                            .foregroundStyle(isSelected ? Color.unbound.textPrimary : Color.unbound.textTertiary)
                            .frame(maxWidth: .infinity)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        ZStack {
                            Color.clear.frame(height: 2)
                            if isSelected {
                                Rectangle()
                                    .fill(Color.unbound.accent)
                                    .frame(height: 2)
                                    .matchedGeometryEffect(id: "underline", in: underlineNS)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(title(tab))
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.top, 4)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.unbound.border).frame(height: 1)
        }
        // Animate only the underline + label tint, scoped to this bar.
        // Reduce Motion: skip the slide, let the underline jump instantly.
        .animation(reduceMotion ? nil : .snappy(duration: 0.26), value: selection)
    }
}

#Preview("Underline tabs") {
    struct Demo: View {
        @State private var selection = "Overview"
        var body: some View {
            VStack {
                UnderlineTabBar(
                    tabs: ["Overview", "Rank", "Stats", "History"],
                    title: { $0 },
                    selection: $selection
                )
                Spacer()
                Text(selection).font(Font.unbound.titleL).foregroundStyle(Color.unbound.textPrimary)
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.unbound.bg)
        }
    }
    return Demo()
}
