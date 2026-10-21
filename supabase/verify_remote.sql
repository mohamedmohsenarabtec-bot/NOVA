-- Read-only post-apply assertions. Any nonzero missing count needs investigation.
select public.client_readiness() as nova_schema_version;
with expected(name) as (values ('profiles'),('staff_roles'),('blocks'),('reports'),('discovery_actions'),('matches'),('conversations'),('conversation_members'),('messages'),('notifications'),('support_tickets'),('admin_audit_logs'),('products'),('feature_flags'),('purchases'),('entitlements'),('subscriptions'),('credit_wallets'),('credit_transactions'),('device_tokens'),('verification_requests'),('media_assets'))
select e.name as missing_or_unprotected_table from expected e left join pg_class c on c.relname=e.name and c.relnamespace='public'::regnamespace where c.oid is null or not c.relrowsecurity;
select p.proname,has_function_privilege('anon',p.oid,'execute') as anon_execute,has_function_privilege('authenticated',p.oid,'execute') as authenticated_execute from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('discover','save_profile','discovery_action','send_message','moderation_queue','moderate_report','apply_credit_delta','record_verified_purchase');
select schemaname,tablename,policyname,cmd from pg_policies where schemaname='public' order by tablename,policyname;
select schemaname,tablename from pg_publication_tables where pubname='supabase_realtime' and tablename='messages';
select id,public,file_size_limit,allowed_mime_types from storage.buckets where id='private-media';
