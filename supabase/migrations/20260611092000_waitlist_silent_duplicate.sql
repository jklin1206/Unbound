-- Close the waitlist email-presence oracle.
--
-- waitlist has unique(email); a duplicate signup surfaced a unique-violation
-- error to the anon caller, letting anyone probe whether an email is already
-- on the list. A BEFORE INSERT trigger silently skips duplicates instead, so
-- the anon client sees the same generic success either way. The landing-page
-- client contract (plain PostgREST insert) is unchanged.
--
-- SECURITY DEFINER because the anon role has no SELECT policy on waitlist
-- (by design) and the duplicate check needs to read existing rows.
-- The unique(email) constraint stays as a backstop; only a near-simultaneous
-- race of the same email can still surface it, which is not a usable oracle.

create or replace function public.waitlist_skip_duplicate_email()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1 from public.waitlist w
    where lower(w.email) = lower(new.email)
  ) then
    return null; -- skip the insert; caller sees generic success
  end if;
  return new;
end; $$;

create trigger waitlist_skip_duplicate_email
  before insert on public.waitlist
  for each row execute function public.waitlist_skip_duplicate_email();
