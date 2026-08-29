-- Dev-only convenience: promotes the E2E-walkthrough test account to admin. Not a
-- schema change - same one-off purpose as seed_admin.sql.example, applied via
-- migration only because this session has no interactive SQL editor access.
-- Safe no-op if the account doesn't exist in a given environment.

update public.profiles
set role = 'admin', status = 'active'
where email = 'e2e.admin.20260824@gmail.com';
