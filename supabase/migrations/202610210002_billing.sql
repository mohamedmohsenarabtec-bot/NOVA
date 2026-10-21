-- Only a trusted, receipt-verifying server may call these functions.
-- NOT a payment provider adapter. Never expose these grants to authenticated.
create function public.apply_credit_delta(who uuid, delta bigint, event_key text, reason text) returns bigint language plpgsql security definer set search_path='' as $$
declare result bigint; existing public.credit_transactions;
begin
 if delta=0 or event_key is null or length(event_key)<8 then raise exception 'Invalid credit event'; end if;
 select balance into result from public.credit_wallets where user_id=who for update;
 if not found then raise exception 'Wallet not found'; end if;
 select * into existing from public.credit_transactions where idempotency_key=event_key;
 if found then
  if existing.user_id<>who or existing.delta<>delta or existing.reason<>reason then raise exception 'Idempotency conflict'; end if;
  return result;
 end if;
 if result+delta<0 then raise exception 'Insufficient credits'; end if;
 insert into public.credit_transactions(user_id,delta,idempotency_key,reason) values(who,delta,event_key,reason);
 update public.credit_wallets set balance=balance+delta where user_id=who returning balance into result;
 return result;
end; $$;

create function public.record_verified_purchase(who uuid, provider_name text, provider_event text, product text, amount bigint, currency_code text, feature_name text, expiration timestamptz) returns uuid language plpgsql security definer set search_path='' as $$
declare purchase_id uuid; existing public.purchases;
begin
 if expiration<=now() then raise exception 'Expired entitlement'; end if;
 perform pg_advisory_xact_lock(hashtextextended(provider_name||':'||provider_event,1));
 select * into existing from public.purchases where provider=provider_name and event_id=provider_event;
 if found then
  if existing.user_id<>who or existing.product_id<>product or existing.amount_minor<>amount or existing.currency<>currency_code then raise exception 'Idempotency conflict'; end if;
  return existing.id;
 end if;
 insert into public.purchases(user_id,provider,event_id,product_id,amount_minor,currency,state) values(who,provider_name,provider_event,product,amount,currency_code,'paid') returning id into purchase_id;
 insert into public.entitlements(user_id,feature,expires_at,source_purchase) values(who,feature_name,expiration,purchase_id)
 on conflict(user_id,feature) do update set expires_at=greatest(public.entitlements.expires_at,excluded.expires_at), source_purchase=excluded.source_purchase;
 insert into public.admin_audit_logs(action,subject_id,metadata) values('verified_purchase',who,jsonb_build_object('purchase_id',purchase_id));
 return purchase_id;
end; $$;
revoke all on function public.apply_credit_delta(uuid,bigint,text,text),public.record_verified_purchase(uuid,text,text,text,bigint,text,text,timestamptz) from public,anon,authenticated;
grant execute on function public.apply_credit_delta(uuid,bigint,text,text),public.record_verified_purchase(uuid,text,text,text,bigint,text,text,timestamptz) to service_role;
