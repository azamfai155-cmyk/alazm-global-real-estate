-- Enforce legal task status transitions for authenticated browser clients.
-- Trusted backend/service-role calls bypass RLS and have auth.uid() = NULL.
create or replace function public.guard_ai_employee_task_updates()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  actor_role public.app_role;
begin
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

  if new.result is distinct from old.result
     or new.error_message is distinct from old.error_message
     or new.started_at is distinct from old.started_at
     or new.completed_at is distinct from old.completed_at then
    raise exception 'Execution output and timestamps are server-managed'
      using errcode = '42501';
  end if;

  if (new.reviewed_by is distinct from old.reviewed_by
      or new.reviewed_at is distinct from old.reviewed_at)
     and actor_role is distinct from 'owner'::public.app_role then
    raise exception 'Only the company owner can record task review'
      using errcode = '42501';
  end if;

  if new.status is distinct from old.status then
    if actor_role is distinct from 'owner'::public.app_role then
      raise exception 'Only the company owner can change task status'
        using errcode = '42501';
    end if;

    if not (
      (old.status = 'queued' and new.status = 'cancelled')
      or (old.status = 'needs_review' and new.status in ('completed','cancelled'))
      or (old.status = 'failed' and new.status in ('queued','cancelled'))
    ) then
      raise exception 'Invalid task status transition'
        using errcode = '42501';
    end if;
  end if;

  return new;
end;
$$;
