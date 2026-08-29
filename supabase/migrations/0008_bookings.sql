-- G4 — Booking Management. FR-22..FR-28.
--
-- Unlike listings/profiles (a single admin-controlled status flag), bookings have a
-- multi-actor state machine (provider accepts/rejects; either party cancels; provider
-- completes) with side effects (notifications, later). Per CLAUDE.md's stack section,
-- that logic belongs in Edge Functions, not client-side RLS/triggers - so this table
-- is RLS-readable but has NO insert/update policies for regular users at all. All
-- writes go through supabase/functions/{create-booking,respond-to-booking,booking-lifecycle}
-- using the service role, which bypasses RLS by design.

create table public.bookings (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings (id),
  customer_id uuid not null references public.profiles (id),
  provider_id uuid not null references public.profiles (id),
  time_slot_id uuid not null references public.listing_time_slots (id),
  date date not null,
  status text not null default 'requested' check (status in ('requested', 'accepted', 'rejected', 'completed', 'cancelled')),
  reject_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.bookings is
  'provider_id is denormalized from listings.provider_id at creation time, so RLS/queries '
  'for "my incoming bookings" don''t need a join to listings.';

create index bookings_customer_id_idx on public.bookings (customer_id);
create index bookings_provider_id_idx on public.bookings (provider_id);
create index bookings_listing_id_idx on public.bookings (listing_id);

alter table public.bookings enable row level security;

create policy "bookings_select_customer"
on public.bookings for select
to authenticated
using (customer_id = auth.uid());

create policy "bookings_select_provider"
on public.bookings for select
to authenticated
using (provider_id = auth.uid());

create policy "bookings_select_admin"
on public.bookings for select
to authenticated
using (public.is_admin());

-- No insert/update/delete policies: writes only via Edge Functions (service role).
