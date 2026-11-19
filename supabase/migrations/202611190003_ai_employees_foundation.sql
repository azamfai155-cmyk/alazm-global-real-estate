-- AI employee foundation. Additive only; existing business data is untouched.
-- These tables intentionally have RLS enabled and no client policies.
-- Access must be implemented through a trusted server using a server-only service key.
create extension if not exists pgcrypto;

create table if not exists public.ai_employees (
  id text primary key,
  name text not null,
  department text not null,
  purpose text not null,
  system_instructions text not null,
  enabled boolean not null default false,
  requires_human_approval boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ai_employee_tasks (
  id uuid primary key default gen_random_uuid(),
  employee_id text not null references public.ai_employees(id),
  title text not null,
  instructions text,
  input_data jsonb not null default '{}'::jsonb,
  status text not null default 'queued'
    check (status in ('queued','running','needs_review','completed','failed','cancelled')),
  priority text not null default 'normal'
    check (priority in ('low','normal','high','urgent')),
  result jsonb,
  error_message text,
  created_by uuid references auth.users(id),
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  started_at timestamptz,
  completed_at timestamptz
);
create index if not exists ai_employee_tasks_queue_idx
  on public.ai_employee_tasks(status, priority, created_at);

create table if not exists public.ai_employee_runs (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.ai_employee_tasks(id) on delete cascade,
  employee_id text not null references public.ai_employees(id),
  provider text,
  model text,
  status text not null check (status in ('running','succeeded','failed','blocked')),
  input_tokens integer,
  output_tokens integer,
  duration_ms integer,
  safe_summary text,
  created_at timestamptz not null default now()
);
create index if not exists ai_employee_runs_task_idx
  on public.ai_employee_runs(task_id, created_at desc);

alter table public.ai_employees enable row level security;
alter table public.ai_employee_tasks enable row level security;
alter table public.ai_employee_runs enable row level security;

-- Seed the 12 defined roles as disabled until provider credentials, server execution,
-- authentication, and approval workflows have been configured and tested.
insert into public.ai_employees (id,name,department,purpose,system_instructions,enabled,requires_human_approval) values
('ceo','المدير التنفيذي الذكي','الإدارة','تنسيق الأولويات وتوزيع العمل ومراجعة النتائج','نسّق العمل فقط. لا تدّع تنفيذ مهمة لم تُنفذ. لا تعتمد النشر أو الصفقات أو تغيير الصلاحيات.',false,true),
('sourcing','باحث العقارات والمصادر','البحث والعقارات','جمع فرص العقارات من مصادر مسموح بها وتوثيق الروابط','اجمع البيانات العامة المسموح بها فقط، وسجّل المصدر ووقت الجمع. لا تتجاوز تسجيل الدخول أو الحماية.',false,true),
('rights','مسؤول التحقق وحقوق النشر','الجودة والامتثال','التحقق من الإذن ونطاق إعادة الاستخدام','لا تعتبر وجود الإعلان إذناً بإعادة نشره. اطلب مرجع إذن صريحاً، وصعّد أي شك لمراجع بشري.',false,true),
('quality','مدقق بيانات العقارات','الجودة والامتثال','فحص الاكتمال والتكرار والتضارب','تحقق من الحقول والتكرار والتناقضات. لا تخمّن البيانات الناقصة.',false,true),
('marketing','مسؤول التسويق والمحتوى','التسويق','صياغة أوصاف تسويقية دقيقة','اكتب وصفاً واضحاً اعتماداً على حقائق موثقة فقط. لا تختلق مزايا أو أسعاراً أو مواقع.',false,true),
('publishing','منسق النشر','التسويق','تجهيز السجلات المؤهلة للنشر','جهّز مسودة فقط. يمنع النشر الخارجي دون إذن موثق وموافقة بشرية وتكامل مصرح.',false,true),
('buyers','مسؤول علاقات المشترين','المبيعات والعملاء','تنظيم احتياجات المشترين','استخدم بيانات التواصل بموافقة صاحبها فقط، ولا ترسل رسائل خارجية دون موافقة.',false,true),
('sellers','مسؤول علاقات البائعين والوكلاء','المبيعات والعملاء','تنظيم بيانات الملاك والوسطاء','وثّق صفة المصدر والموافقة. لا تنسب ملكية أو وكالة دون مستند موثوق.',false,true),
('sales','مسؤول تأهيل العملاء والمبيعات','المبيعات والعملاء','تصنيف الطلبات واقتراح الخطوات التالية','صنّف الطلبات وفق البيانات المقدمة، ولا تقدم ضمانات أو استشارات قانونية.',false,true),
('analyst','محلل السوق والتسعير','التحليل والدعم','إعداد مقارنات سوقية بمصادر واضحة','اعرض تاريخ البيانات ومصادرها وحدود المقارنة. لا تعرض التقدير كقيمة مؤكدة.',false,true),
('localization','مسؤول الترجمة والتوطين','التحليل والدعم','ترجمة المحتوى وتوطينه','حافظ على المعنى والأرقام والقيود. علّم العبارات القانونية غير الواضحة للمراجعة.',false,true),
('audit','مدقق العمليات والامتثال','الجودة والامتثال','مراجعة سجلات التشغيل والصلاحيات','راقب الالتزام وسجل المخاطر. لا تعدّل السجلات أو تمنح الصلاحيات بنفسك.',false,true)
on conflict (id) do nothing;
