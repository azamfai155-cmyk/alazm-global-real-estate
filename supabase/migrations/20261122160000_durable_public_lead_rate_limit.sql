-- Durable, privacy-preserving rate limiting for public lead submissions.
-- Store only a salted SHA-256 hash of the client IP; never store the raw address.
create table if not exists private.lead_submission_rate_limits (
  ip_hash text primary key check (ip_hash ~ '^[0-9a-f]{64}$'),
  last_submission_at timestamptz not null
);

create index if not exists lead_submission_rate_limits_expiry_idx
  on private.lead_submission_rate_limits (last_submission_at);

alter table private.lead_submission_rate_limits enable row level security;
revoke all on table private.lead_submission_rate_limits from public, anon, authenticated;

create or replace function public.allow_public_lead_submission(p_ip_hash text)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog, private
as $$
declare
  v_now timestamptz := clock_timestamp();
  v_allowed boolean := false;
begin
  if p_ip_hash is null or p_ip_hash !~ '^[0-9a-f]{64}$' then
    return false;
  end if;

  delete from private.lead_submission_rate_limits
  where last_submission_at < v_now - interval '24 hours';

  insert into private.lead_submission_rate_limits as current_limit (ip_hash, last_submission_at)
  values (p_ip_hash, v_now)
  on conflict (ip_hash) do update
    set last_submission_at = excluded.last_submission_at
    where current_limit.last_submission_at < v_now - interval '20 seconds'
  returning true into v_allowed;

  return coalesce(v_allowed, false);
end;
$$;

revoke all on function public.allow_public_lead_submission(text) from public, anon, authenticated;
grant execute on function public.allow_public_lead_submission(text) to service_role;
