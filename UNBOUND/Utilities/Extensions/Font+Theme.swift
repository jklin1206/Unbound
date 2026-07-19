import SwiftUI

// Legacy font helpers (60 call sites). Each takes an arbitrary `size`, so all
// route through `Font.unboundScaled` (defined in Font+Unbound.swift) to scale with
// Dynamic Type while rendering identically to the former `.system(size:)` at the
// default (Large) content size category. Anchor text style is picked per role.
extension Font {
    static func headline(_ size: CGFloat = 28) -> Font {
        .unboundScaled(size, relativeTo: .title, weight: .bold)
    }
    static func subheadline(_ size: CGFloat = 20) -> Font {
        .unboundScaled(size, relativeTo: .title3, weight: .semibold)
    }
    static func bodyText(_ size: CGFloat = 16) -> Font {
        .unboundScaled(size, relativeTo: .body, weight: .regular)
    }
    static func bodyMedium(_ size: CGFloat = 16) -> Font {
        .unboundScaled(size, relativeTo: .body, weight: .medium)
    }
    static func stat(_ size: CGFloat = 24) -> Font {
        .unboundScaled(size, relativeTo: .title2, weight: .bold, monospaced: true)
    }
    static func caption(_ size: CGFloat = 13) -> Font {
        .unboundScaled(size, relativeTo: .footnote, weight: .regular)
    }
}
