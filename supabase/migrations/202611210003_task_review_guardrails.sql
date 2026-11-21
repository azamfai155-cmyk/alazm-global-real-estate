-- Tighten AI task review authority without interrupting the CEO pilot.
-- Admins may operate the pilot queue, but only the company owner may approve,
-- complete, cancel, or mark a task as reviewed.
create or replace function public.guard_ai_employee_task_updates()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  actor_role public.app_role;
begin
  -- Trusted SQL/service maintenance is handled outside authenticated client sessions.
  if auth.uid() is null then
    return new;
  end if;

  actor_role := public.current_role();

  -- Task definition and provenance are immutable after creation from the client.
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

  -- Only the active owner can record a human review or final decision.
  if (new.reviewed_by is distinct from old.reviewed_by
      or new.reviewed_at is distinct from old.reviewed_at
      or new.status in ('completed','cancelled') and new.status is distinct from old.status)
     and actor_role is distinct from 'owner'::public.app_role then
    raise exception 'Only the company owner can approve, complete, cancel, or review tasks'
      using errcode = '42501';
  end if;

  -- A client cannot rewrite a finished/reviewed task back into the execution queue.
  if old.status in ('needs_review','completed','cancelled','failed')
     and new.status in ('queued','running')
     and actor_role is distinct from 'owner'::public.app_role then
    raise exception 'Only the company owner can reopen a task'
      using errcode = '42501';
  end if;

  return new;
end;
$$;

drop trigger if exists ai_employee_tasks_review_guard on public.ai_employee_tasks;
create trigger ai_employee_tasks_review_guard
before update on public.ai_employee_tasks
for each row execute function public.guard_ai_employee_task_updates();
