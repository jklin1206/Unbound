import SwiftUI

// MARK: - BodyScanViewModel (DELETED — old grading pipeline)
//
// The old Gemini-based scan flow was removed in the scan-redesign-v2 branch.
// This file is a tombstone kept only while the Body/BodyScan view folders
// are also pending deletion in Phase 9. Once Phase 9 deletes those folders,
// this file will be removed too.
//
// Do not add new functionality here.

@MainActor
final class BodyScanViewModel: ObservableObject {
    @Published var currentAngle: ScanAngle = .front
    @Published var capturedPhotos: [ScanAngle: UIImage] = [:]

    enum AnalysisProgress: String {
        case idle = ""
    }

    let services: ServiceContainer

    init(services: ServiceContainer) {
        self.services = services
    }

    var allPhotosCaptured: Bool {
        ScanAngle.allCases.allSatisfy { capturedPhotos[$0] != nil }
    }

    func capturePhoto(_ image: UIImage, for angle: ScanAngle) {
        capturedPhotos[angle] = image
        if let nextAngle = ScanAngle.allCases.first(where: { $0.order == angle.order + 1 }) {
            currentAngle = nextAngle
        }
    }

    func retakePhoto(for angle: ScanAngle) {
        capturedPhotos[angle] = nil
        currentAngle = angle
    }

    func startAnalysis() async { }
    func generateProgram() async { }
}
