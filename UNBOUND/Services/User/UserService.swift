import Foundation

final class UserService: UserServiceProtocol, @unchecked Sendable {
    static let shared = UserService()
    private let database = DatabaseService.shared
    private let logger = LoggingService.shared

    private init() {}

    func createUserIfNeeded(userId: String, email: String?) async throws -> UserProfile {
        do {
            let existing: UserProfile = try await database.read(collection: "users", documentId: userId)
            return existing
        } catch {
            let newUser = UserProfile(
                id: userId,
                email: email,
                displayName: nil,
                createdAt: Date(),
                onboardingCompleted: false,
                totalScans: 0,
                currentProgramId: nil,
                heightCm: nil,
                weightKg: nil,
                age: nil,
                biologicalSex: nil
            )
            try await database.create(newUser, collection: "users", documentId: userId)
            logger.log("New user profile created", level: .info, context: ["userId": userId])
            return newUser
        }
    }

    func fetchProfile(userId: String) async throws -> UserProfile {
        try await database.read(collection: "users", documentId: userId)
    }

    func updateProfile(userId: String, fields: [String: Any]) async throws {
        try await database.update(fields, collection: "users", documentId: userId)
    }

    func deleteUserData(userId: String) async throws {
        let scans: [ScanSession] = try await database.query(collection: "scans", field: "userId", isEqualTo: userId)
        for scan in scans {
            try await database.delete(collection: "scans", documentId: scan.id)
            if let analysisId = scan.analysisId {
                try await database.delete(collection: "analyses", documentId: analysisId)
            }
            if let programId = scan.programId {
                try await database.delete(collection: "programs", documentId: programId)
            }
        }

        let progress: [ProgressEntry] = try await database.query(collection: "progress", field: "userId", isEqualTo: userId)
        for entry in progress {
            try await database.delete(collection: "progress", documentId: entry.id)
        }

        try await database.delete(collection: "users", documentId: userId)
        try await StorageService.shared.deleteUserPhotos(userId: userId)
        logger.log("All user data deleted", level: .info, context: ["userId": userId])
    }
}
