-- Store exact preferred workout time selected during onboarding.
alter table public.users
    add column if not exists workout_minute_of_day integer;

grant insert (workout_minute_of_day) on table public.users to authenticated;
grant update (workout_minute_of_day) on table public.users to authenticated;

comment on column public.users.workout_minute_of_day is
    'Preferred workout time as minutes after midnight, selected during onboarding.';
