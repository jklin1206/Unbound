import Foundation

struct ProgramRationale: Codable, Sendable, Hashable {
    enum ReasonCategory: String, Codable, CaseIterable, Sendable, Hashable {
        case loadLowered
        case loadRaised
        case repsChanged
        case setCountChanged
        case exerciseSwapped
        case accessoryRemoved
        case vowReplacingAccessory
        case skillBlockInserted
        case deloadApplied
        case missedPressureReduced
        case checkpointRecommendation
    }

    struct Decision: Codable, Sendable, Hashable, Identifiable {
        var id: UUID = UUID()
        let inputSummary: String
        let decisionApplied: String
        let iconSystemName: String
        var reasonCategory: ReasonCategory?
        var regionScope: ProgramBodyRegion?
        var revertible: Bool

        private enum CodingKeys: String, CodingKey {
            case inputSummary
            case decisionApplied
            case iconSystemName
            case reasonCategory
            case regionScope
            case revertible
        }

        init(
            inputSummary: String,
            decisionApplied: String,
            iconSystemName: String,
            reasonCategory: ReasonCategory? = nil,
            regionScope: ProgramBodyRegion? = nil,
            revertible: Bool = false
        ) {
            self.inputSummary = inputSummary
            self.decisionApplied = decisionApplied
            self.iconSystemName = iconSystemName
            self.reasonCategory = reasonCategory
            self.regionScope = regionScope
            self.revertible = revertible
        }

        init(
            category: ReasonCategory,
            regionScope: ProgramBodyRegion? = nil,
            inputSummary: String,
            iconSystemName: String? = nil,
            revertible: Bool = true
        ) {
            self.init(
                inputSummary: inputSummary,
                decisionApplied: ProgramRationaleCopy.text(for: category, region: regionScope),
                iconSystemName: iconSystemName ?? ProgramRationaleCopy.icon(for: category),
                reasonCategory: category,
                regionScope: regionScope,
                revertible: revertible
            )
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.id = UUID()
            self.inputSummary = try c.decode(String.self, forKey: .inputSummary)
            self.decisionApplied = try c.decode(String.self, forKey: .decisionApplied)
            self.iconSystemName = try c.decode(String.self, forKey: .iconSystemName)
            self.reasonCategory = try c.decodeIfPresent(ReasonCategory.self, forKey: .reasonCategory)
            self.regionScope = try c.decodeIfPresent(ProgramBodyRegion.self, forKey: .regionScope)
            self.revertible = try c.decodeIfPresent(Bool.self, forKey: .revertible) ?? false
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(inputSummary, forKey: .inputSummary)
            try c.encode(decisionApplied, forKey: .decisionApplied)
            try c.encode(iconSystemName, forKey: .iconSystemName)
            try c.encodeIfPresent(reasonCategory, forKey: .reasonCategory)
            try c.encodeIfPresent(regionScope, forKey: .regionScope)
            try c.encode(revertible, forKey: .revertible)
        }
    }

    let headline: String
    let summaryCopy: String
    let decisions: [Decision]
}

enum ProgramRationaleCopy {
    static func text(
        for category: ProgramRationale.ReasonCategory,
        region: ProgramBodyRegion? = nil
    ) -> String {
        let regionName = region?.displayName.lowercased()
        switch category {
        case .loadLowered:
            return regionName.map { "Lowered load for \($0) so recovery can catch up." }
                ?? "Lowered load so recovery can catch up."
        case .loadRaised:
            return regionName.map { "Raised load for \($0) because recent work cleared the target cleanly." }
                ?? "Raised load because recent work cleared the target cleanly."
        case .repsChanged:
            return "Adjusted reps to keep the set target inside the right effort range."
        case .setCountChanged:
            return "Adjusted set count to match the current weekly training budget."
        case .exerciseSwapped:
            return "Swapped the exercise to keep the same intent with a better fit."
        case .accessoryRemoved:
            return regionName.map { "Trimmed \($0) accessory volume because that region is over budget." }
                ?? "Trimmed accessory volume because the week is over budget."
        case .vowReplacingAccessory:
            return regionName.map { "Your vow adds \($0) work, so matching accessory volume was replaced." }
                ?? "Your vow adds work, so matching accessory volume was replaced."
        case .skillBlockInserted:
            return regionName.map { "Inserted skill work for \($0) without changing the rest of the split." }
                ?? "Inserted skill work without changing the rest of the split."
        case .deloadApplied:
            return "Applied a deload so the next push starts from better recovery."
        case .missedPressureReduced:
            return "Reduced pressure because recent scheduled sessions were missed."
        case .checkpointRecommendation:
            return "Checkpoint signals changed the next Arc recommendation."
        }
    }

    static func icon(for category: ProgramRationale.ReasonCategory) -> String {
        switch category {
        case .loadLowered, .deloadApplied, .missedPressureReduced:
            return "gauge.with.dots.needle.33percent"
        case .loadRaised:
            return "arrow.up.forward"
        case .repsChanged, .setCountChanged:
            return "slider.horizontal.3"
        case .exerciseSwapped:
            return "arrow.triangle.2.circlepath"
        case .accessoryRemoved:
            return "scissors"
        case .vowReplacingAccessory:
            return "seal.fill"
        case .skillBlockInserted:
            return "sparkles"
        case .checkpointRecommendation:
            return "camera.metering.center.weighted"
        }
    }
}
