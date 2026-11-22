-- Keep source rows private while allowing public-property RLS to verify
-- that a property's source still has current reuse permission.
create or replace function private.is_property_source_public(p_source_id uuid)
returns boolean language sql stable security definer set search_path = ''
as $function$
  select exists (
    select 1 from public.sources s
    where s.id=p_source_id and s.active=true
      and nullif(btrim(coalesce(s.permission_scope,'')),'') is not null
      and nullif(btrim(coalesce(s.permission_reference,'')),'') is not null
      and s.verified_by is not null and s.verified_at is not null
      and (s.permission_valid_until is null or s.permission_valid_until>=current_date)
  )
$function$;

revoke all on function private.is_property_source_public(uuid) from public,anon,authenticated;
grant execute on function private.is_property_source_public(uuid) to anon,authenticated,service_role;

alter policy properties_select_access on public.properties
using (
  (
    status='published'
    and permission_confirmed=true
    and suspicious=false
    and duplicate_of is null
    and private.is_property_source_public(source_id)
  )
  or (
    auth.uid() is not null
    and private.has_any_role(array['owner'::public.app_role,'admin'::public.app_role,'reviewer'::public.app_role,'agent'::public.app_role,'support'::public.app_role])
  )
);
