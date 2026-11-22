do $migration$
declare
  v_definition text;
begin
  select pg_catalog.pg_get_functiondef(
    'public.approve_ai_property_workflow_step(uuid,uuid)'::regprocedure
  ) into v_definition;
  v_definition := pg_catalog.replace(
    v_definition,
    'v_current_step.status <> ''needs_review''',
    'v_current_step.status not in (''queued'',''running'',''needs_review'')'
  );
  if v_definition not like '%v_current_step.status not in (%' then
    raise exception 'Could not safely update workflow step state validation';
  end if;
  execute v_definition;
end;
$migration$;
