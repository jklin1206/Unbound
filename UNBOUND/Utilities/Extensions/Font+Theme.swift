import SwiftUI

extension Font {
    static func headline(_ size: CGFloat = 28) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }
    static func subheadline(_ size: CGFloat = 20) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }
    static func bodyText(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }
    static func bodyMedium(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .medium, design: .default)
    }
    static func stat(_ size: CGFloat = 24) -> Font {
        .system(size: size, weight: .bold, design: .monospaced)
    }
    static func caption(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }
}
