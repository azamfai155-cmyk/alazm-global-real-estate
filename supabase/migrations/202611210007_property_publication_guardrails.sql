-- AL AZM GLOBAL REAL ESTATE: publication and rights guardrails
-- Prevent authenticated staff from bypassing review by inserting/updating published listings.
-- Trusted server maintenance (auth.uid() IS NULL) remains possible, but must enforce its own workflow.

create or replace function public.guard_property_publication()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  actor_role public.app_role;
  source_active boolean;
  source_scope text;
  source_permission_reference text;
begin
  if auth.uid() is null then
    return new;
  end if;

  actor_role := public.current_role();

  -- Only owner/admin/reviewer may attest to reuse rights.
  if new.permission_confirmed is distinct from coalesce(old.permission_confirmed, false)
     or new.permission_reference is distinct from old.permission_reference
     or new.permission_checked_by is distinct from old.permission_checked_by
     or new.permission_checked_at is distinct from old.permission_checked_at then
    if actor_role not in ('owner','admin','reviewer') then
      raise exception 'Only owner, admin, or reviewer may verify property reuse rights'
        using errcode = '42501';
    end if;
  end if;

  if new.permission_confirmed then
    if nullif(btrim(coalesce(new.permission_reference,'')), '') is null
       or new.permission_checked_by is null
       or new.permission_checked_at is null then
      raise exception 'Verified reuse rights require a reference, reviewer, and verification timestamp'
        using errcode = '23514';
    end if;

    select s.active, s.permission_scope, s.permission_reference
      into source_active, source_scope, source_permission_reference
      from public.sources s
     where s.id = new.source_id;

    if coalesce(source_active,false) is not true
       or nullif(btrim(coalesce(source_scope,'')), '') is null
       or nullif(btrim(coalesce(source_permission_reference,'')), '') is null then
      raise exception 'The source must be active and have a documented permission scope and reference'
        using errcode = '23514';
    end if;
  end if;

  if new.status = 'published' and new.status is distinct from old.status then
    if actor_role is distinct from 'owner'::public.app_role then
      raise exception 'Only the company owner may publish a property'
        using errcode = '42501';
    end if;

    if not new.permission_confirmed then
      raise exception 'Property cannot be published before reuse rights are verified'
        using errcode = '23514';
    end if;

    if new.suspicious or new.duplicate_of is not null then
      raise exception 'Suspicious or duplicate properties cannot be published'
        using errcode = '23514';
    end if;

    if exists (
      select 1 from public.property_media m
       where m.property_id = new.id
         and (not m.rights_confirmed
              or nullif(btrim(coalesce(m.rights_reference,'')), '') is null)
    ) then
      raise exception 'Every attached media item must have verified reuse rights before publication'
        using errcode = '23514';
    end if;

    new.published_at := coalesce(new.published_at, now());
  elsif new.status is distinct from 'published' then
    new.published_at := null;
  end if;

  -- Once a listing is public, only owner/admin may edit its content.
  if tg_op = 'UPDATE' and old.status = 'published'
     and actor_role not in ('owner','admin') then
    raise exception 'Only owner or admin may edit a published property'
      using errcode = '42501';
  end if;

  return new;
end;
$$;

drop trigger if exists properties_publication_guard on public.properties;
create trigger properties_publication_guard
before insert or update on public.properties
for each row execute function public.guard_property_publication();

-- A media item cannot be marked as rights-cleared by an agent/support account.
create or replace function public.guard_property_media_rights()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  actor_role public.app_role;
begin
  if auth.uid() is null then
    return new;
  end if;

  actor_role := public.current_role();

  if new.rights_confirmed
     and actor_role not in ('owner','admin','reviewer') then
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
$$;

drop trigger if exists property_media_rights_guard on public.property_media;
create trigger property_media_rights_guard
before insert or update on public.property_media
for each row execute function public.guard_property_media_rights();

-- Do not allow browser clients to delete or rewrite audit history.
-- RLS remains the primary row-level boundary; explicit grants are audited separately.
