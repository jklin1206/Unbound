# Profile Photo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user take or pick a profile photo that shows in the avatar circle on Profile + Home; with no photo, show a generic purple placeholder instead of a letter.

**Architecture:** One new local-only `ProfilePhotoStore` (downscaled JPEG keyed by userId, `ObservableObject`). `CosmeticAvatar`'s empty state becomes a purple placeholder. `ProfileView` gains a tap-to-edit affordance (confirmation dialog → `PhotosPicker` or a small camera representable). Both `CosmeticAvatar` call sites read the store and observe it for live refresh.

**Tech Stack:** Swift 5.9, SwiftUI (iOS 17), PhotosUI `PhotosPicker`, `UIImagePickerController` (camera), XCTest, XcodeGen (`project.yml` is source of truth; `.pbxproj` is generated + gitignored — run `xcodegen generate` after adding/removing files).

**Project facts the engineer must know:**
- `xcodegen` is at `/opt/homebrew/bin/xcodegen`. After creating/deleting any `.swift` file you MUST run `xcodegen generate` before building or the file won't be in the project.
- Build/test: `xcodebuild build-for-testing -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/dd-pp`. A plain `xcodebuild build` against existing DerivedData has false-greened in this repo — always use a fresh `-derivedDataPath` for the trust check.
- Run a test suite: `xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/ProfilePhotoStoreTests`.
- `userId` source everywhere: `AuthService.shared.currentUserId ?? ""`.
- Commit footer (every commit):
  `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`
- Do NOT hand-edit `UNBOUND.xcodeproj/project.pbxproj` (generated + gitignored).

---

### Task 1: ProfilePhotoStore (local store + downscale)

**Files:**
- Create: `UNBOUND/Services/Photo/ProfilePhotoStore.swift`
- Test: `UNBOUNDTests/Services/Photo/ProfilePhotoStoreTests.swift`

- [ ] **Step 1: Write the failing test**

Create `UNBOUNDTests/Services/Photo/ProfilePhotoStoreTests.swift`:

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodegen generate && xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/ProfilePhotoStoreTests 2>&1 | tail -20`
Expected: FAIL — `cannot find 'ProfilePhotoStore' in scope`.

- [ ] **Step 3: Write minimal implementation**

Create `UNBOUND/Services/Photo/ProfilePhotoStore.swift`:

```swift
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/ProfilePhotoStoreTests 2>&1 | tail -20`
Expected: PASS — `Test Suite 'ProfilePhotoStoreTests' passed`, 5 tests.

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Services/Photo/ProfilePhotoStore.swift UNBOUNDTests/Services/Photo/ProfilePhotoStoreTests.swift
git commit -m "$(cat <<'EOF'
feat(profile): ProfilePhotoStore — local downscaled profile-pic store

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: CosmeticAvatar purple placeholder

**Files:**
- Modify: `UNBOUND/Models/RankCosmetics.swift:96-100` (the `else` branch of `innerCore`)

- [ ] **Step 1: Replace the letter fallback with a purple placeholder**

In `UNBOUND/Models/RankCosmetics.swift`, the `innerCore` `else` branch currently is:

```swift
            } else {
                Text(letterFallback.uppercased().prefix(1))
                    .font(.system(size: size * 0.34, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.unbound.textPrimary)
            }
```

Replace it with:

```swift
            } else {
                Circle()
                    .fill(Color.unbound.accent)
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.34, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.55))
            }
```

Leave the `letterFallback` property and all call-site arguments untouched (source-compatible; the parameter is simply no longer rendered).

- [ ] **Step 2: Verify it compiles**

Run: `xcodegen generate && xcodebuild build-for-testing -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/dd-pp 2>&1 | tail -5`
Expected: `** TEST BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add UNBOUND/Models/RankCosmetics.swift
git commit -m "$(cat <<'EOF'
feat(profile): CosmeticAvatar empty state is a purple placeholder

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Camera picker representable + photo-library Info.plist string

**Files:**
- Create: `UNBOUND/Views/Profile/CameraPicker.swift`
- Modify: `project.yml:14` (add the photo-library usage key right after the camera one)

- [ ] **Step 1: Create the camera representable**

Create `UNBOUND/Views/Profile/CameraPicker.swift`:

```swift
import SwiftUI
import UIKit

/// Minimal camera capture sheet. Returns the captured `UIImage` via
/// `onPicked`; dismisses on cancel. Only present this when
/// `UIImagePickerController.isSourceTypeAvailable(.camera)` is true.
struct CameraPicker: UIViewControllerRepresentable {
    var onPicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let c = UIImagePickerController()
        c.sourceType = .camera
        c.allowsEditing = true
        c.delegate = context.coordinator
        return c
    }

    func updateUIViewController(_ c: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject,
        UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo
            info: [UIImagePickerController.InfoKey: Any]
        ) {
            let img = (info[.editedImage] as? UIImage)
                ?? (info[.originalImage] as? UIImage)
            if let img { parent.onPicked(img) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ p: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
```

- [ ] **Step 2: Add the photo-library usage string to project.yml**

In `project.yml`, the line is:

```yaml
    INFOPLIST_KEY_NSCameraUsageDescription: "UNBOUND needs camera access to take your body scan photos"
```

Add a new line immediately after it:

```yaml
    INFOPLIST_KEY_NSPhotoLibraryUsageDescription: "UNBOUND needs photo library access to set your profile picture"
```

- [ ] **Step 3: Verify it compiles**

Run: `xcodegen generate && xcodebuild build-for-testing -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/dd-pp 2>&1 | tail -5`
Expected: `** TEST BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add UNBOUND/Views/Profile/CameraPicker.swift project.yml
git commit -m "$(cat <<'EOF'
feat(profile): CameraPicker representable + photo-library usage string

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Wire ProfileView — tap avatar to set/remove photo

**Files:**
- Modify: `UNBOUND/Views/Profile/ProfileView.swift` (imports, state, header avatar block at lines ~210-216, plus modifiers)

- [ ] **Step 1: Add the PhotosUI import**

At the top of `UNBOUND/Views/Profile/ProfileView.swift`, ensure these imports exist (add any missing):

```swift
import SwiftUI
import PhotosUI
```

- [ ] **Step 2: Add state for the store and pickers**

In `struct ProfileView`, directly below the existing
`@State private var showCadenceConfirmation = false` line, add:

```swift
    @ObservedObject private var photoStore = ProfilePhotoStore.shared
    @State private var showPhotoOptions = false
    @State private var showCamera = false
    @State private var pickedItem: PhotosPickerItem?
    private var photoUserId: String { AuthService.shared.currentUserId ?? "" }
```

- [ ] **Step 3: Make the avatar tappable and feed the stored image**

Replace the existing avatar call (lines ~211-216):

```swift
                CosmeticAvatar(
                    tier: aggregateRank.title,
                    size: 104,
                    image: nil, // future: user-uploaded profile photo
                    letterFallback: initial
                )
```

with:

```swift
                Button {
                    showPhotoOptions = true
                } label: {
                    CosmeticAvatar(
                        tier: aggregateRank.title,
                        size: 104,
                        image: photoStore.image(userId: photoUserId),
                        letterFallback: initial
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Profile picture. Tap to change.")
```

(`photoStore.image(...)` re-reads whenever `photoStore.revision` changes because `ProfileView` observes `photoStore`.)

- [ ] **Step 4: Add the dialog, PhotosPicker, and camera sheet modifiers**

Find the header card's `.task { await load() }` modifier (around line 87, attached to the outer `ZStack`). Immediately after the existing `.confirmationDialog("Your body adapts...")` block on that ZStack, add these modifiers:

```swift
        .confirmationDialog("Profile picture",
                            isPresented: $showPhotoOptions,
                            titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") { showCamera = true }
            }
            PhotosPicker("Choose from Library",
                         selection: $pickedItem, matching: .images)
            if photoStore.image(userId: photoUserId) != nil {
                Button("Remove Photo", role: .destructive) {
                    photoStore.remove(userId: photoUserId)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                photoStore.set(image, userId: photoUserId)
            }
            .ignoresSafeArea()
        }
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    photoStore.set(img, userId: photoUserId)
                }
                pickedItem = nil
            }
        }
```

- [ ] **Step 5: Verify it compiles**

Run: `xcodegen generate && xcodebuild build-for-testing -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/dd-pp 2>&1 | tail -5`
Expected: `** TEST BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add UNBOUND/Views/Profile/ProfileView.swift
git commit -m "$(cat <<'EOF'
feat(profile): tap avatar to take/pick/remove a profile photo

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Wire Home avatar to the same store

**Files:**
- Modify: `UNBOUND/Views/Home/UnboundHomeView.swift` (the `avatarBadge(level:)` func ~1365-1376 and one state addition)

- [ ] **Step 1: Observe the store in the Home view**

In `UNBOUND/Views/Home/UnboundHomeView.swift`, find the `struct` that declares `avatarBadge(level:)`. Add this property alongside its other `@State`/`@ObservedObject` properties (top of that struct):

```swift
    @ObservedObject private var photoStore = ProfilePhotoStore.shared
```

- [ ] **Step 2: Feed the stored image into the Home avatar**

In `avatarBadge(level:)`, replace:

```swift
                CosmeticAvatar(
                    tier: aggregateRank.title,
                    size: 44,
                    image: nil,
                    letterFallback: letter
                )
```

with:

```swift
                CosmeticAvatar(
                    tier: aggregateRank.title,
                    size: 44,
                    image: photoStore.image(userId: AuthService.shared.currentUserId ?? ""),
                    letterFallback: letter
                )
```

- [ ] **Step 3: Verify it compiles**

Run: `xcodegen generate && xcodebuild build-for-testing -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/dd-pp 2>&1 | tail -5`
Expected: `** TEST BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add UNBOUND/Views/Home/UnboundHomeView.swift
git commit -m "$(cat <<'EOF'
feat(home): Home avatar reflects the user's profile photo

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Full verification

**Files:** none (verification only)

- [ ] **Step 1: Clean test-build (fresh DerivedData — trust check)**

Run: `xcodegen generate && xcodebuild build-for-testing -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/dd-pp-final 2>&1 | tail -5`
Expected: `** TEST BUILD SUCCEEDED **`.

- [ ] **Step 2: Run the new test suite**

Run: `xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/ProfilePhotoStoreTests 2>&1 | tail -15`
Expected: `Test Suite 'ProfilePhotoStoreTests' passed` — 5 tests, 0 failures.

- [ ] **Step 3: Confirm no remaining hardcoded nil at the two call sites**

Run: `grep -n "CosmeticAvatar(" -A4 UNBOUND/Views/Profile/ProfileView.swift UNBOUND/Views/Home/UnboundHomeView.swift | grep "image:"`
Expected: both show `image: photoStore.image(...)`, neither shows `image: nil`.

---

## Self-Review

**1. Spec coverage:**
- Purple placeholder, no letter → Task 2. ✓
- Tap avatar → dialog (Take Photo / Choose from Library / Remove) → Task 4. ✓
- Camera + library → Task 3 (`CameraPicker`) + Task 4 (`PhotosPicker`). ✓
- Downscale ≤512 JPEG, keyed by userId → Task 1. ✓
- Profile + Home live update → Task 4 + Task 5 (`@ObservedObject` on `revision`). ✓
- Info.plist camera (already present) + photo-library string → Task 3. ✓
- Local-only / no cloud sync → Task 1 (no outbox). ✓
- Tests for store + downscale + isolation → Task 1. ✓
- Success criteria 1–6 → covered by Tasks 2,4,5,6. ✓

**2. Placeholder scan:** No "TBD/TODO/handle edge cases" — every code step is complete Swift. ✓

**3. Type consistency:** `ProfilePhotoStore` API (`image(userId:)`, `set(_:userId:)`, `remove(userId:)`, `revision`, `init(directory:)`) is identical across Tasks 1, 4, 5, and the tests. `CameraPicker(onPicked:)` defined in Task 3, used in Task 4. `pickedItem: PhotosPickerItem?` consistent in Task 4. ✓

No gaps found.
