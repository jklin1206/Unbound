-- Enriched squad roster: members joined to their display name + handle.
--
-- public.users RLS is owner-only (users_self_read: id = auth.uid()), so a squad
-- member cannot read a co-member's row directly — the client roster therefore
-- shows raw UUIDs. This SECURITY DEFINER function bypasses that RLS in a gated,
-- minimal way:
--   * gate: returns rows ONLY when the CALLER (auth.uid()) is a member of the
--     requested squad, via the existing is_squad_member(user, squad) check. A
--     non-member gets an empty set.
--   * minimal surface: selects ONLY display_name / display_handle from users —
--     never email, handles to private columns, or anything else.
-- This is the standard Supabase pattern for "let squad members see each other's
-- public-ish profile fields without opening up the users table to everyone."

create or replace function public.squad_members_enriched(p_squad_id uuid)
returns table (
  id uuid,
  squad_id uuid,
  user_id uuid,
  joined_at timestamptz,
  display_name text,
  display_handle text
)
language sql
stable
security definer
set search_path to ''
as $$
  select sm.id, sm.squad_id, sm.user_id, sm.joined_at,
         u.display_name, u.display_handle
  from   public.squad_members sm
  join   public.users u on u.id = sm.user_id
  where  sm.squad_id = p_squad_id
    and  public.is_squad_member(auth.uid(), p_squad_id)
  order by sm.joined_at asc;
$$;

-- Only authenticated callers; the membership gate inside does the real check.
revoke all on function public.squad_members_enriched(uuid) from public, anon;
grant execute on function public.squad_members_enriched(uuid) to authenticated;
