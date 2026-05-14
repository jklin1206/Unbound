// UNBOUND/Services/Scan/ScanCheckpointService.swift
import Foundation

/// Minimal protocol for writing photo bytes to disk. Real impl wires
/// through the existing image-capture/storage pipeline; tests inject a stub.
protocol ScanPhotoWriting {
    func write(_ data: Data, filename: String) throws
}

/// Orchestrates the new scan flow: reads BuildIdentity from the attribute
/// system (never from the photo), persists photo + checkpoint, calls Claude
/// Haiku for narrative copy. Never grades the body.
@MainActor
final class ScanCheckpointService {

    static let shared = ScanCheckpointService(
        store: .shared,
        attribute: AttributeService.shared,
        photoWriter: DefaultScanPhotoWriter(),
        narrative: { identity in
            await ScanNarrativeService.firstScanNarrative(for: identity)
        },
        evolutionNarrative: { prior, current, delta in
            await ScanNarrativeService.evolutionNarrative(prior: prior, current: current, delta: delta)
        }
    )

    private let store: ScanCheckpointStore
    private let attribute: AttributeServiceProtocol
    private let photoWriter: ScanPhotoWriting
    private let firstNarrative: (BuildIdentity) async -> String
    private let evolutionNarrative: (BuildIdentity, BuildIdentity, BuildIdentityDelta) async -> String

    init(
        store: ScanCheckpointStore,
        attribute: AttributeServiceProtocol,
        photoWriter: ScanPhotoWriting,
        narrative: @escaping (BuildIdentity) async -> String,
        evolutionNarrative: @escaping (BuildIdentity, BuildIdentity, BuildIdentityDelta) async -> String
    ) {
        self.store = store
        self.attribute = attribute
        self.photoWriter = photoWriter
        self.firstNarrative = narrative
        self.evolutionNarrative = evolutionNarrative
    }

    @discardableResult
    func commit(userId: String, photoData: Data, now: Date = .now) async throws -> ScanCheckpoint {
        let currentProfile = attribute.snapshot(userId: userId, asOf: now)
        let identity = currentProfile.buildIdentity

        let prior = try? store.mostRecent(userId: userId)

        let scanId = UUID().uuidString
        let filename = "\(scanId)-front.jpg"
        try photoWriter.write(photoData, filename: filename)

        // Pin BEFORE computing delta — pinning appends current profile to
        // attribute history, so the prior pinned profile is at history[count-2].
        await attribute.snapshotForScan(scanId: scanId, userId: userId)

        let delta: BuildIdentityDelta?
        let narrative: String
        if let prior {
            let history = attribute.scanHistory(userId: userId)
            if history.count >= 2 {
                let priorPinned = history[history.count - 2]
                var perAxis: [AttributeKey: Int] = [:]
                for key in AttributeKey.allCases {
                    let before = Int(priorPinned.value(for: key).current)
                    let after = Int(currentProfile.value(for: key).current)
                    perAxis[key] = after - before
                }
                delta = BuildIdentityDelta(perAxis: perAxis)
            } else {
                delta = BuildIdentityDelta(perAxis: [:])
            }
            narrative = await evolutionNarrative(prior.buildIdentitySnapshot, identity, delta!)
        } else {
            delta = nil
            narrative = await firstNarrative(identity)
        }

        let checkpoint = ScanCheckpoint(
            id: scanId,
            userId: userId,
            createdAt: now,
            photoFilename: filename,
            buildIdentitySnapshot: identity,
            narrative: narrative,
            deltaFromPrior: delta
        )
        try store.save(checkpoint)
        return checkpoint
    }
}

/// Default writer — JPEGs land in Documents/scan-photos.
final class DefaultScanPhotoWriter: ScanPhotoWriting {
    func write(_ data: Data, filename: String) throws {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("scan-photos", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try data.write(to: dir.appendingPathComponent(filename))
    }
}
