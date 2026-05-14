// UNBOUND/Services/Scan/ScanNarrativeService.swift
import Foundation

/// Writes lightweight narrative copy around already-derived BuildIdentity
/// data. NEVER sees a photo. NEVER grades the body. Uses Claude Haiku 4.5
/// for the live path and a deterministic template as fallback.
///
/// See project_unbound_scan_not_source_of_truth + project_unbound_create_your_own_arc.
enum ScanNarrativeService {

    static func firstScanNarrative(
        for identity: BuildIdentity,
        client: ClaudeClient = .shared
    ) async -> String {
        let system = """
        You are writing 2-3 sentences of flavor copy for a fitness app's \
        first body-scan checkpoint. The user just seeded a starting build \
        tendency through onboarding — the scan is the visual anchor for \
        their training arc. NEVER grade the body. NEVER mention body fat, \
        muscle mass, or appearance. NEVER claim medical or scientific \
        authority. Frame the moment as "your arc begins" — earned through \
        training, not assigned.
        """
        let userText = """
        Build shape: \(identity.shape.rawValue)
        Primary axis: \(identity.primary?.rawValue ?? "none")
        Secondary axis: \(identity.secondary?.rawValue ?? "none")
        Display name: \(identity.displayName)
        Tagline: \(identity.tagline)

        Write 2-3 sentences anchoring this starting point. Address the \
        reader as "you". No headings, no bullets, no quotes.
        """
        do {
            return try await client.sendText(
                model: .haiku45, system: system, userText: userText, maxTokens: 256
            )
        } catch {
            return fallbackFirstScanNarrative(for: identity)
        }
    }

    static func evolutionNarrative(
        prior: BuildIdentity,
        current: BuildIdentity,
        delta: BuildIdentityDelta,
        client: ClaudeClient = .shared
    ) async -> String {
        let system = """
        You are writing 2-3 sentences for a fitness app's monthly scan. The \
        user has trained for ~30 days. Their BuildIdentity moved per the \
        delta. ONLY mention positive growth. If an axis regressed, do not \
        mention it. NEVER grade the body or talk about appearance. NEVER \
        mention body fat or muscle mass. Tone: earned, specific, quietly \
        proud. End on a forward-looking line.
        """
        let positives = delta.positiveDeltas
            .map { "\($0.key.rawValue): +\($0.value)" }
            .joined(separator: ", ")
        let userText = """
        Prior build: \(prior.displayName)
        Current build: \(current.displayName)
        Positive deltas: \(positives.isEmpty ? "none — user held the line" : positives)

        Write 2-3 sentences on the evolution. Address the reader as "you". \
        No headings, no bullets, no quotes.
        """
        do {
            return try await client.sendText(
                model: .haiku45, system: system, userText: userText, maxTokens: 256
            )
        } catch {
            return fallbackEvolutionNarrative(prior: prior, current: current, delta: delta)
        }
    }

    // MARK: - Deterministic fallbacks

    static func fallbackFirstScanNarrative(for identity: BuildIdentity) -> String {
        switch identity.shape {
        case .balancedAthlete:
            return "Your arc begins balanced across every axis. No single specialty yet — that's a starting line, not a verdict. Come back in 30 days and we'll see where you've tilted."
        case .hybridAthlete:
            return "Your arc begins as a hybrid athlete — multiple strengths, no single specialty. The next 30 days of training will start sharpening the lines."
        case .specialist:
            let axis = identity.primary?.buildVocab ?? "Balanced"
            return "Your arc begins tilted toward \(axis). That's where you walked in — now we'll see how it compounds with training. Come back in 30 days."
        case .hybrid:
            let primary = identity.primary?.buildVocab ?? "Balanced"
            let secondary = identity.secondary?.buildVocab ?? ""
            let secondaryText = secondary.isEmpty ? "" : " with strong \(secondary)"
            return "Your arc begins as a \(primary) hybrid\(secondaryText). Two strengths to lean into, room everywhere else. The next checkpoint shows what 30 days does."
        case .lean:
            let axis = identity.primary?.buildVocab ?? "Balanced"
            return "Your arc begins trending \(axis). A clear direction, but plenty of room to grow elsewhere. Come back in 30 days."
        }
    }

    static func fallbackEvolutionNarrative(
        prior: BuildIdentity,
        current: BuildIdentity,
        delta: BuildIdentityDelta
    ) -> String {
        let positives = delta.positiveDeltas
        guard !positives.isEmpty else {
            return "Your build held steady this month. Consistency is its own kind of win — keep the work going and the next checkpoint will show more."
        }
        if let primary = delta.primaryGrowthAxis,
           let value = positives[primary] {
            let other = positives.keys.filter { $0 != primary }.first
            let secondaryClause: String
            if let other, let v = positives[other], v > 0 {
                secondaryClause = " \(other.buildVocab) climbed +\(v) alongside it."
            } else {
                secondaryClause = ""
            }
            return "Your \(primary.buildVocab) grew +\(value) over the last month.\(secondaryClause) The arc is compounding — keep training and the next checkpoint will keep moving."
        }
        return "Your build moved this month. Keep training — the next checkpoint will show more."
    }
}
