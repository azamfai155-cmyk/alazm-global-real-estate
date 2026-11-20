update public.ai_employees set enabled = true, updated_at = now() where id = 'ceo';
create policy "admins_create_ai_employee_runs"
on public.ai_employee_runs for insert to authenticated
with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.active = true and p.role in ('owner','admin')));
