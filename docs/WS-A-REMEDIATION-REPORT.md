# Workstream A — "Stop the Bleeding" · Parallel Remediation Report

**Date:** 2026-05-28
**Coordinator:** main session · **Workers:** 3 parallel subagents (isolated worktrees)
**Result:** ✅ All 3 parallelizable Category-A issue-groups fixed, proven, and merged to `main`.

---

## Orchestration model

Each worker ran fully isolated so they could never block each other on source, the iOS Simulator, or the build cache:

| Worker | Worktree | Branch | Dedicated simulator | DerivedData |
|---|---|---|---|---|
| migration | `UNBOUND-wsa-migration` | `fix/ws-a-migration` | UNBOUND-wsa-migration | `.derivedData-wsa-migration` |
| paywall | `UNBOUND-wsa-paywall` | `fix/ws-a-paywall` | UNBOUND-wsa-paywall | `.derivedData-wsa-paywall` |
| deletion | `UNBOUND-wsa-deletion` | `fix/ws-a-deletion` | UNBOUND-wsa-deletion | `.derivedData-wsa-deletion` |

All three branched off a **clean `main`** (after committing the 15k-line in-progress baseline so worktrees branched from a complete tree). Every worker was required to use TDD (red → green, red-state confirmed) and return a structured status + proof.

---

## What each worker did

### 1. Migration — scans/photos lost on sign-in + fire-and-forget migration (CRITICAL ×2)
**Root cause:** `UserDataMigrationCoordinator` re-keyed workout logs / weights / skill progress but **never** re-keyed `ScanCheckpoint` records or moved the on-disk `ScanPhotos/<uid>/` directory; and `LocalToSupabaseMigration` ran once with no await, no retry, no persisted completion flag.
**Fix:** added scan re-key + `movePhotoDirectory` (additive on `StorageService`), an `allCollectionsSucceeded` gate, awaited bounded retry (3 attempts, backoff), and a per-pair `migrationCompleted` flag in `UserDefaults` that drives cross-launch resume.
**Files:** `UserDataMigrationCoordinator.swift`, `UserDataMigrationStores.swift`, `StorageService.swift` (additive), `LocalToSupabaseMigration.swift`, + 2 test files.
**Proof:** `UserDataMigrationScanResumeTests` — Proof A (3 scans + photos re-keyed to new UID, old location empty) ✅, Proof B (mid-migration kill → resume → flag true only when all collections done) ✅. Red-state confirmed before fix.

### 2. Paywall — bypass via local-only entitlement (HIGH)
**Root cause:** premium access gated only by a **local** RevenueCat/onboarding flag; the premium Edge function `anthropic_proxy` did paid work after an auth check but never verified entitlement. No server-owned source of truth.
**Fix:** new `users.is_pro` (+ expiry) column; new `revenuecat_webhook` Edge fn (shared-secret auth) as the single writer of premium truth; `assertServerPro()` (fails **closed**) enforced in `anthropic_proxy` → **403** when false; client maps 403 → non-retryable `.premiumRequired`.
**Files:** `supabase/migrations/20260528000001_user_is_pro.sql`, `revenuecat_webhook/index.ts`, `_shared/entitlement.ts`, `anthropic_proxy/index.ts`, `ClaudeClient.swift`, + 4 test files.
**Proof:** 22 deno tests (Proof A: spoofed local + server `is_pro=false` → 403; `is_pro=true` → success; auth not weakened) ✅; `ClaudeClientTests.testServer403SurfacesPremiumRequiredAndDoesNotRetry` (Proof B: no local backdoor, no retry) ✅. Red-state confirmed.

### 3. Deletion — incomplete wipe + captain wipe (MED)
**Root cause:** `delete_account` deleted only the user row + auth user, never Storage objects under `scans/{uid}/*` nor the legacy-UUID photo dir; and `squads.captain_id … ON DELETE CASCADE` deleted the **whole squad** when a captain was deleted.
**Fix:** reassign captaincy (oldest remaining member) — or delete sole-member squad — **before** auth-user delete; recursive Storage teardown of live + legacy roots; client now passes `legacy_user_id` and purges both on-disk roots. Additive `deleteAllPhotoRoots` on `StorageService`.
**Files:** `delete_account/handler.ts` (new, DI'd) + `index.ts`, `StorageService.swift` (additive), `StorageServiceProtocol.swift`, `AuthService.swift`, + 2 test files.
**Proof:** 3 deno tests (Proof A: 0 rows + 0 files incl. legacy dir; Proof B: captain deleted → squad survives w/ promoted captain; edge: sole-member squad removed cleanly) ✅; 3 `StorageServicePhotoRootTests` (on-disk wipe + dedupe + no-op) ✅. Red-state confirmed.

---

## Integration (coordinator)

- Merged `fix/ws-a-paywall` → `fix/ws-a-deletion` → `fix/ws-a-migration` into `integ/ws-a`. **Zero conflicts** — the two additive `StorageService.swift` edits auto-merged at different file points.
- Regenerated the project (XcodeGen) so the new test files registered, then ran the **combined** suite on one simulator:
  - Swift: `UserDataMigrationScanResumeTests`, `UserDataMigrationCoordinatorTests`, `StorageServicePhotoRootTests`, `ClaudeClientTests` → **all pass, `** TEST SUCCEEDED **`**
  - Deno (all 4 suites): **25 passed / 0 failed**
- Fast-forwarded `main` to the integration result (`39cbd92`). Removed all worktrees, deleted the merged branches + dedicated simulators + scratch DerivedData. Tree clean.

---

## ⚠️ HUMAN STILL NEEDS TO (before paywall/deletion fixes take effect in prod)

1. **Apply DB migration** `20260528000001_user_is_pro.sql` (adds `users.is_pro`, `users.is_pro_expires_at`).
2. **Set Edge secret** `REVENUECAT_WEBHOOK_SECRET` (`supabase secrets set …`).
3. **Deploy** `revenuecat_webhook` (`--no-verify-jwt`), and redeploy `anthropic_proxy` + `delete_account`.
4. **RevenueCat dashboard:** set webhook URL → `…/functions/v1/revenuecat_webhook` with `Authorization: Bearer <secret>`.
5. **Backfill** `is_pro=true` for existing active subscribers (RC only emits events on new lifecycle changes).
6. Confirm the service role can delete objects in the `scans` Storage bucket (staging check).

## Still LEFT in Category A (deliberately NOT parallelized)

These two rewrite `DatabaseService` core, which every other fix calls — running them in parallel would conflict with everything. **Do them solo, sequentially, in this order:**

- **#3 DB write race (lost updates)** — make `DatabaseService` an actor / add locking. Proof: 100 parallel updates to one doc → 0 lost writes.
- **#5 Sync last-write-wins** — `updated_at`/version merge on pull. Proof: 2 devices edit different fields offline → merged doc keeps both. (Best done after #3.)

## Minor follow-ups flagged by workers (out of scope, not changed)

- `LocalToSupabaseMigration.migrateUserProfile` re-key is best-effort (`try?`) and sits outside the `allCollectionsSucceeded` gate — a failed profile re-key won't block the completion flag.
- Optional hardening: a server-side `delete_account`/`leave_squad` Postgres transaction would close a rare concurrent-leave race already noted in `SquadService`.

---

## Verdict

**3 / 3 parallelizable Category-A groups: DONE with falsifiable proof, integrated to `main`, zero merge conflicts, full combined suite green.** `main` is ahead of `origin` (not pushed). Next: the 2 deferred `DatabaseService` issues, solo.
