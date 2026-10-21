-- READ ONLY: run before any migration against the owner's existing project.
-- No passwords, tokens, message contents or user metadata are selected.
select current_database() as database_name, current_user as executing_role;
select n.nspname as schema_name,c.relname as object_name,c.relkind,c.relrowsecurity as rls_enabled
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname in ('public','private','supabase_migrations') and c.relkind in ('r','p','v','m')
order by n.nspname,c.relname;
select schemaname,tablename,policyname,roles,cmd,qual,with_check from pg_policies
where schemaname in ('public','private','storage') order by schemaname,tablename,policyname;
select n.nspname as schema_name,p.proname as function_name,pg_get_function_identity_arguments(p.oid) as arguments,p.prosecdef as security_definer
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname in ('public','private') order by n.nspname,p.proname;
select tgname,n.nspname as schema_name,c.relname as table_name
from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace
where not t.tgisinternal and n.nspname in ('auth','public') order by n.nspname,c.relname,tgname;
select id,name,public,file_size_limit,allowed_mime_types from storage.buckets;
select count(*) as existing_auth_accounts from auth.users;
