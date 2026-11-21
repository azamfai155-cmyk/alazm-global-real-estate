-- Server-only protection for AI task outputs and execution metadata.
-- The service-role backend bypasses RLS and has auth.uid() = NULL; authenticated
-- browser sessions cannot forge model results, execution timestamps, or run logs.

drop policy if exists "admins_create_ai_employee_runs" on public.ai_employee_runs;

create or replace function public.guard_ai_employee_task_updates()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  actor_role public.app_role;
begin
  -- Trusted server/service-role maintenance is allowed; never expose the service key.
  if auth.uid() is null then
    return new;
  end if;

  actor_role := public.current_role();

  if new.employee_id is distinct from old.employee_id
     or new.title is distinct from old.title
     or new.instructions is distinct from old.instructions
     or new.input_data is distinct from old.input_data
     or new.priority is distinct from old.priority
     or new.created_by is distinct from old.created_by
     or new.created_at is distinct from old.created_at then
    raise exception 'Task definition and provenance are immutable'
      using errcode = '42501';
  end if;

  -- Only the trusted backend may write model output and execution metadata.
  if new.result is distinct from old.result
     or new.error_message is distinct from old.error_message
     or new.started_at is distinct from old.started_at
     or new.completed_at is distinct from old.completed_at then
    raise exception 'Execution output and timestamps are server-managed'
      using errcode = '42501';
  end if;

  if (new.reviewed_by is distinct from old.reviewed_by
      or new.reviewed_at is distinct from old.reviewed_at
      or (new.status in ('completed','cancelled') and new.status is distinct from old.status))
     and actor_role is distinct from 'owner'::public.app_role then
    raise exception 'Only the company owner can approve, complete, cancel, or review tasks'
      using errcode = '42501';
  end if;

  if old.status in ('needs_review','completed','cancelled','failed')
     and new.status in ('queued','running')
     and actor_role is distinct from 'owner'::public.app_role then
    raise exception 'Only the company owner can reopen a task'
      using errcode = '42501';
  end if;

  return new;
end;
$$;
