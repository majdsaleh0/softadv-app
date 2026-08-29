-- Milestone 2 (G2 — Business Listing Management): listings + related tables. FR-07..FR-13.

create table public.listings (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.profiles (id) on delete cascade,
  title text not null,
  description text not null,
  category text not null check (category in ('home_repair', 'tutoring', 'cleaning', 'beauty', 'other')),
  location text not null,
  price numeric(10, 2) not null check (price >= 0),
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.listings is
  'status is admin-controlled (DR-07, FR-39). is_active is provider-controlled (FR-13 delete/deactivate) '
  '- soft delete, not a hard row delete, so listing history survives.';

create index listings_provider_id_idx on public.listings (provider_id);
create index listings_status_idx on public.listings (status) where status = 'approved';
create index listings_category_idx on public.listings (category);

create table public.listing_images (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings (id) on delete cascade,
  storage_path text not null,
  sort_order smallint not null default 0,
  created_at timestamptz not null default now()
);

create index listing_images_listing_id_idx on public.listing_images (listing_id);

-- Recurring weekly availability (FR-11). Structured, not jsonb, because G4's booking
-- request flow (FR-22) needs to query slot availability directly against this table.
create table public.listing_time_slots (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings (id) on delete cascade,
  day_of_week smallint not null check (day_of_week between 0 and 6),
  start_time time not null,
  end_time time not null check (end_time > start_time),
  created_at timestamptz not null default now()
);

create index listing_time_slots_listing_id_idx on public.listing_time_slots (listing_id);
