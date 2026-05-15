-- =============================================================================
-- Waitlist table — pre-launch email capture from unboundapp.com landing page.
-- Anon role can INSERT only. No SELECT policy → no enumeration.
-- =============================================================================

create table public.waitlist (
  id          uuid primary key default gen_random_uuid(),
  email       text not null,
  source      text,
  created_at  timestamptz not null default now(),
  unique(email)
);

alter table public.waitlist enable row level security;

create policy "waitlist: anon can insert"
  on public.waitlist for insert
  to anon
  with check (
    email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'
    and (source is null or source in ('hero', 'join'))
  );

create index waitlist_created_at_idx on public.waitlist (created_at desc);
