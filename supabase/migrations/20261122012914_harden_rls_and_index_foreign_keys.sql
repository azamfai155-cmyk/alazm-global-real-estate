-- 20261122012914_harden_rls_and_index_foreign_keys.sql
-- Reproducible representation of the hardening already applied to production.
-- Keep these statements idempotent so new environments converge safely.
begin;

alter table public.ai_employee_runs enable row level security;
alter table public.ai_employee_tasks enable row level security;
alter table public.ai_employees enable row level security;
alter table public.audit_logs enable row level security;
alter table public.leads enable row level security;
alter table public.profiles enable row level security;
alter table public.properties enable row level security;
alter table public.property_media enable row level security;
alter table public.sources enable row level security;

create index if not exists ai_employee_runs_employee_id_idx on public.ai_employee_runs (employee_id);
create index if not exists ai_employee_runs_task_idx on public.ai_employee_runs (task_id, created_at desc);
create index if not exists ai_employee_tasks_created_by_idx on public.ai_employee_tasks (created_by);
create index if not exists ai_employee_tasks_employee_id_idx on public.ai_employee_tasks (employee_id);
create index if not exists ai_employee_tasks_queue_idx on public.ai_employee_tasks (status, priority, created_at);
create index if not exists ai_employee_tasks_reviewed_by_idx on public.ai_employee_tasks (reviewed_by);
create index if not exists audit_logs_actor_id_idx on public.audit_logs (actor_id);
create index if not exists audit_logs_entity_idx on public.audit_logs (entity_type, entity_id, created_at desc);
create index if not exists leads_assigned_to_idx on public.leads (assigned_to);
create index if not exists leads_created_by_idx on public.leads (created_by);
create index if not exists leads_status_idx on public.leads (status, created_at desc);
create index if not exists properties_assigned_to_idx on public.properties (assigned_to);
create index if not exists properties_created_by_idx on public.properties (created_by);
create index if not exists properties_duplicate_of_idx on public.properties (duplicate_of);
create index if not exists properties_permission_checked_by_idx on public.properties (permission_checked_by);
create index if not exists properties_search_idx on public.properties (country, city, status);
create index if not exists properties_source_id_idx on public.properties (source_id);
create index if not exists properties_status_idx on public.properties (status, created_at desc);
create index if not exists property_media_property_id_idx on public.property_media (property_id);
create index if not exists sources_created_by_idx on public.sources (created_by);
create index if not exists sources_verified_by_idx on public.sources (verified_by);
create unique index if not exists properties_source_url_unique on public.properties (source_listing_url) where source_listing_url is not null;

commit;
