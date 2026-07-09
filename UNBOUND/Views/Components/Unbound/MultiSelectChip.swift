import SwiftUI

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

#Preview("Flexible wrap") {
    FlexibleWrap(spacing: 10) {
        ForEach(Equipment.allCases) { equipment in
            Text(equipment.displayName)
                .font(Font.unbound.bodyMStrong)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Capsule(style: .continuous).fill(Color.unbound.surface))
        }
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.unbound.bg)
}
