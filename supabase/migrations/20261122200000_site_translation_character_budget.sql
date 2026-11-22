alter table private.site_translation_rate_limits
  add column if not exists day_char_window_started_at timestamptz not null default now(),
  add column if not exists day_char_count integer not null default 0;

create or replace function public.reserve_site_translation_chars(
  p_ip_hash text,
  p_char_count integer
)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog, private
as $function$
declare
  v_now timestamptz := clock_timestamp();
  v_allowed boolean := false;
begin
  if p_ip_hash is null or p_ip_hash !~ '^[0-9a-f]{64}$'
     or p_char_count is null or p_char_count < 1 or p_char_count > 450 then
    return false;
  end if;

  delete from private.site_translation_rate_limits
  where updated_at < v_now - interval '48 hours';

  insert into private.site_translation_rate_limits as current_limit (
    ip_hash, minute_window_started_at, minute_count,
    day_window_started_at, day_count,
    day_char_window_started_at, day_char_count, updated_at
  ) values (
    p_ip_hash, v_now, 0, v_now, 0, v_now, p_char_count, v_now
  )
  on conflict (ip_hash) do update
    set day_char_window_started_at = case
          when current_limit.day_char_window_started_at <= v_now - interval '24 hours' then v_now
          else current_limit.day_char_window_started_at
        end,
        day_char_count = case
          when current_limit.day_char_window_started_at <= v_now - interval '24 hours' then p_char_count
          else current_limit.day_char_count + p_char_count
        end,
        updated_at = v_now
  returning (current_limit.day_char_count <= 4500)
  into v_allowed;

  return coalesce(v_allowed, false);
end;
$function$;

revoke all on function public.reserve_site_translation_chars(text, integer) from public, anon, authenticated;
grant execute on function public.reserve_site_translation_chars(text, integer) to service_role;