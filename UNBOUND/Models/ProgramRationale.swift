import Foundation

struct ProgramRationale: Codable, Sendable, Hashable {
    struct Decision: Codable, Sendable, Hashable, Identifiable {
        var id: UUID = UUID()
        let inputSummary: String
        let decisionApplied: String
        let iconSystemName: String

        private enum CodingKeys: String, CodingKey {
            case inputSummary, decisionApplied, iconSystemName
        }

        init(inputSummary: String, decisionApplied: String, iconSystemName: String) {
            self.inputSummary = inputSummary
            self.decisionApplied = decisionApplied
            self.iconSystemName = iconSystemName
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.id = UUID()
            self.inputSummary = try c.decode(String.self, forKey: .inputSummary)
            self.decisionApplied = try c.decode(String.self, forKey: .decisionApplied)
            self.iconSystemName = try c.decode(String.self, forKey: .iconSystemName)
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(inputSummary, forKey: .inputSummary)
            try c.encode(decisionApplied, forKey: .decisionApplied)
            try c.encode(iconSystemName, forKey: .iconSystemName)
        }
    }

    let headline: String
    let summaryCopy: String
    let decisions: [Decision]
}
