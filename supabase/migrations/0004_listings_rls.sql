-- RLS for listings + child tables. Same is_admin()/privilege-escalation pattern as
-- profiles (0002_profiles_rls.sql).

alter table public.listings enable row level security;
alter table public.listing_images enable row level security;
alter table public.listing_time_slots enable row level security;

-- listings ------------------------------------------------------------------

create policy "listings_select_public"
on public.listings for select
to anon, authenticated
using (status = 'approved' and is_active);

create policy "listings_select_own"
on public.listings for select
to authenticated
using (provider_id = auth.uid());

create policy "listings_select_admin"
on public.listings for select
to authenticated
using (public.is_admin());

create policy "listings_insert_own"
on public.listings for insert
to authenticated
with check (
  provider_id = auth.uid()
  and status = 'pending'
  and exists (select 1 from public.profiles where id = auth.uid() and role = 'provider')
);

create policy "listings_update_own"
on public.listings for update
to authenticated
using (provider_id = auth.uid())
with check (provider_id = auth.uid());

create policy "listings_update_admin"
on public.listings for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

-- No DELETE policy: FR-13 "delete/deactivate" is is_active = false (soft delete).

-- Mirrors prevent_privilege_escalation on profiles: a provider can edit their own
-- listing but can't self-approve/reject.
-- TODO(G4): also block is_active flipping to false while active bookings exist
-- (FR-13's "blocked while active bookings exist" clause) once bookings exists.
create or replace function public.prevent_listing_status_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if current_setting('role', true) = 'authenticated'
     and new.status is distinct from old.status
     and not public.is_admin() then
    raise exception 'Only admins can change listing status';
  end if;
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_prevent_listing_status_change
before update on public.listings
for each row execute function public.prevent_listing_status_change();

-- listing_images --------------------------------------------------------------

create policy "listing_images_select"
on public.listing_images for select
to anon, authenticated
using (
  exists (
    select 1 from public.listings l
    where l.id = listing_id
      and (
        (l.status = 'approved' and l.is_active)
        or l.provider_id = auth.uid()
        or public.is_admin()
      )
  )
);

create policy "listing_images_write_own"
on public.listing_images for all
to authenticated
using (exists (select 1 from public.listings l where l.id = listing_id and l.provider_id = auth.uid()))
with check (exists (select 1 from public.listings l where l.id = listing_id and l.provider_id = auth.uid()));

-- listing_time_slots ------------------------------------------------------------

create policy "listing_time_slots_select"
on public.listing_time_slots for select
to anon, authenticated
using (
  exists (
    select 1 from public.listings l
    where l.id = listing_id
      and (
        (l.status = 'approved' and l.is_active)
        or l.provider_id = auth.uid()
        or public.is_admin()
      )
  )
);

create policy "listing_time_slots_write_own"
on public.listing_time_slots for all
to authenticated
using (exists (select 1 from public.listings l where l.id = listing_id and l.provider_id = auth.uid()))
with check (exists (select 1 from public.listings l where l.id = listing_id and l.provider_id = auth.uid()));
