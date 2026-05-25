import CryptoKit
import Foundation

enum SquadUserIdentity {
    static func uuid(from userId: String) -> UUID? {
        if let uuid = UUID(uuidString: userId) {
            return uuid
        }

        #if DEBUG
        return deterministicDebugUUID(for: userId)
        #else
        return nil
        #endif
    }

    static func usesLocalOnlySquad(for userId: String) -> Bool {
        #if DEBUG
        UUID(uuidString: userId) == nil
        #else
        false
        #endif
    }

    #if DEBUG
    private static func deterministicDebugUUID(for userId: String) -> UUID {
        let digest = SHA256.hash(data: Data("unbound.squads.\(userId)".utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        let start = hex.startIndex
        let p1 = hex.index(start, offsetBy: 8)
        let p2 = hex.index(p1, offsetBy: 4)
        let p3 = hex.index(p2, offsetBy: 4)
        let p4 = hex.index(p3, offsetBy: 4)
        let p5 = hex.index(p4, offsetBy: 12)
        let uuidString = [
            String(hex[start..<p1]),
            String(hex[p1..<p2]),
            String(hex[p2..<p3]),
            String(hex[p3..<p4]),
            String(hex[p4..<p5])
        ].joined(separator: "-")
        return UUID(uuidString: uuidString)!
    }
    #endif
}
