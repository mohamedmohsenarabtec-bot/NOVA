-- READ ONLY: run before any migration against the owner's existing project.
-- No passwords, tokens, message contents or user metadata are selected.
-- One result set: some CLI versions return only the last of multiple SELECTs.
select jsonb_build_object(
 'database',current_database(),'executing_role',current_user,
 'objects',coalesce((select jsonb_agg(to_jsonb(x)) from (
  select n.nspname as schema_name,c.relname as object_name,c.relkind,c.relrowsecurity as rls_enabled
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname in ('public','private','supabase_migrations') and c.relkind in ('r','p','v','m') order by 1,2
 ) x),'[]'::jsonb),
 'policies',coalesce((select jsonb_agg(to_jsonb(x)) from (
  select schemaname,tablename,policyname,roles,cmd,qual,with_check from pg_policies
  where schemaname in ('public','private','storage') order by 1,2,3
 ) x),'[]'::jsonb),
 'functions',coalesce((select jsonb_agg(to_jsonb(x)) from (
  select n.nspname as schema_name,p.proname as function_name,pg_get_function_identity_arguments(p.oid) as arguments,p.prosecdef as security_definer
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','private') order by 1,2
 ) x),'[]'::jsonb),
 'triggers',coalesce((select jsonb_agg(to_jsonb(x)) from (
  select tgname,n.nspname as schema_name,c.relname as table_name from pg_trigger t
  join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace
  where not t.tgisinternal and n.nspname in ('auth','public') order by 2,3,1
 ) x),'[]'::jsonb),
 'buckets',coalesce((select jsonb_agg(jsonb_build_object('id',id,'public',public,'limit',file_size_limit,'mime_types',allowed_mime_types)) from storage.buckets),'[]'::jsonb),
 'auth_accounts',(select count(*) from auth.users),
 'migration_history_present',to_regclass('supabase_migrations.schema_migrations') is not null
) as inspection;
