import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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

private struct UnboundAdaptiveBackdropScope: ViewModifier {
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

private struct UnboundAdaptiveBackdropForeground: ViewModifier {
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

struct UnboundTextLegibilityShadow: ViewModifier {
    var strength: Double = 1

    func body(content: Content) -> some View {
        let amount = CGFloat(strength)

        content
            .shadow(
                color: Color.black.opacity(0.72 * strength),
                radius: 4.5 * amount,
                x: 0,
                y: 1.5 * amount
            )
            .shadow(
                color: Color.black.opacity(0.38 * strength),
                radius: 16 * amount,
                x: 0,
                y: 7 * amount
            )
    }
}

struct UnboundBackdropTextShadow: ViewModifier {
    let tone: UnboundBackdropTextTone
    var strength: Double = 1

    @ViewBuilder
    func body(content: Content) -> some View {
        let amount = CGFloat(strength)

        if tone.usesDarkInk {
            content
                .shadow(
                    color: Color.white.opacity(0.18 * strength),
                    radius: 1.6 * amount,
                    x: 0,
                    y: 0.6 * amount
                )
                .shadow(
                    color: Color.black.opacity(0.16 * strength),
                    radius: 1.4 * amount,
                    x: 0,
                    y: 1.2 * amount
                )
        } else {
            content.unboundTextShadow(strength: strength)
        }
    }
}

extension View {
    func unboundAdaptiveBackdropScope(
        assetName: String?,
        role: BackdropPresentationRole
    ) -> some View {
        modifier(UnboundAdaptiveBackdropScope(assetName: assetName, role: role))
    }

    func unboundAdaptiveBackdropForeground(
        candidates: [UnboundAdaptiveBackdropTextCandidate],
        minimumContrast: CGFloat = 3.0,
        brightPreference: UnboundAdaptiveBackdropBrightPreference? = nil,
        shadowStrength: Double = 1
    ) -> some View {
        modifier(
            UnboundAdaptiveBackdropForeground(
                candidates: candidates,
                minimumContrast: minimumContrast,
                brightPreference: brightPreference,
                shadowStrength: shadowStrength
            )
        )
    }

    func unboundTextShadow(strength: Double = 1) -> some View {
        modifier(UnboundTextLegibilityShadow(strength: strength))
    }

    func unboundBackdropTextShadow(tone: UnboundBackdropTextTone, strength: Double = 1) -> some View {
        modifier(UnboundBackdropTextShadow(tone: tone, strength: strength))
    }
}
