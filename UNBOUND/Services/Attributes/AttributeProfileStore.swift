// UNBOUND/Services/Attributes/AttributeProfileStore.swift
import Foundation

@MainActor
protocol AttributeProfileStoreProtocol: AnyObject {
    func load(userId: String) -> AttributeProfile?
    func save(_ profile: AttributeProfile)
    func pin(_ profile: AttributeProfile, toScan scanId: String)
    func history(userId: String) -> [AttributeProfile]
}

@MainActor
final class AttributeProfileStore: AttributeProfileStoreProtocol {
    static let shared = AttributeProfileStore()

    private let defaults = UserDefaults.standard
    private let profileKeyPrefix = "unbound.attributeProfile."
    private let historyKeyPrefix = "unbound.attributeHistory."

    func load(userId: String) -> AttributeProfile? {
        guard let data = defaults.data(forKey: profileKeyPrefix + userId) else { return nil }
        return try? JSONDecoder().decode(AttributeProfile.self, from: data)
    }

    func save(_ profile: AttributeProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: profileKeyPrefix + profile.userId)
    }

    func pin(_ profile: AttributeProfile, toScan scanId: String) {
        var hist = history(userId: profile.userId)
        hist.append(profile)
        if let data = try? JSONEncoder().encode(hist) {
            defaults.set(data, forKey: historyKeyPrefix + profile.userId)
        }
    }

    func history(userId: String) -> [AttributeProfile] {
        guard let data = defaults.data(forKey: historyKeyPrefix + userId),
              let list = try? JSONDecoder().decode([AttributeProfile].self, from: data)
        else { return [] }
        return list
    }
}
