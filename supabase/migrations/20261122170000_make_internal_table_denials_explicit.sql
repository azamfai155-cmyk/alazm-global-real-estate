-- Make fail-closed client access explicit on internal workflow and rate-limit tables.
-- service_role and the function owner bypass RLS as designed; browser roles remain denied.
create policy deny_client_access_to_workflow_runs
  on public.ai_workflow_runs
  for all to public
  using (false)
  with check (false);

create policy deny_client_access_to_workflow_steps
  on public.ai_workflow_steps
  for all to public
  using (false)
  with check (false);

create policy deny_client_access_to_workflow_templates
  on public.ai_workflow_templates
  for all to public
  using (false)
  with check (false);

create policy deny_client_access_to_lead_rate_limits
  on private.lead_submission_rate_limits
  for all to public
  using (false)
  with check (false);
