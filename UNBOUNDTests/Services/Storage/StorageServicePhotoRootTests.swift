import XCTest
@testable import UNBOUND

// Proof A (on-disk side): account deletion must remove the ENTIRE photo root
// for the live UID *and* any legacy/old-UUID directory, leaving nothing behind.
// Exercises the additive `StorageService.deletePhotoRoots` teardown helper.
final class StorageServicePhotoRootTests: XCTestCase {
    private let fm = FileManager.default

    private func tempRoot() -> URL {
        let url = fm.temporaryDirectory
            .appendingPathComponent("storage-root-tests-\(UUID().uuidString)", isDirectory: true)
        try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Write a dummy photo at root/<userId>/<scanId>/<angle>.jpg.
    private func seedPhoto(root: URL, userId: String, scanId: String, angle: String) {
        let dir = root
            .appendingPathComponent(userId, isDirectory: true)
            .appendingPathComponent(scanId, isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("\(angle).jpg")
        try? Data([0x1, 0x2, 0x3]).write(to: file)
    }

    func test_deletePhotoRoots_wipes_live_and_legacy_uuid_directories() {
        let root = tempRoot()
        let liveUID = "00000000-live"
        let legacyUID = "11111111-legacy"
        let strangerUID = "22222222-stranger"

        seedPhoto(root: root, userId: liveUID, scanId: "scan1", angle: "front")
        seedPhoto(root: root, userId: liveUID, scanId: "scan2", angle: "back")
        seedPhoto(root: root, userId: legacyUID, scanId: "scan0", angle: "front")
        seedPhoto(root: root, userId: strangerUID, scanId: "scanX", angle: "front")

        StorageService.deletePhotoRoots([liveUID, legacyUID], under: root, fileManager: fm)

        // Zero files remain under the live and legacy roots.
        XCTAssertFalse(fm.fileExists(atPath: root.appendingPathComponent(liveUID).path),
                       "live UID photo root should be gone")
        XCTAssertFalse(fm.fileExists(atPath: root.appendingPathComponent(legacyUID).path),
                       "legacy/old UUID photo root should be gone")
        // A different user's photos are untouched.
        XCTAssertTrue(fm.fileExists(atPath: root.appendingPathComponent(strangerUID).path),
                      "unrelated user's photos must not be deleted")
    }

    func test_deletePhotoRoots_is_noop_for_missing_directory() {
        let root = tempRoot()
        // Nothing seeded — must not throw or create anything.
        StorageService.deletePhotoRoots(["never-existed"], under: root, fileManager: fm)
        let contents = (try? fm.contentsOfDirectory(atPath: root.path)) ?? []
        XCTAssertEqual(contents.count, 0)
    }

    func test_deletePhotoRoots_dedupes_when_live_equals_legacy() {
        let root = tempRoot()
        let uid = "same-uid"
        seedPhoto(root: root, userId: uid, scanId: "scan1", angle: "front")

        // Passing the same id twice (live == legacy) must still cleanly delete.
        StorageService.deletePhotoRoots([uid, uid], under: root, fileManager: fm)
        XCTAssertFalse(fm.fileExists(atPath: root.appendingPathComponent(uid).path))
    }
}
