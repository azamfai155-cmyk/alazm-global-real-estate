-- Close service-role / missing-user-context bypasses in property and media guards.
-- Keep public listings visible only while their source permission is currently valid.

create or replace function public.guard_property_publication()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  actor_role public.app_role;
  source_active boolean;
  source_scope text;
  source_permission_reference text;
  source_verified_by uuid;
  source_verified_at timestamptz;
  source_permission_valid_until date;
begin
  if auth.uid() is null then
    raise exception 'Authenticated user context is required for property changes'
      using errcode = '42501';
  end if;

  actor_role := public.current_role();

  if (tg_op = 'INSERT' and (new.permission_confirmed or new.permission_reference is not null or new.permission_checked_by is not null or new.permission_checked_at is not null))
     or (tg_op = 'UPDATE' and (
       new.permission_confirmed is distinct from old.permission_confirmed
       or new.permission_reference is distinct from old.permission_reference
       or new.permission_checked_by is distinct from old.permission_checked_by
       or new.permission_checked_at is distinct from old.permission_checked_at
     )) then
    if actor_role is null or actor_role not in ('owner','admin','reviewer') then
      raise exception 'Only owner, admin, or reviewer may verify property reuse rights' using errcode = '42501';
    end if;
  end if;

  if new.permission_confirmed then
    if nullif(btrim(coalesce(new.permission_reference,'')), '') is null
       or new.permission_checked_by is null
       or new.permission_checked_at is null
       or new.permission_checked_by is distinct from auth.uid() then
      raise exception 'Verified reuse rights require a reference and the current reviewer identity and timestamp'
        using errcode = '23514';
    end if;

    select s.active, s.permission_scope, s.permission_reference,
           s.verified_by, s.verified_at, s.permission_valid_until
      into source_active, source_scope, source_permission_reference,
           source_verified_by, source_verified_at, source_permission_valid_until
      from public.sources s
     where s.id = new.source_id;

    if coalesce(source_active,false) is not true
       or nullif(btrim(coalesce(source_scope,'')), '') is null
       or nullif(btrim(coalesce(source_permission_reference,'')), '') is null
       or source_verified_by is null
       or source_verified_at is null
       or (source_permission_valid_until is not null and source_permission_valid_until < current_date) then
      raise exception 'The source must be active, verified, in date, and have documented permission scope and reference'
        using errcode = '23514';
    end if;
  end if;

  if new.status = 'published' then
    if (tg_op = 'INSERT' or new.status is distinct from old.status)
       and actor_role is distinct from 'owner'::public.app_role then
      raise exception 'Only the company owner may publish a property' using errcode = '42501';
    end if;

    if not new.permission_confirmed then
      raise exception 'Property cannot remain published without verified reuse rights' using errcode = '23514';
    end if;

    if new.suspicious or new.duplicate_of is not null then
      raise exception 'Suspicious or duplicate properties cannot be published' using errcode = '23514';
    end if;

    select s.active, s.permission_scope, s.permission_reference,
           s.verified_by, s.verified_at, s.permission_valid_until
      into source_active, source_scope, source_permission_reference,
           source_verified_by, source_verified_at, source_permission_valid_until
      from public.sources s
     where s.id = new.source_id;

    if coalesce(source_active,false) is not true
       or nullif(btrim(coalesce(source_scope,'')), '') is null
       or nullif(btrim(coalesce(source_permission_reference,'')), '') is null
       or source_verified_by is null
       or source_verified_at is null
       or (source_permission_valid_until is not null and source_permission_valid_until < current_date) then
      raise exception 'Published property requires a currently active, verified, authorized source'
        using errcode = '23514';
    end if;

    if exists (
      select 1 from public.property_media m
      where m.property_id = new.id
        and (not m.rights_confirmed or nullif(btrim(coalesce(m.rights_reference,'')), '') is null)
    ) then
      raise exception 'Every attached media item must have verified reuse rights before publication'
        using errcode = '23514';
    end if;

    new.published_at := coalesce(new.published_at, now());
  else
    new.published_at := null;
  end if;

  if tg_op = 'UPDATE' and old.status = 'published'
     and (actor_role is null or actor_role not in ('owner','admin')) then
    raise exception 'Only owner or admin may edit a published property' using errcode = '42501';
  end if;

  return new;
end;
$function$;

create or replace function public.guard_property_media_rights()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  actor_role public.app_role;
  parent_status public.property_status;
begin
  if auth.uid() is null then
    raise exception 'Authenticated user context is required for property media changes'
      using errcode = '42501';
  end if;

  actor_role := public.current_role();
  select p.status into parent_status
    from public.properties p
   where p.id = new.property_id;

  if parent_status = 'published' and (actor_role is null or actor_role not in ('owner','admin')) then
    raise exception 'Only owner or admin may change media on a published property'
      using errcode = '42501';
  end if;

  if parent_status = 'published'
     and (not new.rights_confirmed or nullif(btrim(coalesce(new.rights_reference,'')), '') is null) then
    raise exception 'Published properties cannot contain media without verified reuse rights'
      using errcode = '23514';
  end if;

  if new.rights_confirmed
     and (actor_role is null or actor_role not in ('owner','admin','reviewer')) then
    raise exception 'Only owner, admin, or reviewer may verify media reuse rights'
      using errcode = '42501';
  end if;

  if new.rights_confirmed
     and nullif(btrim(coalesce(new.rights_reference,'')), '') is null then
    raise exception 'Verified media rights require a reference'
      using errcode = '23514';
  end if;

  return new;
end;
$function$;

drop policy if exists public_published_properties on public.properties;
create policy public_published_properties
on public.properties
for select
to anon, authenticated
using (
  status = 'published'
  and permission_confirmed = true
  and suspicious = false
  and duplicate_of is null
  and exists (
    select 1
    from public.sources s
    where s.id = properties.source_id
      and s.active = true
      and nullif(btrim(coalesce(s.permission_scope,'')), '') is not null
      and nullif(btrim(coalesce(s.permission_reference,'')), '') is not null
      and s.verified_by is not null
      and s.verified_at is not null
      and (s.permission_valid_until is null or s.permission_valid_until >= current_date)
  )
);
