import SwiftUI

struct TriStateToggle: View {
    @Binding var status: ExercisePreferenceStatus?

    var body: some View {
        HStack(spacing: 6) {
            stateButton(.available, icon: "checkmark", color: .theme.success)
            stateButton(.substitute, icon: "arrow.triangle.2.circlepath", color: .theme.warning)
            stateButton(.avoid, icon: "xmark", color: .theme.danger)
        }
    }

    private func stateButton(_ state: ExercisePreferenceStatus, icon: String, color: Color) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if status == state {
                    status = nil
                } else {
                    status = state
                    HapticManager.impact(.light)
                }
            }
        } label: {
            Image(systemName: icon)
                .font(.caption(12))
                .foregroundColor(status == state ? .white : color)
                .frame(width: 32, height: 32)
                .background(status == state ? color : color.opacity(0.15))
                .clipShape(Circle())
        }
    }
}
