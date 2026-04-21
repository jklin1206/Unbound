import SwiftUI

struct Step_Chapter_Mapping: View {
    let onContinue: () -> Void

    var body: some View {
        ChapterInterstitial(
            number: "CHAPTER II",
            title: "THE MAPPING",
            message: "We map who you are. Answer true.",
            onContinue: onContinue
        )
    }
}

#Preview {
    Step_Chapter_Mapping(onContinue: {})
}
