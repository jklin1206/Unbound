import SwiftUI

// MARK: - MultiSelectChip
//
// Capsule chip for multi-select grids (equipment, obstacles, prior attempts).
// Icon is SF Symbol (spec bans emoji). Selected state = violet border +
// faint violet tint + slight scale.

struct MultiSelectChip: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void

    @State private var isPressed: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                }
                Text(title)
                    .font(Font.unbound.bodyMStrong)
            }
            .foregroundStyle(
                isSelected ? Color.unbound.accent : Color.unbound.textPrimary
            )
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                Capsule(style: .continuous)
                    .fill(Color.unbound.accent.opacity(isSelected ? 0.08 : 0))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.unbound.accent : Color.unbound.border,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .shadow(
                color: isSelected
                    ? Color.unbound.accent.opacity(0.25)
                    : Color.black.opacity(0.25),
                radius: isSelected ? 10 : 6,
                x: 0,
                y: isSelected ? 0 : 4
            )
            .scaleEffect(isPressed ? 0.96 : (isSelected ? 1.02 : 1.0))
            .animation(.spring(response: 0.28, dampingFraction: 0.75), value: isSelected)
            .animation(.spring(response: 0.22, dampingFraction: 0.75), value: isPressed)
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(
            PressableCardStyle(
                isPressed: $isPressed,
                onPressBegin: { UnboundHaptics.soft() },
                onPressRelease: { UnboundHaptics.medium() }
            )
        )
    }
}

// MARK: - MultiSelectChipGrid — convenience wrapper

struct MultiSelectChipGrid<T: Hashable & Identifiable>: View {
    let options: [T]
    @Binding var selection: Set<T>
    let title: (T) -> String
    var icon: (T) -> String? = { _ in nil }

    var body: some View {
        FlexibleWrap(spacing: 10) {
            ForEach(options) { option in
                MultiSelectChip(
                    title: title(option),
                    icon: icon(option),
                    isSelected: selection.contains(option)
                ) {
                    if selection.contains(option) {
                        selection.remove(option)
                    } else {
                        selection.insert(option)
                    }
                }
            }
        }
    }
}

// MARK: - FlexibleWrap — tag-cloud layout
// A minimal HStack-that-wraps. Used for chip grids.

struct FlexibleWrap: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let arrangement = arrange(subviews: subviews, maxWidth: maxWidth)
        return arrangement.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let arrangement = arrange(subviews: subviews, maxWidth: bounds.width)
        for (i, frame) in arrangement.frames.enumerated() {
            subviews[i].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrange(subviews: Subviews, maxWidth: CGFloat) -> (frames: [CGRect], size: CGSize) {
        var frames: [CGRect] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            totalWidth = max(totalWidth, currentX - spacing)
        }
        return (frames, CGSize(width: totalWidth, height: currentY + lineHeight))
    }
}

#Preview("Chips") {
    StatefulChipPreview()
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.unbound.bg)
}

private struct StatefulChipPreview: View {
    @State private var selected: Set<Equipment> = [.fullGym, .homeWeights]
    var body: some View {
        MultiSelectChipGrid(
            options: Equipment.allCases,
            selection: $selected,
            title: { $0.displayName },
            icon: { $0.icon }
        )
    }
}
