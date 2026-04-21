import SwiftUI

// MARK: - ScrollWheelPicker
//
// Shows exactly three rows at a time: selected center + one above + one
// below (dimmed). Uses ScrollViewReader for reliable initial positioning
// (iOS 17's `.scrollPosition(id:, anchor: .center)` alone is flaky on
// first render — the binding is set before the ScrollView lays out, so
// the selected value lands off-center). ScrollViewReader's `.scrollTo`
// is battle-tested and fires after the first layout pass.
//
// `.scrollPosition` + `.scrollTargetBehavior(.viewAligned)` are still used
// for ongoing user-scroll tracking + haptic ticks on integer crossings.
//
// Fires `UnboundHaptics.tick()` on every integer crossing after the
// initial programmatic scroll settles (see `hasSettled`).

struct ScrollWheelPicker<V: Hashable>: View {
    @Binding var selection: V
    let values: [V]
    let formatter: (V) -> String

    private let rowHeight: CGFloat = 72
    private var totalHeight: CGFloat { rowHeight * 3 }

    @State private var scrollTarget: V?
    @State private var hasSettled = false

    init(selection: Binding<V>, values: [V], formatter: @escaping (V) -> String) {
        self._selection = selection
        self.values = values
        self.formatter = formatter
        self._scrollTarget = State(initialValue: selection.wrappedValue)
    }

    var body: some View {
        ZStack {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(values, id: \.self) { value in
                            Text(formatter(value))
                                .font(Font.unbound.monoXL)
                                .foregroundStyle(Color.unbound.textPrimary)
                                .frame(height: rowHeight)
                                .frame(maxWidth: .infinity)
                                .id(value)
                                .opacity(value == selection ? 1.0 : 0.28)
                                .scaleEffect(value == selection ? 1.0 : 0.82)
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
                    // Force initial center position via the proxy. The
                    // scrollPosition binding alone isn't reliable on first
                    // render; the proxy always is. Small delay lets the
                    // ScrollView finish its first layout pass.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        var tx = Transaction()
                        tx.disablesAnimations = true
                        withTransaction(tx) {
                            proxy.scrollTo(selection, anchor: .center)
                        }
                        scrollTarget = selection
                        // Gate haptics until after the initial programmatic scroll
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

            bandOverlay
        }
        .frame(height: totalHeight)
    }

    // MARK: Sub-views

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

    private var bandOverlay: some View {
        VStack(spacing: 0) {
            Spacer()
            Rectangle()
                .fill(Color.unbound.accent)
                .frame(height: 1)
                .shadow(color: Color.unbound.accent.opacity(0.5), radius: 4, x: 0, y: 0)
            Spacer().frame(height: rowHeight)
            Rectangle()
                .fill(Color.unbound.accent)
                .frame(height: 1)
                .shadow(color: Color.unbound.accent.opacity(0.5), radius: 4, x: 0, y: 0)
            Spacer()
        }
        .frame(height: totalHeight)
        .allowsHitTesting(false)
    }
}

// MARK: - UnitToggle

struct UnitToggle: View {
    let leftLabel: String
    let rightLabel: String
    @Binding var isRight: Bool

    var body: some View {
        HStack(spacing: 0) {
            segment(label: leftLabel, active: !isRight) { isRight = false }
            segment(label: rightLabel, active: isRight) { isRight = true }
        }
        .padding(3)
        .background(Capsule().fill(Color.unbound.surface))
        .overlay(Capsule().strokeBorder(Color.unbound.border, lineWidth: 1))
    }

    @ViewBuilder
    private func segment(label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            UnboundHaptics.medium()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                action()
            }
        }) {
            Text(label)
                .font(Font.unbound.bodyMStrong)
                .foregroundStyle(active ? Color.unbound.textPrimary : Color.unbound.textSecondary)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .frame(minWidth: 72)
                .background(
                    Capsule().fill(active ? Color.unbound.accent.opacity(0.18) : Color.clear)
                )
                .overlay(
                    Capsule().strokeBorder(active ? Color.unbound.accent : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview("Wheel + toggle") {
    StatefulWheelPreview()
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.unbound.bg)
}

private struct StatefulWheelPreview: View {
    @State private var age: Int = 26
    @State private var useMetric: Bool = false
    var body: some View {
        VStack(spacing: 32) {
            UnitToggle(leftLabel: "cm", rightLabel: "ft", isRight: $useMetric)
            ScrollWheelPicker(
                selection: $age,
                values: Array(14...55),
                formatter: { "\($0)" }
            )
        }
    }
}
