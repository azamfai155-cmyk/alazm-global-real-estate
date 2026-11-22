create table if not exists private.site_translation_rate_limits (
  ip_hash text primary key check (ip_hash ~ '^[0-9a-f]{64}$'),
  minute_window_started_at timestamptz not null,
  minute_count integer not null check (minute_count >= 0),
  day_window_started_at timestamptz not null,
  day_count integer not null check (day_count >= 0),
  updated_at timestamptz not null default now()
);

revoke all on table private.site_translation_rate_limits from public, anon, authenticated, service_role;

create or replace function public.allow_site_translation(p_ip_hash text)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog, private
as $function$
declare
  v_now timestamptz := clock_timestamp();
  v_allowed boolean := false;
begin
  if p_ip_hash is null or p_ip_hash !~ '^[0-9a-f]{64}$' then
    return false;
  end if;

  delete from private.site_translation_rate_limits
  where updated_at < v_now - interval '48 hours';

  insert into private.site_translation_rate_limits as current_limit (
    ip_hash, minute_window_started_at, minute_count,
    day_window_started_at, day_count, updated_at
  ) values (
    p_ip_hash, v_now, 1, v_now, 1, v_now
  )
  on conflict (ip_hash) do update
    set minute_window_started_at = case
          when current_limit.minute_window_started_at <= v_now - interval '1 minute' then v_now
          else current_limit.minute_window_started_at
        end,
        minute_count = case
          when current_limit.minute_window_started_at <= v_now - interval '1 minute' then 1
          else current_limit.minute_count + 1
        end,
        day_window_started_at = case
          when current_limit.day_window_started_at <= v_now - interval '24 hours' then v_now
          else current_limit.day_window_started_at
        end,
        day_count = case
          when current_limit.day_window_started_at <= v_now - interval '24 hours' then 1
          else current_limit.day_count + 1
        end,
        updated_at = v_now
  returning (current_limit.minute_count <= 60 and current_limit.day_count <= 1000)
  into v_allowed;

  return coalesce(v_allowed, false);
end;
$function$;

revoke all on function public.allow_site_translation(text) from public, anon, authenticated;
grant execute on function public.allow_site_translation(text) to service_role;