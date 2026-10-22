-- Other viewers use the fresh-RLS Edge gateway; direct storage reads remain
-- owner-only. This closes stale authorization/cache reads following a block.
drop policy profile_photo_download on storage.objects;
create or replace function public.client_capabilities() returns integer language sql stable security invoker set search_path='' as $$select 10;$$;
