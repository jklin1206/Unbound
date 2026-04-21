import SwiftUI

struct PhotoCaptureOverlay: View {
    let angle: ScanAngle

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)

            RoundedRectangle(cornerRadius: 80)
                .stroke(Color.theme.primary.opacity(0.6), lineWidth: 2)
                .frame(width: 200, height: 400)

            VStack {
                Spacer()

                Text(angle.instruction)
                    .font(.bodyMedium())
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.bottom, 140)
            }
        }
    }
}
