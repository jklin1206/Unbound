import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Unbound Adaptive Backdrop Text
//
// The adaptive text-over-art machinery: foreground candidates, bright-surface
// preferences, the sampling-context environment plumbing, and the scope /
// foreground ViewModifiers behind `unboundAdaptiveBackdropScope` /
// `unboundAdaptiveBackdropForeground` (entry points in UnboundBackdrops.swift).
// Split from UnboundBackdrops.swift.

enum UnboundAdaptiveBackdropTextShadow {
    case dark
    case light
    case none
}

struct UnboundAdaptiveBackdropTextCandidate {
    let color: Color
    let relativeLuminance: CGFloat
    let shadow: UnboundAdaptiveBackdropTextShadow

    init(color: Color, uiColor: UIColor, shadow: UnboundAdaptiveBackdropTextShadow) {
        self.color = color
        relativeLuminance = uiColor.unboundRelativeLuminance
        self.shadow = shadow
    }
}

struct UnboundAdaptiveBackdropBrightPreference {
    let minimumAverage: CGFloat
    let minimumContrastMultiplier: CGFloat
    let minimumContrastFloor: CGFloat
    let minimumAverageContrast: CGFloat

    static let heroTitle = UnboundAdaptiveBackdropBrightPreference(
        minimumAverage: 0.22,
        minimumContrastMultiplier: 0.44,
        minimumContrastFloor: 1.36,
        minimumAverageContrast: 2.70
    )

    static let heroBody = UnboundAdaptiveBackdropBrightPreference(
        minimumAverage: 0.20,
        minimumContrastMultiplier: 0.42,
        minimumContrastFloor: 1.30,
        minimumAverageContrast: 2.45
    )

    static let accent = UnboundAdaptiveBackdropBrightPreference(
        minimumAverage: 0.18,
        minimumContrastMultiplier: 0.40,
        minimumContrastFloor: 1.22,
        minimumAverageContrast: 1.72
    )
}

extension Array where Element == UnboundAdaptiveBackdropTextCandidate {
    static var unboundBackdropPrimary: [UnboundAdaptiveBackdropTextCandidate] {
        return [
            UnboundAdaptiveBackdropTextCandidate(
                color: Color.unbound.textPrimary,
                uiColor: UIColor(Color.unbound.textPrimary),
                shadow: .dark
            )
        ]
    }

    static var unboundBackdropBody: [UnboundAdaptiveBackdropTextCandidate] {
        return [
            UnboundAdaptiveBackdropTextCandidate(
                color: Color.unbound.textPrimary,
                uiColor: UIColor(Color.unbound.textPrimary),
                shadow: .dark
            )
        ]
    }

    static var unboundBackdropMeta: [UnboundAdaptiveBackdropTextCandidate] {
        return [
            UnboundAdaptiveBackdropTextCandidate(
                color: Color.unbound.textPrimary,
                uiColor: UIColor(Color.unbound.textPrimary),
                shadow: .dark
            )
        ]
    }

    static func unboundBackdropAccent(_ tint: Color) -> [UnboundAdaptiveBackdropTextCandidate] {
        return [
            UnboundAdaptiveBackdropTextCandidate(
                color: Color.unbound.textPrimary,
                uiColor: UIColor(Color.unbound.textPrimary),
                shadow: .dark
            )
        ]
    }
}

private struct UnboundBackdropSamplingContext: Equatable {
    var assetName: String?
    var role: BackdropPresentationRole
    var containerFrame: CGRect

    var isReady: Bool {
        assetName != nil && containerFrame.width > 1 && containerFrame.height > 1
    }
}

private struct UnboundBackdropSamplingContextKey: EnvironmentKey {
    static let defaultValue = UnboundBackdropSamplingContext(
        assetName: nil,
        role: .homePoster,
        containerFrame: .zero
    )
}

private extension EnvironmentValues {
    var unboundBackdropSamplingContext: UnboundBackdropSamplingContext {
        get { self[UnboundBackdropSamplingContextKey.self] }
        set { self[UnboundBackdropSamplingContextKey.self] = newValue }
    }
}

private struct UnboundGlobalFrameReader: View {
    let onChange: (CGRect) -> Void

    var body: some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .global)

            Color.clear
                .onAppear {
                    onChange(frame)
                }
                .onChange(of: frame) { _, newFrame in
                    onChange(newFrame)
                }
        }
    }
}

struct UnboundAdaptiveBackdropScope: ViewModifier {
    let assetName: String?
    let role: BackdropPresentationRole
    @State private var containerFrame: CGRect = .zero

    func body(content: Content) -> some View {
        content
            .environment(
                \.unboundBackdropSamplingContext,
                UnboundBackdropSamplingContext(
                    assetName: assetName,
                    role: role,
                    containerFrame: containerFrame
                )
            )
            .background {
                UnboundGlobalFrameReader { frame in
                    if containerFrame.unboundNeedsGeometryUpdate(to: frame) {
                        containerFrame = frame
                    }
                }
            }
    }
}

struct UnboundAdaptiveBackdropForeground: ViewModifier {
    @Environment(\.unboundBackdropSamplingContext) private var backdropContext
    let candidates: [UnboundAdaptiveBackdropTextCandidate]
    let minimumContrast: CGFloat
    let brightPreference: UnboundAdaptiveBackdropBrightPreference?
    let shadowStrength: Double
    @State private var textFrame: CGRect = .zero

    func body(content: Content) -> some View {
        let candidate = resolvedCandidate

        content
            .foregroundStyle(candidate.color)
            .modifier(
                UnboundAdaptiveBackdropTextShadowModifier(
                    style: candidate.shadow,
                    strength: shadowStrength
                )
            )
            .background {
                UnboundGlobalFrameReader { frame in
                    if textFrame.unboundNeedsGeometryUpdate(to: frame) {
                        textFrame = frame
                    }
                }
            }
    }

    private var resolvedCandidate: UnboundAdaptiveBackdropTextCandidate {
        guard let fallback = candidates.first else {
            return UnboundAdaptiveBackdropTextCandidate(
                color: Color.unbound.textPrimary,
                uiColor: UIColor(Color.unbound.textPrimary),
                shadow: .dark
            )
        }

        guard backdropContext.isReady,
              textFrame.width > 1,
              textFrame.height > 1,
              let assetName = backdropContext.assetName,
              let image = UIImage(named: assetName) else {
            return fallback
        }

        return image.unboundBestBackdropTextCandidate(
            candidates: candidates,
            containerFrame: backdropContext.containerFrame,
            textFrame: textFrame,
            role: backdropContext.role,
            minimumContrast: minimumContrast,
            brightPreference: brightPreference
        ) ?? fallback
    }
}

private struct UnboundAdaptiveBackdropTextShadowModifier: ViewModifier {
    let style: UnboundAdaptiveBackdropTextShadow
    let strength: Double

    @ViewBuilder
    func body(content: Content) -> some View {
        let amount = CGFloat(strength)

        switch style {
        case .dark:
            content.unboundTextShadow(strength: strength)
        case .light:
            content
                .shadow(
                    color: Color.white.opacity(0.16 * strength),
                    radius: 1.4 * amount,
                    x: 0,
                    y: 0.5 * amount
                )
                .shadow(
                    color: Color.black.opacity(0.16 * strength),
                    radius: 1.4 * amount,
                    x: 0,
                    y: 1.0 * amount
                )
        case .none:
            content
        }
    }
}

private extension CGRect {
    func unboundNeedsGeometryUpdate(to newValue: CGRect) -> Bool {
        abs(minX - newValue.minX) > 0.5 ||
            abs(minY - newValue.minY) > 0.5 ||
            abs(width - newValue.width) > 0.5 ||
            abs(height - newValue.height) > 0.5
    }
}
