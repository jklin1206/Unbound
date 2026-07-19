import Foundation

// MARK: - PendingSquadInvite
//
// A tapped squad invite universal link (https://unboundbtr.com/squad/<code>)
// can arrive long before the app is in a state that can act on it: a brand-new
// user cold-launches into onboarding -> paywall -> auth and only reaches the
// Squads tab minutes later. The old non-sticky NotificationCenter post fired
// into the void, so the viral join loop was broken for exactly the people it
// exists for.
//
// This persists the tapped code the moment the URL arrives, regardless of app
// state, so a single central consumption seam (HomeTabView, once routing has
// resolved to the signed-in + onboarded main app) can surface the join flow
// with the code prefilled.
//
// The store is intentionally NOT keyed to user identity — the invite predates
// sign-in — so it uses one stable global key. Identity keying would lose the
// invite across the anonymous->authed handoff (see the streak-keyed-to-volatile-
// identity history for why that class of bug bites).
//
// A saved-at timestamp gates a 7-day TTL so a stale code can't ambush someone
// weeks later. Date() here is deliberate wall-clock UX and is NOT governed by
// the repo's dev clock (ProgramClock / dayOffset), which only governs program
// WRITES; `now` is injected so tests can pin it.

struct PendingSquadInvite {
    private static let codeKey = "pendingSquadInvite.code"
    private static let savedAtKey = "pendingSquadInvite.savedAt"

    /// How long a pending invite stays actionable before it is treated as stale.
    static let timeToLive: TimeInterval = 7 * 24 * 60 * 60

    /// Shared production instance, backed by the standard defaults.
    static let shared = PendingSquadInvite()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Persist a tapped invite code. A newer tap overwrites an older pending one
    /// (last link wins). Non-code input normalizes away to empty and is ignored.
    func save(code: String, now: Date = Date()) {
        let normalized = Self.normalize(code)
        guard !normalized.isEmpty else { return }
        defaults.set(normalized, forKey: Self.codeKey)
        defaults.set(now.timeIntervalSince1970, forKey: Self.savedAtKey)
    }

    /// The pending code if one is stored and still within its TTL; nil otherwise.
    /// An expired (or half-written, timestamp-missing) entry is cleared as a side
    /// effect so it can never linger past its window.
    func pendingCode(now: Date = Date()) -> String? {
        guard let code = defaults.string(forKey: Self.codeKey), !code.isEmpty else {
            return nil
        }
        let savedAt = defaults.double(forKey: Self.savedAtKey)
        guard savedAt > 0, now.timeIntervalSince1970 - savedAt <= Self.timeToLive else {
            clear()
            return nil
        }
        return code
    }

    /// Clear the pending invite. Called once the join sheet is actually presented
    /// with the code (not on mere app foreground), and defensively on expiry.
    func clear() {
        defaults.removeObject(forKey: Self.codeKey)
        defaults.removeObject(forKey: Self.savedAtKey)
    }

    /// Normalize a raw code into the 6-char uppercased alphanumeric shape that
    /// invite codes use (`SquadService.makeInviteCode`) and that `JoinSquadSheet`
    /// expects, so a stored code is directly presentable.
    static func normalize(_ raw: String) -> String {
        String(raw.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(6))
    }
}

// MARK: - SquadInviteLink
//
// Pure, testable parser for the /squad/<code> universal link. Tolerant of host
// casing and an optional `www.` prefix, and of the "squad" segment's casing;
// rejects a wrong host, a missing/empty code, and any extra path components.

enum SquadInviteLink {
    private static let inviteHost = "unboundbtr.com"

    /// Extract a normalized invite code from a universal-link URL, or nil if the
    /// URL is not a well-formed `/squad/<code>` link.
    static func inviteCode(from url: URL) -> String? {
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
            var host = components.host?.lowercased()
        else { return nil }

        if host.hasPrefix("www.") {
            host = String(host.dropFirst("www.".count))
        }
        guard host == inviteHost else { return nil }

        let segments = components.path.split(separator: "/").map(String.init)
        guard segments.count == 2, segments[0].lowercased() == "squad" else {
            return nil
        }

        let code = PendingSquadInvite.normalize(segments[1])
        return code.isEmpty ? nil : code
    }
}
