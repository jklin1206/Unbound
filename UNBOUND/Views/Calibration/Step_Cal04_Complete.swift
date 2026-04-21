import SwiftUI

struct Step_Cal04_Complete: View {
    let onContinue: () -> Void

    var body: some View {
        ChapterInterstitial(
            number: "CHAPTER V · COMPLETE",
            title: "ARC LOCKED",
            message: "Your path is live.",
            onContinue: onContinue
        )
    }
}

#Preview {
    Step_Cal04_Complete(onContinue: {})
}
