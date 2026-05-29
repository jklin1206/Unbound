-- Fix for sync_merge_row (20260528000002): the INSERT path used
-- `jsonb_populate_record(null::tbl, p_full)` which materializes EVERY column,
-- setting columns absent from the client payload (e.g. updated_at NOT NULL
-- DEFAULT now()) to an explicit NULL — defeating the column DEFAULT and
-- violating NOT NULL on insert of any new row. Caught by a live merge test.
--
-- Corrected: INSERT only the columns actually present in p_full (so omitted
-- columns with defaults fall back to their DEFAULT); UPDATE only the changed
-- columns on conflict. Ownership guard + table whitelist unchanged.
create or replace function public.sync_merge_row(p_table text, p_full jsonb, p_changed text[])
returns void language plpgsql security definer set search_path = public as $$
declare
  v_uid text := auth.uid()::text;   -- null for service_role / trusted backend calls
  v_owner text;
  insert_cols text;
  update_cols text;
begin
  -- whitelist: only the synced tables may be merged
  if p_table not in ('workout_logs','programs','progression_state','exercise_preferences','program_blocks','scan_checkpoints','users') then
    raise exception 'sync_merge_row: table % not allowed', p_table;
  end if;

  -- Ownership guard: SECURITY DEFINER bypasses RLS, so for end-user
  -- (authenticated) calls the row owner MUST be the caller. service_role
  -- (v_uid null) is trusted and skips the check.
  if v_uid is not null then
    v_owner := case when p_table = 'users' then p_full->>'id' else p_full->>'user_id' end;
    if v_owner is distinct from v_uid then
      raise exception 'sync_merge_row: ownership mismatch (caller % may not write row owned by %)', v_uid, v_owner;
    end if;
  end if;

  -- INSERT only columns present in the payload AND real on the table, so
  -- omitted defaulted columns get their DEFAULT (not an explicit NULL).
  select string_agg(format('%I', key), ', ')
    into insert_cols
    from jsonb_object_keys(p_full) as key
    where key in (select column_name from information_schema.columns
                  where table_schema = 'public' and table_name = p_table);
  if insert_cols is null then return; end if;

  -- UPDATE only changed columns (excluding id), restricted to columns present
  -- in the payload. Empty/absent p_changed => all payload columns except id.
  select string_agg(format('%I = excluded.%I', col, col), ', ')
    into update_cols
    from (
      select c.column_name as col
      from information_schema.columns c
      where c.table_schema = 'public' and c.table_name = p_table
        and c.column_name <> 'id'
        and c.column_name in (select jsonb_object_keys(p_full))
        and (p_changed is null or array_length(p_changed, 1) is null or c.column_name = any(p_changed))
    ) s;

  if update_cols is null then
    execute format(
      'insert into public.%I (%s) select %s from jsonb_populate_record(null::public.%I, $1) on conflict (id) do nothing',
      p_table, insert_cols, insert_cols, p_table
    ) using p_full;
  else
    execute format(
      'insert into public.%I (%s) select %s from jsonb_populate_record(null::public.%I, $1) on conflict (id) do update set %s',
      p_table, insert_cols, insert_cols, p_table, update_cols
    ) using p_full;
  end if;
end; $$;

grant execute on function public.sync_merge_row(text, jsonb, text[]) to authenticated, service_role;
