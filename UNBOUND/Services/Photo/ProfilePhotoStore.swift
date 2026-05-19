import UIKit
import SwiftUI

/// Local-only profile picture store. One downscaled JPEG per userId at
/// `<dir>/<userId>.jpg`. `revision` lets SwiftUI views refresh live.
/// No cloud sync in v1 (device-local; follow-up later).
@MainActor
final class ProfilePhotoStore: ObservableObject {
    static let shared = ProfilePhotoStore()

    @Published private(set) var revision: Int = 0

    private let dir: URL
    private var cache: [String: UIImage] = [:]
    private let maxSide: CGFloat = 512

    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ProfilePhoto", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: base, withIntermediateDirectories: true)
        self.dir = base
    }

    private func fileURL(_ userId: String) -> URL {
        dir.appendingPointSafe(userId)
    }

    func image(userId: String) -> UIImage? {
        guard !userId.isEmpty else { return nil }
        if let cached = cache[userId] { return cached }
        guard let data = try? Data(contentsOf: fileURL(userId)),
              let img = UIImage(data: data) else { return nil }
        cache[userId] = img
        return img
    }

    func set(_ image: UIImage, userId: String) {
        guard !userId.isEmpty else { return }
        let scaled = downscale(image, maxSide: maxSide)
        guard let data = scaled.jpegData(compressionQuality: 0.85) else {
            LoggingService.shared.log("ProfilePhoto encode failed",
                                      level: .error, context: [:])
            return
        }
        do {
            try data.write(to: fileURL(userId), options: .atomic)
            cache[userId] = scaled
            revision &+= 1
        } catch {
            LoggingService.shared.log("ProfilePhoto write failed: \(error)",
                                      level: .error, context: [:])
        }
    }

    func remove(userId: String) {
        guard !userId.isEmpty else { return }
        try? FileManager.default.removeItem(at: fileURL(userId))
        cache[userId] = nil
        revision &+= 1
    }

    private func downscale(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let w = image.size.width, h = image.size.height
        let longest = max(w, h)
        guard longest > maxSide, longest > 0 else { return image }
        let scale = maxSide / longest
        let target = CGSize(width: w * scale, height: h * scale)
        let r = UIGraphicsImageRenderer(size: target)
        return r.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

private extension URL {
    /// Safe filename for an arbitrary userId (UUIDs/emails) → `<sanitized>.jpg`.
    func appendingPointSafe(_ userId: String) -> URL {
        let safe = userId.replacingOccurrences(
            of: "[^A-Za-z0-9_-]", with: "_", options: .regularExpression)
        return appendingPathComponent("\(safe).jpg")
    }
}
