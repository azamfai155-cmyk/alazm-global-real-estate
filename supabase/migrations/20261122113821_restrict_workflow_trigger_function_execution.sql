revoke all on function public.sync_ai_workflow_from_task() from public, anon, authenticated;
grant execute on function public.sync_ai_workflow_from_task() to service_role;
