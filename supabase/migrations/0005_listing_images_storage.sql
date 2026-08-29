-- Storage bucket for listing images (FR-08). Not flagged "public" at the bucket level -
-- read access is RLS-gated on storage.objects instead, so pending/rejected listings'
-- images stay hidden the same way the listings row itself does (DR-07).
--
-- Path convention: {provider_id}/{listing_id}/{filename}

insert into storage.buckets (id, name, public)
values ('listing-images', 'listing-images', false)
on conflict (id) do nothing;

create policy "listing_images_storage_select"
on storage.objects for select
to anon, authenticated
using (
  bucket_id = 'listing-images'
  and (
    (storage.foldername(name))[1] = auth.uid()::text
    or public.is_admin()
    or exists (
      select 1 from public.listings l
      where l.id::text = (storage.foldername(name))[2]
        and l.status = 'approved' and l.is_active
    )
  )
);

create policy "listing_images_storage_write"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'listing-images'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "listing_images_storage_update"
on storage.objects for update
to authenticated
using (bucket_id = 'listing-images' and (storage.foldername(name))[1] = auth.uid()::text)
with check (bucket_id = 'listing-images' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "listing_images_storage_delete"
on storage.objects for delete
to authenticated
using (bucket_id = 'listing-images' and (storage.foldername(name))[1] = auth.uid()::text);
