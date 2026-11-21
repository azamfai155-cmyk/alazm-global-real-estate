-- 202611210010_minimum_table_privileges.sql
-- Reduce SQL privileges to the minimum required; RLS continues to enforce row-level access.
-- In particular, remove TRUNCATE, TRIGGER and REFERENCES from client roles.
begin;

revoke all privileges on all tables in schema public from anon, authenticated;

-- Anonymous visitors may only read published property rows (RLS policy applies).
grant select on table public.properties to anon;

-- Authenticated users receive only the operations represented by the existing RLS policies.
grant select, update on table public.profiles to authenticated;
grant select, insert, update, delete on table public.sources to authenticated;
grant select, insert, update, delete on table public.properties to authenticated;
grant select, insert, delete on table public.property_media to authenticated;
grant select, insert, update, delete on table public.leads to authenticated;
grant select on table public.audit_logs to authenticated;
grant select on table public.ai_employees to authenticated;
grant select, insert, update on table public.ai_employee_tasks to authenticated;
grant select on table public.ai_employee_runs to authenticated;

-- Do not change service_role privileges; backend service operations remain server-side.
commit;
