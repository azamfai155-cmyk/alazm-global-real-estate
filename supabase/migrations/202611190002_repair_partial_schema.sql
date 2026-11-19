-- Repair migration for databases where the initial schema was only partially applied.
-- Existing tables/types are preserved; missing tables and supporting objects are added.
create extension if not exists pgcrypto;

create table if not exists public.properties (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  country text not null,
  city text not null,
  address text,
  property_type text not null,
  listing_kind text not null check (listing_kind in ('sale','rent','lease')),
  price numeric(18,2),
  currency char(3),
  bedrooms integer check (bedrooms is null or bedrooms >= 0),
  bathrooms numeric(4,1) check (bathrooms is null or bathrooms >= 0),
  area_sqm numeric(14,2) check (area_sqm is null or area_sqm > 0),
  source_id uuid not null references public.sources(id),
  source_listing_url text,
  permission_confirmed boolean not null default false,
  permission_reference text,
  permission_checked_by uuid references public.profiles(id),
  permission_checked_at timestamptz,
  suspicious boolean not null default false,
  duplicate_of uuid references public.properties(id),
  review_notes text,
  status public.property_status not null default 'pending_review',
  published_at timestamptz,
  created_by uuid references public.profiles(id),
  assigned_to uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.property_media (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties(id) on delete cascade,
  storage_path text not null,
  media_type text not null check (media_type in ('image','video','document')),
  alt_text text,
  rights_confirmed boolean not null default false,
  rights_reference text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.leads (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  email text,
  phone text,
  kind public.lead_kind not null,
  country text,
  city text,
  budget_min numeric(18,2),
  budget_max numeric(18,2),
  currency char(3),
  details text,
  status public.lead_status not null default 'new',
  assigned_to uuid references public.profiles(id),
  consent_to_contact boolean not null default false,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid references public.profiles(id),
  action text not null,
  entity_type text not null,
  entity_id uuid,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create unique index if not exists properties_source_url_unique
  on public.properties(source_listing_url) where source_listing_url is not null;
create index if not exists properties_search_idx on public.properties(country, city, status);
create index if not exists properties_status_idx on public.properties(status, created_at desc);
create index if not exists leads_status_idx on public.leads(status, created_at desc);
create index if not exists audit_logs_entity_idx on public.audit_logs(entity_type, entity_id, created_at desc);

create or replace function public.touch_updated_at()
returns trigger language plpgsql set search_path = public
as $$ begin new.updated_at = now(); return new; end $$;

create or replace function public.current_role()
returns public.app_role language sql stable security definer set search_path = public
as $$ select role from public.profiles where id = auth.uid() and active = true $$;

create or replace function public.has_any_role(allowed public.app_role[])
returns boolean language sql stable security definer set search_path = public
as $$ select coalesce(public.current_role() = any(allowed), false) $$;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public
as $$ begin
  insert into public.profiles(id, full_name, role)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name',''), 'support')
  on conflict (id) do nothing;
  return new;
end $$;

do $$
declare t text;
begin
  foreach t in array array['profiles','sources','properties','leads'] loop
    execute format('drop trigger if exists %I on public.%I', t || '_touch', t);
    execute format('create trigger %I before update on public.%I for each row execute function public.touch_updated_at()', t || '_touch', t);
  end loop;
  if not exists (select 1 from pg_trigger where tgname = 'on_auth_user_created' and tgrelid = 'auth.users'::regclass) then
    create trigger on_auth_user_created after insert on auth.users
    for each row execute procedure public.handle_new_user();
  end if;
end $$;

alter table public.profiles enable row level security;
alter table public.sources enable row level security;
alter table public.properties enable row level security;
alter table public.property_media enable row level security;
alter table public.leads enable row level security;
alter table public.audit_logs enable row level security;

-- Create policies only when absent; preserve any existing policy definitions.
do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='profiles' and policyname='profiles_read_self_or_admin') then
    create policy profiles_read_self_or_admin on public.profiles for select to authenticated
    using (id = auth.uid() or public.has_any_role(array['owner','admin']::public.app_role[]));
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='profiles' and policyname='profiles_update_admin') then
    create policy profiles_update_admin on public.profiles for update to authenticated
    using (public.has_any_role(array['owner','admin']::public.app_role[]))
    with check (public.has_any_role(array['owner','admin']::public.app_role[]));
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='sources' and policyname='sources_staff_read') then
    create policy sources_staff_read on public.sources for select to authenticated
    using (public.has_any_role(array['owner','admin','reviewer','agent','support']::public.app_role[]));
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='sources' and policyname='sources_admin_manage') then
    create policy sources_admin_manage on public.sources for all to authenticated
    using (public.has_any_role(array['owner','admin']::public.app_role[]))
    with check (public.has_any_role(array['owner','admin']::public.app_role[]));
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='properties' and policyname='properties_staff_read') then
    create policy properties_staff_read on public.properties for select to authenticated
    using (public.has_any_role(array['owner','admin','reviewer','agent','support']::public.app_role[]));
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='properties' and policyname='properties_agent_insert') then
    create policy properties_agent_insert on public.properties for insert to authenticated
    with check (public.has_any_role(array['owner','admin','reviewer','agent']::public.app_role[]));
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='properties' and policyname='properties_review_update') then
    create policy properties_review_update on public.properties for update to authenticated
    using (public.has_any_role(array['owner','admin','reviewer']::public.app_role[]))
    with check (public.has_any_role(array['owner','admin','reviewer']::public.app_role[]));
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='properties' and policyname='properties_admin_delete') then
    create policy properties_admin_delete on public.properties for delete to authenticated
    using (public.has_any_role(array['owner','admin']::public.app_role[]));
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='properties' and policyname='public_published_properties') then
    create policy public_published_properties on public.properties for select to anon, authenticated
    using (status = 'published');
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='property_media' and policyname='media_staff_read') then
    create policy media_staff_read on public.property_media for select to authenticated
    using (public.has_any_role(array['owner','admin','reviewer','agent','support']::public.app_role[]));
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='property_media' and policyname='media_agent_insert') then
    create policy media_agent_insert on public.property_media for insert to authenticated
    with check (public.has_any_role(array['owner','admin','reviewer','agent']::public.app_role[]));
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='property_media' and policyname='media_admin_manage') then
    create policy media_admin_manage on public.property_media for delete to authenticated
    using (public.has_any_role(array['owner','admin']::public.app_role[]));
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='leads' and policyname='leads_staff_read') then
    create policy leads_staff_read on public.leads for select to authenticated
    using (public.has_any_role(array['owner','admin','reviewer','agent','support']::public.app_role[]));
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='leads' and policyname='leads_staff_insert') then
    create policy leads_staff_insert on public.leads for insert to authenticated
    with check (public.has_any_role(array['owner','admin','reviewer','agent','support']::public.app_role[]));
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='leads' and policyname='leads_staff_update') then
    create policy leads_staff_update on public.leads for update to authenticated
    using (public.has_any_role(array['owner','admin','reviewer','agent','support']::public.app_role[]))
    with check (public.has_any_role(array['owner','admin','reviewer','agent','support']::public.app_role[]));
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='leads' and policyname='leads_admin_delete') then
    create policy leads_admin_delete on public.leads for delete to authenticated
    using (public.has_any_role(array['owner','admin']::public.app_role[]));
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='audit_logs' and policyname='audit_read_admin') then
    create policy audit_read_admin on public.audit_logs for select to authenticated
    using (public.has_any_role(array['owner','admin']::public.app_role[]));
  end if;
end $$;
