// UNBOUND/Services/Scan/ScanPayoffFlavorService.swift
import Foundation

/// Returns one-liner flavor copy commenting on Build Identity.
/// Uses claude-haiku-4-5 (cheap one-liner generation).
/// NEVER references body parts. Falls back on error.
@MainActor
final class ScanPayoffFlavorService {
    static let shared = ScanPayoffFlavorService()
    private let client = ClaudeClient.shared
    private let logger = LoggingService.shared
    private let fallback = "Your work is showing."

    /// Returns one-liner flavor copy commenting on Build Identity.
    /// Never references body parts. Falls back on error.
    func flavor(for identity: BuildIdentity) async -> String {
        let system = """
        You write one-sentence flavor copy for a fitness app. \
        Comment on the user's training identity, not their body.
        """
        let userText = ScanPayoffFlavorService.composedPrompt(
            buildIdentityName: identity.displayName,
            dominantAxis: identity.primary?.buildVocab ?? "balanced"
        )

        do {
            let response = try await client.sendText(
                model: .haiku45,
                system: system,
                userText: userText,
                maxTokens: 60
            )
            let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? fallback : trimmed
        } catch {
            logger.log("ScanPayoffFlavorService.flavor error: \(error)", level: .warning)
            return fallback
        }
    }

    static func composedPrompt(buildIdentityName: String, dominantAxis: String) -> String {
        """
        The user just took a body scan. Their training has earned them a Build Identity of "\(buildIdentityName)".
        Their dominant axis: \(dominantAxis).

        Write ONE sentence (max 12 words) that comments on their training progress in a grounded, encouraging way.
        DO NOT rate or grade their body. DO NOT mention specific body parts.
        DO NOT use generic motivational language ("you got this", "keep going").
        FOCUS ON: their earned identity, the work showing through.

        Examples:
        - "Power-Oriented build — the work is reading on the page."
        - "Endurance Hybrid taking shape. The miles are doing it."
        - "Mobility specialist energy. Movement is becoming language."

        Now write the sentence for "\(buildIdentityName)":
        """
    }
}
