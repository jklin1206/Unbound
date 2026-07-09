import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Unbound Backdrop Luminance Sampling
//
// Pixel-level luminance analysis behind the adaptive backdrop text system:
// cached region sampling, contrast scoring, and candidate selection.
// Split from UnboundBackdrops.swift.

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

extension UIImage {
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

    fileprivate func unboundBackdropLuminanceSample(
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

    fileprivate func unboundImageRect(
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

    static fileprivate func unboundRelativeLuminance(red: CGFloat, green: CGFloat, blue: CGFloat) -> CGFloat {
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

extension UIColor {
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

    fileprivate func unboundMixed(with other: UIColor, amount: CGFloat) -> UIColor {
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
