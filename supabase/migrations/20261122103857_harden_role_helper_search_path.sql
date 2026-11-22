-- Harden SECURITY DEFINER role helpers without changing their behavior.
-- All referenced objects are schema-qualified and the search_path is empty.
CREATE OR REPLACE FUNCTION public.current_role()
RETURNS public.app_role
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT p.role
  FROM public.profiles AS p
  WHERE p.id = (SELECT auth.uid())
    AND p.active = true
$function$;

CREATE OR REPLACE FUNCTION public.has_any_role(allowed public.app_role[])
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT COALESCE(public.current_role() = ANY(allowed), false)
$function$;

REVOKE ALL ON FUNCTION public.current_role() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.has_any_role(public.app_role[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.current_role() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.has_any_role(public.app_role[]) TO authenticated, service_role;
