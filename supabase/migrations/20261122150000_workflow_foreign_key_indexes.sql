-- Cover foreign-key lookups used by workflow administration and joins.
-- Safe additive indexes; no data or access-policy changes.
create index if not exists ai_workflow_runs_created_by_idx
  on public.ai_workflow_runs (created_by);

create index if not exists ai_workflow_runs_template_id_idx
  on public.ai_workflow_runs (template_id);

create index if not exists ai_workflow_steps_employee_id_idx
  on public.ai_workflow_steps (employee_id);
