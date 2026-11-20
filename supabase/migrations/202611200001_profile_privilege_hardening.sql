-- Security hardening: prevent admins and ordinary users from changing account roles.
-- Trusted SQL Editor / service-role provisioning remains possible (auth.uid() is NULL).
create or replace function public.guard_profile_privilege_changes()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (new.role is distinct from old.role or new.active is distinct from old.active)
     and auth.uid() is not null
     and public.current_role() is distinct from 'owner'::public.app_role then
    raise exception 'Only the company owner can change profile roles or activation status'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_guard_privilege_changes on public.profiles;
create trigger profiles_guard_privilege_changes
before update on public.profiles
for each row execute function public.guard_profile_privilege_changes();

-- Keep profile updates restricted to authenticated owner/admin accounts.
drop policy if exists profiles_update_admin on public.profiles;
create policy profiles_update_admin on public.profiles
for update to authenticated
using (public.has_any_role(array['owner','admin']::public.app_role[]))
with check (public.has_any_role(array['owner','admin']::public.app_role[]));

-- AI workforce tables remain inaccessible to anon/authenticated clients until
-- a trusted server API and explicit authorization policies are implemented.
alter table public.ai_employees enable row level security;
alter table public.ai_employee_tasks enable row level security;
alter table public.ai_employee_runs enable row level security;
