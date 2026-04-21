import SwiftUI

struct Step_Chapter_Path: View {
    let onContinue: () -> Void

    var body: some View {
        ChapterInterstitial(
            number: "CHAPTER IV",
            title: "THE PATH",
            message: "Your arc begins.",
            onContinue: onContinue
        )
    }
}

#Preview {
    Step_Chapter_Path(onContinue: {})
}
