// UNBOUNDTests/Services/AttributeServiceDriftTests.swift
import XCTest
@testable import UNBOUND

final class AttributeServiceDriftTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeProfile(peak: Double, current: Double, at: Date) -> AttributeProfile {
        var p = AttributeProfile.empty(userId: "u", at: at)
        p.set(.power, AttributeValue(peak: peak, current: current, lastContributionAt: at))
        return p
    }

    func testNoChangeAtLastContributionAt() {
        let p = makeProfile(peak: 80, current: 70, at: t0)
        let snap = AttributeDrift.project(p, to: t0)
        XCTAssertEqual(snap.value(for: .power).current, 70, accuracy: 0.001)
    }

    func testNoChangeWithin7DayGrace() {
        let p = makeProfile(peak: 80, current: 70, at: t0)
        let snap = AttributeDrift.project(p, to: t0.addingTimeInterval(7 * 86400))
        XCTAssertEqual(snap.value(for: .power).current, 70, accuracy: 0.001)
    }

    func testMidWindowAt22DaysIdleIs50PercentTowardFloor() {
        // 22d idle = 7d grace + 15d decay → decayProgress = 0.5
        // floor = 80 * 0.7 = 56; expected = 56 + (70 - 56) * 0.5 = 63
        let p = makeProfile(peak: 80, current: 70, at: t0)
        let snap = AttributeDrift.project(p, to: t0.addingTimeInterval(22 * 86400))
        XCTAssertEqual(snap.value(for: .power).current, 63, accuracy: 0.001)
    }

    func testExactFloorAt37DaysIdle() {
        let p = makeProfile(peak: 80, current: 70, at: t0)
        let snap = AttributeDrift.project(p, to: t0.addingTimeInterval(37 * 86400))
        XCTAssertEqual(snap.value(for: .power).current, 56, accuracy: 0.001)
    }

    func testClampsAtFloorPast37Days() {
        let p = makeProfile(peak: 80, current: 70, at: t0)
        let snap = AttributeDrift.project(p, to: t0.addingTimeInterval(90 * 86400))
        XCTAssertEqual(snap.value(for: .power).current, 56, accuracy: 0.001)
    }

    func testPeakIndependentTempoIdenticalCurveForLowAndHighPeaks() {
        let pLow  = makeProfile(peak: 20, current: 20, at: t0)
        let pHigh = makeProfile(peak: 90, current: 90, at: t0)
        let date = t0.addingTimeInterval(22 * 86400)
        let snapLow  = AttributeDrift.project(pLow, to: date).value(for: .power).current
        let snapHigh = AttributeDrift.project(pHigh, to: date).value(for: .power).current
        let progressLow  = (20.0 - snapLow)  / (20.0 - 14.0)
        let progressHigh = (90.0 - snapHigh) / (90.0 - 63.0)
        XCTAssertEqual(progressLow, progressHigh, accuracy: 0.001)
    }

    func testPerAxisIndependenceUnrelatedAxesDriftIndependently() {
        var p = AttributeProfile.empty(userId: "u", at: t0)
        p.set(.power, AttributeValue(peak: 80, current: 70, lastContributionAt: t0))
        let mobilityContribAt = t0.addingTimeInterval(14 * 86400)
        p.set(.mobility, AttributeValue(peak: 40, current: 40, lastContributionAt: mobilityContribAt))

        let evalAt = t0.addingTimeInterval(37 * 86400)
        let snap = AttributeDrift.project(p, to: evalAt)

        XCTAssertEqual(snap.value(for: .power).current, 56, accuracy: 0.001)
        XCTAssertEqual(snap.value(for: .mobility).current, 33.6, accuracy: 0.001)
    }

    func testFractionalDayInGraceWindowReturnsCurrentUnchanged() {
        let p = makeProfile(peak: 80, current: 70, at: t0)
        // 2.5 days idle (well inside 7-day grace) — no decay.
        let snap = AttributeDrift.project(p, to: t0.addingTimeInterval(2.5 * 86400))
        XCTAssertEqual(snap.value(for: .power).current, 70, accuracy: 0.001)
    }

    func testFractionalDayJustPastGraceProducesSmoothDecayStart() {
        let p = makeProfile(peak: 80, current: 70, at: t0)
        // 7.4 days idle → effective = 0.4d, progress = 0.4/30 = 1.333...%
        // expected = 56 + (70 − 56) × (1 − 0.0133...) = 56 + 14 × 0.98666... ≈ 69.8133...
        let snap = AttributeDrift.project(p, to: t0.addingTimeInterval(7.4 * 86400))
        XCTAssertEqual(snap.value(for: .power).current, 69.8133, accuracy: 0.001)
    }
}
