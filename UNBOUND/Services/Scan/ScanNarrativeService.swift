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
            return L10n.string(
                .scanNarrativeFirstBalanced,
                defaultValue: "Your arc begins balanced across every axis. No single specialty yet — that's a starting line, not a verdict. Come back in 30 days and we'll see where you've tilted."
            )
        case .hybridAthlete:
            return L10n.string(
                .scanNarrativeFirstHybridAthlete,
                defaultValue: "Your arc begins as a hybrid athlete — multiple strengths, no single specialty. The next 30 days of training will start sharpening the lines."
            )
        case .specialist:
            let axis = identity.primary?.buildVocab ?? L10n.string(.buildIdentityAxisBalanced, defaultValue: "Balanced")
            return L10n.format(
                .scanNarrativeFirstSpecialist,
                defaultValue: "Your arc begins tilted toward %@. That's where you walked in — now we'll see how it compounds with training. Come back in 30 days.",
                axis
            )
        case .hybrid:
            let primary = identity.primary?.buildVocab ?? L10n.string(.buildIdentityAxisBalanced, defaultValue: "Balanced")
            if let secondary = identity.secondary?.buildVocab {
                return L10n.format(
                    .scanNarrativeFirstHybridWithSecondary,
                    defaultValue: "Your arc begins as a %@ hybrid with strong %@. Two strengths to lean into, room everywhere else. The next checkpoint shows what 30 days does.",
                    primary,
                    secondary
                )
            }
            return L10n.format(
                .scanNarrativeFirstHybridWithoutSecondary,
                defaultValue: "Your arc begins as a %@ hybrid. Two strengths to lean into, room everywhere else. The next checkpoint shows what 30 days does.",
                primary
            )
        case .lean:
            let axis = identity.primary?.buildVocab ?? L10n.string(.buildIdentityAxisBalanced, defaultValue: "Balanced")
            return L10n.format(
                .scanNarrativeFirstLean,
                defaultValue: "Your arc begins trending %@. A clear direction, but plenty of room to grow elsewhere. Come back in 30 days.",
                axis
            )
        }
    }

    static func fallbackEvolutionNarrative(
        prior: BuildIdentity,
        current: BuildIdentity,
        delta: BuildIdentityDelta
    ) -> String {
        let positives = delta.positiveDeltas
        guard !positives.isEmpty else {
            return L10n.string(
                .scanNarrativeEvolutionSteady,
                defaultValue: "Your build held steady this month. Consistency is its own kind of win — keep the work going and the next checkpoint will show more."
            )
        }
        if let primary = delta.primaryGrowthAxis,
           let value = positives[primary] {
            let other = positives.keys.filter { $0 != primary }.first
            if let other, let v = positives[other], v > 0 {
                return L10n.format(
                    .scanNarrativeEvolutionPrimaryWithSecondary,
                    defaultValue: "Your %@ grew +%d over the last month. %@ climbed +%d alongside it. The arc is compounding — keep training and the next checkpoint will keep moving.",
                    primary.buildVocab,
                    value,
                    other.buildVocab,
                    v
                )
            }
            return L10n.format(
                .scanNarrativeEvolutionPrimaryOnly,
                defaultValue: "Your %@ grew +%d over the last month. The arc is compounding — keep training and the next checkpoint will keep moving.",
                primary.buildVocab,
                value
            )
        }
        return L10n.string(
            .scanNarrativeEvolutionMoved,
            defaultValue: "Your build moved this month. Keep training — the next checkpoint will show more."
        )
    }
}
