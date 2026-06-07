alter table public.squads
  add column if not exists logo_id text not null default 'forge';

alter table public.squads
  drop constraint if exists squads_logo_id_length;

alter table public.squads
  add constraint squads_logo_id_length
  check (char_length(logo_id) between 1 and 40);
