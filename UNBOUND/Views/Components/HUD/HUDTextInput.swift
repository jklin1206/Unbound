import SwiftUI

struct HUDTextInput: View {
    @Binding var text: String
    let placeholder: String
    var eyebrow: String? = nil
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let eyebrow {
                Text(eyebrow.uppercased())
                    .font(Font.unbound.monoS)
                    .tracking(1.6)
                    .foregroundStyle(isFocused.wrappedValue ? Color.unbound.accent : Color.unbound.textTertiary)
            }

            HUDPanel(isActive: isFocused.wrappedValue, pulse: false) {
                TextField("", text: $text, prompt:
                    Text(placeholder)
                        .foregroundStyle(Color.unbound.textTertiary)
                )
                .font(Font.unbound.titleM)
                .foregroundStyle(Color.unbound.textPrimary)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .focused(isFocused)
                .padding(.horizontal, 18)
                .padding(.vertical, 18)
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.78), value: isFocused.wrappedValue)
        }
    }
}

#Preview("Input") {
    StatefulHUDInputPreview()
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.unbound.bg)
}

private struct StatefulHUDInputPreview: View {
    @State private var handle: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        HUDTextInput(
            text: $handle,
            placeholder: "Your handle",
            eyebrow: "HANDLE",
            isFocused: $focused
        )
    }
}
