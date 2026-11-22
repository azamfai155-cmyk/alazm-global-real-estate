-- Consolidate overlapping SELECT policies without broadening access.
drop policy if exists properties_staff_read on public.properties;
drop policy if exists public_published_properties on public.properties;

create policy properties_select_access
on public.properties
for select
to anon, authenticated
using (
  (
    status = 'published'
    and permission_confirmed = true
    and suspicious = false
    and duplicate_of is null
    and exists (
      select 1 from public.sources s
      where s.id = properties.source_id
        and s.active = true
        and nullif(btrim(coalesce(s.permission_scope,'')), '') is not null
        and nullif(btrim(coalesce(s.permission_reference,'')), '') is not null
        and s.verified_by is not null
        and s.verified_at is not null
        and (s.permission_valid_until is null or s.permission_valid_until >= current_date)
    )
  )
  or (
    auth.uid() is not null
    and private.has_any_role(array['owner'::public.app_role,'admin'::public.app_role,'reviewer'::public.app_role,'agent'::public.app_role,'support'::public.app_role])
  )
);

drop policy if exists sources_admin_manage on public.sources;

create policy sources_admin_insert
on public.sources for insert to authenticated
with check (private.has_any_role(array['owner'::public.app_role,'admin'::public.app_role]));

create policy sources_admin_update
on public.sources for update to authenticated
using (private.has_any_role(array['owner'::public.app_role,'admin'::public.app_role]))
with check (private.has_any_role(array['owner'::public.app_role,'admin'::public.app_role]));

create policy sources_admin_delete
on public.sources for delete to authenticated
using (private.has_any_role(array['owner'::public.app_role,'admin'::public.app_role]));
