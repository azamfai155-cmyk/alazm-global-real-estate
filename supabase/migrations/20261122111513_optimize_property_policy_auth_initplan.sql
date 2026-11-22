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
    (select auth.uid()) is not null
    and private.has_any_role(array['owner'::public.app_role,'admin'::public.app_role,'reviewer'::public.app_role,'agent'::public.app_role,'support'::public.app_role])
  )
);
