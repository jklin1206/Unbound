import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Unbound Backdrop System
//
// Backdrop art presentation + the adaptive text-legibility machinery
// (scrims, shields, tone analysis, shadows).
// Split from View+UnboundStyle.swift (was 1,369 lines).
//
// This file keeps the core presentation types (`BackdropPresentationRole`,
// `UnboundBackdropArt`) and the `View` entry points. Companions:
// - UnboundBackdrops+Scrims.swift — scrims, text shields, ink tone, shadows.
// - UnboundBackdrops+AdaptiveText.swift — adaptive foreground candidates + modifiers.
// - UnboundBackdrops+LuminanceSampling.swift — pixel luminance sampling/scoring.

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
                // Authored landscape header banners render FIT, top-anchored:
                // the full 16:9 art is always visible edge-to-edge at every
                // device width (no fill-crop — the old 1.30 overscan was tuned
                // for the retired photoreal set and chopped the anime art).
                // The header frame is at least as tall as the art band; any
                // sliver below the art dissolves into the page background via
                // the header's bottom scrim, so the avatar + identity still
                // read on the art's quiet dead space.
                Image(uiImage: ui)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: containerSize.width, alignment: .top)
                    .frame(
                        width: containerSize.width,
                        height: containerSize.height,
                        alignment: .top
                    )
                    .clipped()
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
                // The ramp must complete to FULL page bg at the hero's end —
                // stopping short leaves a lighter ghost band between the hero
                // and the section below it.
                LinearGradient(
                    stops: [
                        .init(color: Color.unbound.bg.opacity(0.01), location: 0),
                        .init(color: Color.unbound.bg.opacity(0.05), location: 0.46),
                        .init(color: Color.unbound.bg.opacity(0.56), location: 0.86),
                        .init(color: Color.unbound.bg.opacity(0.92), location: 0.97),
                        .init(color: Color.unbound.bg, location: 1)
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
                        .init(color: Color.black.opacity(0.28), location: 0),
                        .init(color: Color.black.opacity(0.12), location: 0.44),
                        .init(color: Color.black.opacity(0.02), location: 0.78)
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
