// supabase/functions/delete_account/handler.ts
//
// Pure, dependency-injected account-deletion logic, extracted from index.ts so
// it can be unit-tested under `deno test` without a live Supabase project.
//
// Responsibilities (the two data-integrity guarantees this module enforces):
//   1. COMPLETE WIPE — remove the user's profile row (which cascades every
//      public.* table) AND every Storage object under their photo root,
//      including any legacy/old-UUID directory left behind by the
//      local→cloud migration.
//   2. CAPTAIN SURVIVAL — before the auth user is deleted (squads.captain_id
//      has ON DELETE CASCADE → deleting the auth user would wipe the squad),
//      hand captaincy of every squad the user leads to the longest-tenured
//      remaining member, removing the squad only when the captain is the sole
//      member.
//
// index.ts wires these interfaces to the real Supabase admin client; tests
// wire them to in-memory fakes.

// ---------------------------------------------------------------------------
// Injected dependency contracts
// ---------------------------------------------------------------------------

/** Minimal squad row shape the handler needs. */
export interface SquadRow {
  id: string
  captain_id: string
}

/** Minimal squad member row shape the handler needs. */
export interface SquadMemberRow {
  squad_id: string
  user_id: string
  joined_at: string
}

/**
 * Database operations the handler depends on. The real implementation is a
 * thin wrapper over the Supabase service-role client; tests inject a fake.
 */
export interface AccountDeletionDb {
  /** Squads where the given user is the captain. */
  squadsCaptainedBy(userId: string): Promise<SquadRow[]>
  /** All members of a squad, ordered by joined_at ascending (oldest first). */
  squadMembers(squadId: string): Promise<SquadMemberRow[]>
  /** Reassign a squad's captain_id. */
  updateSquadCaptain(squadId: string, newCaptainId: string): Promise<void>
  /** Remove a single membership row. */
  removeSquadMember(squadId: string, userId: string): Promise<void>
  /** Delete an entire squad (cascades members/activity/messages). */
  deleteSquad(squadId: string): Promise<void>
  /** Delete the public.users row — cascades every user-owned public.* table. */
  deleteUserRow(userId: string): Promise<void>
  /** Delete the auth.users row (hard delete, no soft-delete tombstone). */
  deleteAuthUser(userId: string): Promise<void>
}

/**
 * Storage operations the handler depends on. The real implementation lists and
 * removes objects from the `scans` bucket; tests inject a fake.
 */
export interface AccountDeletionStorage {
  /**
   * Recursively delete every object under `scans/{prefix}/`. Must be a no-op
   * (not an error) when the prefix has no objects, so passing a legacy UID
   * that never uploaded is safe.
   */
  deletePhotoRoot(prefix: string): Promise<void>
}

export interface DeleteAccountInput {
  userId: string
  /**
   * Optional legacy/local UUID the client used before the Supabase
   * migration. Its Storage directory is purged too. Ignored when absent or
   * equal to userId.
   */
  legacyUserId?: string | null
}

export interface DeleteAccountResult {
  deleted: true
  squadsReassigned: number
  squadsDeleted: number
  photoRootsPurged: string[]
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

/**
 * Fully delete an account. Ordering is load-bearing:
 *   1. Reassign / dissolve captained squads FIRST, while the auth user still
 *      exists — otherwise the auth-user delete cascades the squad away before
 *      a new captain can be named.
 *   2. Delete the public.users row (cascades public.* user-owned tables).
 *   3. Delete the auth user (cascades remaining auth-referencing squad tables
 *      for squads where the user was a non-captain member).
 *   4. Purge Storage photo roots for the live UID and any legacy UID.
 *
 * @throws if any DB/storage step fails — the caller maps this to HTTP 500.
 */
export async function handleDeleteAccount(
  input: DeleteAccountInput,
  db: AccountDeletionDb,
  storage: AccountDeletionStorage,
): Promise<DeleteAccountResult> {
  const { userId } = input

  // --- Step 1: captain survival -------------------------------------------
  let squadsReassigned = 0
  let squadsDeleted = 0

  const captained = await db.squadsCaptainedBy(userId)
  for (const squad of captained) {
    const members = await db.squadMembers(squad.id)
    const others = members.filter((m) => m.user_id !== userId)
    if (others.length === 0) {
      // Sole member — nothing to hand off; remove the squad.
      await db.deleteSquad(squad.id)
      squadsDeleted++
    } else {
      // Longest-tenured remaining member becomes captain (members arrive
      // ordered joined_at ASC, so index 0 is oldest).
      const newCaptain = others[0]
      await db.updateSquadCaptain(squad.id, newCaptain.user_id)
      // Drop the departing captain's own membership now so the auth-user
      // cascade has nothing left to remove for this squad.
      await db.removeSquadMember(squad.id, userId)
      squadsReassigned++
    }
  }

  // --- Step 2: profile row (cascades public.* user-owned tables) ----------
  await db.deleteUserRow(userId)

  // --- Step 3: auth user (cascades remaining auth-referencing rows) -------
  await db.deleteAuthUser(userId)

  // --- Step 4: Storage photo roots ----------------------------------------
  const purged: string[] = []
  const roots = new Set<string>([userId])
  if (input.legacyUserId && input.legacyUserId !== userId) {
    roots.add(input.legacyUserId)
  }
  for (const root of roots) {
    await storage.deletePhotoRoot(root)
    purged.push(root)
  }

  return {
    deleted: true,
    squadsReassigned,
    squadsDeleted,
    photoRootsPurged: purged,
  }
}
