-- Admin-only cloud access for AI employee definitions and task management.
-- AI execution remains backend-only; this migration does not activate agents.
create policy "admins_read_ai_employees"
on public.ai_employees for select to authenticated
using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.active = true and p.role in ('owner','admin')));

create policy "admins_read_ai_employee_tasks"
on public.ai_employee_tasks for select to authenticated
using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.active = true and p.role in ('owner','admin')));

create policy "admins_create_ai_employee_tasks"
on public.ai_employee_tasks for insert to authenticated
with check (
  created_by = auth.uid()
  and exists (select 1 from public.profiles p where p.id = auth.uid() and p.active = true and p.role in ('owner','admin'))
);

create policy "admins_update_ai_employee_tasks"
on public.ai_employee_tasks for update to authenticated
using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.active = true and p.role in ('owner','admin')))
with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.active = true and p.role in ('owner','admin')));

create policy "admins_read_ai_employee_runs"
on public.ai_employee_runs for select to authenticated
using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.active = true and p.role in ('owner','admin')));
