create schema if not exists private;
-- NOVA MVP. Apply only to a new project using the Supabase CLI.
create extension if not exists pgcrypto;

create table public.profiles (
 id uuid primary key references auth.users on delete cascade,
 display_name text not null default '' check (length(display_name)<=40),
 birth_date date not null check (birth_date <= (current_date - interval '18 years')::date),
 gender text not null default 'woman' check (gender in ('woman','man','nonbinary')),
 seeking_gender text not null default 'man' check (seeking_gender in ('woman','man','nonbinary','any')),
 intention text not null default 'serious' check (intention in ('marriage','serious','dating','friendship','social')),
 interests text[] not null default '{}' check (cardinality(interests)<=12),
 min_age integer not null default 18 check (min_age>=18),
 max_age integer not null default 80 check (max_age between min_age and 120),
 visible boolean not null default true,
 status text not null default 'active' check(status in ('active','suspended')),
 verified boolean not null default false,
 onboarding_step integer not null default 0 check(onboarding_step between 0 and 5),
 onboarding_complete boolean not null default false,
 consent_version text not null,
 consent_at timestamptz not null default now(),
 created_at timestamptz not null default now()
);
create index profiles_discovery on public.profiles(intention,gender,birth_date) where visible and status='active' and onboarding_complete;
create table public.staff_roles(user_id uuid references auth.users on delete cascade, role text check(role in ('support','moderator','administrator')), primary key(user_id,role));
create table public.blocks(actor_id uuid references public.profiles on delete cascade, target_id uuid references public.profiles on delete cascade, created_at timestamptz not null default now(), primary key(actor_id,target_id), check(actor_id<>target_id));
create index blocks_target on public.blocks(target_id,actor_id);
create table public.reports(id uuid primary key default gen_random_uuid(), reporter_id uuid not null references public.profiles on delete cascade, subject_id uuid not null references public.profiles on delete cascade, category text not null check(category in ('safety','spam','harassment','underage','fraud')), status text not null default 'pending' check(status in ('pending','dismissed','actioned')), created_at timestamptz not null default now(), check(reporter_id<>subject_id));
create index reports_pending on public.reports(created_at) where status='pending';
create index reports_exclusion on public.reports(reporter_id,subject_id);
create table public.discovery_actions(actor_id uuid references public.profiles on delete cascade, target_id uuid references public.profiles on delete cascade, kind text not null check(kind in ('like','pass')), created_at timestamptz not null default now(), primary key(actor_id,target_id), check(actor_id<>target_id));
create index actions_daily on public.discovery_actions(actor_id,created_at);
create table public.matches(id uuid primary key default gen_random_uuid(), user_a uuid not null references public.profiles on delete cascade, user_b uuid not null references public.profiles on delete cascade, created_at timestamptz not null default now(), unique(user_a,user_b), check(user_a<user_b));
create table public.conversations(id uuid primary key default gen_random_uuid(), match_id uuid not null unique references public.matches on delete cascade, created_at timestamptz not null default now());
create table public.conversation_members(conversation_id uuid references public.conversations on delete cascade, user_id uuid references public.profiles on delete cascade, muted boolean not null default false, archived boolean not null default false, last_read_at timestamptz, primary key(conversation_id,user_id));
create index members_user on public.conversation_members(user_id,conversation_id);
create table public.messages(id uuid primary key default gen_random_uuid(), conversation_id uuid not null references public.conversations on delete cascade, sender_id uuid not null references public.profiles on delete cascade, body text not null check(length(trim(body)) between 1 and 2000), created_at timestamptz not null default now());
create index messages_history on public.messages(conversation_id,created_at desc,id);
create index messages_rate on public.messages(sender_id,created_at desc);
create table public.notifications(id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles on delete cascade, kind text not null check(kind in ('match','message','verification','billing')), reference_id uuid, read_at timestamptz, created_at timestamptz not null default now());
create index notifications_user on public.notifications(user_id,created_at desc);
create table public.support_tickets(id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles on delete cascade, body text not null check(length(trim(body)) between 1 and 2000), status text not null default 'open', created_at timestamptz not null default now());
create table public.admin_audit_logs(id bigint generated always as identity primary key, actor_id uuid, action text not null, subject_id uuid, metadata jsonb not null default '{}', created_at timestamptz not null default now());
create table public.products(id text primary key, name_ar text not null, name_en text not null, description_ar text not null, description_en text not null, active boolean not null default false, sort_order integer not null default 0);
create table public.feature_flags(key text primary key, enabled boolean not null default false, config jsonb not null default '{}');
insert into public.feature_flags values ('discovery',true,'{"daily_limit":50}'),('moments',false,'{}'),('payments',false,'{}'),('push',false,'{}');
create table public.purchases(id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles on delete cascade, provider text not null, event_id text not null, product_id text references public.products, amount_minor bigint not null check(amount_minor>=0), currency text not null check(length(currency)=3), state text not null check(state in ('paid','refunded','cancelled')), created_at timestamptz not null default now(), unique(provider,event_id));
create table public.entitlements(user_id uuid references public.profiles on delete cascade, feature text not null, expires_at timestamptz not null, source_purchase uuid references public.purchases, primary key(user_id,feature));
create table public.subscriptions(id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles on delete cascade, provider text not null, external_id text not null, status text not null, expires_at timestamptz, unique(provider,external_id));
create table public.credit_wallets(user_id uuid primary key references public.profiles on delete cascade, balance bigint not null default 0 check(balance>=0));
create table public.credit_transactions(id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles on delete cascade, delta bigint not null check(delta<>0), idempotency_key text not null unique, reason text not null, created_at timestamptz not null default now());
create table public.device_tokens(id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles on delete cascade, token text not null unique, platform text not null check(platform in ('android','ios','web')), created_at timestamptz not null default now());
create table public.verification_requests(id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles on delete cascade, status text not null default 'pending' check(status in ('pending','approved','rejected')), created_at timestamptz not null default now());
create table public.media_assets(id uuid primary key default gen_random_uuid(), owner_id uuid not null references public.profiles on delete cascade, path text not null unique, status text not null default 'pending' check(status in ('pending','approved','rejected')), created_at timestamptz not null default now());

create function private.is_staff(allowed text[]) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.staff_roles where user_id=auth.uid() and role=any(allowed));
$$;
create function private.is_active(who uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.profiles p join auth.users u on u.id=p.id where p.id=who and p.status='active' and u.email_confirmed_at is not null);
$$;
create function private.is_blocked(a uuid,b uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.blocks where (actor_id=a and target_id=b) or (actor_id=b and target_id=a));
$$;
create function private.can_chat(conversation uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.conversations c join public.matches m on m.id=c.match_id where c.id=conversation and auth.uid() in (m.user_a,m.user_b) and private.is_active(m.user_a) and private.is_active(m.user_b) and not private.is_blocked(m.user_a,m.user_b));
$$;

-- The profile is created by the auth trigger; user metadata can never grant roles.
create function private.on_signup() returns trigger language plpgsql security definer set search_path='' as $$
declare dob date;
begin
 dob := (new.raw_user_meta_data->>'birth_date')::date;
 if dob is null or dob > (current_date-interval '18 years')::date then raise exception 'Adults 18+ only'; end if;
 if new.raw_user_meta_data->>'consent_version' is distinct from 'draft-v1' then raise exception 'Consent required'; end if;
 insert into public.profiles(id,birth_date,consent_version) values(new.id,dob,'draft-v1');
 insert into public.credit_wallets(user_id) values(new.id);
 return new;
end; $$;
create trigger nova_signup after insert on auth.users for each row execute function private.on_signup();

create function public.save_profile(data jsonb) returns void language plpgsql security definer set search_path='' as $$
begin
 if not private.is_active(auth.uid()) then raise exception 'Account unavailable'; end if;
 update public.profiles set
 display_name=coalesce(data->>'display_name',display_name),
 gender=coalesce(data->>'gender',gender), seeking_gender=coalesce(data->>'seeking_gender',seeking_gender),
 intention=coalesce(data->>'intention',intention),
 interests=case when data ? 'interests' then array(select jsonb_array_elements_text(data->'interests')) else interests end,
 min_age=coalesce((data->>'min_age')::integer,min_age), max_age=coalesce((data->>'max_age')::integer,max_age),
 visible=coalesce((data->>'visible')::boolean,visible),
 onboarding_step=coalesce((data->>'onboarding_step')::integer,onboarding_step),
 onboarding_complete=coalesce((data->>'onboarding_complete')::boolean,onboarding_complete)
 where id=auth.uid();
 if exists(select 1 from public.profiles where id=auth.uid() and onboarding_complete and length(trim(display_name))<2) then raise exception 'Display name required'; end if;
end; $$;

create function private.eligible(viewer uuid,target uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.profiles a cross join public.profiles b where a.id=viewer and b.id=target and a.id<>b.id and private.is_active(a.id) and private.is_active(b.id) and a.onboarding_complete and b.onboarding_complete and b.visible
 and (a.seeking_gender='any' or a.seeking_gender=b.gender) and (b.seeking_gender='any' or b.seeking_gender=a.gender)
 and a.intention=b.intention
 and extract(year from age(b.birth_date)) between a.min_age and a.max_age
 and extract(year from age(a.birth_date)) between b.min_age and b.max_age
 and not private.is_blocked(a.id,b.id)
 and not exists(select 1 from public.reports r where (r.reporter_id=a.id and r.subject_id=b.id) or (r.reporter_id=b.id and r.subject_id=a.id)));
$$;
create function public.discover(page_offset integer default 0) returns table(id uuid, display_name text, age integer, intention text, interests text[], verified boolean, shared_interests bigint) language sql stable security definer set search_path='' as $$
 select p.id,p.display_name,extract(year from age(p.birth_date))::integer,p.intention,p.interests,p.verified,
 (select count(*) from (select unnest(p.interests) intersect select unnest(me.interests)) x) as shared_interests
 from public.profiles p cross join public.profiles me
 where me.id=auth.uid() and private.eligible(me.id,p.id)
 and not exists(select 1 from public.discovery_actions d where d.actor_id=me.id and d.target_id=p.id)
 order by shared_interests desc,p.id limit 20 offset greatest(0,least(page_offset,10000));
$$;

create function public.discovery_action(target_id uuid,action_kind text) returns boolean language plpgsql security definer set search_path='' as $$
declare me uuid:=auth.uid(); pair uuid; conv uuid; daily integer;
begin
 if me is null or action_kind not in ('like','pass') then raise exception 'Invalid action'; end if;
 -- Same ordered pair lock prevents concurrent reciprocal likes losing a match.
 perform pg_advisory_xact_lock(hashtextextended(least(me,target_id)::text||greatest(me,target_id)::text,0));
 perform 1 from public.profiles where id=me for update;
 if not private.eligible(me,target_id) then raise exception 'Unavailable profile'; end if;
 if exists(select 1 from public.discovery_actions where actor_id=me and discovery_actions.target_id=discovery_action.target_id) then return false; end if;
 select coalesce((config->>'daily_limit')::integer,50) into daily from public.feature_flags where key='discovery' and enabled;
 if daily is null then raise exception 'Discovery disabled'; end if;
 if (select count(*) from public.discovery_actions where actor_id=me and created_at>=date_trunc('day',now()))>=daily then raise exception 'Daily limit reached'; end if;
 insert into public.discovery_actions(actor_id,target_id,kind) values(me,target_id,action_kind);
 if action_kind='like' and exists(select 1 from public.discovery_actions where actor_id=discovery_action.target_id and discovery_actions.target_id=me and kind='like') then
  insert into public.matches(user_a,user_b) values(least(me,target_id),greatest(me,target_id)) on conflict do nothing returning id into pair;
  if pair is not null then
   insert into public.conversations(match_id) values(pair) returning id into conv;
   insert into public.conversation_members values(conv,me,false,false,null),(conv,target_id,false,false,null);
   insert into public.notifications(user_id,kind,reference_id) values(me,'match',conv),(target_id,'match',conv);
  end if;
  return true;
 end if;
 return false;
end; $$;

create function public.send_message(conversation uuid,body text) returns void language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.profiles where id=auth.uid() for update;
 if not private.can_chat(conversation) then raise exception 'Conversation unavailable'; end if;
 if (select count(*) from public.messages where sender_id=auth.uid() and created_at>now()-interval '1 minute')>=20 then raise exception 'Message rate limit'; end if;
 insert into public.messages(conversation_id,sender_id,body) values(conversation,auth.uid(),trim(body));
 insert into public.notifications(user_id,kind,reference_id) select user_id,'message',conversation from public.conversation_members where conversation_id=conversation and user_id<>auth.uid() and not muted;
end; $$;

create function public.moderation_queue() returns setof public.reports language plpgsql security definer set search_path='' as $$
begin
 if not private.is_staff(array['moderator','administrator']) then raise exception 'Forbidden'; end if;
 return query select * from public.reports where status='pending' order by created_at limit 100;
end; $$;
create function public.moderate_report(report_id uuid,decision text) returns void language plpgsql security definer set search_path='' as $$
declare subject uuid;
begin
 if not private.is_staff(array['moderator','administrator']) or decision not in ('dismiss','suspend') then raise exception 'Forbidden'; end if;
 select subject_id into subject from public.reports where id=report_id and status='pending' for update;
 if subject is null then raise exception 'Report unavailable'; end if;
 if decision='suspend' then update public.profiles set status='suspended' where id=subject; end if;
 update public.reports set status=case when decision='dismiss' then 'dismissed' else 'actioned' end where id=report_id;
 insert into public.admin_audit_logs(actor_id,action,subject_id,metadata) values(auth.uid(),decision,subject,jsonb_build_object('report_id',report_id));
end; $$;

create function public.export_my_data() returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('profile',(select to_jsonb(p) from public.profiles p where id=auth.uid()),'messages_sent',coalesce((select jsonb_agg(to_jsonb(m)) from public.messages m where sender_id=auth.uid()),'[]'),'purchases',coalesce((select jsonb_agg(to_jsonb(p)) from public.purchases p where user_id=auth.uid()),'[]'),'reports',coalesce((select jsonb_agg(to_jsonb(r)) from public.reports r where reporter_id=auth.uid()),'[]'));
$$;
create function public.delete_my_account() returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Unauthenticated'; end if;
 delete from auth.users where id=auth.uid();
end; $$;

-- Deny by default. Mutations use narrowly scoped functions, never client grants.
do $$ declare t text; begin
 foreach t in array array['profiles','staff_roles','blocks','reports','discovery_actions','matches','conversations','conversation_members','messages','notifications','support_tickets','admin_audit_logs','products','feature_flags','purchases','entitlements','subscriptions','credit_wallets','credit_transactions','device_tokens','verification_requests','media_assets'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('revoke all on public.%I from anon, authenticated',t);
 end loop;
end $$;
grant select on public.profiles,public.staff_roles,public.blocks,public.reports,public.discovery_actions,public.matches,public.conversations,public.conversation_members,public.messages,public.notifications,public.support_tickets,public.products,public.feature_flags,public.purchases,public.entitlements,public.subscriptions,public.credit_wallets,public.credit_transactions,public.device_tokens,public.verification_requests,public.media_assets to authenticated;
grant insert,delete on public.blocks to authenticated;
grant insert on public.reports,public.support_tickets to authenticated;
create policy own_profile on public.profiles for select to authenticated using(id=auth.uid());
create policy own_roles on public.staff_roles for select to authenticated using(user_id=auth.uid());
create policy own_blocks_read on public.blocks for select to authenticated using(actor_id=auth.uid());
create policy own_blocks_insert on public.blocks for insert to authenticated with check(actor_id=auth.uid());
create policy own_blocks_delete on public.blocks for delete to authenticated using(actor_id=auth.uid());
create policy own_reports_read on public.reports for select to authenticated using(reporter_id=auth.uid());
create policy own_reports_insert on public.reports for insert to authenticated with check(reporter_id=auth.uid() and private.is_active(auth.uid()) and status='pending');
create policy own_actions on public.discovery_actions for select to authenticated using(actor_id=auth.uid());
create policy own_matches on public.matches for select to authenticated using(auth.uid() in (user_a,user_b) and not private.is_blocked(user_a,user_b));
create policy member_conversations on public.conversations for select to authenticated using(private.can_chat(id));
create policy own_membership on public.conversation_members for select to authenticated using(user_id=auth.uid() and private.can_chat(conversation_id));
create policy member_messages on public.messages for select to authenticated using(private.can_chat(conversation_id));
create policy own_notifications on public.notifications for select to authenticated using(user_id=auth.uid());
create policy own_tickets_read on public.support_tickets for select to authenticated using(user_id=auth.uid());
create policy own_tickets_insert on public.support_tickets for insert to authenticated with check(user_id=auth.uid() and status='open');
create policy active_products on public.products for select to authenticated using(active);
create policy flags_read on public.feature_flags for select to authenticated using(true);
do $$ declare t text; begin
 foreach t in array array['purchases','entitlements','subscriptions','credit_wallets','credit_transactions','device_tokens','verification_requests'] loop
 execute format('create policy own_rows on public.%I for select to authenticated using(user_id=auth.uid())',t);
 end loop;
end $$;
create policy own_media on public.media_assets for select to authenticated using(owner_id=auth.uid());

-- Functions are not public APIs unless explicitly allowed below.
revoke execute on all functions in schema public from public,anon,authenticated;
revoke execute on all functions in schema private from public,anon,authenticated;
grant usage on schema private to authenticated;
grant execute on function private.is_staff(text[]),private.is_active(uuid),private.is_blocked(uuid,uuid),private.can_chat(uuid),public.save_profile(jsonb),public.discover(integer),public.discovery_action(uuid,text),public.send_message(uuid,text),public.moderation_queue(),public.moderate_report(uuid,text),public.export_my_data(),public.delete_my_account() to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('private-media','private-media',false,5242880,array['image/jpeg','image/png','image/webp']);
-- No uploads allowed until validation/moderation pipeline is implemented.
create policy own_private_media on storage.objects for select to authenticated using(bucket_id='private-media' and (storage.foldername(name))[1]=auth.uid()::text);
alter publication supabase_realtime add table public.messages;
