-- G5 — Reviews & Ratings. FR-29..FR-32. DR-05: only after a booking is 'completed'.
--
-- Unlike bookings' multi-step state machine, review mutations are single-shot RLS
-- checks (does this booking belong to me and is it completed?) so this stays in
-- RLS/triggers rather than an Edge Function, matching the pattern from G1-G3.

create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.bookings (id),
  customer_id uuid not null references public.profiles (id),
  rating smallint not null check (rating between 1 and 5),
  comment text,
  provider_reply text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.reviews enable row level security;

-- select ----------------------------------------------------------------------

create policy "reviews_select_public"
on public.reviews for select
to anon, authenticated
using (
  exists (
    select 1 from public.bookings b
    join public.listings l on l.id = b.listing_id
    where b.id = booking_id and l.status = 'approved' and l.is_active
  )
);

create policy "reviews_select_own"
on public.reviews for select
to authenticated
using (customer_id = auth.uid());

create policy "reviews_select_provider"
on public.reviews for select
to authenticated
using (
  exists (
    select 1 from public.bookings b
    join public.listings l on l.id = b.listing_id
    where b.id = booking_id and l.provider_id = auth.uid()
  )
);

create policy "reviews_select_admin"
on public.reviews for select
to authenticated
using (public.is_admin());

-- insert (FR-29, DR-05) --------------------------------------------------------

create policy "reviews_insert_own"
on public.reviews for insert
to authenticated
with check (
  customer_id = auth.uid()
  and exists (select 1 from public.bookings b where b.id = booking_id and b.customer_id = auth.uid() and b.status = 'completed')
);

-- update: customer edits rating/comment (FR-30), provider sets provider_reply (FR-32) --

create policy "reviews_update_customer"
on public.reviews for update
to authenticated
using (customer_id = auth.uid())
with check (customer_id = auth.uid());

create policy "reviews_update_provider"
on public.reviews for update
to authenticated
using (exists (select 1 from public.bookings b join public.listings l on l.id = b.listing_id where b.id = booking_id and l.provider_id = auth.uid()))
with check (exists (select 1 from public.bookings b join public.listings l on l.id = b.listing_id where b.id = booking_id and l.provider_id = auth.uid()));

create policy "reviews_update_admin"
on public.reviews for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

-- RLS can't restrict individual columns, so a trigger keeps the customer out of
-- provider_reply and the provider out of everything except provider_reply.
create or replace function public.prevent_review_field_tampering()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_is_customer boolean := auth.uid() = old.customer_id;
begin
  if current_setting('role', true) = 'authenticated' and not public.is_admin() then
    if v_is_customer then
      if new.provider_reply is distinct from old.provider_reply then
        raise exception 'Only the listing''s provider can set provider_reply';
      end if;
    else
      if new.rating is distinct from old.rating
         or new.comment is distinct from old.comment
         or new.customer_id is distinct from old.customer_id
         or new.booking_id is distinct from old.booking_id then
        raise exception 'Only the review''s author can edit the rating or comment';
      end if;
    end if;
  end if;
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_prevent_review_field_tampering
before update on public.reviews
for each row execute function public.prevent_review_field_tampering();

-- delete (FR-31) ----------------------------------------------------------------

create policy "reviews_delete_own"
on public.reviews for delete
to authenticated
using (customer_id = auth.uid());

create policy "reviews_delete_admin"
on public.reviews for delete
to authenticated
using (public.is_admin());

-- Keeps listings.avg_rating/review_count (added in G3, migration 0006) in sync.
create or replace function public.sync_listing_rating()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_booking_id uuid := coalesce(new.booking_id, old.booking_id);
  v_listing_id uuid;
begin
  select listing_id into v_listing_id from public.bookings where id = v_booking_id;

  update public.listings l
  set avg_rating = agg.avg_rating, review_count = agg.review_count
  from (
    select round(avg(r.rating)::numeric, 1) as avg_rating, count(*) as review_count
    from public.reviews r
    join public.bookings b on b.id = r.booking_id
    where b.listing_id = v_listing_id
  ) agg
  where l.id = v_listing_id;

  return coalesce(new, old);
end;
$$;

create trigger trg_sync_listing_rating
after insert or update of rating or delete on public.reviews
for each row execute function public.sync_listing_rating();
