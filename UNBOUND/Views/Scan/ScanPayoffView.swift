// UNBOUND/Views/Scan/ScanPayoffView.swift
import SwiftUI
import UIKit

struct ScanPayoffView: View {
    let checkpoint: ScanCheckpoint
    let onDone: () -> Void
    let onShare: () -> Void

    @EnvironmentObject var services: ServiceContainer
    @State private var photoImage: UIImage?
    @State private var priorCheckpoint: ScanCheckpoint?
    @State private var priorImage: UIImage?
    @State private var currentProfile: AttributeProfile?
    @State private var priorProfile: AttributeProfile?

    var body: some View {
        Group {
            if let priorCheckpoint, let currentProfile, let priorProfile {
                NthScanEvolutionCard(
                    priorCheckpoint: priorCheckpoint,
                    currentCheckpoint: checkpoint,
                    priorImage: priorImage,
                    currentImage: photoImage,
                    priorAttributeProfile: priorProfile,
                    currentAttributeProfile: currentProfile,
                    onPrimary: onDone,
                    onShare: onShare
                )
            } else if let currentProfile {
                FirstScanArcCard(
                    checkpoint: checkpoint,
                    photoImage: photoImage,
                    buildAxisValues: currentProfile.hexValues,
                    onPrimary: onDone,
                    onShare: onShare
                )
            } else {
                Color.unbound.bg.ignoresSafeArea()
            }
        }
        .task { await loadAuxiliary() }
    }

    private func loadAuxiliary() async {
        photoImage = ScanPhotoLoader.load(filename: checkpoint.photoFilename)
        let userId = services.auth.currentUserId ?? checkpoint.userId
        currentProfile = services.attribute.snapshot(userId: userId, asOf: .now)
        if let prior = (try? ScanCheckpointStore.shared.history(userId: userId))?.dropLast().last {
            priorCheckpoint = prior
            priorImage = ScanPhotoLoader.load(filename: prior.photoFilename)
            let history = services.attribute.scanHistory(userId: userId)
            if history.count >= 2 {
                priorProfile = history[history.count - 2]
            }
        }
    }
}

/// Loads a scan photo from disk by filename. Lives at module scope so
/// FirstScan / NthScan / share-sheet code paths can share it.
enum ScanPhotoLoader {
    static func load(filename: String) -> UIImage? {
        guard !filename.isEmpty else { return nil }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let url = docs.appendingPathComponent("scan-photos").appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
}

/// Convenience for converting AttributeProfile → [AttributeKey: Double]
/// used by AttributeHex / BuildHexHUD.
extension AttributeProfile {
    var hexValues: [AttributeKey: Double] {
        var dict: [AttributeKey: Double] = [:]
        for key in AttributeKey.allCases {
            dict[key] = value(for: key).hexFill * 100
        }
        return dict
    }
}
