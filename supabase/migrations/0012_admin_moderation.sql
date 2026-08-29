-- G8 — Admin & Moderation. FR-38..FR-45.
--
-- FR-38 (Admin Login) needs no new schema/auth - an admin is just a profiles row
-- with role='admin' using the same login as everyone else; "logging in as admin"
-- is a client-side nav concern (show the admin dashboard), not a new auth path.
--
-- FR-39/40 (approve/reject, view all listings) and FR-42/43's write side (view/suspend
-- users) already work off is_admin() policies from G1/G2 (profiles_select_admin,
-- profiles_update_admin, listings_select_admin, listings_update_admin). Only the items
-- below are genuinely new.

-- FR-41: admin "remove" must be distinguishable from the provider's own is_active
-- deactivate (FR-13) - a provider whose listing gets pulled for a violation should see
-- that distinctly, not think they did it or hit a bug.
alter table public.listings add column removed_by_admin boolean not null default false;

-- FR-43: suspending a provider must also hide their listings from public browse/search,
-- without touching every listing row (so un-suspending instantly un-hides them again).
alter policy "listings_select_public"
on public.listings
using (
  status = 'approved'
  and is_active
  and not removed_by_admin
  and not exists (select 1 from public.profiles p where p.id = provider_id and p.status = 'suspended')
);

-- FR-44/45: reports. target_id is polymorphic (listings.id or reviews.id depending on
-- target_type) so it can't carry a normal FK - enforced at the application layer instead,
-- same tradeoff as most "report a thing" schemas.
create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles (id),
  target_type text not null check (target_type in ('listing', 'review')),
  target_id uuid not null,
  reason text not null,
  status text not null default 'open' check (status in ('open', 'resolved')),
  resolution text,
  created_at timestamptz not null default now()
);

create index reports_status_idx on public.reports (status);

alter table public.reports enable row level security;

create policy "reports_select_own"
on public.reports for select
to authenticated
using (reporter_id = auth.uid());

create policy "reports_select_admin"
on public.reports for select
to authenticated
using (public.is_admin());

create policy "reports_insert_own"
on public.reports for insert
to authenticated
with check (reporter_id = auth.uid());

-- No update policy for reporters: a report can't be edited after submission, only
-- resolved by an admin.
create policy "reports_update_admin"
on public.reports for update
to authenticated
using (public.is_admin())
with check (public.is_admin());
