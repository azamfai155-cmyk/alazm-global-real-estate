-- Move role lookup helpers out of the exposed public API schema.
create schema if not exists private authorization postgres;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated, service_role;

create or replace function private.current_role()
returns public.app_role
language sql
stable
security definer
set search_path = ''
as $function$
  select p.role from public.profiles as p
  where p.id = (select auth.uid()) and p.active = true
$function$;

create or replace function private.has_any_role(allowed public.app_role[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select coalesce(private.current_role() = any(allowed), false)
$function$;

revoke all on function private.current_role() from public, anon, authenticated;
grant execute on function private.current_role() to service_role;
revoke all on function private.has_any_role(public.app_role[]) from public, anon;
grant execute on function private.has_any_role(public.app_role[]) to authenticated, service_role;

create or replace function public.guard_ai_employee_task_updates()
returns trigger language plpgsql security definer set search_path = ''
as $function$
declare actor_role public.app_role;
begin
  if auth.uid() is null then return new; end if;
  actor_role := private.current_role();
  if new.employee_id is distinct from old.employee_id
     or new.title is distinct from old.title
     or new.instructions is distinct from old.instructions
     or new.input_data is distinct from old.input_data
     or new.priority is distinct from old.priority
     or new.created_by is distinct from old.created_by
     or new.created_at is distinct from old.created_at then
    raise exception 'Task definition and provenance are immutable' using errcode = '42501';
  end if;
  if new.result is distinct from old.result
     or new.error_message is distinct from old.error_message
     or new.started_at is distinct from old.started_at
     or new.completed_at is distinct from old.completed_at then
    raise exception 'Execution output and timestamps are server-managed' using errcode = '42501';
  end if;
  if (new.reviewed_by is distinct from old.reviewed_by or new.reviewed_at is distinct from old.reviewed_at)
     and actor_role is distinct from 'owner'::public.app_role then
    raise exception 'Only the company owner can record task review' using errcode = '42501';
  end if;
  if new.status is distinct from old.status then
    if actor_role is distinct from 'owner'::public.app_role then
      raise exception 'Only the company owner can change task status' using errcode = '42501';
    end if;
    if not ((old.status = 'queued' and new.status = 'cancelled')
      or (old.status = 'needs_review' and new.status in ('completed','cancelled'))
      or (old.status = 'failed' and new.status in ('queued','cancelled'))) then
      raise exception 'Invalid task status transition' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$function$;

create or replace function public.guard_profile_privilege_changes()
returns trigger language plpgsql security definer set search_path = ''
as $function$
begin
  if (new.role is distinct from old.role or new.active is distinct from old.active)
     and auth.uid() is not null
     and private.current_role() is distinct from 'owner'::public.app_role then
    raise exception 'Only the company owner can change profile roles or activation status' using errcode = '42501';
  end if;
  return new;
end;
$function$;

-- Replace public.current_role() with private.current_role() in publication/source/media guards.
create or replace function public.guard_property_publication()
returns trigger language plpgsql security definer set search_path = ''
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
  if auth.uid() is null then raise exception 'Authenticated user context is required for property changes' using errcode = '42501'; end if;
  actor_role := private.current_role();
  if (tg_op = 'INSERT' and (new.permission_confirmed or new.permission_reference is not null or new.permission_checked_by is not null or new.permission_checked_at is not null))
     or (tg_op = 'UPDATE' and (new.permission_confirmed is distinct from old.permission_confirmed
       or new.permission_reference is distinct from old.permission_reference
       or new.permission_checked_by is distinct from old.permission_checked_by
       or new.permission_checked_at is distinct from old.permission_checked_at)) then
    if actor_role is null or actor_role not in ('owner','admin','reviewer') then raise exception 'Only owner, admin, or reviewer may verify property reuse rights' using errcode = '42501'; end if;
  end if;
  if new.permission_confirmed then
    if nullif(btrim(coalesce(new.permission_reference,'')), '') is null or new.permission_checked_by is null
       or new.permission_checked_at is null or new.permission_checked_by is distinct from auth.uid() then
      raise exception 'Verified reuse rights require a reference and the current reviewer identity and timestamp' using errcode = '23514';
    end if;
    select s.active,s.permission_scope,s.permission_reference,s.verified_by,s.verified_at,s.permission_valid_until
      into source_active,source_scope,source_permission_reference,source_verified_by,source_verified_at,source_permission_valid_until
      from public.sources s where s.id=new.source_id;
    if coalesce(source_active,false) is not true or nullif(btrim(coalesce(source_scope,'')), '') is null
       or nullif(btrim(coalesce(source_permission_reference,'')), '') is null or source_verified_by is null
       or source_verified_at is null or (source_permission_valid_until is not null and source_permission_valid_until < current_date) then
      raise exception 'The source must be active, verified, in date, and have documented permission scope and reference' using errcode = '23514';
    end if;
  end if;
  if new.status = 'published' then
    if actor_role is distinct from 'owner'::public.app_role and (tg_op = 'INSERT' or new.status is distinct from old.status) then
      raise exception 'Only the company owner may publish a property' using errcode = '42501';
    end if;
    if not new.permission_confirmed then raise exception 'Property cannot remain published without verified reuse rights' using errcode = '23514'; end if;
    if new.suspicious or new.duplicate_of is not null then raise exception 'Suspicious or duplicate properties cannot be published' using errcode = '23514'; end if;
    select s.active,s.permission_scope,s.permission_reference,s.verified_by,s.verified_at,s.permission_valid_until
      into source_active,source_scope,source_permission_reference,source_verified_by,source_verified_at,source_permission_valid_until
      from public.sources s where s.id=new.source_id;
    if coalesce(source_active,false) is not true or nullif(btrim(coalesce(source_scope,'')), '') is null
       or nullif(btrim(coalesce(source_permission_reference,'')), '') is null or source_verified_by is null
       or source_verified_at is null or (source_permission_valid_until is not null and source_permission_valid_until < current_date) then
      raise exception 'Published property requires a currently active, verified, authorized source' using errcode = '23514';
    end if;
    if exists (select 1 from public.property_media m where m.property_id=new.id
      and (not m.rights_confirmed or nullif(btrim(coalesce(m.rights_reference,'')), '') is null)) then
      raise exception 'Every attached media item must have verified reuse rights before publication' using errcode = '23514';
    end if;
    new.published_at := coalesce(new.published_at,now());
  else new.published_at := null;
  end if;
  if tg_op='UPDATE' and old.status='published' and (actor_role is null or actor_role not in ('owner','admin')) then
    raise exception 'Only owner or admin may edit a published property' using errcode = '42501';
  end if;
  return new;
end;
$function$;

create or replace function public.guard_property_media_rights()
returns trigger language plpgsql security definer set search_path = ''
as $function$
declare actor_role public.app_role; parent_status public.property_status; parent_id uuid;
begin
  if auth.uid() is null then raise exception 'Authenticated user context is required for property media changes' using errcode = '42501'; end if;
  actor_role := private.current_role();
  if tg_op='DELETE' then
    parent_id := old.property_id;
    select p.status into parent_status from public.properties p where p.id=parent_id;
    if actor_role is null or actor_role not in ('owner','admin') then raise exception 'Only owner or admin may delete property media' using errcode = '42501'; end if;
    return old;
  end if;
  parent_id := new.property_id;
  select p.status into parent_status from public.properties p where p.id=parent_id;
  if parent_status='published' and (actor_role is null or actor_role not in ('owner','admin')) then
    raise exception 'Only owner or admin may change media on a published property' using errcode = '42501';
  end if;
  if parent_status='published' and (not new.rights_confirmed or nullif(btrim(coalesce(new.rights_reference,'')), '') is null) then
    raise exception 'Published properties cannot contain media without verified reuse rights' using errcode = '23514';
  end if;
  if new.rights_confirmed and (actor_role is null or actor_role not in ('owner','admin','reviewer')) then
    raise exception 'Only owner, admin, or reviewer may verify media reuse rights' using errcode = '42501';
  end if;
  if new.rights_confirmed and nullif(btrim(coalesce(new.rights_reference,'')), '') is null then
    raise exception 'Verified media rights require a reference' using errcode = '23514';
  end if;
  return new;
end;
$function$;

create or replace function public.guard_source_management()
returns trigger language plpgsql security definer set search_path = ''
as $function$
declare actor_role public.app_role;
begin
  if auth.uid() is null then raise exception 'Authenticated user context is required for source changes' using errcode = '42501'; end if;
  actor_role := private.current_role();
  if actor_role is null or actor_role not in ('owner','admin') then raise exception 'Only an active owner or admin may manage source records' using errcode = '42501'; end if;
  if tg_op='DELETE' then return old; end if;
  return new;
end;
$function$;

alter policy audit_read_admin on public.audit_logs using (private.has_any_role(array['owner'::public.app_role,'admin'::public.app_role]));
alter policy leads_admin_delete on public.leads using (private.has_any_role(array['owner'::public.app_role,'admin'::public.app_role]));
alter policy leads_admin_insert on public.leads with check (private.has_any_role(array['owner'::public.app_role,'admin'::public.app_role]));
alter policy leads_admin_read on public.leads using (private.has_any_role(array['owner'::public.app_role,'admin'::public.app_role]));
alter policy leads_admin_update on public.leads using (private.has_any_role(array['owner'::public.app_role,'admin'::public.app_role])) with check (private.has_any_role(array['owner'::public.app_role,'admin'::public.app_role]));
alter policy profiles_read_self_or_admin on public.profiles using ((id=(select auth.uid())) or (select private.has_any_role(array['owner'::public.app_role,'admin'::public.app_role])));
alter policy profiles_update_admin on public.profiles using (private.has_any_role(array['owner'::public.app_role,'admin'::public.app_role])) with check (private.has_any_role(array['owner'::public.app_role,'admin'::public.app_role]));
alter policy properties_admin_delete on public.properties using (private.has_any_role(array['owner'::public.app_role,'admin'::public.app_role]));
alter policy properties_agent_insert on public.properties with check (private.has_any_role(array['owner'::public.app_role,'admin'::public.app_role,'reviewer'::public.app_role,'agent'::public.app_role]));
alter policy properties_review_update on public.properties using (private.has_any_role(array['owner'::public.app_role,'admin'::public.app_role,'reviewer'::public.app_role])) with check (private.has_any_role(array['owner'::public.app_role,'admin'::public.app_role,'reviewer'::public.app_role]));
alter policy properties_staff_read on public.properties using (private.has_any_role(array['owner'::public.app_role,'admin'::public.app_role,'reviewer'::public.app_role,'agent'::public.app_role,'support'::public.app_role]));
alter policy media_admin_manage on public.property_media using (private.has_any_role(array['owner'::public.app_role,'admin'::public.app_role]));
alter policy media_agent_insert on public.property_media with check (private.has_any_role(array['owner'::public.app_role,'admin'::public.app_role,'reviewer'::public.app_role,'agent'::public.app_role]));
alter policy media_staff_read on public.property_media using (private.has_any_role(array['owner'::public.app_role,'admin'::public.app_role,'reviewer'::public.app_role,'agent'::public.app_role,'support'::public.app_role]));
alter policy sources_admin_manage on public.sources using (private.has_any_role(array['owner'::public.app_role,'admin'::public.app_role])) with check (private.has_any_role(array['owner'::public.app_role,'admin'::public.app_role]));
alter policy sources_staff_read on public.sources using (private.has_any_role(array['owner'::public.app_role,'admin'::public.app_role,'reviewer'::public.app_role,'agent'::public.app_role,'support'::public.app_role]));

revoke all on function public.current_role() from public,anon,authenticated;
grant execute on function public.current_role() to service_role;
revoke all on function public.has_any_role(public.app_role[]) from public,anon,authenticated;
grant execute on function public.has_any_role(public.app_role[]) to service_role;
