create table public.membership_offers(
 id text primary key,tier text not null check(tier in ('free','plus','premium')),months integer not null check(months in (1,3,6,12)),
 currency text not null default 'EGP',price_minor integer not null check(price_minor>=0),illustrative boolean not null default true,
 trial_days integer not null default 7,trial_enabled boolean not null default false,purchases_enabled boolean not null default false,
 features jsonb not null default '{}'::jsonb,unique(tier,months)
);
alter table public.membership_offers enable row level security;
create policy offers_read on public.membership_offers for select to authenticated using(true);
grant select on public.membership_offers to authenticated;
insert into public.membership_offers(id,tier,months,price_minor,features)
select tier||'-'||months,tier,months,price,jsonb_build_object('daily_likes',case tier when 'free' then 50 when 'plus' then 100 else 200 end,'advanced_filters',tier<>'free','liked_you',tier='premium','photos',6)
from (values ('free',1,0),('plus',1,9900),('plus',3,24900),('plus',6,44900),('plus',12,79900),('premium',1,19900),('premium',3,49900),('premium',6,89900),('premium',12,149900)) v(tier,months,price);

create table private.identity_salt(singleton boolean primary key default true check(singleton),salt text not null);
insert into private.identity_salt(salt) values(gen_random_uuid()::text||gen_random_uuid()::text);
create table private.benefit_history(fingerprint text not null,benefit text not null,expires_at timestamptz not null default now()+interval '180 days',primary key(fingerprint,benefit));
create function private.identity_fingerprint(who uuid) returns text language sql stable security definer set search_path='' as $$
 select encode(extensions.hmac(convert_to(lower(trim(u.email)),'UTF8'),convert_to(s.salt,'UTF8'),'sha256'),'hex') from auth.users u cross join private.identity_salt s where u.id=who and u.email is not null;
$$;
create function public.membership_status() returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('tier',private.tier(auth.uid()),'expires_at',(select max(expires_at) from public.entitlements where user_id=auth.uid() and feature in ('plus','premium') and expires_at>now()),
 'trial_eligible',private.is_active(auth.uid()) and not exists(select 1 from private.benefit_history where fingerprint=private.identity_fingerprint(auth.uid()) and benefit='trial' and expires_at>now()) and not exists(select 1 from public.purchases where user_id=auth.uid()),'trial_enabled',false,'purchases_enabled',false);
$$;
create table public.referral_codes(user_id uuid primary key references public.profiles on delete cascade,code text not null unique default substr(replace(gen_random_uuid()::text,'-',''),1,16),created_at timestamptz not null default now());
create table public.referrals(id uuid primary key default gen_random_uuid(),inviter_id uuid not null references public.profiles on delete cascade,invitee_id uuid not null unique references public.profiles on delete cascade,state text not null default 'pending' check(state in ('pending','qualified','rewarded','rejected')),reviewed_at timestamptz,created_at timestamptz not null default now(),check(inviter_id<>invitee_id));
create table public.referral_rewards(referral_id uuid primary key references public.referrals on delete cascade,user_id uuid not null references public.profiles on delete cascade,expires_at timestamptz not null,created_at timestamptz not null default now());
insert into public.feature_flags(key,enabled,config) values('referral_rewards',false,'{"extra_likes":25,"days":7,"minimum_age_days":7,"monthly_cap":3}');
alter table public.referral_codes enable row level security;
alter table public.referrals enable row level security;
alter table public.referral_rewards enable row level security;
create policy own_referral_code on public.referral_codes for select to authenticated using(user_id=auth.uid());
-- No table SELECT for referrals: invitees' identifiers are not disclosed.
create policy own_reward on public.referral_rewards for select to authenticated using(user_id=auth.uid());
grant select on public.referral_codes,public.referral_rewards to authenticated;

create function public.referral_progress() returns jsonb language plpgsql security definer set search_path='' as $$
declare own_code text;
begin
 if not private.is_active(auth.uid()) then raise exception 'Account unavailable'; end if;
 insert into public.referral_codes(user_id) values(auth.uid()) on conflict do nothing;
 select code into own_code from public.referral_codes where user_id=auth.uid();
 return jsonb_build_object('code',own_code,'pending',(select count(*) from public.referrals where inviter_id=auth.uid() and state='pending'),'qualified',(select count(*) from public.referrals where inviter_id=auth.uid() and state='qualified'),'rewarded',(select count(*) from public.referrals where inviter_id=auth.uid() and state='rewarded'),'rewards_enabled',(select enabled from public.feature_flags where key='referral_rewards'),'claimed',exists(select 1 from public.referrals where invitee_id=auth.uid()));
end; $$;
create function public.claim_referral(invitation_code text) returns void language plpgsql security definer set search_path='' as $$
declare inviter uuid;
begin
 perform 1 from public.profiles where id=auth.uid() for update;
 if not private.is_active(auth.uid()) or not exists(select 1 from public.profiles where id=auth.uid() and created_at>now()-interval '7 days') then raise exception 'Invitation eligibility unavailable'; end if;
 select user_id into inviter from public.referral_codes where code=lower(trim(invitation_code));
 if inviter is null or inviter=auth.uid() or not private.is_active(inviter) or private.is_blocked(inviter,auth.uid()) or private.identity_fingerprint(inviter)=private.identity_fingerprint(auth.uid()) then raise exception 'Invalid invitation'; end if;
 if exists(select 1 from public.referrals where invitee_id=auth.uid()) or exists(select 1 from private.benefit_history where fingerprint=private.identity_fingerprint(auth.uid()) and benefit='referral' and expires_at>now()) then raise exception 'Invitation already claimed'; end if;
 insert into public.referrals(inviter_id,invitee_id) values(inviter,auth.uid());
 insert into private.benefit_history(fingerprint,benefit) values(private.identity_fingerprint(auth.uid()),'referral') on conflict do nothing;
end; $$;
create function public.review_referral(referral_id uuid,approve boolean) returns void language plpgsql security definer set search_path='' as $$
begin
 if not private.is_staff(array['administrator']) then raise exception 'Forbidden'; end if;
 update public.referrals set state=case when approve then 'qualified' else 'rejected' end,reviewed_at=now() where id=referral_id and state='pending';
 insert into public.admin_audit_logs(actor_id,action,subject_id,metadata) values(auth.uid(),'referral_review',auth.uid(),jsonb_build_object('referral',referral_id,'approved',approve));
end; $$;
create function public.grant_referral_reward(referral_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare r public.referrals; until_at timestamptz;
begin
 select * into r from public.referrals where id=referral_id for update;
 if not found then raise exception 'Referral unavailable'; end if;
 if exists(select 1 from public.referral_rewards where referral_rewards.referral_id=r.id) then return; end if;
 if not exists(select 1 from public.feature_flags where key='referral_rewards' and enabled) then raise exception 'Rewards pending business approval'; end if;
 if r.state<>'qualified' or r.reviewed_at is null or not private.is_active(r.inviter_id) or not private.is_active(r.invitee_id) or private.is_blocked(r.inviter_id,r.invitee_id)
 or not exists(select 1 from public.profiles where id=r.invitee_id and onboarding_complete and created_at<=now()-interval '7 days')
 or not exists(select 1 from public.matches where ended_at is null and r.invitee_id in(user_a,user_b) and r.inviter_id not in(user_a,user_b))
 or (select count(*) from public.referral_rewards where user_id=r.inviter_id and created_at>now()-interval '30 days')>=3 then raise exception 'Referral not eligible'; end if;
 until_at:=now()+interval '7 days';
 insert into public.referral_rewards(referral_id,user_id,expires_at) values(r.id,r.inviter_id,until_at);
 insert into public.entitlements(user_id,feature,expires_at) values(r.inviter_id,'referral_extra_likes',until_at) on conflict(user_id,feature) do update set expires_at=greatest(public.entitlements.expires_at,excluded.expires_at);
 update public.referrals set state='rewarded' where id=r.id;
 perform private.notify(r.inviter_id,'referral',null,'referral:'||r.id);
 insert into public.admin_audit_logs(action,subject_id,metadata) values('referral_reward',r.inviter_id,jsonb_build_object('referral',r.id));
end; $$;
grant execute on function public.grant_referral_reward(uuid) to service_role;

create table public.account_deletion_requests(user_id uuid primary key references public.profiles on delete cascade,requested_at timestamptz not null default now(),execute_after timestamptz not null default now()+interval '7 days',cancelled_at timestamptz);
alter table public.account_deletion_requests enable row level security;
create policy own_deletion on public.account_deletion_requests for select to authenticated using(user_id=auth.uid());
grant select on public.account_deletion_requests to authenticated;
create function public.request_account_deletion(cancel_request boolean default false) returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if cancel_request then
  update public.account_deletion_requests set cancelled_at=now() where user_id=auth.uid() and execute_after>now();
  if not found then raise exception 'Cancellation period ended'; end if;
 else
  insert into public.account_deletion_requests(user_id) values(auth.uid()) on conflict(user_id) do update set requested_at=now(),execute_after=now()+interval '7 days',cancelled_at=null;
  update public.profiles set visible=false where id=auth.uid();
 end if;
end; $$;
create or replace function public.export_my_data() returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('profile',(select to_jsonb(p) from public.profiles p where id=auth.uid()),
 'photos',coalesce((select jsonb_agg(to_jsonb(x)) from public.profile_photos x where owner_id=auth.uid()),'[]'),
 'favorites',coalesce((select jsonb_agg(to_jsonb(x)) from public.favorites x where user_id=auth.uid()),'[]'),
 'outgoing_interactions',coalesce((select jsonb_agg(to_jsonb(x)) from public.discovery_actions x where actor_id=auth.uid()),'[]'),
 'messages_sent',coalesce((select jsonb_agg(to_jsonb(x)) from public.messages x where sender_id=auth.uid()),'[]'),
 'purchases',coalesce((select jsonb_agg(to_jsonb(x)) from public.purchases x where user_id=auth.uid()),'[]'),
 'reports',coalesce((select jsonb_agg(to_jsonb(x)) from public.reports x where reporter_id=auth.uid()),'[]'),
 'notifications',coalesce((select jsonb_agg(to_jsonb(x)) from public.notifications x where user_id=auth.uid()),'[]'));
$$;
grant execute on function public.membership_status(),public.referral_progress(),public.claim_referral(text),public.review_referral(uuid,boolean),public.request_account_deletion(boolean) to authenticated;
create or replace function public.client_readiness() returns integer language sql stable security invoker set search_path='' as $$ select 7; $$;

-- Supabase projects can have default EXECUTE grants to API roles in addition
-- to PUBLIC. Explicitly close every new function before granting the API list.
do $$ declare fn text; begin
 for fn in select p.oid::regprocedure::text from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where (n.nspname='private' and p.proname in ('tier','profile_completion','may_view_profile','may_read_photo','profile_projection','notify','expire_interactions','identity_fingerprint'))
 or (n.nspname='public' and p.proname in ('save_profile_core','public_profile','save_profile','save_discovery_filters','discover_profiles','discovery_summary','toggle_favorite','favorite_profiles','prepare_profile_photo','finalize_profile_photo','manage_profile_photos','interaction_overview','end_match','chat_list','mark_chat_read','notification_inbox','read_notifications','membership_status','referral_progress','claim_referral','review_referral','grant_referral_reward','request_account_deletion'))
 loop execute 'revoke all on function '||fn||' from public,anon,authenticated'; end loop;
end $$;
revoke all on private.identity_salt,private.benefit_history from public,anon,authenticated;
grant execute on function private.may_read_photo(public.profile_photos),public.save_profile(jsonb),public.public_profile(uuid),public.save_discovery_filters(jsonb),public.discover_profiles(integer),public.discovery_summary(),public.toggle_favorite(uuid,boolean),public.favorite_profiles(),public.prepare_profile_photo(text),public.finalize_profile_photo(uuid),public.manage_profile_photos(uuid,text,uuid[],boolean),public.interaction_overview(),public.end_match(uuid),public.chat_list(),public.mark_chat_read(uuid),public.notification_inbox(integer),public.read_notifications(uuid),public.membership_status(),public.referral_progress(),public.claim_referral(text),public.review_referral(uuid,boolean),public.request_account_deletion(boolean) to authenticated;
grant execute on function public.grant_referral_reward(uuid) to service_role;

create function private.notify_account_change() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_table_name='profiles' then
  if new.verified is distinct from old.verified then perform private.notify(new.id,'verification',null,'verification:'||new.id||':'||new.verified::text||':'||extract(epoch from now())::text); end if;
 else perform private.notify(new.user_id,'billing',null,'membership:'||new.user_id||':'||new.feature||':'||new.expires_at::text);
 end if;
 return new;
end; $$;
revoke all on function private.notify_account_change() from public,anon,authenticated;
create trigger profile_verification_notification after update of verified on public.profiles for each row execute function private.notify_account_change();
create trigger entitlement_notification after insert or update on public.entitlements for each row execute function private.notify_account_change();
