-- Run with `supabase test db` against a disposable local Supabase instance.
begin;
create extension if not exists pgtap with schema extensions;
set search_path=public,extensions;
select plan(31);
select is(public.client_readiness(),7,'installed client schema version');

select throws_ok($$insert into auth.users(id,raw_user_meta_data) values('00000000-0000-0000-0000-000000000099','{"birth_date":"2020-01-01","consent_version":"draft-v1"}')$$, 'P0001','Adults 18+ only','backend rejects minors');
insert into auth.users(id,raw_user_meta_data) values
('00000000-0000-0000-0000-000000000001','{"birth_date":"1995-01-01","consent_version":"draft-v1"}'),
('00000000-0000-0000-0000-000000000002','{"birth_date":"1994-01-01","consent_version":"draft-v1"}'),
('00000000-0000-0000-0000-000000000003','{"birth_date":"1993-01-01","consent_version":"draft-v1"}');
update auth.users set email_confirmed_at=now();
update public.profiles set display_name='Fictional test adult',onboarding_complete=true,onboarding_step=5;
update public.profiles set gender='man',seeking_gender='woman' where id='00000000-0000-0000-0000-000000000002';
update public.profiles set intention='friendship' where id='00000000-0000-0000-0000-000000000003';

set local role authenticated;
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
select is((select count(*)::integer from public.profiles),1,'RLS exposes own profile only');
select is((select count(*)::integer from public.discover()),1,'discovery filters incompatible intentions/preferences');
select lives_ok($$select public.save_profile('{"onboarding_step":3,"interests":["books"]}')$$,'onboarding progress saves');
select is((select onboarding_step from public.profiles),3,'progress persisted');
select throws_ok($$update public.profiles set verified=true$$,'42501',null,'client cannot self-verify');
select throws_ok($$insert into public.staff_roles values(auth.uid(),'administrator')$$,'42501',null,'client cannot become administrator');
select throws_ok($$select public.moderation_queue()$$,'P0001','Forbidden','admin RPC denies normal user');
select is(public.discovery_action('00000000-0000-0000-0000-000000000002','like'),false,'one-sided like is not match');
select is(public.discovery_action('00000000-0000-0000-0000-000000000002','like'),false,'duplicate action idempotent');
select is((select count(*)::integer from public.discovery_actions),1,'duplicate like not inserted');

set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000002';
select is(public.discovery_action('00000000-0000-0000-0000-000000000001','like'),true,'reciprocal like creates match');
select is((select count(*)::integer from public.matches),1,'single canonical match');
select lives_ok($$select public.send_message((select id from public.conversations limit 1),'Hello from a test')$$,'participant can send');
select is((select count(*)::integer from public.messages),1,'participant can read');

reset role;
select set_config('test.conversation',(select id::text from public.conversations limit 1),true);
set local role authenticated;
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000003';
select is((select count(*)::integer from public.messages),0,'outsider cannot read chat');
select throws_ok($$select public.send_message(current_setting('test.conversation')::uuid,'intrusion')$$,'P0001','Conversation unavailable','outsider cannot send');

set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
insert into public.blocks(actor_id,target_id) values(auth.uid(),'00000000-0000-0000-0000-000000000002');
select is((select count(*)::integer from public.messages),0,'block revokes message access');
select throws_ok($$select public.send_message(current_setting('test.conversation')::uuid,'blocked')$$,'P0001','Conversation unavailable','block prevents sending');
insert into public.reports(reporter_id,subject_id,category) values(auth.uid(),'00000000-0000-0000-0000-000000000002','safety');
select is((select count(*)::integer from public.reports),1,'report persisted for owner');
select throws_ok($$select public.apply_credit_delta(auth.uid(),100,'forged-credit','fake')$$,'42501',null,'client cannot manufacture credits');

reset role;
select is(public.apply_credit_delta('00000000-0000-0000-0000-000000000001',100,'test-event-001','test'),100::bigint,'server grants credits');
select is(public.apply_credit_delta('00000000-0000-0000-0000-000000000001',100,'test-event-001','test'),100::bigint,'credit event deduplicated');
select throws_ok($$select public.apply_credit_delta('00000000-0000-0000-0000-000000000001',-101,'test-event-002','test')$$,'P0001','Insufficient credits','wallet cannot overdraw');
insert into public.entitlements(user_id,feature,expires_at) values('00000000-0000-0000-0000-000000000001','rewind',now()-interval '1 day');
select is((select count(*)::integer from public.entitlements where expires_at>now()),0,'expired entitlements excluded');
insert into public.products(id,name_ar,name_en,description_ar,description_en) values('test-plan','test','test','test','test');
select lives_ok($$select public.record_verified_purchase('00000000-0000-0000-0000-000000000001','test','event-001','test-plan',100,'EGP','extra-discovery',now()+interval '1 month')$$,'server records verified purchase');
select lives_ok($$select public.record_verified_purchase('00000000-0000-0000-0000-000000000001','test','event-001','test-plan',100,'EGP','extra-discovery',now()+interval '1 month')$$,'duplicate payment event accepted idempotently');
select is((select count(*)::integer from public.purchases),1,'duplicate webhook cannot double charge ledger');
insert into public.staff_roles values('00000000-0000-0000-0000-000000000003','support');
set local role authenticated;
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000003';
select throws_ok($$select public.moderation_queue()$$,'P0001','Forbidden','support role cannot moderate');
reset role;
insert into public.staff_roles values('00000000-0000-0000-0000-000000000003','moderator');
set local role authenticated;
select lives_ok($$select public.moderation_queue()$$,'moderator may read reports without private chat access');
select * from finish();
rollback;
