import SwiftUI

// MARK: - Bottom-docked logging controls (Phase 1b)
//
// The numeric keypad + RPE quick-pick that auto-pop from the bottom when a set
// value is tapped — replacing the old modal editor sheet. Part of the calm-list
// redesign (see docs/superpowers/specs/2026-06-08-program-frontend-redesign-design.md).

enum NumberPadKey: Equatable {
    case digit(Int)
    case decimal
    case delete
}

/// A bottom-docked numeric keypad. Stateless: the parent owns the typed buffer
/// (so it can write the value live into the session and re-target as different
/// cells are tapped). The parent passes the current `valueText` to show.
struct InlineNumberPad: View {
    let title: String
    let unit: String?
    let valueText: String
    let placeholder: String
    let allowsDecimal: Bool
    let onKey: (NumberPadKey) -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title.uppercased())
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)
                Spacer()
                Text(valueText.isEmpty ? placeholder : valueText)
                    .font(Font.unbound.monoL.weight(.bold))
                    .foregroundStyle(valueText.isEmpty ? Color.unbound.textTertiary : Color.unbound.textPrimary)
                if let unit {
                    Text(unit)
                        .font(Font.unbound.captionS.weight(.semibold))
                        .foregroundStyle(Color.unbound.textTertiary)
                }
            }

            VStack(spacing: 8) {
                ForEach([[1, 2, 3], [4, 5, 6], [7, 8, 9]], id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(row, id: \.self) { digit in
                            keyButton(text: "\(digit)") { onKey(.digit(digit)) }
                        }
                    }
                }
                HStack(spacing: 8) {
                    if allowsDecimal {
                        keyButton(text: ".") { onKey(.decimal) }
                    } else {
                        Color.clear.frame(maxWidth: .infinity, minHeight: 48)
                    }
                    keyButton(text: "0") { onKey(.digit(0)) }
                    keyButton(systemImage: "delete.left") { onKey(.delete) }
                }
            }

            Button(action: onDone) {
                Text("Done")
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.bg)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.unbound.accent))
            }
            .buttonStyle(.plain)
        }
        .bottomDock()
    }

    private func keyButton(
        text: String? = nil,
        systemImage: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            UnboundHaptics.tick()
            action()
        } label: {
            Group {
                if let text {
                    Text(text).font(Font.unbound.titleM.weight(.semibold))
                } else if let systemImage {
                    Image(systemName: systemImage).font(.system(size: 18, weight: .semibold))
                }
            }
            .foregroundStyle(Color.unbound.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.unbound.surfaceElevated))
        }
        .buttonStyle(.plain)
    }
}

/// Bottom-docked RPE quick-pick (its own control, never the numeric keypad).
/// Real strength scale (6–10) with reps-in-reserve meanings.
struct InlineRPEPicker: View {
    let current: Int?
    let onPick: (Int?) -> Void
    let onDone: () -> Void

    private static let rows: [(value: Int, meaning: String)] = [
        (10, "Nothing left"),
        (9, "1 rep left"),
        (8, "2 reps left"),
        (7, "3 reps left"),
        (6, "4+ reps left")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("HOW HARD? — RPE")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.textTertiary)
                Spacer()
                Button("Clear") { onPick(nil) }
                    .font(Font.unbound.captionS.weight(.bold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .buttonStyle(.plain)
            }
            .padding(.bottom, 6)

            ForEach(Self.rows, id: \.value) { row in
                Button { onPick(row.value) } label: {
                    HStack(spacing: 16) {
                        Text("\(row.value)")
                            .font(Font.unbound.monoL)
                            .foregroundStyle(current == row.value ? Color.unbound.accent : Color.unbound.textPrimary)
                            .frame(width: 38, alignment: .leading)
                        Text(row.meaning)
                            .font(Font.unbound.bodyM)
                            .foregroundStyle(Color.unbound.textSecondary)
                        Spacer()
                        if current == row.value {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.unbound.accent)
                        }
                    }
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if row.value != Self.rows.last?.value {
                    Divider().overlay(Color.unbound.borderSubtle)
                }
            }
        }
        .bottomDock()
    }
}

// MARK: - Bottom dock chrome

private struct BottomDockModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity)
            .background {
                UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22, style: .continuous)
                    .fill(Color.unbound.surface)
                    .overlay(
                        UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22, style: .continuous)
                            .strokeBorder(Color.unbound.border, lineWidth: 1)
                    )
                    .ignoresSafeArea(edges: .bottom)
            }
            .transition(.move(edge: .bottom))
    }
}

extension View {
    /// Wraps a control as a bottom-anchored dock panel (surface fill, top-rounded,
    /// extends under the home indicator, slides in from the bottom).
    func bottomDock() -> some View { modifier(BottomDockModifier()) }
}
