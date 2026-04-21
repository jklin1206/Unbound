import SwiftUI

extension View {
    @ViewBuilder
    func loadingOverlay(_ isLoading: Bool) -> some View {
        self.overlay {
            if isLoading {
                ZStack {
                    Color.black.opacity(0.4)
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                }
                .ignoresSafeArea()
            }
        }
    }
}
