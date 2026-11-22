alter table public.properties
  add column if not exists listing_category text not null default 'real_estate',
  add column if not exists category_details jsonb not null default '{}'::jsonb;
alter table public.properties
  drop constraint if exists properties_listing_category_check;
alter table public.properties
  add constraint properties_listing_category_check
  check (listing_category in ('real_estate','shop','car','motorcycle'));
alter table public.properties
  drop constraint if exists properties_category_details_object_check;
alter table public.properties
  add constraint properties_category_details_object_check
  check (jsonb_typeof(category_details) = 'object');
create index if not exists properties_listing_category_status_idx
  on public.properties (listing_category, status, published_at desc);