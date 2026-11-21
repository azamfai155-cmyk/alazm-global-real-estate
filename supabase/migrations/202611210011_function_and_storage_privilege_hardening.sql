-- 202611210011_function_and_storage_privilege_hardening.sql
-- Harden company RPC/trigger function execution and keep Storage unavailable
-- until explicit buckets and least-privilege policies are designed.
-- Does not modify Supabase-managed roles or Storage schema default privileges.

begin;

-- Remove implicit PUBLIC execution from application-owned functions.
revoke execute on function public.current_role() from public, anon;
revoke execute on function public.has_any_role(public.app_role[]) from public, anon;
revoke execute on function public.touch_updated_at() from public, anon, authenticated;
revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.guard_profile_privilege_changes() from public, anon, authenticated;
revoke execute on function public.guard_ai_employee_task_updates() from public, anon, authenticated;
revoke execute on function public.guard_property_publication() from public, anon, authenticated;
revoke execute on function public.guard_property_media_rights() from public, anon, authenticated;

-- RLS policies call these helpers as the authenticated database role.
grant execute on function public.current_role() to authenticated;
grant execute on function public.has_any_role(public.app_role[]) to authenticated;

-- Prevent future tables/sequences/functions created by postgres in public
-- from automatically receiving client-role privileges.
alter default privileges for role postgres in schema public
  revoke all privileges on tables from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke all privileges on sequences from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke execute on functions from public, anon, authenticated;

-- No Storage buckets currently exist. Disable direct client SQL access to
-- the Storage metadata tables until an explicit bucket/policy design is approved.
revoke all privileges on table storage.buckets from anon, authenticated;
revoke all privileges on table storage.objects from anon, authenticated;

commit;
