import UIKit

extension UIImage {
    func compressed(maxWidth: CGFloat = AppConstants.Limits.maxPhotoWidthPx,
                    quality: CGFloat = AppConstants.Limits.jpegCompressionQuality) -> Data? {
        let ratio = maxWidth / size.width
        let newSize: CGSize
        if ratio < 1 {
            newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        } else {
            newSize = size
        }
        UIGraphicsBeginImageContextWithOptions(newSize, true, 1.0)
        draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resized?.jpegData(compressionQuality: quality)
    }
}
