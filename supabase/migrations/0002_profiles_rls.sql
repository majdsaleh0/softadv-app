-- RLS for profiles. See is_admin() for why policies don't self-reference profiles directly
-- (a plain "exists (select ... from profiles ...)" inside a profiles policy triggers
-- "infinite recursion detected in policy for relation profiles").

alter table public.profiles enable row level security;

-- SECURITY DEFINER breaks the recursion: this function's internal SELECT runs as the
-- function owner, bypassing the caller's RLS, so it never re-enters the calling policy.
create or replace function public.is_admin()
returns boolean
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated, service_role;

create policy "profiles_select_own"
on public.profiles for select
to authenticated
using (id = auth.uid());

create policy "profiles_select_admin"
on public.profiles for select
to authenticated
using (public.is_admin());

create policy "profiles_update_own"
on public.profiles for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

create policy "profiles_update_admin"
on public.profiles for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

-- No INSERT policy: rows are only created by handle_new_user() (0001_init_profiles.sql).
-- No DELETE policy: account deletion cascades from auth.users, not exposed to clients.

-- Blocks a user from promoting/unbanning themselves via a plain profile edit
-- (profiles_update_own would otherwise let them set role/status to anything).
-- Scoped to current_setting('role') = 'authenticated' so it only restricts normal
-- end-user requests through PostgREST — migrations, the SQL editor, and service_role
-- (Edge Functions) all run as a different Postgres role and bypass this check, which is
-- also what lets the admin-seed bootstrap step in seed_admin.sql.example work.
create or replace function public.prevent_privilege_escalation()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if current_setting('role', true) = 'authenticated'
     and (new.role is distinct from old.role or new.status is distinct from old.status)
     and not public.is_admin() then
    raise exception 'Only admins can change role or status';
  end if;
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_prevent_privilege_escalation
before update on public.profiles
for each row execute function public.prevent_privilege_escalation();
