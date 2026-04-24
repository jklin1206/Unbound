import SwiftUI

struct Step_Chapter_Scan: View {
    let onContinue: () -> Void

    var body: some View {
        ChapterInterstitial(
            number: "CHAPTER III",
            title: "DAY ZERO",
            message: "One photo. The arc starts here.",
            onContinue: onContinue
        )
    }
}

#Preview {
    Step_Chapter_Scan(onContinue: {})
}
