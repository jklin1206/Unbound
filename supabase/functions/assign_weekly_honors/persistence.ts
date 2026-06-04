export interface WeeklyHonorRow {
  squad_id: string
  week_iso: string
  honor_kind: string
  recipient_user_id: string
}

interface WeeklyHonorUpsertTarget {
  upsert(
    rows: WeeklyHonorRow[],
    options: { onConflict: string; ignoreDuplicates: boolean },
  ): Promise<{ error: unknown | null }>
}

interface WeeklyHonorDb {
  from(table: string): WeeklyHonorUpsertTarget
}

export async function persistWeeklyHonors(
  db: WeeklyHonorDb,
  honors: WeeklyHonorRow[],
): Promise<void> {
  if (honors.length === 0) return

  const { error } = await db.from("squad_weekly_honors").upsert(honors, {
    onConflict: "squad_id,week_iso,honor_kind",
    ignoreDuplicates: true,
  })

  if (error) {
    console.error("assign_weekly_honors upsert failed", error)
    throw error
  }
}
