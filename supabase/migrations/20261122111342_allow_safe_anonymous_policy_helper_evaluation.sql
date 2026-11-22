-- Anonymous property SELECT evaluates the combined policy.
-- The helper returns false for anonymous sessions (auth.uid() is null).
-- The private schema remains outside the PostgREST exposed schema list.
grant usage on schema private to anon;
grant execute on function private.has_any_role(public.app_role[]) to anon;
