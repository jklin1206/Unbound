import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2"
import {
  type AccountDeletionDb,
  type AccountDeletionStorage,
  handleDeleteAccount,
  type SquadMemberRow,
  type SquadRow,
} from "./handler.ts"

const PHOTO_BUCKET = "scans"

const jsonHeaders = {
  "content-type": "application/json",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
}

// ---------------------------------------------------------------------------
// Supabase-backed implementations of the deletion contracts.
// The handler owns the ordering/logic; these adapters only do I/O.
// ---------------------------------------------------------------------------

/** Wraps the service-role client as the DB contract the handler depends on. */
function makeDb(admin: SupabaseClient): AccountDeletionDb {
  return {
    async squadsCaptainedBy(userId) {
      const { data, error } = await admin
        .from("squads")
        .select("id, captain_id")
        .eq("captain_id", userId)
      if (error) throw error
      return (data ?? []) as SquadRow[]
    },
    async squadMembers(squadId) {
      const { data, error } = await admin
        .from("squad_members")
        .select("squad_id, user_id, joined_at")
        .eq("squad_id", squadId)
        .order("joined_at", { ascending: true })
      if (error) throw error
      return (data ?? []) as SquadMemberRow[]
    },
    async updateSquadCaptain(squadId, newCaptainId) {
      const { error } = await admin
        .from("squads")
        .update({ captain_id: newCaptainId })
        .eq("id", squadId)
      if (error) throw error
    },
    async removeSquadMember(squadId, userId) {
      const { error } = await admin
        .from("squad_members")
        .delete()
        .eq("squad_id", squadId)
        .eq("user_id", userId)
      if (error) throw error
    },
    async deleteSquad(squadId) {
      const { error } = await admin.from("squads").delete().eq("id", squadId)
      if (error) throw error
    },
    async deleteUserRow(userId) {
      const { error } = await admin.from("users").delete().eq("id", userId)
      if (error) throw error
    },
    async deleteAuthUser(userId) {
      const { error } = await admin.auth.admin.deleteUser(userId, false)
      if (error) throw error
    },
    async isAuthUser(userId) {
      const { data, error } = await admin.auth.admin.getUserById(userId)
      if (error) {
        // A definitive not-found means the id never was an auth user. Any
        // other failure is indeterminate — fail safe (treat as existing so
        // the optional legacy purge is skipped, never risked cross-user).
        return error.status !== 404
      }
      return data.user !== null
    },
  }
}

/**
 * Recursively deletes every object under `scans/{prefix}/`. The Storage API has
 * no recursive remove, so we walk the directory tree (scan dirs → angle files)
 * and batch-delete the leaf object paths.
 */
function makeStorage(admin: SupabaseClient): AccountDeletionStorage {
  return {
    async deletePhotoRoot(prefix) {
      const bucket = admin.storage.from(PHOTO_BUCKET)
      const objectPaths: string[] = []

      // Level 1: the user's scan directories (scans/{prefix}/{scanId}).
      const { data: scanDirs, error: listErr } = await bucket.list(prefix)
      if (listErr) throw listErr
      for (const entry of scanDirs ?? []) {
        // Storage list() returns a placeholder row for "folders"; recurse into
        // each to collect the actual object names.
        const { data: files, error: filesErr } = await bucket.list(`${prefix}/${entry.name}`)
        if (filesErr) throw filesErr
        if (files && files.length > 0) {
          for (const file of files) {
            objectPaths.push(`${prefix}/${entry.name}/${file.name}`)
          }
        } else {
          // A direct object sitting at scans/{prefix}/{name} with no children.
          objectPaths.push(`${prefix}/${entry.name}`)
        }
      }

      if (objectPaths.length > 0) {
        const { error: removeErr } = await bucket.remove(objectPaths)
        if (removeErr) throw removeErr
      }
    },
  }
}

interface DeleteAccountRequestBody {
  confirm?: boolean
  // Legacy/local UUID the client used before the Supabase migration, so its
  // old Storage directory is purged too. Optional.
  legacy_user_id?: string | null
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: jsonHeaders })
  }
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "method_not_allowed" }), {
      status: 405,
      headers: jsonHeaders,
    })
  }

  const authHeader = req.headers.get("Authorization") ?? ""
  const userClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  )
  const adminClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  )

  const { data: { user }, error: userError } = await userClient.auth.getUser()
  if (userError || !user) {
    return new Response(JSON.stringify({ error: "unauthorized" }), {
      status: 401,
      headers: jsonHeaders,
    })
  }

  let confirm = false
  let legacyUserId: string | null = null
  try {
    const body = (await req.json()) as DeleteAccountRequestBody
    confirm = body.confirm === true
    legacyUserId = body.legacy_user_id ?? null
  } catch {
    // Absent/invalid body means no confirmation and no legacy UID.
  }

  // Deletion is irreversible; require the explicit confirm flag so a stray
  // authenticated POST can't wipe the account.
  if (!confirm) {
    return new Response(JSON.stringify({ error: "confirmation_required" }), {
      status: 400,
      headers: jsonHeaders,
    })
  }

  try {
    const result = await handleDeleteAccount(
      { userId: user.id, legacyUserId },
      makeDb(adminClient),
      makeStorage(adminClient),
    )
    return new Response(JSON.stringify(result), {
      status: 200,
      headers: jsonHeaders,
    })
  } catch (err) {
    console.error("delete_account failed", err)
    return new Response(JSON.stringify({ error: "delete_failed" }), {
      status: 500,
      headers: jsonHeaders,
    })
  }
})
