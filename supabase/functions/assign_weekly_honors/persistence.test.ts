import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts"
import { persistWeeklyHonors, type WeeklyHonorRow } from "./persistence.ts"

function honor(kind = "mostConsistent"): WeeklyHonorRow {
  return {
    squad_id: "squad-1",
    week_iso: "2026-W22",
    honor_kind: kind,
    recipient_user_id: "user-1",
  }
}

function fakeDb(error: unknown | null = null) {
  const calls: Array<{ table: string; rows: WeeklyHonorRow[]; options: unknown }> = []
  return {
    calls,
    db: {
      from(table: string) {
        return {
          async upsert(rows: WeeklyHonorRow[], options: unknown) {
            calls.push({ table, rows, options })
            return { error }
          },
        }
      },
    },
  }
}

Deno.test("persistWeeklyHonors uses the weekly honor uniqueness target for duplicate cron runs", async () => {
  const { db, calls } = fakeDb()

  await persistWeeklyHonors(db, [honor()])
  await persistWeeklyHonors(db, [honor()])

  assertEquals(calls.length, 2)
  assertEquals(calls[0].table, "squad_weekly_honors")
  assertEquals(calls[0].options, {
    onConflict: "squad_id,week_iso,honor_kind",
    ignoreDuplicates: true,
  })
  assertEquals(calls[1].options, calls[0].options)
})

Deno.test("persistWeeklyHonors fails loudly when the database rejects the upsert", async () => {
  const { db } = fakeDb(new Error("missing unique constraint"))

  await assertRejects(
    () => persistWeeklyHonors(db, [honor("ironWill")]),
    Error,
    "missing unique constraint",
  )
})

Deno.test("persistWeeklyHonors skips empty honor batches", async () => {
  const { db, calls } = fakeDb()

  await persistWeeklyHonors(db, [])

  assertEquals(calls.length, 0)
})
