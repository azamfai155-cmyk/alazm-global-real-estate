create or replace function public.approve_ai_property_workflow_step(
  p_actor_id uuid,
  p_task_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_profile public.profiles%rowtype;
  v_task public.ai_employee_tasks%rowtype;
  v_workflow_id uuid;
  v_run public.ai_workflow_runs%rowtype;
begin
  select * into v_profile from public.profiles
  where id = p_actor_id and active = true;
  if not found or v_profile.role <> 'owner'::public.app_role then
    raise exception 'Only an active company owner can approve workflow steps' using errcode = '42501';
  end if;

  select * into v_task from public.ai_employee_tasks where id = p_task_id for update;
  if not found or v_task.status <> 'needs_review'
     or jsonb_typeof(v_task.result) <> 'object'
     or coalesce(v_task.result->>'report','') = ''
     or coalesce((v_task.result->>'requires_human_approval')::boolean, false) is not true then
    raise exception 'Task has no complete report awaiting owner review' using errcode = '22023';
  end if;

  v_workflow_id := nullif(v_task.input_data->>'workflow_id','')::uuid;
  -- The existing sync_ai_workflow_from_task trigger owns sequential workflow advancement.
  -- This RPC only performs the guarded owner approval; the trigger advances exactly once.
  update public.ai_employee_tasks
  set status = 'completed', reviewed_by = p_actor_id, reviewed_at = pg_catalog.now()
  where id = p_task_id;

  if v_workflow_id is null then
    return pg_catalog.jsonb_build_object('status','completed','workflow_advanced',false);
  end if;

  select * into v_run from public.ai_workflow_runs where id = v_workflow_id;
  if not found then raise exception 'Workflow record missing after task approval' using errcode = '22023'; end if;

  return pg_catalog.jsonb_build_object(
    'status',v_run.status,'workflow_advanced',true,
    'workflow_id',v_workflow_id,'current_step',v_run.current_step
  );
end;
$function$;

revoke all on function public.approve_ai_property_workflow_step(uuid,uuid) from public, anon, authenticated;
grant execute on function public.approve_ai_property_workflow_step(uuid,uuid) to service_role;
