// UNBOUND/Services/Trials/VowWeeklyDraw.swift
import Foundation

/// Draws the 3 weekly Binding Vow cards from the bank pool (spec §6).
/// Deterministic in (weekNumber, completionsByLane). Guarantees the most
/// neglected lane appears, then fills to 3 spanning lanes/bets.
enum VowWeeklyDraw {
    static func cards(weekNumber: Int, yearForWeekOfYear: Int, completionsByLane: [VowLane: Int]) -> [WeeklyVowCard] {
        let pool = VowBankPool.all
        guard !pool.isEmpty else { return [] }

        // Seeded, non-cryptographic rotation. weekNumber advances the offset so
        // the trio rotates week to week without RNG.
        func pick(_ candidates: [VowCardTemplate], salt: Int) -> VowCardTemplate? {
            guard !candidates.isEmpty else { return nil }
            let idx = ((weekNumber &* 31) &+ salt) % candidates.count
            return candidates[(idx % candidates.count + candidates.count) % candidates.count]
        }

        var chosen: [VowCardTemplate] = []

        // 1) Most neglected lane (lowest completion count; ties broken by lane order).
        let neglected = VowLane.allCases.min { a, b in
            (completionsByLane[a] ?? 0, a.rawValue) < (completionsByLane[b] ?? 0, b.rawValue)
        }
        if let neglected, let t = pick(pool.filter { $0.lane == neglected }, salt: 1) {
            chosen.append(t)
        }

        // 2) Fill remaining slots, preferring unused lanes then unused bets.
        var salt = 2
        while chosen.count < 3 {
            let usedLanes = Set(chosen.map(\.lane))
            let usedBets = Set(chosen.map(\.bet))
            let preferred = pool.filter { !usedLanes.contains($0.lane) }
            let pickFrom = preferred.isEmpty ? pool.filter { !chosen.contains($0) } : preferred
            guard var t = pick(pickFrom, salt: salt) else { break }
            // nudge toward an unused bet size if the picked one is taken
            if usedBets.contains(t.bet),
               let alt = pickFrom.first(where: { !usedBets.contains($0.bet) }) {
                t = alt
            }
            if !chosen.contains(t) { chosen.append(t) }
            salt += 1
            if salt > 64 { break } // safety
        }

        return chosen.prefix(3).map { template in
            WeeklyVowCard(
                id: "weekly-vow-\(yearForWeekOfYear)-W\(weekNumber)-\(template.templateId)",
                lane: template.lane,
                bet: template.bet,
                displayName: template.displayName,
                blurb: template.blurb,
                target: template.target
            )
        }
    }
}
