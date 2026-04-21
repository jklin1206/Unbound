import UIKit

enum ImageCompressor {
    static func compress(image: UIImage,
                         maxWidth: CGFloat = AppConstants.Limits.maxPhotoWidthPx,
                         quality: CGFloat = AppConstants.Limits.jpegCompressionQuality,
                         maxBytes: Int = AppConstants.Limits.maxPhotoSizeBytes) -> Data? {
        guard var data = image.compressed(maxWidth: maxWidth, quality: quality) else { return nil }
        var currentQuality = quality
        while data.count > maxBytes && currentQuality > 0.1 {
            currentQuality -= 0.1
            data = image.compressed(maxWidth: maxWidth, quality: currentQuality) ?? data
        }
        return data
    }
}
