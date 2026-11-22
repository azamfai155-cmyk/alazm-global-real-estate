-- Private property image storage with least-privilege authenticated access.
begin;
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('property-media-private','property-media-private',false,10485760,array['image/jpeg','image/png','image/webp','image/gif']::text[])
on conflict (id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
revoke all privileges on table storage.objects from anon, public;
grant select, insert, delete on table storage.objects to authenticated;
drop policy if exists property_media_private_staff_read on storage.objects;
create policy property_media_private_staff_read on storage.objects for select to authenticated
using (bucket_id='property-media-private' and private.has_any_role(array['owner','admin','reviewer','agent','support']::public.app_role[]) and exists(select 1 from public.properties p where p.id::text=(storage.foldername(name))[1]));
drop policy if exists property_media_private_staff_upload on storage.objects;
create policy property_media_private_staff_upload on storage.objects for insert to authenticated
with check (bucket_id='property-media-private' and private.has_any_role(array['owner','admin','reviewer','agent']::public.app_role[]) and exists(select 1 from public.properties p where p.id::text=(storage.foldername(name))[1]));
drop policy if exists property_media_private_admin_delete on storage.objects;
create policy property_media_private_admin_delete on storage.objects for delete to authenticated
using (bucket_id='property-media-private' and private.has_any_role(array['owner','admin']::public.app_role[]) and exists(select 1 from public.properties p where p.id::text=(storage.foldername(name))[1]));
commit;
