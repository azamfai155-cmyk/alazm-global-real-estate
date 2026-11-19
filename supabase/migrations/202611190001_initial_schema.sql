-- AL AZM GLOBAL REAL ESTATE — initial production-oriented schema
-- Apply in a NEW Supabase project via SQL Editor. Review policies before launch.
create extension if not exists pgcrypto;

create type public.app_role as enum ('owner','admin','reviewer','agent','support');
create type public.property_status as enum ('draft','pending_review','approved','published','rejected','archived');
create type public.lead_kind as enum ('buy','sell','rent','lease','partnership','inquiry');
create type public.lead_status as enum ('new','contacted','qualified','in_progress','closed_won','closed_lost');
create type public.source_kind as enum ('owner','licensed_broker','agency','portal','marketing_partner','other');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  role public.app_role not null default 'support',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.sources (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  kind public.source_kind not null default 'other',
  contact text,
  website_url text,
  permission_scope text,
  permission_reference text,
  permission_valid_until date,
  verified_by uuid references public.profiles(id),
  verified_at timestamptz,
  active boolean not null default true,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.properties (
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

create unique index properties_source_url_unique on public.properties(source_listing_url)
where source_listing_url is not null;
create index properties_search_idx on public.properties(country, city, status);
create index properties_status_idx on public.properties(status, created_at desc);

create table public.property_media (
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

create table public.leads (
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
create index leads_status_idx on public.leads(status, created_at desc);

create table public.audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid references public.profiles(id),
  action text not null,
  entity_type text not null,
  entity_id uuid,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index audit_logs_entity_idx on public.audit_logs(entity_type, entity_id, created_at desc);

create or replace function public.current_role()
returns public.app_role language sql stable security definer set search_path = public
as $$ select role from public.profiles where id = auth.uid() and active = true $$;

create or replace function public.has_any_role(allowed public.app_role[])
returns boolean language sql stable security definer set search_path = public
as $$ select coalesce(public.current_role() = any(allowed), false) $$;

create or replace function public.touch_updated_at()
returns trigger language plpgsql set search_path = public
as $$ begin new.updated_at = now(); return new; end $$;

create trigger profiles_touch before update on public.profiles for each row execute function public.touch_updated_at();
create trigger sources_touch before update on public.sources for each row execute function public.touch_updated_at();
create trigger properties_touch before update on public.properties for each row execute function public.touch_updated_at();
create trigger leads_touch before update on public.leads for each row execute function public.touch_updated_at();

-- Profile provisioning: new users are support by default. Elevate the first owner manually
-- from the Supabase SQL editor after verifying the account identity.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public
as $$ begin
  insert into public.profiles(id, full_name, role)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name',''), 'support');
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.sources enable row level security;
alter table public.properties enable row level security;
alter table public.property_media enable row level security;
alter table public.leads enable row level security;
alter table public.audit_logs enable row level security;

-- Staff can see their own profile; admins/owner can manage profiles.
create policy profiles_read_self_or_admin on public.profiles for select to authenticated
using (id = auth.uid() or public.has_any_role(array['owner','admin']::public.app_role[]));
create policy profiles_update_admin on public.profiles for update to authenticated
using (public.has_any_role(array['owner','admin']::public.app_role[]))
with check (public.has_any_role(array['owner','admin']::public.app_role[]));

create policy sources_staff_read on public.sources for select to authenticated
using (public.has_any_role(array['owner','admin','reviewer','agent','support']::public.app_role[]));
create policy sources_admin_manage on public.sources for all to authenticated
using (public.has_any_role(array['owner','admin']::public.app_role[]))
with check (public.has_any_role(array['owner','admin']::public.app_role[]));

create policy properties_staff_read on public.properties for select to authenticated
using (public.has_any_role(array['owner','admin','reviewer','agent','support']::public.app_role[]));
create policy properties_agent_insert on public.properties for insert to authenticated
with check (public.has_any_role(array['owner','admin','reviewer','agent']::public.app_role[]));
create policy properties_review_update on public.properties for update to authenticated
using (public.has_any_role(array['owner','admin','reviewer']::public.app_role[]))
with check (public.has_any_role(array['owner','admin','reviewer']::public.app_role[]));
create policy properties_admin_delete on public.properties for delete to authenticated
using (public.has_any_role(array['owner','admin']::public.app_role[]));

create policy media_staff_read on public.property_media for select to authenticated
using (public.has_any_role(array['owner','admin','reviewer','agent','support']::public.app_role[]));
create policy media_agent_insert on public.property_media for insert to authenticated
with check (public.has_any_role(array['owner','admin','reviewer','agent']::public.app_role[]));
create policy media_admin_manage on public.property_media for delete to authenticated
using (public.has_any_role(array['owner','admin']::public.app_role[]));

create policy leads_staff_read on public.leads for select to authenticated
using (public.has_any_role(array['owner','admin','reviewer','agent','support']::public.app_role[]));
create policy leads_staff_insert on public.leads for insert to authenticated
with check (public.has_any_role(array['owner','admin','reviewer','agent','support']::public.app_role[]));
create policy leads_staff_update on public.leads for update to authenticated
using (public.has_any_role(array['owner','admin','reviewer','agent','support']::public.app_role[]))
with check (public.has_any_role(array['owner','admin','reviewer','agent','support']::public.app_role[]));
create policy leads_admin_delete on public.leads for delete to authenticated
using (public.has_any_role(array['owner','admin']::public.app_role[]));

create policy audit_read_admin on public.audit_logs for select to authenticated
using (public.has_any_role(array['owner','admin']::public.app_role[]));
-- No client-side insert/update/delete policy on audit_logs: write via trusted server only.

-- Public read-only property catalogue: only explicitly published records.
create policy public_published_properties on public.properties for select to anon, authenticated
using (status = 'published');

-- Critical: status changes are still role-gated. No public insert/update policies exist.
