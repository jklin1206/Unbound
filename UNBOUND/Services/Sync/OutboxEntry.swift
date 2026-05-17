// UNBOUND/Services/Sync/OutboxEntry.swift
import Foundation

/// One pending change to a single document. The unit drained by SyncEngine.
struct OutboxEntry: Codable, Equatable, Identifiable, Sendable {
    enum Op: String, Codable, Sendable { case upsert, delete }

    let id: UUID
    let userId: String
    let collection: String
    let docId: String
    let op: Op
    /// Encoded document JSON for `.upsert`; nil for `.delete`.
    let payloadJSON: Data?
    let enqueuedAt: Date
    var attempt: Int
}
