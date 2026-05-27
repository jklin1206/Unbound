import Foundation

#if canImport(HealthKit)
@preconcurrency import HealthKit
#endif

struct HealthRecoverySnapshot: Codable, Equatable, Sendable {
    var date: Date
    var steps: Int
    var walkingRunningDistanceMeters: Double
    var asleepSeconds: TimeInterval

    var asleepHours: Double {
        asleepSeconds / 3_600
    }

    var vitalitySignals: [VitalityCheckInSignal] {
        var signals: [VitalityCheckInSignal] = []
        if steps >= 2_500 || walkingRunningDistanceMeters >= 1_600 {
            signals.append(.easyWalkOrMobility)
        }
        if asleepSeconds >= 7 * 3_600 {
            signals.append(.sleep)
        }
        return signals
    }

    var evidenceNote: String {
        let kilometers = walkingRunningDistanceMeters / 1_000
        return "healthkit:steps=\(steps) healthkit:walk_km=\(String(format: "%.2f", kilometers)) healthkit:sleep_h=\(String(format: "%.1f", asleepHours))"
    }
}

enum HealthKitServiceError: Error, Equatable {
    case unavailable
    case quantityTypeUnavailable(String)
    case categoryTypeUnavailable(String)
}

protocol HealthKitServiceProtocol: Sendable {
    var isHealthDataAvailable: Bool { get }
    func requestRecoveryReadAuthorization() async -> Bool
    func recoverySnapshot(for date: Date, calendar: Calendar) async throws -> HealthRecoverySnapshot
}

#if canImport(HealthKit)
actor HealthKitService: HealthKitServiceProtocol {
    static let shared = HealthKitService()

    private let store = HKHealthStore()

    nonisolated var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestRecoveryReadAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                store.requestAuthorization(toShare: Set<HKSampleType>(), read: recoveryReadTypes) { success, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if success {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: HealthKitServiceError.unavailable)
                    }
                }
            }
            return true
        } catch {
            return false
        }
    }

    func recoverySnapshot(for date: Date, calendar: Calendar = .current) async throws -> HealthRecoverySnapshot {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitServiceError.unavailable
        }

        _ = await requestRecoveryReadAuthorization()

        let interval = calendar.dateInterval(of: .day, for: date) ?? DateInterval(
            start: calendar.startOfDay(for: date),
            duration: 86_400
        )
        async let steps = cumulativeQuantity(
            .stepCount,
            unit: .count(),
            start: interval.start,
            end: interval.end
        )
        async let distance = cumulativeQuantity(
            .distanceWalkingRunning,
            unit: .meter(),
            start: interval.start,
            end: interval.end
        )
        async let sleep = asleepSeconds(start: interval.start, end: interval.end)

        return HealthRecoverySnapshot(
            date: date,
            steps: Int((try await steps).rounded()),
            walkingRunningDistanceMeters: try await distance,
            asleepSeconds: try await sleep
        )
    }

    private var recoveryReadTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) {
            types.insert(steps)
        }
        if let distance = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) {
            types.insert(distance)
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        return types
    }

    private func cumulativeQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date
    ) async throws -> Double {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            throw HealthKitServiceError.quantityTypeUnavailable(identifier.rawValue)
        }

        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: start,
                end: end,
                options: [.strictStartDate, .strictEndDate]
            )
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let value = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func asleepSeconds(start: Date, end: Date) async throws -> TimeInterval {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthKitServiceError.categoryTypeUnavailable("sleepAnalysis")
        }

        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let seconds = (samples as? [HKCategorySample] ?? [])
                    .filter(Self.isAsleepSample)
                    .reduce(0) { total, sample in
                        let clampedStart = max(sample.startDate, start)
                        let clampedEnd = min(sample.endDate, end)
                        return total + max(0, clampedEnd.timeIntervalSince(clampedStart))
                    }
                continuation.resume(returning: seconds)
            }
            store.execute(query)
        }
    }

    private static func isAsleepSample(_ sample: HKCategorySample) -> Bool {
        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ]
        return asleepValues.contains(sample.value)
    }
}
#else
struct HealthKitService: HealthKitServiceProtocol {
    static let shared = HealthKitService()

    var isHealthDataAvailable: Bool { false }

    func requestRecoveryReadAuthorization() async -> Bool {
        false
    }

    func recoverySnapshot(for date: Date, calendar: Calendar = .current) async throws -> HealthRecoverySnapshot {
        throw HealthKitServiceError.unavailable
    }
}
#endif

struct MockHealthKitService: HealthKitServiceProtocol {
    var snapshot: HealthRecoverySnapshot?
    var authorizationGranted = false

    var isHealthDataAvailable: Bool {
        snapshot != nil
    }

    func requestRecoveryReadAuthorization() async -> Bool {
        authorizationGranted
    }

    func recoverySnapshot(for date: Date, calendar: Calendar = .current) async throws -> HealthRecoverySnapshot {
        guard let snapshot else {
            throw HealthKitServiceError.unavailable
        }
        return snapshot
    }
}
