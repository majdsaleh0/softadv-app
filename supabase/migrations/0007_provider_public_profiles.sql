-- FR-21 needs public read access to a provider's name/business name. profiles RLS only
-- allows reading your own row, and a row-level policy opening it up would also expose
-- email. This view exposes only the safe columns; owned by the migration role (same
-- owner as profiles), so it bypasses profiles' RLS by design rather than needing anon
-- granted directly on the table.

create view public.provider_public_profiles as
select id, name, business_name, created_at
from public.profiles
where role = 'provider';

grant select on public.provider_public_profiles to anon, authenticated;
