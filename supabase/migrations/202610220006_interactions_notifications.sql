alter table public.discovery_actions add column id uuid not null default gen_random_uuid() unique,
 add column state text not null default 'pending' check(state in ('pending','accepted','dismissed','expired')),
 add column expires_at timestamptz;
update public.discovery_actions d set expires_at=created_at+interval '48 hours',state=case
 when exists(select 1 from public.matches m where m.user_a=least(d.actor_id,d.target_id) and m.user_b=greatest(d.actor_id,d.target_id)) then 'accepted'
 when kind='pass' then 'dismissed' when created_at+interval '48 hours'<=now() then 'expired' else 'pending' end;
create index actions_pending on public.discovery_actions(target_id,expires_at) where kind='like' and state='pending';
alter table public.matches add column ended_at timestamptz;
alter table public.notifications drop constraint notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check check(kind in ('like','match','message','verification','billing','referral','expiring','system'));
alter table public.notifications add column event_key text unique;
insert into public.feature_flags(key,enabled,config) values('interaction_window',true,'{"pending_hours":48}');

create or replace function private.can_chat(conversation uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.conversations c join public.matches m on m.id=c.match_id where c.id=conversation and m.ended_at is null and auth.uid() in (m.user_a,m.user_b) and private.is_active(m.user_a) and private.is_active(m.user_b) and not private.is_blocked(m.user_a,m.user_b));
$$;
create or replace function private.may_view_profile(viewer uuid,target uuid) returns boolean language sql stable security definer set search_path='' as $$
 select viewer is not null and (viewer=target or (private.is_active(viewer) and private.is_active(target) and not private.is_blocked(viewer,target)
 and (private.eligible(viewer,target) or exists(select 1 from public.matches m where m.ended_at is null and least(viewer,target)=m.user_a and greatest(viewer,target)=m.user_b))));
$$;
create function private.notify(who uuid,event_kind text,reference uuid,event text) returns void language sql security definer set search_path='' as $$
 insert into public.notifications(user_id,kind,reference_id,event_key) values(who,event_kind,reference,event) on conflict(event_key) do nothing;
$$;
create function private.expire_interactions() returns void language plpgsql security definer set search_path='' as $$
begin
 update public.discovery_actions set state='expired' where state='pending' and expires_at<=now() and auth.uid() in(actor_id,target_id);
 insert into public.notifications(user_id,kind,reference_id,event_key)
 select actor_id,'expiring',null,'expiring:'||id from public.discovery_actions where actor_id=auth.uid() and state='pending' and kind='like' and expires_at>now() and expires_at<now()+interval '6 hours' on conflict(event_key) do nothing;
end; $$;
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
 if private.tier(me)='plus' then daily:=100; elsif private.tier(me)='premium' then daily:=200; end if;
 if exists(select 1 from public.entitlements where user_id=me and feature='referral_extra_likes' and expires_at>now()) then daily:=daily+25; end if;
 if (select count(*) from public.discovery_actions where actor_id=me and created_at>=date_trunc('day',now() at time zone 'UTC') at time zone 'UTC')>=daily then raise exception 'Daily limit reached'; end if;
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
create function public.interaction_overview() returns jsonb language plpgsql security definer set search_path='' as $$
declare incoming_count integer; allowed boolean;
begin
 perform private.expire_interactions();
 allowed:=private.tier(auth.uid())='premium';
 select count(*) into incoming_count from public.discovery_actions d where d.target_id=auth.uid() and d.kind='like' and d.state='pending' and d.expires_at>now() and private.eligible(auth.uid(),d.actor_id);
 return jsonb_build_object('can_view_likers',allowed,'incoming_count',incoming_count,
 'incoming',case when allowed then coalesce((select jsonb_agg(jsonb_build_object('profile',private.profile_projection(p),'expires_at',d.expires_at)) from public.discovery_actions d join public.profiles p on p.id=d.actor_id where d.target_id=auth.uid() and d.kind='like' and d.state='pending' and d.expires_at>now() and private.eligible(auth.uid(),p.id)),'[]'::jsonb) else '[]'::jsonb end,
 'outgoing',coalesce((select jsonb_agg(jsonb_build_object('profile',private.profile_projection(p),'state',d.state,'expires_at',d.expires_at)) from public.discovery_actions d join public.profiles p on p.id=d.target_id where d.actor_id=auth.uid() and d.kind='like' and d.state='pending' and d.expires_at>now() and private.may_view_profile(auth.uid(),p.id)),'[]'::jsonb));
end; $$;
create function public.end_match(conversation uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 if not private.can_chat(conversation) then raise exception 'Conversation unavailable'; end if;
 update public.matches set ended_at=now() where id=(select match_id from public.conversations where id=conversation);
 insert into public.admin_audit_logs(actor_id,action,subject_id,metadata) values(auth.uid(),'unmatch',auth.uid(),jsonb_build_object('conversation',conversation));
end; $$;
create function public.chat_list() returns setof jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',c.id,'created_at',c.created_at,'profile',private.profile_projection(p),'unread',(select count(*) from public.messages msg where msg.conversation_id=c.id and msg.sender_id<>auth.uid() and msg.created_at>coalesce(cm.last_read_at,'epoch'::timestamptz)))
 from public.conversation_members cm join public.conversations c on c.id=cm.conversation_id join public.matches m on m.id=c.match_id join public.profiles p on p.id=case when m.user_a=auth.uid() then m.user_b else m.user_a end where cm.user_id=auth.uid() and private.can_chat(c.id) order by c.created_at desc limit 100;
$$;
create function public.mark_chat_read(conversation uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 if not private.can_chat(conversation) then raise exception 'Conversation unavailable'; end if;
 update public.conversation_members set last_read_at=now() where conversation_id=conversation and user_id=auth.uid();
 update public.notifications set read_at=now() where user_id=auth.uid() and reference_id=conversation and read_at is null;
end; $$;
create or replace function public.send_message(conversation uuid,body text) returns void language plpgsql security definer set search_path='' as $$
declare msg uuid;
begin
 perform 1 from public.profiles where id=auth.uid() for update;
 if not private.can_chat(conversation) then raise exception 'Conversation unavailable'; end if;
 if (select count(*) from public.messages where sender_id=auth.uid() and created_at>now()-interval '1 minute')>=20 then raise exception 'Message rate limit'; end if;
 insert into public.messages(conversation_id,sender_id,body) values(conversation,auth.uid(),trim(body)) returning id into msg;
 perform private.notify(user_id,'message',conversation,'message:'||msg||':'||user_id) from public.conversation_members where conversation_id=conversation and user_id<>auth.uid() and not muted;
end; $$;
create function public.notification_inbox(page_offset integer default 0) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 perform private.expire_interactions();
 return jsonb_build_object('unread',(select count(*) from public.notifications n where n.user_id=auth.uid() and n.read_at is null and n.created_at>now()-interval '90 days' and (n.kind not in ('match','message') or private.can_chat(n.reference_id))),
 'items',coalesce((select jsonb_agg(to_jsonb(x)) from (select n.id,n.kind,n.reference_id,n.read_at,n.created_at from public.notifications n where n.user_id=auth.uid() and n.created_at>now()-interval '90 days' and (n.kind not in ('match','message') or private.can_chat(n.reference_id)) order by n.created_at desc,n.id limit 30 offset greatest(0,least(page_offset,3000))) x),'[]'::jsonb));
end; $$;
create function public.read_notifications(notification_id uuid default null) returns void language sql security definer set search_path='' as $$
 update public.notifications set read_at=now() where user_id=auth.uid() and read_at is null and (notification_id is null or id=notification_id);
$$;
grant execute on function public.interaction_overview(),public.end_match(uuid),public.chat_list(),public.mark_chat_read(uuid),public.notification_inbox(integer),public.read_notifications(uuid) to authenticated;
-- Close all newly-created helpers and API functions before committing phase 6.
do $$ declare fn text; begin
 for fn in select p.oid::regprocedure::text from pg_proc p join pg_namespace n on n.oid=p.pronamespace where
 (n.nspname='private' and p.proname in ('notify','expire_interactions')) or
 (n.nspname='public' and p.proname in ('interaction_overview','end_match','chat_list','mark_chat_read','notification_inbox','read_notifications'))
 loop execute 'revoke all on function '||fn||' from public,anon,authenticated'; end loop;
end $$;
grant execute on function public.interaction_overview(),public.end_match(uuid),public.chat_list(),public.mark_chat_read(uuid),public.notification_inbox(integer),public.read_notifications(uuid) to authenticated;
