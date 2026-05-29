-- Server-side atomic field-level merge for the sync spine (WS-A, bug #5 fix).
--
-- Replaces the racy client-side read-merge-write (fetch remote -> overlay
-- changed fields -> push whole row). That pattern was last-write-wins under
-- concurrency: two devices read the same base then both pushed full rows.
--
-- sync_merge_row performs the merge INSIDE Postgres under the row lock taken
-- by `on conflict ... do update`. Concurrent merges that touch DIFFERENT
-- columns of the same row both land: each update sets only its own changed
-- columns from the incoming full row, serialized by the conflict-path lock.
--
-- Contract (called by SupabaseRemoteSync.merge):
--   p_table   : mapped snake_case table name (whitelisted below).
--   p_full    : the FULL document as a jsonb object, snake_cased keys.
--               Carries every NOT NULL column so the INSERT path is valid.
--   p_changed : snake_cased top-level column names this write is authoritative
--               for. On the UPDATE (conflict) path, ONLY these columns are
--               written. Empty/absent => update ALL columns (full upsert).
create or replace function public.sync_merge_row(p_table text, p_full jsonb, p_changed text[])
returns void language plpgsql security definer set search_path = public as $$
declare
  cols text;
  v_uid text := auth.uid()::text;   -- null for service_role / trusted backend calls
  v_owner text;
begin
  -- whitelist: only the synced tables may be merged
  if p_table not in ('workout_logs','programs','progression_state','exercise_preferences','program_blocks','scan_checkpoints','users') then
    raise exception 'sync_merge_row: table % not allowed', p_table;
  end if;
  -- Ownership guard. SECURITY DEFINER bypasses RLS, so without this an
  -- authenticated user could overwrite ANOTHER user's row by passing their id.
  -- For end-user (authenticated) calls the row's owner MUST be the caller.
  -- service_role (v_uid null) is trusted and skips the check.
  if v_uid is not null then
    v_owner := case when p_table = 'users' then p_full->>'id' else p_full->>'user_id' end;
    if v_owner is distinct from v_uid then
      raise exception 'sync_merge_row: ownership mismatch (caller % may not write row owned by %)', v_uid, v_owner;
    end if;
  end if;
  -- build "col = excluded.col" for changed columns that actually exist (excluding id).
  -- empty/absent p_changed => update ALL columns (full upsert semantics; also neutralizes
  -- any caller that enqueues with empty changedFields).
  select string_agg(format('%I = excluded.%I', column_name, column_name), ', ')
    into cols
    from information_schema.columns
    where table_schema='public' and table_name=p_table and column_name <> 'id'
      and (p_changed is null or array_length(p_changed,1) is null or column_name = any(p_changed));
  if cols is null then return; end if; -- nothing to update and row may already exist
  execute format(
    'insert into public.%I select * from jsonb_populate_record(null::public.%I, $1) on conflict (id) do update set %s',
    p_table, p_table, cols
  ) using p_full;
end; $$;

grant execute on function public.sync_merge_row(text, jsonb, text[]) to authenticated, service_role;
