create table if not exists public.site_translation_cache (
  id bigint generated always as identity primary key,
  source_hash text not null,
  source_lang text not null default 'en',
  target_lang text not null,
  source_text text not null,
  translated_text text not null,
  provider text not null default 'mymemory',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (source_hash, source_lang, target_lang)
);

create index if not exists site_translation_cache_target_idx
  on public.site_translation_cache(target_lang);

alter table public.site_translation_cache enable row level security;

drop policy if exists site_translation_cache_deny_client
  on public.site_translation_cache;

create policy site_translation_cache_deny_client
  on public.site_translation_cache
  for all to anon, authenticated
  using (false) with check (false);

revoke all on public.site_translation_cache from anon, authenticated, public;
grant select, insert, update on public.site_translation_cache to service_role;
grant usage, select on sequence public.site_translation_cache_id_seq to service_role;
