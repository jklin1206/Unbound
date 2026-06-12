// UNBOUND/Models/BuildIdentity.swift
import Foundation

// MARK: - BuildIdentity
//
// Grounded athletic descriptor derived from AttributeProfile.
// BuildIdentity is the canonical identity type (Phase 2g).
//
// Two-layer rule (per feedback_unbound_buildidentity_vs_titles memory):
//   BuildIdentity → grounded (auto-derived).
//   Title         → earned fantasy flavor (separate future system).

struct BuildIdentity: Equatable, Sendable {
    enum Shape: String, Codable, Sendable {
        case balancedAthlete       // spread < 15
        case hybridAthlete          // top3 within 10 of top1 AND gap12 < 10
        case specialist             // gap12 > 25
        case hybrid                 // gap12 < 10 (and NOT hybridAthlete)
        case lean                   // 10 ≤ gap12 ≤ 25
    }

    /// Primary axis — nil for balancedAthlete and hybridAthlete.
    let primary: AttributeKey?
    /// Secondary axis — only set for .hybrid.
    let secondary: AttributeKey?
    let shape: Shape

    var displayName: String {
        switch shape {
        case .balancedAthlete: return balancedDisplayName
        case .hybridAthlete:   return L10n.string(.buildIdentityDisplayNameHybridAthlete, defaultValue: "Hybrid Athlete")
        case .specialist:
            guard let primary else { return balancedDisplayName }
            return L10n.format(.buildIdentityDisplayNameSpecialist, defaultValue: "%@ Specialist", primary.buildVocab)
        case .hybrid:
            guard let primary else { return balancedDisplayName }
            return L10n.format(.buildIdentityDisplayNameHybrid, defaultValue: "%@ Hybrid", primary.buildVocab)
        case .lean:
            guard let primary else { return balancedDisplayName }
            return L10n.format(.buildIdentityDisplayNameLean, defaultValue: "%@%@", primary.buildVocab, primary.leanSuffix)
        }
    }

    var tagline: String {
        switch shape {
        case .balancedAthlete:
            return evenTagline
        case .hybridAthlete:
            return L10n.string(.buildIdentityTaglineHybridAthlete, defaultValue: "Multi-axis athlete — no single specialty.")
        case .specialist:
            guard let primary else { return evenTagline }
            return L10n.format(.buildIdentityTaglineSpecialist, defaultValue: "Built around %@ — sharply focused.", primary.taglinePhrase)
        case .hybrid:
            guard let primary, let secondary else { return evenTagline }
            return L10n.format(.buildIdentityTaglineHybrid, defaultValue: "Built around %@ with strong %@.", primary.taglinePhrase, secondary.buildVocab)
        case .lean:
            guard let primary else { return evenTagline }
            return L10n.format(.buildIdentityTaglineLean, defaultValue: "Trending toward %@.", primary.taglinePhrase)
        }
    }

    private var balancedDisplayName: String {
        L10n.string(.buildIdentityDisplayNameBalancedAthlete, defaultValue: "Balanced Athlete")
    }

    private var evenTagline: String {
        L10n.string(.buildIdentityTaglineEven, defaultValue: "Even across every axis.")
    }
}

// MARK: - Program template mapping

extension BuildIdentity {
    /// Stable string key for program-template selection. Balanced/hybridAthlete
    /// share a neutral template; specialist/hybrid/lean map to the primary axis
    /// rawValue (e.g. "power", "endurance"). Phase 2e consumers in
    /// ProgramGenerationService read this to select a template.
    var programTemplateKey: String {
        switch shape {
        case .balancedAthlete, .hybridAthlete:
            return "balanced"
        case .specialist, .hybrid, .lean:
            return primary?.rawValue ?? "balanced"
        }
    }

}
