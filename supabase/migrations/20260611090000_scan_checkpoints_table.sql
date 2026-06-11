-- scan_checkpoints — the table behind the "scanCheckpoints" sync collection.
--
-- sync_merge_row has whitelisted this table (with a column list) since
-- 20260601080000, but the table itself was never created: every client sync
-- of a scan checkpoint errors at runtime. The client actively writes this
-- collection (RemoteSync.swift maps "scanCheckpoints" → "scan_checkpoints"),
-- so the fix is to create the table, matching the whitelisted columns.
--
-- Column types mirror ScanCheckpoint.swift: BuildIdentity / delta / outcome
-- are Codable structs → jsonb.

create table public.scan_checkpoints (
  id                       uuid primary key default gen_random_uuid(),
  user_id                  uuid not null references public.users(id) on delete cascade,
  created_at               timestamptz not null default now(),
  photo_filename           text not null,
  build_identity_snapshot  jsonb not null,
  narrative                text not null default '',
  delta_from_prior         jsonb,
  checkpoint_outcome       jsonb
);

create index scan_checkpoints_user_created_idx
  on public.scan_checkpoints (user_id, created_at desc);

alter table public.scan_checkpoints enable row level security;

create policy "scan_checkpoints_owner" on public.scan_checkpoints
  for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
