import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Unbound Backdrop System
//
// Backdrop art presentation + the adaptive text-legibility machinery
// (scrims, shields, tone analysis, shadows).
// Split from View+UnboundStyle.swift (was 1,369 lines).

enum BackdropPresentationRole: Equatable {
    case homePoster
    case profileBanner
    case thumbnail
}

enum UnboundBackdropAspect {
    static let homePoster: CGFloat = 9.0 / 16.0
    static let profileBanner: CGFloat = 16.0 / 9.0
}

struct UnboundBackdropArt: View {
    var assetName: String?
    var role: BackdropPresentationRole
    var tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                fallback

                if let assetName, let ui = UIImage(named: assetName) {
                    backdropImage(ui, assetName: assetName, in: proxy.size)
                }

                roleScrim
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func backdropImage(_ ui: UIImage, assetName: String, in containerSize: CGSize) -> some View {
        switch role {
        case .profileBanner:
            let imageAspect = max(0.01, ui.size.width / max(1, ui.size.height))
            let containerAspect = max(0.01, containerSize.width / max(1, containerSize.height))
            let isProfileBannerAsset = assetName.hasPrefix("profile_banner_")
            let isAuthoredForHeader = isProfileBannerAsset || abs(imageAspect - containerAspect) < 0.38

            if isProfileBannerAsset {
                Image(uiImage: ui)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(
                        width: containerSize.width,
                        height: containerSize.height,
                        alignment: .topTrailing
                    )
                    .saturation(1)
                    .contrast(1)
            } else if isAuthoredForHeader {
                Image(uiImage: ui)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(
                        width: containerSize.width,
                        height: containerSize.height,
                        alignment: .trailing
                    )
                    .clipped()
                    .saturation(1)
                    .contrast(1)
            } else {
                let aspect = UnboundBackdropAspect.profileBanner
                let bannerWidth = containerSize.width * 0.92
                let bannerHeight = min(containerSize.height * 0.62, bannerWidth / aspect)
                let bannerYOffset = containerSize.height * 0.10

                Image(uiImage: ui)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: bannerWidth, height: bannerHeight, alignment: .trailing)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .black, location: 0),
                                .init(color: .black, location: 0.78),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .offset(y: bannerYOffset)
                    .frame(width: containerSize.width, height: containerSize.height, alignment: .topTrailing)
                    .clipped()
                    .saturation(1)
                    .contrast(1)
            }
        case .homePoster, .thumbnail:
            Image(uiImage: ui)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: containerSize.width, height: containerSize.height, alignment: imageAlignment)
                .clipped()
                .saturation(saturation)
                .contrast(contrast)
        }
    }

    private var fallback: some View {
        Group {
            if role == .profileBanner {
                Color.black
            } else {
                LinearGradient(
                    colors: [
                        tint.opacity(role == .thumbnail ? 0.58 : 0.42),
                        Color.unbound.surface.opacity(role == .thumbnail ? 0.92 : 0.76),
                        Color.unbound.bg
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    private var roleScrim: some View {
        ZStack {
            switch role {
            case .homePoster:
                LinearGradient(
                    stops: [
                        .init(color: Color.unbound.bg.opacity(0.01), location: 0),
                        .init(color: Color.unbound.bg.opacity(0.05), location: 0.46),
                        .init(color: Color.unbound.bg.opacity(0.56), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.14),
                        Color.black.opacity(0.00),
                        Color.black.opacity(0.06)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                RadialGradient(
                    colors: [tint.opacity(0.018), .clear],
                    center: UnitPoint(x: 0.82, y: 0.16),
                    startRadius: 0,
                    endRadius: 260
                )

            case .profileBanner:
                LinearGradient(
                    stops: [
                        .init(color: Color.black.opacity(0.04), location: 0),
                        .init(color: Color.black.opacity(0.02), location: 0.34),
                        .init(color: Color.black.opacity(0.12), location: 0.58),
                        .init(color: Color.unbound.bg.opacity(0.42), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                LinearGradient(
                    stops: [
                        .init(color: Color.black.opacity(0.46), location: 0),
                        .init(color: Color.black.opacity(0.20), location: 0.44),
                        .init(color: Color.black.opacity(0.04), location: 0.78)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                LinearGradient(
                    stops: [
                        .init(color: Color.clear, location: 0),
                        .init(color: Color.black.opacity(0.10), location: 0.48),
                        .init(color: Color.black.opacity(0.24), location: 1)
                    ],
                    startPoint: .topTrailing,
                    endPoint: .bottomTrailing
                )

            case .thumbnail:
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.12),
                        Color.black.opacity(0.42)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }

    private var imageAlignment: Alignment {
        switch role {
        case .homePoster: return .top
        case .profileBanner: return .center
        case .thumbnail: return .center
        }
    }

    private var saturation: Double {
        switch role {
        case .homePoster: return 1.08
        case .profileBanner: return 1.10
        case .thumbnail: return 1.12
        }
    }

    private var contrast: Double {
        switch role {
        case .homePoster: return 1.05
        case .profileBanner: return 1.06
        case .thumbnail: return 1.08
        }
    }
}

struct UnboundPosterScrim: View {
    var tint: Color
    var topOpacity: Double = 0.34
    var midOpacity: Double = 0.50
    var bottomOpacity: Double = 0.92
    var sideOpacity: Double = 0.46
    var tintOpacity: Double = 0.12

    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: Color.unbound.bg.opacity(topOpacity), location: 0),
                    .init(color: Color.unbound.bg.opacity(midOpacity), location: 0.50),
                    .init(color: Color.unbound.bg.opacity(bottomOpacity), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    tint.opacity(tintOpacity),
                    tint.opacity(tintOpacity * 0.36),
                    .clear
                ],
                center: UnitPoint(x: 0.88, y: 0.10),
                startRadius: 16,
                endRadius: 280
            )

            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(sideOpacity), location: 0),
                    .init(color: Color.black.opacity(sideOpacity * 0.38), location: 0.46),
                    .init(color: Color.black.opacity(0.24), location: 1.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}

struct UnboundPosterTextShield: View {
    var leadingOpacity: Double = 0.76
    var topOpacity: Double = 0.58
    var bottomOpacity: Double = 0.74

    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: Color.unbound.bg.opacity(topOpacity), location: 0),
                    .init(color: Color.unbound.bg.opacity(topOpacity * 0.64), location: 0.36),
                    .init(color: Color.unbound.bg.opacity(bottomOpacity), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(leadingOpacity), location: 0),
                    .init(color: Color.black.opacity(leadingOpacity * 0.54), location: 0.42),
                    .init(color: Color.clear, location: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            RadialGradient(
                colors: [
                    Color.black.opacity(leadingOpacity * 0.70),
                    Color.black.opacity(leadingOpacity * 0.24),
                    .clear
                ],
                center: UnitPoint(x: 0.24, y: 0.24),
                startRadius: 0,
                endRadius: 270
            )
        }
    }
}

struct UnboundBackdropTextTone {
    let usesDarkInk: Bool
    let primary: Color
    let secondary: Color
    let tertiary: Color

    static let lightInk = UnboundBackdropTextTone(
        usesDarkInk: false,
        primary: Color.unbound.textPrimary,
        secondary: Color.unbound.textPrimary.opacity(0.92),
        tertiary: Color.unbound.textSecondary
    )

    static let darkInk = UnboundBackdropTextTone(
        usesDarkInk: true,
        primary: Color(red: 0.055, green: 0.060, blue: 0.066),
        secondary: Color(red: 0.070, green: 0.076, blue: 0.084).opacity(0.94),
        tertiary: Color(red: 0.080, green: 0.088, blue: 0.098).opacity(0.90)
    )

    static func sampled(
        assetName: String,
        regions: [CGRect],
        brightThreshold: CGFloat = 0.52
    ) -> UnboundBackdropTextTone {
        guard let image = UIImage(named: assetName) else { return .lightInk }
        let luminances = regions.compactMap { image.unboundAverageLuminance(in: $0) }
        guard !luminances.isEmpty else { return .lightInk }

        let average = luminances.reduce(0, +) / CGFloat(luminances.count)
        let brightest = luminances.max() ?? average
        let score = (average * 0.78) + (brightest * 0.22)

        return score >= brightThreshold ? .darkInk : .lightInk
    }
}

enum UnboundAdaptiveBackdropTextShadow {
    case dark
    case light
    case none
}

struct UnboundAdaptiveBackdropTextCandidate {
    let color: Color
    fileprivate let relativeLuminance: CGFloat
    fileprivate let shadow: UnboundAdaptiveBackdropTextShadow

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

private struct UnboundBackdropLuminanceSample {
    let luminances: [CGFloat]
    let average: CGFloat

    func contrastFloor(for foregroundLuminance: CGFloat) -> CGFloat {
        guard !luminances.isEmpty else { return 0 }

        let ratios = luminances
            .map { Self.contrastRatio(foregroundLuminance, $0) }
            .sorted()
        let index = min(ratios.count - 1, max(0, Int(CGFloat(ratios.count - 1) * 0.18)))
        return ratios[index]
    }

    func averageContrast(for foregroundLuminance: CGFloat) -> CGFloat {
        guard !luminances.isEmpty else { return 0 }
        let total = luminances.reduce(CGFloat(0)) {
            $0 + Self.contrastRatio(foregroundLuminance, $1)
        }
        return total / CGFloat(luminances.count)
    }

    static func contrastRatio(_ lhs: CGFloat, _ rhs: CGFloat) -> CGFloat {
        let brighter = max(lhs, rhs)
        let darker = min(lhs, rhs)
        return (brighter + 0.05) / (darker + 0.05)
    }
}

private final class UnboundBackdropLuminanceSampleBox: NSObject {
    let sample: UnboundBackdropLuminanceSample

    init(sample: UnboundBackdropLuminanceSample) {
        self.sample = sample
    }
}

private enum UnboundBackdropPixelSamplingCache {
    static let cache = NSCache<NSString, UnboundBackdropLuminanceSampleBox>()
}

private enum UnboundBackdropTextSamplingCache {
    static let cache = NSCache<NSString, NSNumber>()
}

private extension UIImage {
    func unboundBestBackdropTextCandidate(
        candidates: [UnboundAdaptiveBackdropTextCandidate],
        containerFrame: CGRect,
        textFrame: CGRect,
        role: BackdropPresentationRole,
        minimumContrast: CGFloat,
        brightPreference: UnboundAdaptiveBackdropBrightPreference?
    ) -> UnboundAdaptiveBackdropTextCandidate? {
        let localTextFrame = textFrame.offsetBy(dx: -containerFrame.minX, dy: -containerFrame.minY)
        let paddedTextFrame = localTextFrame.insetBy(dx: -2, dy: -2)

        guard let sample = unboundBackdropLuminanceSample(
            displayRect: paddedTextFrame,
            containerSize: containerFrame.size,
            role: role
        ) else {
            return nil
        }

        let scored = candidates.map { candidate in
            let floor = sample.contrastFloor(for: candidate.relativeLuminance)
            let average = sample.averageContrast(for: candidate.relativeLuminance)
            return (
                candidate: candidate,
                floor: floor,
                average: average,
                score: floor * 0.72 + average * 0.28
            )
        }

        let readable = scored.filter { $0.floor >= minimumContrast }
        if let brightPreference, sample.average >= brightPreference.minimumAverage {
            let brightSurfaceFloor = max(
                brightPreference.minimumContrastFloor,
                minimumContrast * brightPreference.minimumContrastMultiplier
            )
            let darkCandidates = scored.filter { $0.candidate.shadow == .light }

            if let darkReadable = darkCandidates
                .filter({ $0.floor >= brightSurfaceFloor })
                .max(by: { $0.score < $1.score }) {
                return darkReadable.candidate
            }

            if let darkAverageReadable = darkCandidates
                .filter({ $0.average >= brightPreference.minimumAverageContrast })
                .max(by: { $0.average < $1.average }) {
                return darkAverageReadable.candidate
            }
        }

        return (readable.isEmpty ? scored : readable)
            .max { $0.score < $1.score }?
            .candidate
    }

    func unboundBackdropLuminanceSample(
        displayRect: CGRect,
        containerSize: CGSize,
        role: BackdropPresentationRole
    ) -> UnboundBackdropLuminanceSample? {
        guard let cgImage,
              containerSize.width > 1,
              containerSize.height > 1,
              displayRect.width > 0,
              displayRect.height > 0 else {
            return nil
        }

        let imageRect = unboundImageRect(
            displayRect: displayRect,
            containerSize: containerSize,
            imageSize: CGSize(width: cgImage.width, height: cgImage.height),
            role: role
        )
        let boundedImageRect = imageRect
            .integral
            .intersection(CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))

        guard !boundedImageRect.isNull,
              boundedImageRect.width > 0,
              boundedImageRect.height > 0 else {
            return nil
        }

        let key = NSString(
            string: "pixel-\(Unmanaged.passUnretained(self).toOpaque())-\(role)-\(containerSize.width.rounded())-\(containerSize.height.rounded())-\(boundedImageRect.minX)-\(boundedImageRect.minY)-\(boundedImageRect.width)-\(boundedImageRect.height)"
        )
        if let cached = UnboundBackdropPixelSamplingCache.cache.object(forKey: key) {
            return cached.sample
        }

        guard let croppedImage = cgImage.cropping(to: boundedImageRect) else {
            return nil
        }

        let sampleWidth = 24
        let sampleHeight = 14
        let bytesPerPixel = 4
        let bytesPerRow = sampleWidth * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: sampleHeight * bytesPerRow)

        guard let context = CGContext(
            data: &pixels,
            width: sampleWidth,
            height: sampleHeight,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .low
        context.draw(croppedImage, in: CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight))

        var luminances: [CGFloat] = []
        luminances.reserveCapacity(sampleWidth * sampleHeight)

        for index in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
            let red = CGFloat(pixels[index]) / 255.0
            let green = CGFloat(pixels[index + 1]) / 255.0
            let blue = CGFloat(pixels[index + 2]) / 255.0
            luminances.append(Self.unboundRelativeLuminance(red: red, green: green, blue: blue))
        }

        let average = luminances.reduce(CGFloat(0), +) / CGFloat(max(1, luminances.count))
        let sample = UnboundBackdropLuminanceSample(luminances: luminances, average: average)
        UnboundBackdropPixelSamplingCache.cache.setObject(
            UnboundBackdropLuminanceSampleBox(sample: sample),
            forKey: key
        )
        return sample
    }

    func unboundImageRect(
        displayRect: CGRect,
        containerSize: CGSize,
        imageSize: CGSize,
        role: BackdropPresentationRole
    ) -> CGRect {
        let scale: CGFloat
        switch role {
        case .homePoster, .profileBanner, .thumbnail:
            scale = max(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
        }
        let scaledImageSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let xOrigin: CGFloat
        switch role {
        case .profileBanner:
            xOrigin = containerSize.width - scaledImageSize.width
        case .homePoster, .thumbnail:
            xOrigin = (containerSize.width - scaledImageSize.width) / 2
        }
        let yOrigin: CGFloat

        switch role {
        case .homePoster:
            yOrigin = 0
        case .profileBanner, .thumbnail:
            yOrigin = (containerSize.height - scaledImageSize.height) / 2
        }

        return CGRect(
            x: (displayRect.minX - xOrigin) / scale,
            y: (displayRect.minY - yOrigin) / scale,
            width: displayRect.width / scale,
            height: displayRect.height / scale
        )
    }

    static func unboundRelativeLuminance(red: CGFloat, green: CGFloat, blue: CGFloat) -> CGFloat {
        func channel(_ value: CGFloat) -> CGFloat {
            value <= 0.03928
                ? value / 12.92
                : pow((value + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }

    func unboundAverageLuminance(in normalizedRect: CGRect) -> CGFloat? {
        guard let cgImage else { return nil }

        let unitRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        let rect = normalizedRect.standardized.intersection(unitRect)
        guard !rect.isNull, rect.width > 0, rect.height > 0 else { return nil }

        let key = NSString(
            string: "\(Unmanaged.passUnretained(self).toOpaque())-\(rect.minX)-\(rect.minY)-\(rect.width)-\(rect.height)"
        )
        if let cached = UnboundBackdropTextSamplingCache.cache.object(forKey: key) {
            return CGFloat(cached.doubleValue)
        }

        let imageRect = CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
        let cropRect = CGRect(
            x: rect.minX * imageRect.width,
            y: rect.minY * imageRect.height,
            width: max(1, rect.width * imageRect.width),
            height: max(1, rect.height * imageRect.height)
        )
        .integral
        .intersection(imageRect)

        guard !cropRect.isNull,
              let croppedImage = cgImage.cropping(to: cropRect) else {
            return nil
        }

        let sampleWidth = 18
        let sampleHeight = 18
        let bytesPerPixel = 4
        let bytesPerRow = sampleWidth * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: sampleHeight * bytesPerRow)

        guard let context = CGContext(
            data: &pixels,
            width: sampleWidth,
            height: sampleHeight,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .low
        context.draw(croppedImage, in: CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight))

        var total: Double = 0
        for index in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
            let r = Double(pixels[index]) / 255.0
            let g = Double(pixels[index + 1]) / 255.0
            let b = Double(pixels[index + 2]) / 255.0
            total += 0.2126 * r + 0.7152 * g + 0.0722 * b
        }

        let luminance = CGFloat(total / Double(sampleWidth * sampleHeight))
        UnboundBackdropTextSamplingCache.cache.setObject(NSNumber(value: Double(luminance)), forKey: key)
        return luminance
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

private extension UIColor {
    var unboundRelativeLuminance: CGFloat {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return 1
        }

        return UIImage.unboundRelativeLuminance(red: red, green: green, blue: blue)
    }

    func unboundMixed(with other: UIColor, amount: CGFloat) -> UIColor {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        var otherRed: CGFloat = 0
        var otherGreen: CGFloat = 0
        var otherBlue: CGFloat = 0
        var otherAlpha: CGFloat = 0

        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha),
              other.getRed(&otherRed, green: &otherGreen, blue: &otherBlue, alpha: &otherAlpha) else {
            return self
        }

        let clampedAmount = min(1, max(0, amount))
        return UIColor(
            red: red * (1 - clampedAmount) + otherRed * clampedAmount,
            green: green * (1 - clampedAmount) + otherGreen * clampedAmount,
            blue: blue * (1 - clampedAmount) + otherBlue * clampedAmount,
            alpha: alpha * (1 - clampedAmount) + otherAlpha * clampedAmount
        )
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

