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
    /// Top-level document field keys this entry intends to change. Client-only
    /// metadata used to merge field-level edits on flush — NEVER sent as a
    /// document column. Persisted; decode is back-compatible (legacy entries
    /// written before this field default to `[]`).
    var changedFields: [String]
    let enqueuedAt: Date
    var attempt: Int

    init(id: UUID, userId: String, collection: String, docId: String, op: Op,
         payloadJSON: Data?, changedFields: [String] = [], enqueuedAt: Date, attempt: Int) {
        self.id = id
        self.userId = userId
        self.collection = collection
        self.docId = docId
        self.op = op
        self.payloadJSON = payloadJSON
        self.changedFields = changedFields
        self.enqueuedAt = enqueuedAt
        self.attempt = attempt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        userId = try c.decode(String.self, forKey: .userId)
        collection = try c.decode(String.self, forKey: .collection)
        docId = try c.decode(String.self, forKey: .docId)
        op = try c.decode(Op.self, forKey: .op)
        payloadJSON = try c.decodeIfPresent(Data.self, forKey: .payloadJSON)
        // Back-compat: absent in entries persisted before field-level merge.
        changedFields = try c.decodeIfPresent([String].self, forKey: .changedFields) ?? []
        enqueuedAt = try c.decode(Date.self, forKey: .enqueuedAt)
        attempt = try c.decode(Int.self, forKey: .attempt)
    }
}
