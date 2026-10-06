-- Recommended Storage hardening for Budgly.
-- Firebase Auth is the identity provider, so ownership is checked with the
-- Firebase `sub` claim exposed by the Supabase JWT hook.
-- Run this migration in Supabase SQL Editor after verifying that the claim is
-- indeed present in the JWT used by the Flutter client.

-- config-files is intentionally public-read. Client-side write access should
-- not be public; use the Supabase dashboard/service role for administration.
drop policy if exists "Public Access" on storage.objects;
drop policy if exists "Public Insert" on storage.objects;
drop policy if exists "Public Update" on storage.objects;
drop policy if exists "Public Delete" on storage.objects;
drop policy if exists "Authenticated users can view config files" on storage.objects;

create policy "Public can read config files"
on storage.objects
for select
to public
using (bucket_id = 'config-files');

-- Account pictures: the first path segment must be the Firebase UID.
drop policy if exists "Users can upload their own files" on storage.objects;
drop policy if exists "Users can view their own pictures" on storage.objects;
drop policy if exists "Users can update their own pictures" on storage.objects;
drop policy if exists "Users can delete their own pictures" on storage.objects;

create policy "Users can upload their own pictures"
on storage.objects
for insert
to public
with check (
  bucket_id = 'accounts-pictures'
  and auth.jwt() is not null
  and (auth.jwt() ->> 'sub') = split_part(name, '/', 1)
);

create policy "Users can view their own pictures"
on storage.objects
for select
to public
using (
  bucket_id = 'accounts-pictures'
  and auth.jwt() is not null
  and (auth.jwt() ->> 'sub') = split_part(name, '/', 1)
);

create policy "Users can update their own pictures"
on storage.objects
for update
to public
using (
  bucket_id = 'accounts-pictures'
  and auth.jwt() is not null
  and (auth.jwt() ->> 'sub') = split_part(name, '/', 1)
)
with check (
  bucket_id = 'accounts-pictures'
  and auth.jwt() is not null
  and (auth.jwt() ->> 'sub') = split_part(name, '/', 1)
);

create policy "Users can delete their own pictures"
on storage.objects
for delete
to public
using (
  bucket_id = 'accounts-pictures'
  and auth.jwt() is not null
  and (auth.jwt() ->> 'sub') = split_part(name, '/', 1)
);
