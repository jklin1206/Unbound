// UNBOUND/Models/ProgressPhoto.swift
import Foundation

struct ProgressPhoto: Codable, Identifiable, Equatable {
    enum Source: String, Codable {
        case manual
        case scan
    }

    let id: String
    let userId: String
    let storageUrl: String
    let capturedAt: Date
    var note: String?
    var angle: ScanAngle?
    var blockNumber: Int?
    var source: Source

    init(
        id: String,
        userId: String,
        storageUrl: String,
        capturedAt: Date,
        note: String? = nil,
        angle: ScanAngle? = nil,
        blockNumber: Int? = nil,
        source: Source
    ) {
        self.id = id
        self.userId = userId
        self.storageUrl = storageUrl
        self.capturedAt = capturedAt
        self.note = note
        self.angle = angle
        self.blockNumber = blockNumber
        self.source = source
    }
}
