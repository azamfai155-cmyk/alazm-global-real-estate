-- 20261122012635_restrict_rls_auto_enable_execution.sql
-- The helper is an internal trigger utility. It must not be callable through the
-- public Data API by anon/authenticated clients.
begin;
revoke execute on function public.rls_auto_enable() from public, anon, authenticated;
grant execute on function public.rls_auto_enable() to service_role;
commit;
