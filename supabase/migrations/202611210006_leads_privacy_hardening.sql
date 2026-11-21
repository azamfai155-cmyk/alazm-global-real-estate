-- Restrict CRM lead records to company owner and admins.
-- Lead records contain personal contact details and should not be visible
-- to general agents, reviewers, or support roles until scoped CRM access exists.
drop policy if exists leads_staff_read on public.leads;
drop policy if exists leads_staff_insert on public.leads;
drop policy if exists leads_staff_update on public.leads;
drop policy if exists leads_admin_delete on public.leads;

create policy leads_admin_read on public.leads
  for select to authenticated
  using (public.has_any_role(array['owner','admin']::public.app_role[]));

create policy leads_admin_insert on public.leads
  for insert to authenticated
  with check (public.has_any_role(array['owner','admin']::public.app_role[]));

create policy leads_admin_update on public.leads
  for update to authenticated
  using (public.has_any_role(array['owner','admin']::public.app_role[]))
  with check (public.has_any_role(array['owner','admin']::public.app_role[]));

create policy leads_admin_delete on public.leads
  for delete to authenticated
  using (public.has_any_role(array['owner','admin']::public.app_role[]));
