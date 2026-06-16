import UIKit

/// Non-deprecated replacement for `UIScreen.main` (deprecated since iOS 16 for
/// multi-window / Stage Manager). Resolves the active window scene's screen; on
/// a single-window iPhone app this is behaviour-identical to `UIScreen.main`.
enum ScreenMetrics {
    private static var activeScreen: UIScreen? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return (scenes.first { $0.activationState == .foregroundActive } ?? scenes.first)?.screen
    }

    static var bounds: CGRect {
        activeScreen?.bounds ?? CGRect(x: 0, y: 0, width: 393, height: 852)
    }

    static var scale: CGFloat {
        activeScreen?.scale ?? UITraitCollection.current.displayScale
    }
}
