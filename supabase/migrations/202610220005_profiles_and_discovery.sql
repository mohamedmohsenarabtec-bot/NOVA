-- Additive evolution. Existing identities, matches and messages are preserved.
alter default privileges in schema public revoke execute on functions from public;
alter default privileges in schema private revoke execute on functions from public;

alter table public.profiles
 add column username text check(username is null or username ~ '^[a-z][a-z0-9_]{2,23}$'),
 add column city text not null default '' check(length(city)<=80),
 add column bio text not null default '' check(length(bio)<=600),
 add column languages text[] not null default '{}' check(cardinality(languages)<=10),
 add column details jsonb not null default '{}' check(jsonb_typeof(details)='object' and length(details::text)<=4000),
 add column public_fields text[] not null default array['city','bio','interests','intention','languages','username'],
 add column filters jsonb not null default '{}' check(jsonb_typeof(filters)='object'),
 add column updated_at timestamptz not null default now();
create unique index profiles_username on public.profiles(lower(username)) where username is not null;

create table public.profile_photos(
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references public.profiles on delete cascade,
 path text not null unique, visibility text not null default 'public' check(visibility in ('public','matches','private')),
 position integer not null default 0 check(position between 0 and 5), ready boolean not null default false,
 created_at timestamptz not null default now(), check(path like owner_id::text||'/%')
);
alter table public.profile_photos enable row level security;
create index profile_photos_owner on public.profile_photos(owner_id,position) where ready;
create table public.favorites(
 user_id uuid not null references public.profiles on delete cascade,
 target_id uuid not null references public.profiles on delete cascade,
 created_at timestamptz not null default now(), primary key(user_id,target_id), check(user_id<>target_id)
);
alter table public.favorites enable row level security;
create policy favorites_private on public.favorites for select to authenticated using(user_id=auth.uid());
grant select on public.favorites,public.profile_photos to authenticated;

create function private.tier(who uuid) returns text language sql stable security definer set search_path='' as $$
 select case when exists(select 1 from public.entitlements where user_id=who and feature='premium' and expires_at>now()) then 'premium'
 when exists(select 1 from public.entitlements where user_id=who and feature='plus' and expires_at>now()) then 'plus' else 'free' end;
$$;
create function private.profile_completion(p public.profiles) returns integer language sql immutable set search_path='' as $$
 select (case when length(trim(p.display_name))>=2 then 20 else 0 end + case when p.onboarding_complete then 20 else 0 end
 +case when p.bio<>'' then 15 else 0 end +case when p.city<>'' then 10 else 0 end
 +case when cardinality(p.interests)>0 then 15 else 0 end +case when cardinality(p.languages)>0 then 10 else 0 end
 +case when p.details<>'{}'::jsonb then 10 else 0 end);
$$;
create function private.may_view_profile(viewer uuid,target uuid) returns boolean language sql stable security definer set search_path='' as $$
 select viewer is not null and (viewer=target or (
 private.is_active(viewer) and private.is_active(target) and not private.is_blocked(viewer,target)
 and (private.eligible(viewer,target) or exists(select 1 from public.matches m where least(viewer,target)=m.user_a and greatest(viewer,target)=m.user_b))));
$$;
create function private.may_read_photo(photo public.profile_photos) returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid()=photo.owner_id or (photo.ready and private.may_view_profile(auth.uid(),photo.owner_id)
 and (photo.visibility='public' or (photo.visibility='matches' and exists(select 1 from public.matches m where m.user_a=least(auth.uid(),photo.owner_id) and m.user_b=greatest(auth.uid(),photo.owner_id)))));
$$;
create policy photos_visible on public.profile_photos for select to authenticated using(private.may_read_photo(profile_photos));
grant execute on function private.may_read_photo(public.profile_photos) to authenticated;

create function private.profile_projection(p public.profiles) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',p.id,'display_name',p.display_name,'age',extract(year from age(p.birth_date))::int,'verified',p.verified,'completion',private.profile_completion(p),'is_favorite',exists(select 1 from public.favorites f where f.user_id=auth.uid() and f.target_id=p.id),'is_match',exists(select 1 from public.matches m where m.user_a=least(auth.uid(),p.id) and m.user_b=greatest(auth.uid(),p.id)),
 'photos',coalesce((select jsonb_agg(jsonb_build_object('id',x.id,'path',x.path,'visibility',x.visibility,'position',x.position) order by x.position,x.created_at) from public.profile_photos x where x.owner_id=p.id and x.ready and private.may_read_photo(x)),'[]'::jsonb))
 || case when 'city'=any(p.public_fields) then jsonb_build_object('city',p.city) else '{}' end
 || case when 'bio'=any(p.public_fields) then jsonb_build_object('bio',p.bio) else '{}' end
 || case when 'username'=any(p.public_fields) then jsonb_build_object('username',p.username) else '{}' end
 || case when 'intention'=any(p.public_fields) then jsonb_build_object('intention',p.intention) else '{}' end
 || case when 'interests'=any(p.public_fields) then jsonb_build_object('interests',p.interests) else '{}' end
 || case when 'languages'=any(p.public_fields) then jsonb_build_object('languages',p.languages) else '{}' end
 || jsonb_build_object('details',coalesce((select jsonb_object_agg(key,value) from jsonb_each(p.details) where key=any(p.public_fields)),'{}'::jsonb));
$$;
create function public.public_profile(target uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if not private.may_view_profile(auth.uid(),target) then raise exception 'Profile unavailable'; end if;
 return (select private.profile_projection(p) from public.profiles p where id=target);
end; $$;

-- Preserve the old validated onboarding writer; the wrapper adds bounded fields.
alter function public.save_profile(jsonb) rename to save_profile_core;
revoke execute on function public.save_profile_core(jsonb) from authenticated,anon,public;
create function public.save_profile(data jsonb) returns void language plpgsql security definer set search_path='' as $$
declare key text; value jsonb; dob date;
begin
 if not private.is_active(auth.uid()) then raise exception 'Account unavailable'; end if;
 if data ? 'birth_date' then
  dob:=(data->>'birth_date')::date;
  if dob is null or dob> (current_date-interval '18 years')::date or dob<current_date-interval '120 years' then raise exception 'Adults 18+ only'; end if;
 end if;
 if data ? 'details' then
  if jsonb_typeof(data->'details')<>'object' then raise exception 'Invalid profile details'; end if;
  for key,value in select * from jsonb_each(data->'details') loop
   if key not in ('education','occupation','lifestyle','partner','relationship_status') or jsonb_typeof(value)<>'string' or length(value::text)>600 then raise exception 'Invalid optional field'; end if;
  end loop;
 end if;
 if data ? 'public_fields' and exists(select 1 from jsonb_array_elements_text(data->'public_fields') f where f not in ('city','bio','interests','intention','languages','username','education','occupation','lifestyle','partner','relationship_status','gender')) then raise exception 'Invalid privacy field'; end if;
 if exists(select 1 from jsonb_array_elements_text(coalesce(data->'languages','[]')) f where length(f)>40) then raise exception 'Invalid language'; end if;
 perform public.save_profile_core(data);
 update public.profiles set username=case when data ? 'username' then nullif(lower(trim(data->>'username')),'') else username end,
 city=coalesce(trim(data->>'city'),city),bio=coalesce(trim(data->>'bio'),bio),birth_date=coalesce(dob,birth_date),
 languages=case when data ? 'languages' then array(select jsonb_array_elements_text(data->'languages')) else languages end,
 details=coalesce(data->'details',details),public_fields=case when data ? 'public_fields' then array(select jsonb_array_elements_text(data->'public_fields')) else public_fields end, updated_at=now()
 where id=auth.uid();
end; $$;

create function public.save_discovery_filters(data jsonb) returns void language plpgsql security definer set search_path='' as $$
begin
 if not private.is_active(auth.uid()) or jsonb_typeof(data)<>'object' then raise exception 'Invalid filters'; end if;
 if length(data::text)>2000 or exists(select 1 from jsonb_object_keys(data) k where k not in ('city','gender','intention','interests','languages','min_completion','has_photo','verified')) then raise exception 'Invalid filters'; end if;
 if private.tier(auth.uid())='free' and (coalesce(data->>'min_completion','0')::int>0 or coalesce((data->>'has_photo')::boolean,false) or coalesce((data->>'verified')::boolean,false) or coalesce(jsonb_array_length(data->'interests'),0)>0 or coalesce(jsonb_array_length(data->'languages'),0)>0) then raise exception 'Advanced filters require Plus'; end if;
 if coalesce(data->>'gender','any') not in ('any','woman','man','nonbinary') or coalesce((data->>'min_completion')::int,0) not between 0 and 100 then raise exception 'Invalid filters'; end if;
 update public.profiles set filters=data,updated_at=now() where id=auth.uid();
end; $$;
create function public.discover_profiles(page_offset integer default 0) returns setof jsonb language sql stable security definer set search_path='' as $$
 select private.profile_projection(p) from public.profiles p cross join public.profiles me
 where me.id=auth.uid() and private.eligible(me.id,p.id)
 and not exists(select 1 from public.matches m where m.user_a=least(me.id,p.id) and m.user_b=greatest(me.id,p.id))
 and not exists(select 1 from public.discovery_actions d where d.actor_id=me.id and d.target_id=p.id)
 and (coalesce(me.filters->>'city','')='' or ('city'=any(p.public_fields) and lower(p.city)=lower(me.filters->>'city')))
 and (coalesce(me.filters->>'gender','any')='any' or p.gender=me.filters->>'gender')
 and (coalesce(me.filters->>'intention','')='' or p.intention=me.filters->>'intention')
 and (private.tier(me.id)='free' or (
   (coalesce((me.filters->>'min_completion')::int,0)<=private.profile_completion(p))
   and (not coalesce((me.filters->>'has_photo')::boolean,false) or exists(select 1 from public.profile_photos ph where ph.owner_id=p.id and ph.visibility='public' and ph.ready))
   and (not coalesce((me.filters->>'verified')::boolean,false) or p.verified)
   and (coalesce(jsonb_array_length(me.filters->'interests'),0)=0 or ('interests'=any(p.public_fields) and p.interests && array(select jsonb_array_elements_text(me.filters->'interests'))))
   and (coalesce(jsonb_array_length(me.filters->'languages'),0)=0 or ('languages'=any(p.public_fields) and p.languages && array(select jsonb_array_elements_text(me.filters->'languages'))))
 )) order by p.updated_at desc,p.id limit 20 offset greatest(0,least(page_offset,10000));
$$;
create function public.discovery_summary() returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('ready',p.onboarding_complete,'visible',p.visible,'completion',private.profile_completion(p),'active_matches',(select count(*) from public.matches m where auth.uid() in(m.user_a,m.user_b)),'filters',p.filters) from public.profiles p where id=auth.uid();
$$;
create function public.toggle_favorite(target uuid,enabled boolean) returns void language plpgsql security definer set search_path='' as $$
begin
 if enabled then
  if target=auth.uid() or not private.may_view_profile(auth.uid(),target) then raise exception 'Profile unavailable'; end if;
  insert into public.favorites(user_id,target_id) values(auth.uid(),target) on conflict do nothing;
 else delete from public.favorites where user_id=auth.uid() and target_id=target;
 end if;
end; $$;
create function public.favorite_profiles() returns setof jsonb language sql stable security definer set search_path='' as $$
 select private.profile_projection(p) from public.favorites f join public.profiles p on p.id=f.target_id where f.user_id=auth.uid() and private.may_view_profile(auth.uid(),p.id) order by f.created_at desc limit 100;
$$;

-- Private storage: authenticated downloads check authorization on EVERY request.
create policy profile_photo_download on storage.objects for select to authenticated using(bucket_id='private-media' and exists(select 1 from public.profile_photos p where p.path=name and private.may_read_photo(p)));
create policy profile_photo_upload on storage.objects for insert to authenticated with check(bucket_id='private-media' and private.is_active(auth.uid()) and exists(select 1 from public.profile_photos p where p.path=name and p.owner_id=auth.uid() and not p.ready));
create policy profile_photo_delete on storage.objects for delete to authenticated using(bucket_id='private-media' and (storage.foldername(name))[1]=auth.uid()::text);
create function public.prepare_profile_photo(photo_visibility text) returns jsonb language plpgsql security definer set search_path='' as $$
declare photo public.profile_photos; new_id uuid:=gen_random_uuid();
begin
 perform 1 from public.profiles where id=auth.uid() for update;
 if not private.is_active(auth.uid()) or photo_visibility not in ('public','matches','private') then raise exception 'Invalid photo'; end if;
 if (select count(*) from public.profile_photos where owner_id=auth.uid())>=6 then raise exception 'Photo limit reached'; end if;
 insert into public.profile_photos(id,owner_id,path,visibility,position) values(new_id,auth.uid(),auth.uid()::text||'/'||new_id::text||'.jpg',photo_visibility,coalesce((select least(max(position)+1,5) from public.profile_photos where owner_id=auth.uid()),0)) returning * into photo;
 return to_jsonb(photo);
end; $$;
create function public.finalize_profile_photo(photo_id uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.profile_photos p join storage.objects o on o.name=p.path and o.bucket_id='private-media' where p.id=photo_id and p.owner_id=auth.uid() and (o.metadata->>'size')::bigint between 1 and 5242880 and o.metadata->>'mimetype'='image/jpeg') then raise exception 'Upload not completed or invalid file'; end if;
 update public.profile_photos set ready=true where id=photo_id and owner_id=auth.uid();
end; $$;
create function public.manage_profile_photos(photo_id uuid default null,photo_visibility text default null,ordered_ids uuid[] default null,remove_photo boolean default false) returns void language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.profiles where id=auth.uid() for update;
 if photo_id is not null and not exists(select 1 from public.profile_photos where id=photo_id and owner_id=auth.uid()) then raise exception 'Photo unavailable'; end if;
 if remove_photo then
  if exists(select 1 from storage.objects o join public.profile_photos p on p.path=o.name where p.id=photo_id and o.bucket_id='private-media') then raise exception 'Remove uploaded object first'; end if;
  delete from public.profile_photos where id=photo_id and owner_id=auth.uid();
 elsif photo_visibility is not null then update public.profile_photos set visibility=photo_visibility where id=photo_id and owner_id=auth.uid();
 end if;
 if ordered_ids is not null then
  if cardinality(ordered_ids)<>(select count(*) from public.profile_photos where owner_id=auth.uid()) or cardinality(ordered_ids)<>(select count(distinct x) from unnest(ordered_ids) x) or exists(select 1 from unnest(ordered_ids) x where not exists(select 1 from public.profile_photos p where p.id=x and p.owner_id=auth.uid())) then raise exception 'Invalid photo ordering'; end if;
  update public.profile_photos p set position=q.n-1 from unnest(ordered_ids) with ordinality q(id,n) where p.id=q.id and p.owner_id=auth.uid();
 end if;
end; $$;

grant execute on function public.save_profile(jsonb),public.public_profile(uuid),public.save_discovery_filters(jsonb),public.discover_profiles(integer),public.discovery_summary(),public.toggle_favorite(uuid,boolean),public.favorite_profiles(),public.prepare_profile_photo(text),public.finalize_profile_photo(uuid),public.manage_profile_photos(uuid,text,uuid[],boolean) to authenticated;

-- Older clients receive the same privacy projection, never newly hidden fields.
create or replace function public.discover(page_offset integer default 0) returns table(id uuid, display_name text, age integer, intention text, interests text[], verified boolean, shared_interests bigint) language sql stable security definer set search_path='' as $$
 select p.id,p.display_name,extract(year from age(p.birth_date))::integer,
 case when 'intention'=any(p.public_fields) then p.intention else null end,
 case when 'interests'=any(p.public_fields) then p.interests else '{}'::text[] end,p.verified,
 case when 'interests'=any(p.public_fields) then (select count(*) from (select unnest(p.interests) intersect select unnest(me.interests)) x) else 0 end
 from public.profiles p cross join public.profiles me where me.id=auth.uid() and private.eligible(me.id,p.id)
 and not exists(select 1 from public.discovery_actions d where d.actor_id=me.id and d.target_id=p.id)
 order by p.id limit 20 offset greatest(0,least(page_offset,10000));
$$;

-- Close project-specific default API grants within this migration transaction.
do $$ declare fn text; begin
 for fn in select p.oid::regprocedure::text from pg_proc p join pg_namespace n on n.oid=p.pronamespace where
 (n.nspname='private' and p.proname in ('tier','profile_completion','may_view_profile','may_read_photo','profile_projection')) or
 (n.nspname='public' and p.proname in ('save_profile_core','save_profile','public_profile','save_discovery_filters','discover_profiles','discovery_summary','toggle_favorite','favorite_profiles','prepare_profile_photo','finalize_profile_photo','manage_profile_photos'))
 loop execute 'revoke all on function '||fn||' from public,anon,authenticated'; end loop;
end $$;
grant execute on function private.may_read_photo(public.profile_photos),public.save_profile(jsonb),public.public_profile(uuid),public.save_discovery_filters(jsonb),public.discover_profiles(integer),public.discovery_summary(),public.toggle_favorite(uuid,boolean),public.favorite_profiles(),public.prepare_profile_photo(text),public.finalize_profile_photo(uuid),public.manage_profile_photos(uuid,text,uuid[],boolean) to authenticated;
