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
