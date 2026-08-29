-- G3 needs rating filter/sort/display (FR-18, FR-19, FR-21), but reviews can't exist
-- until G5 (DR-05 ties them to completed bookings, which needs G4). Denormalized here
-- so G3 works today (everything just shows "no ratings yet") and G5 only needs to
-- populate these via a trigger, not add a migration.

alter table public.listings
  add column avg_rating numeric(2, 1),
  add column review_count integer not null default 0;

comment on column public.listings.avg_rating is 'Denormalized average rating; null until G5 populates it from reviews.';
