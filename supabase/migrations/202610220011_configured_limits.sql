-- Limits and rewards are configured once on the server. No feature is enabled.
create function private.referral_rules() returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object(
 'extra_likes',greatest(1,least(100,coalesce((config->>'extra_likes')::int,25))),
 'days',greatest(1,least(30,coalesce((config->>'days')::int,7))),
 'minimum_age_days',greatest(7,least(90,coalesce((config->>'minimum_age_days')::int,7))),
 'monthly_cap',greatest(1,least(10,coalesce((config->>'monthly_cap')::int,3))))
 from public.feature_flags where key='referral_rewards';
$$;
revoke all on function private.referral_rules() from public,anon,authenticated;
create function private.like_allowance(who uuid) returns integer language sql stable security definer set search_path='' as $$
 select greatest(1,least(1000,coalesce((select (features->>'daily_likes')::int from public.membership_offers where tier=private.tier(who) and months=1),50)))
 +case when exists(select 1 from public.entitlements where user_id=who and feature='referral_extra_likes' and expires_at>now()) then (private.referral_rules()->>'extra_likes')::int else 0 end;
$$;
revoke all on function private.like_allowance(uuid) from public,anon,authenticated;
create or replace function public.discovery_action(target_id uuid,action_kind text) returns boolean language plpgsql security definer set search_path='' as $$
declare me uuid:=auth.uid(); pair uuid; conv uuid; daily integer; incoming public.discovery_actions; outgoing public.discovery_actions;
begin
 if me is null or me=target_id or action_kind not in ('like','pass') then raise exception 'Invalid action'; end if;
 perform pg_advisory_xact_lock(hashtextextended(least(me,target_id)::text||greatest(me,target_id)::text,0));
 perform 1 from public.profiles where id=me for update;
 if not private.eligible(me,target_id) then raise exception 'Unavailable profile'; end if;
 perform private.expire_interactions();
 select * into outgoing from public.discovery_actions where actor_id=me and discovery_actions.target_id=discovery_action.target_id;
 if found then return false; end if;
 select coalesce((config->>'daily_limit')::int,50) into daily from public.feature_flags where key='discovery' and enabled;
 if daily is null then raise exception 'Discovery disabled'; end if;
 daily:=private.like_allowance(me);
 
 if action_kind='like' and (select count(*) from public.discovery_actions where actor_id=me and kind='like' and created_at>=date_trunc('day',now() at time zone 'UTC') at time zone 'UTC')>=daily then raise exception 'Daily limit reached'; end if;
 insert into public.discovery_actions(actor_id,target_id,kind,state,expires_at) values(me,target_id,action_kind,case when action_kind='like' then 'pending' else 'dismissed' end,now()+make_interval(hours=>coalesce((select greatest(1,least(168,(config->>'pending_hours')::int)) from public.feature_flags where key='interaction_window'),48))) returning * into outgoing;
 if action_kind='pass' then
  update public.discovery_actions set state='dismissed' where actor_id=target_id and discovery_actions.target_id=me and state='pending'; return false;
 end if;
 select * into incoming from public.discovery_actions where actor_id=discovery_action.target_id and discovery_actions.target_id=me and kind='like' and state='pending' and expires_at>now();
 if found then
  insert into public.matches(user_a,user_b) values(least(me,target_id),greatest(me,target_id)) on conflict do nothing returning id into pair;
  if pair is not null then
   insert into public.conversations(match_id) values(pair) returning id into conv;
   insert into public.conversation_members values(conv,me,false,false,null),(conv,target_id,false,false,null);
   perform private.notify(me,'match',conv,'match:'||pair||':'||me);
   perform private.notify(target_id,'match',conv,'match:'||pair||':'||target_id);
  end if;
  update public.discovery_actions set state='accepted' where (actor_id=me and discovery_actions.target_id=discovery_action.target_id) or (actor_id=discovery_action.target_id and discovery_actions.target_id=me);
  return true;
 end if;
 -- A generic event only: no liker identifier or photo in free notifications.
 perform private.notify(target_id,'like',null,'like:'||outgoing.id);
 return false;
end; $$;
create or replace function public.grant_referral_reward(referral_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare r public.referrals; until_at timestamptz; rules jsonb:=private.referral_rules();
begin
 select * into r from public.referrals where id=referral_id for update;
 if not found then raise exception 'Referral unavailable'; end if;
 perform pg_advisory_xact_lock(hashtextextended('referral:'||r.inviter_id::text,0));
 if exists(select 1 from public.referral_rewards where referral_rewards.referral_id=r.id) then return; end if;
 if not exists(select 1 from public.feature_flags where key='referral_rewards' and enabled) then raise exception 'Rewards pending business approval'; end if;
 if r.state<>'qualified' or r.reviewed_at is null or not private.is_active(r.inviter_id) or not private.is_active(r.invitee_id) or private.is_blocked(r.inviter_id,r.invitee_id)
 or not exists(select 1 from public.profiles where id=r.invitee_id and onboarding_complete and created_at<=now()-make_interval(days=>(rules->>'minimum_age_days')::int))
 or not exists(select 1 from public.matches where ended_at is null and r.invitee_id in(user_a,user_b) and r.inviter_id not in(user_a,user_b))
 or (select count(*) from public.referral_rewards where user_id=r.inviter_id and created_at>now()-interval '30 days')>=(rules->>'monthly_cap')::int then raise exception 'Referral not eligible'; end if;
 until_at:=now()+make_interval(days=>(rules->>'days')::int);
 insert into public.referral_rewards(referral_id,user_id,expires_at) values(r.id,r.inviter_id,until_at);
 insert into public.entitlements(user_id,feature,expires_at) values(r.inviter_id,'referral_extra_likes',until_at) on conflict(user_id,feature) do update set expires_at=greatest(public.entitlements.expires_at,excluded.expires_at);
 update public.referrals set state='rewarded' where id=r.id;
 perform private.notify(r.inviter_id,'referral',null,'referral:'||r.id);
 insert into public.admin_audit_logs(action,subject_id,metadata) values('referral_reward',r.inviter_id,jsonb_build_object('referral',r.id));
end; $$;
create or replace function public.referral_progress() returns jsonb language plpgsql security definer set search_path='' as $$
declare own_code text;
begin
 if not private.is_active(auth.uid()) then raise exception 'Account unavailable'; end if;
 insert into public.referral_codes(user_id) values(auth.uid()) on conflict do nothing;
 select code into own_code from public.referral_codes where user_id=auth.uid();
 return jsonb_build_object('reward_rules',private.referral_rules(),'code',own_code,'pending',(select count(*) from public.referrals where inviter_id=auth.uid() and state='pending'),'qualified',(select count(*) from public.referrals where inviter_id=auth.uid() and state='qualified'),'rewarded',(select count(*) from public.referrals where inviter_id=auth.uid() and state='rewarded'),'rewards_enabled',(select enabled from public.feature_flags where key='referral_rewards'),'claimed',exists(select 1 from public.referrals where invitee_id=auth.uid()));
end; $$;
