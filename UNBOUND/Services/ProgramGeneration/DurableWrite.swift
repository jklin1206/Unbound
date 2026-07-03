import Foundation

/// Retry wrapper for best-effort side-effect writes in the program-generation
/// flow — scan status markers, `users.currentProgramId` pointer patches, and
/// local program fallbacks. None of these has a caller that can react to a
/// failure, so a bare `try?` silently drops them: a lost `currentProgramId`
/// patch lets `revalidate` re-adopt a finished arc, resurrecting the exact
/// stale-pointer bug the write exists to prevent. Retries a few times with a
/// short escalating backoff, then logs at error level so a persistent failure
/// is visible instead of vanishing.
enum DurableWrite {
    /// Runs `write`, retrying up to `attempts` times with a short escalating
    /// backoff. Returns `true` once a write lands; on total failure logs at
    /// error level and returns `false` — it never throws, since callers here
    /// are fire-and-forget. `write` must be idempotent: a later attempt may
    /// re-run a partially-applied write.
    @discardableResult
    static func attempt(
        _ label: String,
        attempts: Int = 3,
        context: [String: Any] = [:],
        logger: LoggingService = .shared,
        _ write: () async throws -> Void
    ) async -> Bool {
        let total = max(1, attempts)
        var lastError: Error?
        for tryNumber in 1...total {
            do {
                try await write()
                return true
            } catch {
                lastError = error
                if tryNumber < total {
                    try? await Task.sleep(nanoseconds: UInt64(tryNumber) * 150_000_000)
                }
            }
        }
        var errorContext = context
        errorContext["error"] = lastError.map { String(describing: $0) } ?? "unknown"
        logger.log("\(label) failed after \(total) attempts", level: .error, context: errorContext)
        return false
    }
}
