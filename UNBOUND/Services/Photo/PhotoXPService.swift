import Foundation

// MARK: - PhotoXPServiceProtocol

@MainActor
protocol PhotoXPServiceProtocol: AnyObject {
    /// Awards +5 SP the first time a user captures a photo on a given
    /// calendar day. No-ops (returns false) on subsequent same-day captures
    /// to prevent farming. Returns true when SP was awarded.
    @discardableResult
    func awardDailyPhoto(userId: String) -> Bool

    /// Awards +25 SP for a completed bi-weekly scan. No dedup — the
    /// 14-day eligibility gate lives in the UI layer.
    func awardScan(userId: String)
}

// MARK: - PhotoXPService

@MainActor
final class PhotoXPService: PhotoXPServiceProtocol {
    static let shared = PhotoXPService()

    private let defaults = UserDefaults.standard
    private let gainsKey = "unbound.gains"
    private let lastPhotoKeyPrefix = "unbound.photoXP.lastDate."

    // Awards. Keep these inline so the plan numbers (5 / 25) live right
    // next to where they're granted — no separate constants file to stale.
    private let dailyPhotoSP = 5
    private let scanSP = 25

    private init() {}

    @discardableResult
    func awardDailyPhoto(userId: String) -> Bool {
        let today = dayString(for: Date())
        let key = lastPhotoKeyPrefix + userId
        if defaults.string(forKey: key) == today { return false }

        defaults.set(today, forKey: key)
        bumpGains(by: dailyPhotoSP)
        return true
    }

    func awardScan(userId: String) {
        bumpGains(by: scanSP)
    }

    // MARK: Helpers

    private func bumpGains(by amount: Int) {
        let current = defaults.integer(forKey: gainsKey)
        defaults.set(current + amount, forKey: gainsKey)
    }

    private func dayString(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f.string(from: date)
    }
}

// MARK: - MockPhotoXPService

@MainActor
final class MockPhotoXPService: PhotoXPServiceProtocol {
    var photoAwardsByUser: [String: Int] = [:]
    var scanAwardsByUser: [String: Int] = [:]

    @discardableResult
    func awardDailyPhoto(userId: String) -> Bool {
        photoAwardsByUser[userId, default: 0] += 1
        return true
    }

    func awardScan(userId: String) {
        scanAwardsByUser[userId, default: 0] += 1
    }
}
