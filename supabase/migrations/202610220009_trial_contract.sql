-- Disabled by default. A trusted store verifier can consume eligibility only
-- AFTER explicit business approval; no Flutter button can call this procedure.
insert into public.feature_flags(key,enabled,config) values('membership_trials',false,'{"days":7}');
create function public.activate_verified_trial(who uuid,tier_name text,verified_event text) returns void language plpgsql security definer set search_path='' as $$
declare identity_key text; until_at timestamptz;
begin
 if not exists(select 1 from public.feature_flags where key='membership_trials' and enabled) then raise exception 'Trials pending business approval'; end if;
 if not private.is_active(who) or tier_name not in ('plus','premium') or length(verified_event)<12 or private.tier(who)<>'free' or exists(select 1 from public.purchases where user_id=who) then raise exception 'Trial ineligible'; end if;
 identity_key:=private.identity_fingerprint(who);
 if identity_key is null then raise exception 'Trial ineligible'; end if;
 perform pg_advisory_xact_lock(hashtextextended(identity_key,3));
 if exists(select 1 from private.benefit_history where benefit='trial' and benefit_history.fingerprint=identity_key and expires_at>now()) then raise exception 'Trial already used'; end if;
 until_at:=now()+make_interval(days=>coalesce((select greatest(1,least(7,(config->>'days')::int)) from public.feature_flags where key='membership_trials'),7));
 insert into private.benefit_history(fingerprint,benefit) values(identity_key,'trial') on conflict on constraint benefit_history_pkey do update set expires_at=now()+interval '180 days';
 insert into public.entitlements(user_id,feature,expires_at) values(who,tier_name,until_at) on conflict(user_id,feature) do update set expires_at=greatest(public.entitlements.expires_at,excluded.expires_at);
 insert into public.admin_audit_logs(action,subject_id,metadata) values('verified_trial',who,jsonb_build_object('event',verified_event,'tier',tier_name));
end; $$;
revoke all on function public.activate_verified_trial(uuid,text,text) from public,anon,authenticated;
grant execute on function public.activate_verified_trial(uuid,text,text) to service_role;
-- Legacy readiness stays 4 so already installed clients keep working during
-- rollout. New clients require this separate, anonymous-safe capability probe.
create function public.client_capabilities() returns integer language sql stable security invoker set search_path='' as $$select 9;$$;
revoke all on function public.client_capabilities() from public,anon,authenticated;
grant execute on function public.client_capabilities() to anon,authenticated;
