import Foundation
import Supabase

// MARK: - SupabaseProgramService
//
// Lightweight cloud-backed program persistence. ProgramGenerationService
// calls saveProgram() after every successful generate; UI reads currently
// continue to go through DatabaseService for in-memory program state, with
// a future swap to fetchProgram() once the migration is fully wired.
//
// Side-effect: also patches `current_program_id` on the user's row so the
// home screen knows which program is active.
//
// Swallows SupabaseDatabaseError.notAuthenticated and falls back to the
// local DatabaseService — keeps dev (local-UUID) flows working.

final class SupabaseProgramService: @unchecked Sendable {
    static let shared = SupabaseProgramService()

    private let supabase = SupabaseDatabase.shared
    private let local = DatabaseService.shared
    private let logger = LoggingService.shared

    private init() {}

    /// Persist a generated program for `userId`, then mark it as the
    /// current program on the user's row. Errors are logged but never
    /// thrown — caller wraps in `try?` already.
    func saveProgram(_ program: TrainingProgram, userId: String) async {
        do {
            _ = try await supabase.upsert(program, into: "programs")
            try await supabase.patch(
                ["current_program_id": AnyJSON.string(program.id)],
                in: "users",
                keyedBy: "id",
                equals: userId
            )
            logger.log("Program saved to Supabase", level: .info, context: ["programId": program.id])
        } catch SupabaseDatabaseError.notAuthenticated {
            try? await local.create(program, collection: "programs", documentId: program.id)
            try? await local.update(
                ["currentProgramId": program.id],
                collection: "users",
                documentId: userId
            )
        } catch {
            logger.log("SupabaseProgramService.saveProgram failed: \(error)", level: .error, context: ["programId": program.id])
            // Best-effort local fallback so the user never loses their program.
            try? await local.create(program, collection: "programs", documentId: program.id)
            try? await local.update(
                ["currentProgramId": program.id],
                collection: "users",
                documentId: userId
            )
        }
    }

    /// Fetch a program by id from Supabase. Falls back to the local cache
    /// when not authenticated or the row doesn't exist on the server.
    func fetchProgram(id: String) async throws -> TrainingProgram {
        do {
            if let program: TrainingProgram = try await supabase.fetchOne(
                from: "programs",
                keyedBy: "id",
                equals: id
            ) {
                return program
            }
            return try await local.read(collection: "programs", documentId: id)
        } catch SupabaseDatabaseError.notAuthenticated {
            return try await local.read(collection: "programs", documentId: id)
        }
    }
}
