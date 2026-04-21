import SwiftUI

struct Step_Chapter_Scan: View {
    let onContinue: () -> Void

    var body: some View {
        ChapterInterstitial(
            number: "CHAPTER III",
            title: "THE SCAN",
            message: "Your truth. One frame.",
            onContinue: onContinue
        )
    }
}

#Preview {
    Step_Chapter_Scan(onContinue: {})
}
