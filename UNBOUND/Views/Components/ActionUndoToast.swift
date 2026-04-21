import SwiftUI

struct ActionUndoToast: View {
    let entry: AppliedCoachAction
    let onUndo: () -> Void
    let onDismiss: () -> Void

    @State private var progress: CGFloat = 1.0
    @State private var undone = false
    private let duration: Double = 10.0

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .strokeBorder(Color.unbound.border, lineWidth: 2)
                    .frame(width: 22, height: 22)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.unbound.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 22, height: 22)
                    .animation(.linear(duration: duration), value: progress)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(undone ? "Undone" : "Action applied")
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text(entry.action.description)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if !undone {
                Button {
                    UnboundHaptics.medium()
                    undone = true
                    onUndo()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { onDismiss() }
                } label: {
                    Text("Undo")
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(Color.unbound.accent.opacity(0.15))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.unbound.surface.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.unbound.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 16, x: 0, y: 6)
        .onAppear {
            withAnimation(.linear(duration: duration)) { progress = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                if !undone { onDismiss() }
            }
        }
    }
}
