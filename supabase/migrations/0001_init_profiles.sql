-- Milestone 1 (G1 — User Management): profiles table + auto-provisioning trigger.

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  name text not null,
  email text not null unique,
  role text not null check (role in ('customer', 'provider', 'admin')),
  business_name text,
  status text not null default 'active' check (status in ('pending', 'active', 'suspended')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.profiles is
  'One row per auth.users row. Rows are created only by handle_new_user() below, never inserted directly by clients.';

create index profiles_role_idx on public.profiles (role);

-- Provisions a profiles row whenever a new auth.users row is created.
-- Reads role/name/business_name out of the signUp() metadata payload from the client.
-- Providers start status='pending' per DR-07 (require admin approval before appearing publicly).
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_role text := coalesce(new.raw_user_meta_data ->> 'role', 'customer');
begin
  insert into public.profiles (id, name, email, role, business_name, status)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'name', ''),
    new.email,
    v_role,
    new.raw_user_meta_data ->> 'business_name',
    case when v_role = 'provider' then 'pending' else 'active' end
  );
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();
