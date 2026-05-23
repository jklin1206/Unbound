import XCTest
import UIKit
@testable import UNBOUND

@MainActor
final class ProfilePhotoStoreTests: XCTestCase {
    private func tempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pp-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func solidImage(_ side: CGFloat) -> UIImage {
        let r = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return r.image { ctx in
            UIColor.purple.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))
        }
    }

    func test_set_then_image_roundtrips() {
        let dir = tempDir()
        let store = ProfilePhotoStore(directory: dir)
        XCTAssertNil(store.image(userId: "u1"))
        store.set(solidImage(300), userId: "u1")
        XCTAssertNotNil(store.image(userId: "u1"))
    }

    func test_downscale_caps_long_side_at_512() {
        let dir = tempDir()
        let store = ProfilePhotoStore(directory: dir)
        store.set(solidImage(1024), userId: "u1")
        let img = store.image(userId: "u1")
        XCTAssertNotNil(img)
        XCTAssertLessThanOrEqual(max(img!.size.width, img!.size.height), 512)
    }

    func test_remove_clears_photo() {
        let dir = tempDir()
        let store = ProfilePhotoStore(directory: dir)
        store.set(solidImage(200), userId: "u1")
        store.remove(userId: "u1")
        XCTAssertNil(store.image(userId: "u1"))
    }

    func test_per_user_isolation_and_revision_bumps() {
        let dir = tempDir()
        let store = ProfilePhotoStore(directory: dir)
        let r0 = store.revision
        store.set(solidImage(200), userId: "u1")
        XCTAssertGreaterThan(store.revision, r0)
        XCTAssertNil(store.image(userId: "u2"))
    }

    func test_survives_reinit_same_directory() {
        let dir = tempDir()
        ProfilePhotoStore(directory: dir).set(solidImage(200), userId: "u1")
        let store2 = ProfilePhotoStore(directory: dir)
        XCTAssertNotNil(store2.image(userId: "u1"))
    }
}
