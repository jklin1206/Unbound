// supabase/functions/delete_account/handler_test.ts
//
// Run: deno test --allow-all supabase/functions/delete_account/handler_test.ts
//
// These tests model the SAME ON DELETE CASCADE semantics the real Postgres
// schema enforces, so they fail the way production would:
//   • squads.captain_id  references auth.users(id) ON DELETE CASCADE
//   • squad_members.user_id references auth.users(id) ON DELETE CASCADE
//   • public.users-owned tables cascade off the public.users row delete
//   • Storage objects under scans/{uid}/* have NO database cascade — they must
//     be deleted explicitly.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts"
import {
  type AccountDeletionDb,
  type AccountDeletionStorage,
  handleDeleteAccount,
  type SquadMemberRow,
  type SquadRow,
} from "./handler.ts"

// ---------------------------------------------------------------------------
// In-memory fake that enforces the real FK cascades.
// ---------------------------------------------------------------------------

class FakeWorld implements AccountDeletionDb, AccountDeletionStorage {
  userRows = new Set<string>()
  authUsers = new Set<string>()
  squads = new Map<string, SquadRow>()
  members: SquadMemberRow[] = []
  // public.* user-owned rows keyed by table → list of owning userIds.
  publicRows = new Map<string, string[]>()
  // Storage objects: full object paths e.g. "alice/scan1/front.jpg".
  storageObjects = new Set<string>()

  // ---- AccountDeletionDb ----

  squadsCaptainedBy(userId: string): Promise<SquadRow[]> {
    return Promise.resolve(
      [...this.squads.values()].filter((s) => s.captain_id === userId),
    )
  }

  squadMembers(squadId: string): Promise<SquadMemberRow[]> {
    return Promise.resolve(
      this.members
        .filter((m) => m.squad_id === squadId)
        .sort((a, b) => a.joined_at.localeCompare(b.joined_at)),
    )
  }

  updateSquadCaptain(squadId: string, newCaptainId: string): Promise<void> {
    const s = this.squads.get(squadId)
    if (s) s.captain_id = newCaptainId
    return Promise.resolve()
  }

  removeSquadMember(squadId: string, userId: string): Promise<void> {
    this.members = this.members.filter(
      (m) => !(m.squad_id === squadId && m.user_id === userId),
    )
    return Promise.resolve()
  }

  deleteSquad(squadId: string): Promise<void> {
    this.squads.delete(squadId)
    this.members = this.members.filter((m) => m.squad_id !== squadId)
    return Promise.resolve()
  }

  deleteUserRow(userId: string): Promise<void> {
    this.userRows.delete(userId)
    // Cascade every public.* user-owned table.
    for (const [table, owners] of this.publicRows) {
      this.publicRows.set(table, owners.filter((o) => o !== userId))
    }
    return Promise.resolve()
  }

  isAuthUser(userId: string): Promise<boolean> {
    return Promise.resolve(this.authUsers.has(userId))
  }

  deleteAuthUser(userId: string): Promise<void> {
    this.authUsers.delete(userId)
    // ON DELETE CASCADE for auth.users(id):
    //  - squads.captain_id  → squad row (and its members) cascade away
    //  - squad_members.user_id → membership rows cascade away
    for (const [id, s] of [...this.squads]) {
      if (s.captain_id === userId) {
        this.squads.delete(id)
        this.members = this.members.filter((m) => m.squad_id !== id)
      }
    }
    this.members = this.members.filter((m) => m.user_id !== userId)
    return Promise.resolve()
  }

  // ---- AccountDeletionStorage ----

  deletePhotoRoot(prefix: string): Promise<void> {
    for (const obj of [...this.storageObjects]) {
      if (obj === prefix || obj.startsWith(`${prefix}/`)) {
        this.storageObjects.delete(obj)
      }
    }
    return Promise.resolve()
  }
}

// ---------------------------------------------------------------------------
// PROOF A — complete deletion across all tables + storage (incl. old UUID dir)
// ---------------------------------------------------------------------------

Deno.test("Proof A: deleting an account wipes every table row and every photo object, including the legacy-UUID directory", async () => {
  const w = new FakeWorld()
  const uid = "00000000-0000-0000-0000-0000000000aa"
  const legacy = "11111111-1111-1111-1111-1111111111bb"

  w.userRows.add(uid)
  w.authUsers.add(uid)
  for (
    const table of [
      "programs",
      "workout_logs",
      "working_weights",
      "progression_states",
      "exercise_preferences",
      "skill_progress",
      "coach_messages",
      "scans",
      "scan_delta_reports",
    ]
  ) {
    w.publicRows.set(table, [uid])
  }
  // Photos under BOTH the live UID and the legacy/old-UUID directory.
  w.storageObjects.add(`${uid}/scan1/front.jpg`)
  w.storageObjects.add(`${uid}/scan1/back.jpg`)
  w.storageObjects.add(`${uid}/scan2/front.jpg`)
  w.storageObjects.add(`${legacy}/scan0/front.jpg`)

  const result = await handleDeleteAccount(
    { userId: uid, legacyUserId: legacy },
    w,
    w,
  )

  assertEquals(result.deleted, true)
  // Zero rows remain in every relevant table.
  assertEquals(w.userRows.size, 0, "users row remains")
  assertEquals(w.authUsers.size, 0, "auth user remains")
  for (const [table, owners] of w.publicRows) {
    assertEquals(owners.length, 0, `${table} still has rows`)
  }
  // Zero files remain in the photo root, including the legacy-UUID dir.
  assertEquals(w.storageObjects.size, 0, "storage objects remain")
})

// ---------------------------------------------------------------------------
// PROOF B — captain deletion leaves the squad alive with a new captain
// ---------------------------------------------------------------------------

Deno.test("Proof B: when a captain deletes their account, the squad survives with a remaining member promoted to captain", async () => {
  const w = new FakeWorld()
  const captain = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
  const member1 = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
  const member2 = "cccccccc-cccc-cccc-cccc-cccccccccccc"
  const squadId = "dddddddd-dddd-dddd-dddd-dddddddddddd"

  w.userRows.add(captain)
  w.authUsers.add(captain)
  w.squads.set(squadId, { id: squadId, captain_id: captain })
  // joined_at order: captain oldest, then member1, then member2.
  w.members.push({ squad_id: squadId, user_id: captain, joined_at: "2026-01-01T00:00:00Z" })
  w.members.push({ squad_id: squadId, user_id: member1, joined_at: "2026-02-01T00:00:00Z" })
  w.members.push({ squad_id: squadId, user_id: member2, joined_at: "2026-03-01T00:00:00Z" })

  const result = await handleDeleteAccount({ userId: captain }, w, w)

  assertEquals(result.squadsReassigned, 1)
  assertEquals(result.squadsDeleted, 0)
  // Squad still exists.
  const survived = w.squads.get(squadId)
  assertEquals(survived !== undefined, true, "squad was wiped")
  // Longest-tenured remaining member (member1) is the new captain.
  assertEquals(survived?.captain_id, member1)
  // Departing captain's membership is gone; the two remaining members stay.
  const remaining = w.members.filter((m) => m.squad_id === squadId).map((m) => m.user_id).sort()
  assertEquals(remaining, [member1, member2].sort())
})

// ---------------------------------------------------------------------------
// PROOF B (edge): sole-member captain → squad is removed, not orphaned
// ---------------------------------------------------------------------------

Deno.test("Proof B edge: a sole-member captain deleting their account removes the squad cleanly", async () => {
  const w = new FakeWorld()
  const captain = "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee"
  const squadId = "ffffffff-ffff-ffff-ffff-ffffffffffff"

  w.userRows.add(captain)
  w.authUsers.add(captain)
  w.squads.set(squadId, { id: squadId, captain_id: captain })
  w.members.push({ squad_id: squadId, user_id: captain, joined_at: "2026-01-01T00:00:00Z" })

  const result = await handleDeleteAccount({ userId: captain }, w, w)

  assertEquals(result.squadsDeleted, 1)
  assertEquals(result.squadsReassigned, 0)
  assertEquals(w.squads.size, 0, "sole-member squad should be gone")
  assertEquals(w.members.length, 0)
})

// ---------------------------------------------------------------------------
// PROOF C — the client-supplied legacy_user_id cannot purge another account
// ---------------------------------------------------------------------------

Deno.test("Proof C: a legacy_user_id naming another live auth user is refused — the victim's photos survive", async () => {
  const w = new FakeWorld()
  const attacker = "00000000-0000-0000-0000-0000000000aa"
  const victim = "99999999-9999-9999-9999-9999999999ff"

  w.userRows.add(attacker)
  w.authUsers.add(attacker)
  w.userRows.add(victim)
  w.authUsers.add(victim)
  w.storageObjects.add(`${attacker}/scan1/front.jpg`)
  w.storageObjects.add(`${victim}/scan1/front.jpg`)
  w.storageObjects.add(`${victim}/scan2/back.jpg`)

  const result = await handleDeleteAccount(
    { userId: attacker, legacyUserId: victim },
    w,
    w,
  )

  assertEquals(result.deleted, true)
  assertEquals(result.photoRootsPurged, [attacker], "only the caller's root may be purged")
  // The victim's account and photos are untouched.
  assertEquals(w.authUsers.has(victim), true)
  assertEquals(
    [...w.storageObjects].filter((o) => o.startsWith(`${victim}/`)).length,
    2,
    "victim photos were deleted",
  )
})

Deno.test("Proof C edge: a non-UUID legacy_user_id (path traversal shape) is ignored entirely", async () => {
  const w = new FakeWorld()
  const uid = "00000000-0000-0000-0000-0000000000aa"
  const bystander = "12121212-1212-1212-1212-121212121212"

  w.userRows.add(uid)
  w.authUsers.add(uid)
  w.storageObjects.add(`${uid}/scan1/front.jpg`)
  w.storageObjects.add(`${bystander}/scan1/front.jpg`)

  const result = await handleDeleteAccount(
    { userId: uid, legacyUserId: "" },
    w,
    w,
  )
  assertEquals(result.photoRootsPurged, [uid])

  const w2 = new FakeWorld()
  w2.userRows.add(uid)
  w2.authUsers.add(uid)
  w2.storageObjects.add(`${bystander}/scan1/front.jpg`)
  const result2 = await handleDeleteAccount(
    { userId: uid, legacyUserId: bystander.slice(0, 8) },
    w2,
    w2,
  )
  assertEquals(result2.photoRootsPurged, [uid])
  assertEquals(w2.storageObjects.size, 1, "bystander photos must survive a malformed legacy id")
})

Deno.test("Proof C edge: a genuine orphan legacy UUID (never an auth user) is still purged", async () => {
  const w = new FakeWorld()
  const uid = "00000000-0000-0000-0000-0000000000aa"
  const legacy = "11111111-1111-1111-1111-1111111111bb"

  w.userRows.add(uid)
  w.authUsers.add(uid)
  w.storageObjects.add(`${legacy}/scan0/front.jpg`)

  const result = await handleDeleteAccount(
    { userId: uid, legacyUserId: legacy },
    w,
    w,
  )
  assertEquals(result.photoRootsPurged.sort(), [uid, legacy].sort())
  assertEquals(w.storageObjects.size, 0, "orphan legacy directory should be purged")
})
