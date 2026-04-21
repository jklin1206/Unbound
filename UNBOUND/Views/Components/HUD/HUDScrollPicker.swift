import SwiftUI

struct HUDScrollPicker<V: Hashable>: View {
    @Binding var selection: V
    let values: [V]
    let formatter: (V) -> String
    var eyebrow: String? = nil

    private let rowHeight: CGFloat = 66
    private var totalHeight: CGFloat { rowHeight * 3 }

    @State private var scrollTarget: V?
    @State private var hasSettled = false

    init(
        selection: Binding<V>,
        values: [V],
        formatter: @escaping (V) -> String,
        eyebrow: String? = nil
    ) {
        self._selection = selection
        self.values = values
        self.formatter = formatter
        self.eyebrow = eyebrow
        self._scrollTarget = State(initialValue: selection.wrappedValue)
    }

    var body: some View {
        VStack(spacing: 12) {
            if let eyebrow {
                Text(eyebrow.uppercased())
                    .font(Font.unbound.monoS)
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.accent)
            }

            HUDPanel(isActive: true, pulse: false, inset: 12) {
                ZStack {
                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 0) {
                                ForEach(values, id: \.self) { value in
                                    Text(formatter(value))
                                        .font(Font.unbound.monoL)
                                        .foregroundStyle(
                                            value == selection
                                            ? Color.unbound.textPrimary
                                            : Color.unbound.textTertiary
                                        )
                                        .frame(height: rowHeight)
                                        .frame(maxWidth: .infinity)
                                        .id(value)
                                        .opacity(value == selection ? 1.0 : 0.32)
                                        .scaleEffect(value == selection ? 1.0 : 0.85)
                                        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: selection)
                                }
                            }
                            .scrollTargetLayout()
                        }
                        .scrollTargetBehavior(.viewAligned)
                        .scrollPosition(id: $scrollTarget, anchor: .center)
                        .contentMargins(.vertical, rowHeight, for: .scrollContent)
                        .frame(height: totalHeight)
                        .mask(edgeMask)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                var tx = Transaction()
                                tx.disablesAnimations = true
                                withTransaction(tx) {
                                    proxy.scrollTo(selection, anchor: .center)
                                }
                                scrollTarget = selection
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    hasSettled = true
                                }
                            }
                        }
                        .onChange(of: scrollTarget) { _, newTarget in
                            guard let newTarget, newTarget != selection else { return }
                            selection = newTarget
                            if hasSettled {
                                UnboundHaptics.tick()
                            }
                        }
                    }

                    selectionBand
                }
                .frame(height: totalHeight)
                .padding(.vertical, 4)
            }
        }
    }

    private var edgeMask: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.22),
                .init(color: .black, location: 0.78),
                .init(color: .clear, location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var selectionBand: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                HUDHexagon()
                    .stroke(Color.unbound.accent.opacity(0.6), lineWidth: 1)
                    .frame(width: 18, height: 16)
                    .shadow(color: Color.unbound.accent.opacity(0.5), radius: 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 16)
            .overlay(
                ZStack {
                    HUDHexagon()
                        .stroke(Color.unbound.accent.opacity(0.6), lineWidth: 1)
                        .frame(width: 18, height: 16)
                        .shadow(color: Color.unbound.accent.opacity(0.5), radius: 4)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 16)
            )
            .frame(height: rowHeight)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.unbound.accent.opacity(0.4))
                    .frame(height: 0.5)
                    .shadow(color: Color.unbound.accent.opacity(0.5), radius: 3)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.unbound.accent.opacity(0.4))
                    .frame(height: 0.5)
                    .shadow(color: Color.unbound.accent.opacity(0.5), radius: 3)
            }
            Spacer()
        }
        .frame(height: totalHeight)
        .allowsHitTesting(false)
    }
}

#Preview("Picker") {
    StatefulHUDPickerPreview()
        .padding(24)
        .background(Color.unbound.bg)
}

private struct StatefulHUDPickerPreview: View {
    @State private var age: Int = 26
    var body: some View {
        HUDScrollPicker(
            selection: $age,
            values: Array(15...80),
            formatter: { "\($0) YRS" },
            eyebrow: "AGE"
        )
    }
}
