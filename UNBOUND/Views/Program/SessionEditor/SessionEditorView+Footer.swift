import SwiftUI

extension SessionEditorView {
    var bottomStartBar: some View {
        VStack(spacing: 9) {
            HStack(spacing: 8) {
                Text(mode.footerLabel)
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.1)
                    .foregroundStyle(Color.unbound.textSecondary)
                Spacer()
                Text("\(exerciseCount) exercises")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            bottomAddExerciseButton
            startSessionButton(height: 52)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .background(
            Rectangle()
                .fill(Color.unbound.bg.opacity(0.94))
                .overlay(Rectangle().fill(Color.unbound.borderSubtle).frame(height: 1), alignment: .top)
        )
    }

    func startSessionButton(height: CGFloat) -> some View {
        Button {
            guard exerciseCount > 0 else {
                showEmptyWorkoutWarning = true
                return
            }
            UnboundHaptics.heavy()
            onStart(draft)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: mode.primaryIcon)
                    .font(.system(size: 13, weight: .bold))
                Text(mode.primaryTitle)
                    .font(Font.unbound.bodyMStrong)
                    .tracking(1.5)
            }
            .foregroundStyle(Color.unbound.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.unbound.accent)
            )
            .shadow(color: Color.unbound.accent.opacity(0.35), radius: 14, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.primaryTitle.capitalized)
        .accessibilityIdentifier("sessionEditor.start")
    }

}
