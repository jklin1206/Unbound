import SwiftUI

struct Step_Chapter_Scan: View {
    let onContinue: () -> Void

    var body: some View {
        ChapterInterstitial(
            number: "CHAPTER III",
            title: "ARC ENTRY",
            message: "Log your Day Zero. The climb starts here.",
            onContinue: onContinue
        )
    }
}

#Preview {
    Step_Chapter_Scan(onContinue: {})
}
