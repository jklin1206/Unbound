-- Raise squad roster cap from 8 to 10.
-- New squads default to 10; existing 8-cap squads are bumped so the new
-- ceiling applies retroactively. join_squad reads squad.max_size, so no
-- edge-function change is needed.

alter table public.squads alter column max_size set default 10;

update public.squads set max_size = 10 where max_size = 8;
