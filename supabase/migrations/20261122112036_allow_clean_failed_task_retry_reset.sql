create or replace function public.guard_ai_employee_task_updates()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  actor_role public.app_role;
  is_retry_reset boolean;
begin
  if auth.uid() is null then return new; end if;
  actor_role := private.current_role();
  if new.employee_id is distinct from old.employee_id
     or new.title is distinct from old.title
     or new.instructions is distinct from old.instructions
     or new.input_data is distinct from old.input_data
     or new.priority is distinct from old.priority
     or new.created_by is distinct from old.created_by
     or new.created_at is distinct from old.created_at then
    raise exception 'Task definition and provenance are immutable' using errcode = '42501';
  end if;
  is_retry_reset := old.status = 'failed' and new.status = 'queued'
    and new.result is null and new.error_message is null
    and new.started_at is null and new.completed_at is null;
  if new.result is distinct from old.result
     or new.error_message is distinct from old.error_message
     or new.started_at is distinct from old.started_at
     or new.completed_at is distinct from old.completed_at then
    if not is_retry_reset then
      raise exception 'Execution output and timestamps are server-managed except when resetting a failed task for retry' using errcode = '42501';
    end if;
  end if;
  if (new.reviewed_by is distinct from old.reviewed_by or new.reviewed_at is distinct from old.reviewed_at)
     and actor_role is distinct from 'owner'::public.app_role then
    raise exception 'Only the company owner can record task review' using errcode = '42501';
  end if;
  if new.status is distinct from old.status then
    if actor_role is distinct from 'owner'::public.app_role then
      raise exception 'Only the company owner can change task status' using errcode = '42501';
    end if;
    if not (
      (old.status = 'queued' and new.status = 'cancelled')
      or (old.status = 'needs_review' and new.status in ('completed','cancelled'))
      or (old.status = 'failed' and new.status in ('queued','cancelled'))
    ) then
      raise exception 'Invalid task status transition' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$function$;
