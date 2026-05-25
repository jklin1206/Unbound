import Foundation

enum CheckpointOutcome: Codable, Equatable, Sendable {
    case completed(CheckpointSignals)
    case skipped

    var signals: CheckpointSignals? {
        switch self {
        case .completed(let signals): return signals
        case .skipped: return nil
        }
    }

    var wasSkipped: Bool {
        if case .skipped = self { return true }
        return false
    }

    enum CodingKeys: String, CodingKey {
        case kind
        case signals
    }

    enum Kind: String, Codable {
        case completed
        case skipped
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .completed:
            self = .completed(try container.decode(CheckpointSignals.self, forKey: .signals))
        case .skipped:
            self = .skipped
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .completed(let signals):
            try container.encode(Kind.completed, forKey: .kind)
            try container.encode(signals, forKey: .signals)
        case .skipped:
            try container.encode(Kind.skipped, forKey: .kind)
        }
    }
}
