create table if not exists public.ai_workflow_templates (
 id text primary key,
 name text not null,
 description text not null,
 steps jsonb not null check (jsonb_typeof(steps)='array' and jsonb_array_length(steps) between 2 and 12),
 enabled boolean not null default true,
 updated_at timestamptz not null default now()
);
insert into public.ai_workflow_templates(id,name,description,steps,enabled)
values ('property_intake_v1','مسار فحص وتجهيز العقار','مسار متتابع من استلام بيانات العرض حتى تجهيز مسودة النشر، مع مراجعة مالك الشركة بين كل مرحلة والتي تليها.','[
{"employee_id":"sourcing","title":"استلام العرض وفحص المصدر","instructions":"حلل بيانات العرض المرفقة وحدد المصدر الأصلي والرابط وتاريخ الالتقاط وهوية الناشر إن كانت مثبتة. أنشئ قائمة بالحقائق المتاحة والحقول الناقصة، ولا تتصفح الإنترنت ولا تفترض صحة الملكية أو الإذن."},
{"employee_id":"rights","title":"التحقق من حقوق المصدر وإعادة الاستخدام","instructions":"افحص أدلة الإذن المرفقة فقط: صاحب الحق أو الوكيل، نطاق استخدام النص والصور والبيانات، القنوات، المدة، ومرجع الإثبات. صنّف الإذن موثقاً أو ناقصاً أو منتهياً أو غير معلوم. لا تمنح موافقة قانونية نهائية."},
{"employee_id":"quality","title":"تدقيق البيانات والتكرار","instructions":"دقق الحقول العقارية المقدمة وتناسقها واكتمالها والتكرار المحتمل. قارن بالسجلات المتاحة ضمن مدخلات المهمة فقط. لا تدمج أو تخمّن ولا تعتبر التشابه إثباتاً."},
{"employee_id":"analyst","title":"تحليل العرض والسوق","instructions":"حلل البيانات والمقارنات المرفقة فقط، وافصل السعر المطلوب عن سعر الصفقة المنفذة. اذكر حجم العينة وحدودها والثقة والبيانات التي لا يمكن التحقق منها."},
{"employee_id":"marketing","title":"إعداد مسودة التسويق","instructions":"اكتب مسودة وصف عقاري اعتماداً حصراً على الحقائق التي اجتازت المراجعة في المراحل السابقة. لا تضف مزايا أو ضمانات أو عوائد أو معلومات غير مثبتة. لا تنشر."},
{"employee_id":"publishing","title":"مراجعة جاهزية مسودة النشر","instructions":"راجع اكتمال البيانات ونتائج الحقوق والجودة والتسويق. أصدر قائمة تحقق وتوصية جاهز للمراجعة النهائية أو موقوف بسبب النواقص. لا تنشر ولا تنفذ أي إجراء خارجي؛ النشر يحتاج موافقة منفصلة من المالك."}
]'::jsonb,true)
on conflict (id) do update set name=excluded.name,description=excluded.description,steps=excluded.steps,enabled=true,updated_at=now();
create table if not exists public.ai_workflow_runs (
 id uuid primary key default gen_random_uuid(),
 template_id text not null references public.ai_workflow_templates(id),
 title text not null,
 status text not null default 'active' check (status in ('active','blocked','completed','cancelled')),
 current_step integer not null default 1,
 source_payload jsonb not null default '{}'::jsonb,
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 completed_at timestamptz
);
create table if not exists public.ai_workflow_steps (
 id uuid primary key default gen_random_uuid(),
 workflow_id uuid not null references public.ai_workflow_runs(id) on delete cascade,
 step_order integer not null,
 employee_id text not null references public.ai_employees(id),
 title text not null,
 instructions text not null,
 status text not null default 'blocked' check (status in ('blocked','queued','running','needs_review','completed','failed','cancelled')),
 task_id uuid unique references public.ai_employee_tasks(id) on delete set null,
 result jsonb,
 created_at timestamptz not null default now(),
 completed_at timestamptz,
 unique(workflow_id,step_order)
);
create index if not exists ai_workflow_runs_status_created_idx on public.ai_workflow_runs(status,created_at desc);
create index if not exists ai_workflow_steps_workflow_order_idx on public.ai_workflow_steps(workflow_id,step_order);
alter table public.ai_workflow_templates enable row level security;
alter table public.ai_workflow_runs enable row level security;
alter table public.ai_workflow_steps enable row level security;
create or replace function public.start_ai_property_workflow(p_actor_id uuid,p_title text,p_source_payload jsonb,p_template_id text default 'property_intake_v1')
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_template public.ai_workflow_templates%rowtype; v_profile public.profiles%rowtype; v_run_id uuid; v_step jsonb; v_order integer:=0; v_first_task_id uuid; v_step_id uuid;
begin
 select * into v_profile from public.profiles where id=p_actor_id and active=true;
 if not found or v_profile.role<>'owner'::public.app_role then raise exception 'Only an active company owner can start a workflow' using errcode='42501'; end if;
 if p_title is null or length(btrim(p_title))=0 or length(p_title)>160 then raise exception 'Workflow title is required and must be at most 160 characters' using errcode='22023'; end if;
 if p_source_payload is null or jsonb_typeof(p_source_payload)<>'object' or length(p_source_payload::text)>8000 then raise exception 'Source payload must be a JSON object up to 8000 characters' using errcode='22023'; end if;
 select * into v_template from public.ai_workflow_templates where id=p_template_id and enabled=true;
 if not found then raise exception 'Workflow template is unavailable' using errcode='22023'; end if;
 v_run_id:=gen_random_uuid();
 insert into public.ai_workflow_runs(id,template_id,title,source_payload,created_by) values(v_run_id,p_template_id,btrim(p_title),p_source_payload,p_actor_id);
 for v_step in select value from jsonb_array_elements(v_template.steps) as x(value) loop
  v_order:=v_order+1;
  if not exists(select 1 from public.ai_employees where id=v_step->>'employee_id' and enabled=true) then raise exception 'Workflow employee is disabled or missing: %',v_step->>'employee_id'; end if;
  insert into public.ai_workflow_steps(workflow_id,step_order,employee_id,title,instructions,status)
  values(v_run_id,v_order,v_step->>'employee_id',v_step->>'title',v_step->>'instructions',case when v_order=1 then 'queued' else 'blocked' end)
  returning id into v_step_id;
  if v_order=1 then
   insert into public.ai_employee_tasks(employee_id,title,instructions,input_data,priority,status,created_by)
   values(v_step->>'employee_id',v_step->>'title',v_step->>'instructions',jsonb_build_object('workflow_id',v_run_id,'workflow_step',v_order,'source_payload',p_source_payload),'normal','queued',p_actor_id)
   returning id into v_first_task_id;
   update public.ai_workflow_steps set task_id=v_first_task_id where id=v_step_id;
  end if;
 end loop;
 return jsonb_build_object('workflow_id',v_run_id,'first_task_id',v_first_task_id,'status','active','step_count',v_order);
end; $$;
revoke all on function public.start_ai_property_workflow(uuid,text,jsonb,text) from public,anon,authenticated;
grant execute on function public.start_ai_property_workflow(uuid,text,jsonb,text) to service_role;
create or replace function public.sync_ai_workflow_from_task()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_step public.ai_workflow_steps%rowtype; v_run public.ai_workflow_runs%rowtype; v_next public.ai_workflow_steps%rowtype; v_prior jsonb; v_new_task uuid;
begin
 if new.status is not distinct from old.status then return new; end if;
 select * into v_step from public.ai_workflow_steps where task_id=new.id;
 if not found then return new; end if;
 select * into v_run from public.ai_workflow_runs where id=v_step.workflow_id;
 if not found then return new; end if;
 if new.status='running' then update public.ai_workflow_steps set status='running' where id=v_step.id and status='queued';
 elsif new.status='needs_review' then update public.ai_workflow_steps set status='needs_review',result=new.result where id=v_step.id;
 elsif new.status='failed' then update public.ai_workflow_steps set status='failed',result=new.result where id=v_step.id; update public.ai_workflow_runs set status='blocked',updated_at=now() where id=v_run.id;
 elsif new.status='cancelled' then update public.ai_workflow_steps set status='cancelled' where id=v_step.id; update public.ai_workflow_runs set status='cancelled',updated_at=now() where id=v_run.id;
 elsif new.status='queued' and old.status='failed' then update public.ai_workflow_steps set status='queued',result=null,completed_at=null where id=v_step.id; update public.ai_workflow_runs set status='active',updated_at=now(),current_step=v_step.step_order where id=v_run.id;
 elsif new.status='completed' and old.status='needs_review' then
  update public.ai_workflow_steps set status='completed',result=new.result,completed_at=now() where id=v_step.id;
  select * into v_next from public.ai_workflow_steps where workflow_id=v_run.id and step_order=v_step.step_order+1 and status='blocked';
  if not found then update public.ai_workflow_runs set status='completed',updated_at=now(),completed_at=now(),current_step=v_step.step_order where id=v_run.id;
  else
   select coalesce(jsonb_agg(jsonb_build_object('step_order',s.step_order,'employee_id',s.employee_id,'title',s.title,'report',s.result->'report') order by s.step_order),'[]'::jsonb) into v_prior
   from public.ai_workflow_steps s where s.workflow_id=v_run.id and s.step_order<=v_step.step_order and s.status='completed';
   insert into public.ai_employee_tasks(employee_id,title,instructions,input_data,priority,status,created_by)
   values(v_next.employee_id,v_next.title,v_next.instructions,jsonb_build_object('workflow_id',v_run.id,'workflow_step',v_next.step_order,'source_payload',v_run.source_payload,'prior_approved_reports',v_prior),'normal','queued',v_run.created_by)
   returning id into v_new_task;
   update public.ai_workflow_steps set status='queued',task_id=v_new_task where id=v_next.id;
   update public.ai_workflow_runs set status='active',updated_at=now(),current_step=v_next.step_order where id=v_run.id;
  end if;
 end if;
 return new;
end; $$;
drop trigger if exists ai_workflow_sync_after_task_update on public.ai_employee_tasks;
create trigger ai_workflow_sync_after_task_update after update of status on public.ai_employee_tasks for each row execute function public.sync_ai_workflow_from_task();
comment on table public.ai_workflow_templates is 'Approved internal AI workflow templates; no external publication actions.';
comment on table public.ai_workflow_runs is 'Sequential AI workflow runs; each step is unlocked only after owner approval of the previous report.';
comment on table public.ai_workflow_steps is 'Workflow step state and task linkage; later steps remain blocked until predecessor approval.';
