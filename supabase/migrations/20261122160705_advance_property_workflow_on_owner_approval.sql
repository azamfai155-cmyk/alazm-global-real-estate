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
  v_workflow public.ai_workflow_runs%rowtype;
  v_current_step public.ai_workflow_steps%rowtype;
  v_next_step public.ai_workflow_steps%rowtype;
  v_next_task_id uuid;
  v_previous_results jsonb;
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
  if v_workflow_id is null then
    update public.ai_employee_tasks
    set status = 'completed', reviewed_by = p_actor_id, reviewed_at = pg_catalog.now()
    where id = p_task_id;
    return pg_catalog.jsonb_build_object('status','completed','workflow_advanced',false);
  end if;

  select * into v_workflow from public.ai_workflow_runs where id = v_workflow_id for update;
  if not found or v_workflow.status <> 'active' then
    raise exception 'Workflow is missing or not active' using errcode = '22023';
  end if;

  select * into v_current_step from public.ai_workflow_steps
  where workflow_id = v_workflow_id and task_id = p_task_id for update;
  if not found or v_current_step.status not in ('queued','running','needs_review') then
    raise exception 'Workflow step is not awaiting review' using errcode = '22023';
  end if;

  update public.ai_employee_tasks
  set status = 'completed', reviewed_by = p_actor_id, reviewed_at = pg_catalog.now()
  where id = p_task_id;
  update public.ai_workflow_steps
  set status = 'completed', result = v_task.result, completed_at = pg_catalog.now()
  where id = v_current_step.id;

  select * into v_next_step from public.ai_workflow_steps
  where workflow_id = v_workflow_id and step_order > v_current_step.step_order and status = 'blocked'
  order by step_order limit 1 for update;

  if not found then
    update public.ai_workflow_runs
    set status = 'completed', current_step = v_current_step.step_order,
        completed_at = pg_catalog.now(), updated_at = pg_catalog.now()
    where id = v_workflow_id;
    return pg_catalog.jsonb_build_object('status','completed','workflow_advanced',true,
      'workflow_id',v_workflow_id,'completed_step',v_current_step.step_order);
  end if;

  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'step_order',s.step_order,'employee_id',s.employee_id,'title',s.title,'result',s.result
  ) order by s.step_order), '[]'::jsonb)
  into v_previous_results
  from public.ai_workflow_steps s
  where s.workflow_id = v_workflow_id and s.status = 'completed';

  insert into public.ai_employee_tasks(employee_id,title,instructions,input_data,priority,status,created_by)
  values(v_next_step.employee_id,v_next_step.title,v_next_step.instructions,
    pg_catalog.jsonb_build_object('workflow_id',v_workflow_id,'workflow_step',v_next_step.step_order,
      'source_payload',v_workflow.source_payload,'previous_steps',v_previous_results),
    'normal','queued',p_actor_id)
  returning id into v_next_task_id;

  update public.ai_workflow_steps set status = 'queued', task_id = v_next_task_id where id = v_next_step.id;
  update public.ai_workflow_runs set status = 'active', current_step = v_next_step.step_order,
    updated_at = pg_catalog.now() where id = v_workflow_id;

  return pg_catalog.jsonb_build_object('status','active','workflow_advanced',true,
    'workflow_id',v_workflow_id,'completed_step',v_current_step.step_order,
    'next_step',v_next_step.step_order,'next_task_id',v_next_task_id);
end;
$function$;

revoke all on function public.approve_ai_property_workflow_step(uuid,uuid) from public, anon, authenticated;
grant execute on function public.approve_ai_property_workflow_step(uuid,uuid) to service_role;
