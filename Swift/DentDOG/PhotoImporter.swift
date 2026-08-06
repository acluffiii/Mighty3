import SwiftUI
import PhotosUI

/// Imports a photo from the user's library — distinct from CameraViewfinder,
/// which captures live. Uses PHPickerViewController (iOS 14+), Apple's
/// modern picker: unlike the old UIImagePickerController photo-library path,
/// this doesn't require Photo Library permission at all — the picker runs
/// out-of-process and only hands back the one photo the user picked.
struct PhotoImporter: UIViewControllerRepresentable {
    var onImport: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoImporter
        init(_ parent: PhotoImporter) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else {
                parent.dismiss()
                return
            }
            provider.loadObject(ofClass: UIImage.self) { image, _ in
                DispatchQueue.main.async {
                    if let image = image as? UIImage { parent.onImport(image) }
                    parent.dismiss()
                }
            }
        }
    }
}
