import SwiftUI

struct Step_Cal00_Intro: View {
    let onContinue: () -> Void

    var body: some View {
        ChapterInterstitial(
            number: "CHAPTER V",
            title: "CALIBRATION",
            message: "Lock your starting point. The arc responds to truth.",
            onContinue: onContinue
        )
    }
}

#Preview {
    Step_Cal00_Intro(onContinue: {})
}
