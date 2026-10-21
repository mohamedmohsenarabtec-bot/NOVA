create function private.limit_safety_submissions() returns trigger language plpgsql security definer set search_path='' as $$
declare who uuid; recent integer;
begin
 who:=auth.uid();
 perform 1 from public.profiles where id=who for update;
 if tg_table_name='reports' then
  select count(*) into recent from public.reports where reporter_id=who and created_at>now()-interval '1 day';
  if recent>=20 then raise exception 'Report limit reached; contact support'; end if;
 else
  select count(*) into recent from public.support_tickets where user_id=who and created_at>now()-interval '1 day';
  if recent>=10 then raise exception 'Support limit reached'; end if;
 end if;
 new.created_at:=now();
 return new;
end; $$;
revoke all on function private.limit_safety_submissions() from public,anon,authenticated;
create trigger report_rate before insert on public.reports for each row execute function private.limit_safety_submissions();
create trigger ticket_rate before insert on public.support_tickets for each row execute function private.limit_safety_submissions();
