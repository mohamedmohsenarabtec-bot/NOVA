-- Public health metadata only. No user data or privileged operation is exposed.
create function public.client_readiness() returns integer
language sql stable security invoker set search_path='' as $$ select 4; $$;
revoke all on function public.client_readiness() from public;
grant execute on function public.client_readiness() to anon,authenticated;
