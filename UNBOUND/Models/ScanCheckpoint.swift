// UNBOUND/Models/ScanCheckpoint.swift
import Foundation

/// Monthly scan record. Replaces BodyAnalysis (deleted in Phase 9).
/// Photos are visual proof; the BuildIdentity snapshot is read FROM the
/// attribute system, never derived from the photo.
struct ScanCheckpoint: Codable, Equatable, Identifiable {
    let id: String
    let userId: String
    let createdAt: Date
    /// Filename of the JPEG on disk. Resolved by ScanCheckpointStore /
    /// ImageCaptureService. Never raw photo data inside the model.
    let photoFilename: String
    let buildIdentitySnapshot: BuildIdentity
    let narrative: String
    let deltaFromPrior: BuildIdentityDelta?

    var isFirstScan: Bool { deltaFromPrior == nil }
}

// MARK: - BuildIdentity Codable conformance
//
// BuildIdentity isn't Codable in its declaration (only its nested Shape is).
// We add the conformance here next to the persistence touchpoint that needs it.

extension BuildIdentity: Codable {
    enum CodingKeys: String, CodingKey { case primary, secondary, shape }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let primary = try c.decodeIfPresent(AttributeKey.self, forKey: .primary)
        let secondary = try c.decodeIfPresent(AttributeKey.self, forKey: .secondary)
        let shape = try c.decode(Shape.self, forKey: .shape)
        self.init(primary: primary, secondary: secondary, shape: shape)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(primary, forKey: .primary)
        try c.encodeIfPresent(secondary, forKey: .secondary)
        try c.encode(shape, forKey: .shape)
    }
}
