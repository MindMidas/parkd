-- Flutter/Supabase Storage uploads often omit object metadata mimetype/size on
-- insert, which made parkd_listing_photos_insert (and avatars) reject valid
-- JPEGs with HTTP 400. Bucket allowed_mime_types + path extension checks remain.

drop policy if exists "parkd_listing_photos_insert" on storage.objects;
create policy "parkd_listing_photos_insert" on storage.objects for insert
with check (
  bucket_id = 'listing-photos'
  and split_part(name, '/', 1) = auth.uid()::text
  and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/[^/]+\.(jpg|jpeg|png|webp)$'
  and exists (
    select 1 from public.listings l
    where l.id = split_part(name, '/', 2)::uuid
      and l.host_id = auth.uid()
      and l.deleted_at is null
  )
);

drop policy if exists "parkd_avatars_insert" on storage.objects;
create policy "parkd_avatars_insert" on storage.objects for insert
with check (
  bucket_id = 'avatars'
  and split_part(name, '/', 1) = auth.uid()::text
  and name ~ '^[0-9a-f-]{36}/[^/]+\.(jpg|jpeg|png|webp)$'
);
