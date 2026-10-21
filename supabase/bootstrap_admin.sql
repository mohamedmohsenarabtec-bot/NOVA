-- Run ONLY through an authorized database session after reviewing the exact
-- Auth UUID and confirmed identity. Set nova.owner_uuid for this transaction.
-- Never expose this operation as a client RPC or grant it to API roles.
begin;
do $$
declare
  owner_id uuid := nullif(current_setting('nova.owner_uuid', true), '')::uuid;
begin
  if current_user not in ('postgres', 'supabase_admin') then
    raise exception 'Authorized database operator required';
  end if;
  if owner_id is null then
    raise exception 'Set nova.owner_uuid to the reviewed Auth UUID first';
  end if;
  perform pg_advisory_xact_lock(hashtext('nova_admin_bootstrap'));
  if exists(select 1 from public.staff_roles where role = 'administrator' and user_id <> owner_id) then
    raise exception 'An administrator already exists; use the reviewed staff management process';
  end if;
  if not exists(
    select 1 from auth.users u join public.profiles p on p.id = u.id
    where u.id = owner_id and u.email_confirmed_at is not null
      and u.last_sign_in_at is not null and p.status = 'active'
  ) then
    raise exception 'Active, signed-in Auth account required';
  end if;
  insert into public.staff_roles(user_id, role) values(owner_id, 'administrator')
    on conflict do nothing;
  insert into public.admin_audit_logs(actor_id, action, subject_id, metadata)
    values(null, 'administrator_bootstrap', owner_id,
      jsonb_build_object('operator', current_user, 'identity_review', 'out_of_band_owner_verification'));
end $$;
commit;
