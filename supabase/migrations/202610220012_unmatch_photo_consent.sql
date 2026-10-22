-- Ending a match withdraws access to match-restricted photos as well as chat.
-- Existing conversations/objects remain stored; no data is deleted.
create or replace function private.may_read_photo(photo public.profile_photos) returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid()=photo.owner_id or (photo.ready and private.may_view_profile(auth.uid(),photo.owner_id)
 and (photo.visibility='public' or (photo.visibility='matches' and exists(select 1 from public.matches m where m.ended_at is null and m.user_a=least(auth.uid(),photo.owner_id) and m.user_b=greatest(auth.uid(),photo.owner_id)))));
$$;
create or replace function private.profile_projection(p public.profiles) returns jsonb language sql stable security definer set search_path='' as $$
 select private.profile_projection_core(p)||jsonb_build_object('is_test_account',p.is_test_account,'is_match',exists(select 1 from public.matches m where m.ended_at is null and m.user_a=least(auth.uid(),p.id) and m.user_b=greatest(auth.uid(),p.id)));
$$;
