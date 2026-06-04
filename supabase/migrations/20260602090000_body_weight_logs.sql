-- Bodyweight check-ins shown on the home screen.
-- The profile keeps the latest weight_kg; this table keeps the log history.

create table public.body_weight_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  weight_kg double precision not null check (weight_kg > 0),
  logged_at timestamptz not null default now(),
  note text,
  created_at timestamptz not null default now()
);

create index body_weight_logs_user_logged_idx
  on public.body_weight_logs (user_id, logged_at desc);

alter table public.body_weight_logs enable row level security;

create policy "body_weight_logs_owner" on public.body_weight_logs
  for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create or replace function public.sync_merge_row(p_table text, p_full jsonb, p_changed text[])
returns void language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_role text := coalesce(auth.role(), '');
  v_owner_column text;
  v_payload_owner text;
  v_existing_owner text;
  v_id text := p_full->>'id';
  v_writable_columns text[];
  insert_cols text;
  update_cols text;
begin
  if p_table not in (
    'workout_logs',
    'programs',
    'exercise_preferences',
    'program_blocks',
    'scan_checkpoints',
    'body_weight_logs',
    'users'
  ) then
    raise exception 'sync_merge_row: table % not allowed', p_table;
  end if;

  v_owner_column := case when p_table = 'users' then 'id' else 'user_id' end;
  v_writable_columns := case p_table
    when 'users' then array[
      'id',
      'email',
      'display_name',
      'display_handle',
      'created_at',
      'updated_at',
      'onboarding_completed',
      'total_scans',
      'current_program_id',
      'preferred_archetype',
      'height_cm',
      'weight_kg',
      'age',
      'biological_sex',
      'gender',
      'motivations',
      'goals',
      'target_areas',
      'obstacles',
      'experience',
      'current_frequency',
      'target_frequency',
      'workout_time',
      'equipment',
      'exercise_styles',
      'session_length',
      'prior_attempts',
      'diet_quality',
      'sleep_quality',
      'stress_level',
      'commitment',
      'current_body_type',
      'training_feedback_mode',
      'training_style_override',
      'training_days',
      'cut_mode'
    ]
    when 'workout_logs' then array[
      'id',
      'user_id',
      'program_id',
      'day_number',
      'planned_workout_name',
      'started_at',
      'completed_at',
      'duration_minutes',
      'local_start_hour',
      'overall_rpe',
      'overall_notes',
      'exercise_entries'
    ]
    when 'programs' then array[
      'id',
      'user_id',
      'scan_id',
      'analysis_id',
      'created_at',
      'archetype',
      'name',
      'description',
      'duration_days',
      'difficulty_level',
      'required_equipment',
      'estimated_daily_minutes',
      'days',
      'nutrition_plan',
      'recovery_plan'
    ]
    when 'exercise_preferences' then array[
      'id',
      'user_id',
      'exercise_name',
      'display_name',
      'status',
      'muscle_groups',
      'substitute_preference',
      'notes',
      'updated_at'
    ]
    when 'program_blocks' then array[
      'id',
      'user_id',
      'program_id',
      'block_number',
      'started_at',
      'ended_at',
      'scan_id',
      'accessory_bias',
      'cut_mode_active',
      'bias_refreshed_from_previous',
      'exercise_rotations_this_block',
      'created_at'
    ]
    when 'scan_checkpoints' then array[
      'id',
      'user_id',
      'created_at',
      'photo_filename',
      'build_identity_snapshot',
      'narrative',
      'delta_from_prior',
      'checkpoint_outcome'
    ]
    when 'body_weight_logs' then array[
      'id',
      'user_id',
      'weight_kg',
      'logged_at',
      'note',
      'created_at'
    ]
    else array[]::text[]
  end;

  if v_role <> 'service_role' then
    if v_uid is null then
      raise exception 'sync_merge_row: authenticated caller required';
    end if;

    v_payload_owner := p_full->>v_owner_column;
    if v_payload_owner is distinct from v_uid::text then
      raise exception 'sync_merge_row: ownership mismatch (caller % may not write row owned by %)',
        v_uid, v_payload_owner;
    end if;

    if v_id is null or btrim(v_id) = '' then
      raise exception 'sync_merge_row: id is required';
    end if;

    execute format('select %I::text from public.%I where id::text = $1', v_owner_column, p_table)
      into v_existing_owner
      using v_id;

    if v_existing_owner is not null and v_existing_owner is distinct from v_uid::text then
      raise exception 'sync_merge_row: existing row owner % does not match caller %',
        v_existing_owner, v_uid;
    end if;
  end if;

  select string_agg(format('%I', key), ', ')
    into insert_cols
    from jsonb_object_keys(p_full) as key
    where key in (
      select column_name from information_schema.columns
      where table_schema = 'public' and table_name = p_table
    )
      and (v_role = 'service_role' or key = any(v_writable_columns));
  if insert_cols is null then return; end if;

  select string_agg(format('%I = excluded.%I', col, col), ', ')
    into update_cols
    from (
      select c.column_name as col
      from information_schema.columns c
      where c.table_schema = 'public' and c.table_name = p_table
        and c.column_name <> 'id'
        and (v_role = 'service_role' or c.column_name <> v_owner_column)
        and (v_role = 'service_role' or c.column_name = any(v_writable_columns))
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

revoke all on function public.sync_merge_row(text, jsonb, text[]) from public;
revoke all on function public.sync_merge_row(text, jsonb, text[]) from anon;
grant execute on function public.sync_merge_row(text, jsonb, text[]) to authenticated, service_role;
