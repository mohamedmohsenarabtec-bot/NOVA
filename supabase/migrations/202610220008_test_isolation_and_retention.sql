-- Development profiles never enter an ordinary user's dating feed. This flag
-- is assigned only by an authorized DB operator, never signup metadata/client.
alter table public.profiles add column is_test_account boolean not null default false;
alter function private.eligible(uuid,uuid) rename to eligible_core;
revoke all on function private.eligible_core(uuid,uuid) from public,anon,authenticated;
create function private.eligible(viewer uuid,target uuid) returns boolean language sql stable security definer set search_path='' as $$
 select private.eligible_core(viewer,target) and exists(select 1 from public.profiles a,public.profiles b where a.id=viewer and b.id=target and a.is_test_account=b.is_test_account);
$$;
revoke all on function private.eligible(uuid,uuid) from public,anon,authenticated;
alter function private.profile_projection(public.profiles) rename to profile_projection_core;
revoke all on function private.profile_projection_core(public.profiles) from public,anon,authenticated;
create function private.profile_projection(p public.profiles) returns jsonb language sql stable security definer set search_path='' as $$select private.profile_projection_core(p)||jsonb_build_object('is_test_account',p.is_test_account);$$;
revoke all on function private.profile_projection(public.profiles) from public,anon,authenticated;

-- Shared completion/age validation remains unchanged. Old clients receive a
-- schema version >=4; the new client requires all eight migrations.
create or replace function public.client_readiness() returns integer language sql stable security invoker set search_path='' as $$select 8;$$;

-- Operator maintenance only. No deletion/retention action is exposed to users.
create function public.retention_maintenance() returns void language plpgsql security definer set search_path='' as $$
begin
 delete from public.notifications where created_at<now()-interval '90 days';
 delete from private.benefit_history where expires_at<now();
 update public.discovery_actions set state='expired' where state='pending' and expires_at<=now();
end; $$;
revoke all on function public.retention_maintenance() from public,anon,authenticated;
grant execute on function public.retention_maintenance() to service_role;
