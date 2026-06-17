// UNBOUND/Services/Trials/VowBankPool.swift
import Foundation

/// A hand-authored bank-pool entry (spec §6). Stable `templateId`; the weekly
/// draw stamps a per-week card id.
struct VowCardTemplate: Equatable, Sendable {
    let templateId: String
    let lane: VowLane
    let bet: VowBet
    let displayName: String
    let blurb: String
    let target: VowTarget
}

/// The curated Binding Vow bank pool. Expandable over time.
enum VowBankPool {
    static let all: [VowCardTemplate] = recovery + fuel + engine

    // MARK: Recovery (auto-verified from a logged recovery session)
    private static let recovery: [VowCardTemplate] = [
        VowCardTemplate(templateId: "rec-still-water", lane: .recovery, bet: .small,
            displayName: "Still Water Vow",
            blurb: "Bind one recovery reset this week. Protect the arc; let the body catch up.",
            target: VowTarget(count: 1, noun: "recovery reset")),
        VowCardTemplate(templateId: "rec-open-gate", lane: .recovery, bet: .medium,
            displayName: "Open Gate Vow",
            blurb: "Bind two recovery resets. Keep the joints honest while the load builds.",
            target: VowTarget(count: 2, noun: "recovery reset")),
        VowCardTemplate(templateId: "rec-deep-current", lane: .recovery, bet: .large,
            displayName: "Deep Current Vow",
            blurb: "Bind three recovery resets. A full week of tending the engine.",
            target: VowTarget(count: 3, noun: "recovery reset")),
    ]

    // MARK: Fuel (self-report anchors, vow-scoped only)
    private static let fuel: [VowCardTemplate] = [
        VowCardTemplate(templateId: "fuel-first-spark", lane: .fuel, bet: .small,
            displayName: "First Spark Vow",
            blurb: "Bind three fuel anchors this week — protein, water, or a real meal. Tap each as you hit it.",
            target: VowTarget(count: 3, noun: "fuel anchor")),
        VowCardTemplate(templateId: "fuel-steady-forge", lane: .fuel, bet: .medium,
            displayName: "Steady Forge Vow",
            blurb: "Bind five fuel anchors. Fuel the work without counting a single calorie.",
            target: VowTarget(count: 5, noun: "fuel anchor")),
        VowCardTemplate(templateId: "fuel-full-furnace", lane: .fuel, bet: .large,
            displayName: "Full Furnace Vow",
            blurb: "Bind seven fuel anchors. A week of feeding the arc on purpose.",
            target: VowTarget(count: 7, noun: "fuel anchor")),
    ]

    // MARK: Engine (auto-verified from a logged cardio session)
    private static let engine: [VowCardTemplate] = [
        VowCardTemplate(templateId: "eng-blood-pace", lane: .engine, bet: .small,
            displayName: "Blood Pace Vow",
            blurb: "Bind one easy cardio session this week. Keep the engine turning over.",
            target: VowTarget(count: 1, noun: "easy cardio session")),
        VowCardTemplate(templateId: "eng-long-road", lane: .engine, bet: .medium,
            displayName: "Long Road Vow",
            blurb: "Bind two easy cardio sessions. Build the base under everything else.",
            target: VowTarget(count: 2, noun: "easy cardio session")),
        VowCardTemplate(templateId: "eng-iron-lungs", lane: .engine, bet: .large,
            displayName: "Iron Lungs Vow",
            blurb: "Bind three easy cardio sessions. A full week of engine work.",
            target: VowTarget(count: 3, noun: "easy cardio session")),
    ]
}
