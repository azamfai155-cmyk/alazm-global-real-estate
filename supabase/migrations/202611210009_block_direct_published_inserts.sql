-- Fix: apply owner-only publication checks to INSERT as well as UPDATE.
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
       or new.permission_checked_by is null or new.permission_checked_at is null then
      raise exception 'Verified reuse rights require a reference, reviewer, and verification timestamp' using errcode = '23514';
    end if;
    select s.active, s.permission_scope, s.permission_reference
      into source_active, source_scope, source_permission_reference
      from public.sources s where s.id = new.source_id;
    if coalesce(source_active,false) is not true
       or nullif(btrim(coalesce(source_scope,'')), '') is null
       or nullif(btrim(coalesce(source_permission_reference,'')), '') is null then
      raise exception 'The source must be active and have a documented permission scope and reference' using errcode = '23514';
    end if;
  end if;

  if new.status = 'published' and (tg_op = 'INSERT' or new.status is distinct from old.status) then
    if actor_role is distinct from 'owner'::public.app_role then
      raise exception 'Only the company owner may publish a property' using errcode = '42501';
    end if;
    if not new.permission_confirmed then
      raise exception 'Property cannot be published before reuse rights are verified' using errcode = '23514';
    end if;
    if new.suspicious or new.duplicate_of is not null then
      raise exception 'Suspicious or duplicate properties cannot be published' using errcode = '23514';
    end if;
    if exists (select 1 from public.property_media m where m.property_id = new.id
      and (not m.rights_confirmed or nullif(btrim(coalesce(m.rights_reference,'')), '') is null)) then
      raise exception 'Every attached media item must have verified reuse rights before publication' using errcode = '23514';
    end if;
    new.published_at := coalesce(new.published_at, now());
  elsif new.status is distinct from 'published' then
    new.published_at := null;
  end if;

  if tg_op = 'UPDATE' and old.status = 'published'
     and (actor_role is null or actor_role not in ('owner','admin')) then
    raise exception 'Only owner or admin may edit a published property' using errcode = '42501';
  end if;
  return new;
end;
$$;
