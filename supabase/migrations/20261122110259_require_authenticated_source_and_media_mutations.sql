-- Fail closed for source and media writes that bypass an authenticated user session.
create or replace function public.guard_source_management()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  actor_role public.app_role;
begin
  if auth.uid() is null then
    raise exception 'Authenticated user context is required for source changes'
      using errcode = '42501';
  end if;

  actor_role := public.current_role();
  if actor_role is null or actor_role not in ('owner','admin') then
    raise exception 'Only an active owner or admin may manage source records'
      using errcode = '42501';
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$function$;

drop trigger if exists sources_management_guard on public.sources;
create trigger sources_management_guard
before insert or update or delete on public.sources
for each row execute function public.guard_source_management();

create or replace function public.guard_property_media_rights()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  actor_role public.app_role;
  parent_status public.property_status;
  parent_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authenticated user context is required for property media changes'
      using errcode = '42501';
  end if;

  actor_role := public.current_role();

  if tg_op = 'DELETE' then
    parent_id := old.property_id;
    select p.status into parent_status
      from public.properties p
     where p.id = parent_id;

    if actor_role is null or actor_role not in ('owner','admin') then
      raise exception 'Only owner or admin may delete property media'
        using errcode = '42501';
    end if;

    if parent_status = 'published' and actor_role not in ('owner','admin') then
      raise exception 'Only owner or admin may change media on a published property'
        using errcode = '42501';
    end if;

    return old;
  end if;

  parent_id := new.property_id;
  select p.status into parent_status
    from public.properties p
   where p.id = parent_id;

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

drop trigger if exists property_media_rights_guard on public.property_media;
create trigger property_media_rights_guard
before insert or update or delete on public.property_media
for each row execute function public.guard_property_media_rights();

revoke all on function public.guard_source_management() from public, anon, authenticated;
grant execute on function public.guard_source_management() to service_role;
