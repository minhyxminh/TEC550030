-- Run after 001. Business operations use the verified JWT identity, never a client user_id.
begin;

alter table public.membership_orders add column if not exists idempotency_key uuid;
create unique index if not exists membership_order_request_once
  on public.membership_orders(user_id, idempotency_key);
alter table public.pt_bookings add column if not exists idempotency_key uuid;
create unique index if not exists booking_request_once on public.pt_bookings(user_id, idempotency_key);

-- All writes are deliberately confined to this checked transaction function.
-- Row locks serialize a member's balance changes and concurrent inventory changes.
create or replace function public.gymflow_command(action text, payload jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  profile public.users;
  qr public.qr_tokens;
  visit public.gym_sessions;
  reward public.rewards;
  redemption public.redemptions;
  package public.memberships;
  ord public.membership_orders;
  booking public.pt_bookings;
  ident uuid;
  request_key uuid;
  earned integer := 0;
  balance bigint;
  start_time timestamptz;
  slot_time timestamptz;
  result jsonb;
begin
  if uid is null then raise exception using errcode='P0001', message='UNAUTHORIZED'; end if;
  select * into profile from public.users where id=uid for update;
  if not found then raise exception using errcode='P0001', message='PROFILE_NOT_FOUND'; end if;
  if action like 'admin_%' and profile.role <> 'ADMIN' then
    raise exception using errcode='P0001', message='FORBIDDEN';
  end if;

  if action='profile' then
    if length(trim(payload->>'name')) not between 1 and 100 or payload->>'name' is null then
      raise exception using errcode='P0001', message='INVALID_INPUT';
    end if;
    update public.users set name=trim(payload->>'name') where id=uid returning to_jsonb(users.*) into result;
    return result - 'role';

  elsif action='check_in' then
    select * into qr from public.qr_tokens where token_hash=payload->>'token_hash'
      and revoked_at is null and expires_at > now() and issued_at <= now() for share;
    if not found then raise exception using errcode='P0001', message='INVALID_QR'; end if;
    select * into visit from public.gym_sessions where user_id=uid and check_out_at is null;
    if found then
      if visit.qr_token_id <> qr.id then raise exception using errcode='P0001', message='ALREADY_CHECKED_IN'; end if;
      return jsonb_build_object('session',to_jsonb(visit),'points_earned',0,'already_checked_in',true);
    end if;
    if profile.membership_expires_at is null or profile.membership_expires_at <= now() then
      raise exception using errcode='P0001', message='MEMBERSHIP_REQUIRED';
    end if;
    select * into package from public.memberships where id=profile.active_membership_id;
    insert into public.gym_sessions(user_id,gym_id,qr_token_id) values(uid,qr.gym_id,qr.id) returning * into visit;
    insert into public.point_transactions(user_id,type,points,reason,qr_token_id,gym_session_id)
      values(uid,'EARN',package.points_per_checkin,'Check-in tại phòng tập',qr.id,visit.id)
      on conflict (user_id,qr_token_id) where type='EARN' do nothing;
    if found then earned := package.points_per_checkin; end if;
    return jsonb_build_object('session',to_jsonb(visit),'points_earned',earned,'already_checked_in',false);

  elsif action='check_out' then
    ident := (payload->>'session_id')::uuid;
    update public.gym_sessions set check_out_at=coalesce(check_out_at,now())
      where id=ident and user_id=uid returning * into visit;
    if not found then raise exception using errcode='P0001', message='NOT_FOUND'; end if;
    return to_jsonb(visit);

  elsif action='redeem' then
    request_key := (payload->>'idempotency_key')::uuid;
    ident := (payload->>'reward_id')::uuid;
    if request_key is null or ident is null then raise exception using errcode='P0001', message='INVALID_INPUT'; end if;
    select * into redemption from public.redemptions where user_id=uid and idempotency_key=request_key;
    if found then
      if redemption.reward_id <> ident then raise exception using errcode='P0001', message='REQUEST_CONFLICT'; end if;
      return to_jsonb(redemption);
    end if;
    select * into reward from public.rewards where id=ident and is_active for update;
    if not found then raise exception using errcode='P0001', message='NOT_FOUND'; end if;
    if reward.stock <= 0 then raise exception using errcode='P0001', message='OUT_OF_STOCK'; end if;
    select coalesce(sum(points),0) into balance from public.point_transactions where user_id=uid;
    if balance < reward.points then raise exception using errcode='P0001', message='INSUFFICIENT_POINTS'; end if;
    update public.rewards set stock=stock-1 where id=ident;
    insert into public.redemptions(user_id,reward_id,points_spent,idempotency_key)
      values(uid,ident,reward.points,request_key) returning * into redemption;
    insert into public.point_transactions(user_id,type,points,reason,redemption_id)
      values(uid,'REDEEM',-reward.points,'Đổi quà: '||reward.name,redemption.id);
    return to_jsonb(redemption);

  elsif action='membership_order' then
    ident := (payload->>'membership_id')::uuid;
    request_key := (payload->>'idempotency_key')::uuid;
    if ident is null or request_key is null then raise exception using errcode='P0001', message='INVALID_INPUT'; end if;
    select * into ord from public.membership_orders where user_id=uid and idempotency_key=request_key;
    if found then
      if ord.membership_id <> ident then raise exception using errcode='P0001', message='REQUEST_CONFLICT'; end if;
      return to_jsonb(ord);
    end if;
    select * into package from public.memberships where id=ident and is_active for share;
    if not found then raise exception using errcode='P0001', message='NOT_FOUND'; end if;
    if exists(select 1 from public.membership_orders where user_id=uid and status='PENDING') then
      raise exception using errcode='P0001', message='PENDING_ORDER_EXISTS';
    end if;
    insert into public.membership_orders(user_id,membership_id,price_vnd_at_order,duration_days_at_order,idempotency_key)
      values(uid,ident,package.price_vnd,package.duration_days,request_key) returning * into ord;
    return to_jsonb(ord);

  elsif action='book_pt' then
    ident := (payload->>'trainer_id')::uuid;
    request_key := (payload->>'idempotency_key')::uuid;
    slot_time := (payload->>'slot')::timestamptz;
    if ident is null or request_key is null or slot_time is null then raise exception using errcode='P0001', message='INVALID_INPUT'; end if;
    select * into booking from public.pt_bookings where user_id=uid and idempotency_key=request_key;
    if found then
      if booking.trainer_id <> ident or booking.slot <> slot_time then raise exception using errcode='P0001', message='REQUEST_CONFLICT'; end if;
      return to_jsonb(booking);
    end if;
    if slot_time <= now() or slot_time > now()+interval '30 days'
      or extract(minute from slot_time at time zone 'Asia/Ho_Chi_Minh') <> 0
      or extract(second from slot_time at time zone 'Asia/Ho_Chi_Minh') <> 0
      or extract(hour from slot_time at time zone 'Asia/Ho_Chi_Minh') not between 6 and 21 then
      raise exception using errcode='P0001', message='INVALID_SLOT';
    end if;
    if not exists(select 1 from public.trainers where id=ident and is_active) then
      raise exception using errcode='P0001', message='NOT_FOUND';
    end if;
    insert into public.pt_bookings(user_id,trainer_id,slot,idempotency_key)
      values(uid,ident,slot_time,request_key) returning * into booking;
    return to_jsonb(booking);

  elsif action='cancel_pt' then
    select * into booking from public.pt_bookings where id=(payload->>'id')::uuid and user_id=uid for update;
    if not found then raise exception using errcode='P0001', message='NOT_FOUND'; end if;
    if booking.status='CANCELLED' then return to_jsonb(booking); end if;
    if booking.slot <= now() then raise exception using errcode='P0001', message='BOOKING_STARTED'; end if;
    update public.pt_bookings set status='CANCELLED' where id=booking.id returning * into booking;
    return to_jsonb(booking);

  elsif action='admin_qr' then
    if (payload->>'minutes')::integer not between 1 and 60 or payload->>'token_hash' !~ '^[0-9a-f]{64}$'
      or length(payload->>'gym_id') not between 1 and 100 then
      raise exception using errcode='P0001', message='INVALID_INPUT';
    end if;
    insert into public.qr_tokens(gym_id,token_hash,expires_at)
      values(payload->>'gym_id',payload->>'token_hash',now()+make_interval(mins => (payload->>'minutes')::integer)) returning * into qr;
    return to_jsonb(qr) - 'token_hash';

  elsif action='admin_revoke_qr' then
    update public.qr_tokens set revoked_at=coalesce(revoked_at,now()) where id=(payload->>'id')::uuid returning * into qr;
    if not found then raise exception using errcode='P0001', message='NOT_FOUND'; end if;
    return to_jsonb(qr) - 'token_hash';

  elsif action='admin_order' then
    -- Lock the member before their order: same order as member command locks.
    select user_id into ident from public.membership_orders where id=(payload->>'id')::uuid;
    if ident is null then raise exception using errcode='P0001', message='NOT_FOUND'; end if;
    select * into profile from public.users where id=ident for update;
    select * into ord from public.membership_orders where id=(payload->>'id')::uuid for update;
    if payload->>'status' not in ('APPROVED','REJECTED') then raise exception using errcode='P0001', message='INVALID_INPUT'; end if;
    if ord.status=payload->>'status' then return to_jsonb(ord); end if;
    if ord.status <> 'PENDING' then raise exception using errcode='P0001', message='ORDER_PROCESSED'; end if;
    if payload->>'status'='APPROVED' then
      start_time := greatest(now(),coalesce(profile.membership_expires_at,now()));
      update public.membership_orders set status='APPROVED',approved_at=now(),starts_at=start_time,
        ends_at=start_time+make_interval(days => ord.duration_days_at_order) where id=ord.id returning * into ord;
      update public.users set active_membership_id=ord.membership_id,membership_expires_at=ord.ends_at where id=ord.user_id;
    else
      update public.membership_orders set status='REJECTED' where id=ord.id returning * into ord;
    end if;
    return to_jsonb(ord);

  elsif action='admin_fulfill' then
    update public.redemptions set status='FULFILLED' where id=(payload->>'id')::uuid returning * into redemption;
    if not found then raise exception using errcode='P0001', message='NOT_FOUND'; end if;
    return to_jsonb(redemption);
  else
    raise exception using errcode='P0001', message='INVALID_INPUT';
  end if;
end;
$$;
revoke all on function public.gymflow_command(text,jsonb) from public, anon, authenticated;
grant execute on function public.gymflow_command(text,jsonb) to authenticated;

create or replace function public.gymflow_read(action text, payload jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  result jsonb;
  day_start timestamptz;
  page_limit integer := least(100,greatest(1,coalesce((payload->>'limit')::integer,100)));
  page_offset integer := least(100000,greatest(0,coalesce((payload->>'offset')::integer,0)));
begin
  if uid is null then raise exception using errcode='P0001', message='UNAUTHORIZED'; end if;
  if action like 'admin_%' and not exists(select 1 from public.users where id=uid and role='ADMIN') then
    raise exception using errcode='P0001', message='FORBIDDEN';
  end if;
  if action='occupancy' then
    select jsonb_build_object('count',count(*),'gym_id',payload->>'gym_id','updated_at',now()) into result
      from public.gym_sessions where gym_id=payload->>'gym_id' and check_out_at is null;
  elsif action='hourly' then
    day_start := coalesce((payload->>'date')::date,(now() at time zone 'Asia/Ho_Chi_Minh')::date)::timestamp at time zone 'Asia/Ho_Chi_Minh';
    -- Count members overlapping each hour; future hours on today are omitted.
    select coalesce(jsonb_agg(jsonb_build_object('hour',h,'count',n) order by h),'[]') into result
    from (select h,count(distinct s.user_id) as n from generate_series(0,23) h
      left join public.gym_sessions s on s.gym_id=payload->>'gym_id'
        and s.check_in_at < least(day_start+make_interval(hours => h+1),now())
        and coalesce(s.check_out_at,now()) > day_start+make_interval(hours => h)
      where day_start+make_interval(hours => h) <= now() group by h) hours;
  elsif action='pt_slots' then
    if not exists(select 1 from public.trainers where id=(payload->>'trainer_id')::uuid and is_active) then
      raise exception using errcode='P0001', message='NOT_FOUND';
    end if;
    day_start := (payload->>'date')::date::timestamp at time zone 'Asia/Ho_Chi_Minh';
    select coalesce(jsonb_agg(jsonb_build_object('slot',s,'available',not exists(
      select 1 from public.pt_bookings b where b.slot=s and b.status='CONFIRMED'
      and (b.trainer_id=(payload->>'trainer_id')::uuid or b.user_id=uid))) order by s),'[]') into result
      from generate_series(day_start+interval '6 hours',day_start+interval '21 hours',interval '1 hour') s
      where s>now() and s<=now()+interval '30 days';
  elsif action='history' then
    -- Return names even when the catalogue entry was archived.
    select jsonb_build_object(
      'sessions',coalesce((select jsonb_agg(to_jsonb(s)) from (select * from public.gym_sessions where user_id=uid order by check_in_at desc,id limit page_limit offset page_offset) s),'[]'),
      'redemptions',coalesce((select jsonb_agg(to_jsonb(r)) from (select r.*,w.name as reward_name from public.redemptions r join public.rewards w on w.id=r.reward_id where r.user_id=uid order by r.created_at desc,r.id limit page_limit offset page_offset) r),'[]'),
      'orders',coalesce((select jsonb_agg(to_jsonb(o)) from (select o.*,m.name as membership_name from public.membership_orders o join public.memberships m on m.id=o.membership_id where o.user_id=uid order by o.created_at desc,o.id limit page_limit offset page_offset) o),'[]'),
      'bookings',coalesce((select jsonb_agg(to_jsonb(b)) from (select b.*,t.name as trainer_name from public.pt_bookings b join public.trainers t on t.id=b.trainer_id where b.user_id=uid order by b.slot desc,b.id limit page_limit offset page_offset) b),'[]')) into result;
  elsif action='admin_dashboard' then
    select jsonb_build_object(
      'orders',coalesce((select jsonb_agg(to_jsonb(o)) from (select o.*,u.name as member_name,m.name as membership_name from public.membership_orders o join public.users u on u.id=o.user_id join public.memberships m on m.id=o.membership_id where o.status='PENDING' order by o.created_at,o.id limit page_limit offset page_offset) o),'[]'),
      'redemptions',coalesce((select jsonb_agg(to_jsonb(r)) from (select r.*,u.name as member_name,w.name as reward_name from public.redemptions r join public.users u on u.id=r.user_id join public.rewards w on w.id=r.reward_id where r.status='PENDING' order by r.created_at,r.id limit page_limit offset page_offset) r),'[]'),
      'qr_tokens',coalesce((select jsonb_agg(to_jsonb(q)-'token_hash') from (select * from public.qr_tokens where expires_at>now() and revoked_at is null order by issued_at desc,id limit page_limit offset page_offset) q),'[]')) into result;
  else raise exception using errcode='P0001', message='INVALID_INPUT';
  end if;
  return result;
end;
$$;
revoke all on function public.gymflow_read(text,jsonb) from public, anon, authenticated;
grant execute on function public.gymflow_read(text,jsonb) to authenticated;

-- Whitelisted catalogue tables/columns only. Archiving preserves history foreign keys.
create or replace function public.gymflow_catalogue(table_name text, record_id uuid default null, changes jsonb default null,
  page_limit integer default 100, page_offset integer default 0)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  existing jsonb;
  merged jsonb;
  defaults jsonb;
  columns_sql text;
  updates_sql text;
  result jsonb;
  ident uuid := coalesce(record_id,gen_random_uuid());
begin
  if not exists(select 1 from public.users where id=auth.uid() and role='ADMIN') then
    raise exception using errcode='P0001',message='FORBIDDEN';
  end if;
  if table_name not in ('rewards','memberships','trainers') then raise exception using errcode='P0001',message='INVALID_INPUT'; end if;
  if changes is null then
    execute format('select coalesce(jsonb_agg(to_jsonb(t)),''[]'') from (select * from public.%I order by created_at,id limit $1 offset $2) t',table_name)
      into result using least(100,greatest(1,page_limit)),least(100000,greatest(0,page_offset));
    return result;
  end if;
  if table_name='rewards' then
    columns_sql := 'name,description,points,stock,image_url,is_active';
    defaults := '{"description":"","stock":0,"image_url":"","is_active":true}'::jsonb;
  elsif table_name='memberships' then
    columns_sql := 'name,description,price_vnd,duration_days,points_per_checkin,is_active';
    defaults := '{"description":"","is_active":true}'::jsonb;
  else
    columns_sql := 'name,specialty,experience_years,description,image_url,is_active';
    defaults := '{"specialty":"","experience_years":0,"description":"","image_url":"","is_active":true}'::jsonb;
  end if;
  if exists(select 1 from jsonb_object_keys(changes) k where k <> all(string_to_array(columns_sql,','))) then
    raise exception using errcode='P0001',message='INVALID_INPUT';
  end if;
  if record_id is not null then
    execute format('select to_jsonb(t) from public.%I t where id=$1 for update',table_name) into existing using ident;
    if existing is null then raise exception using errcode='P0001',message='NOT_FOUND'; end if;
  end if;
  merged := defaults || coalesce(existing,'{}'::jsonb) || changes || jsonb_build_object('id',ident);
  select string_agg(format('%I=excluded.%I',c,c),',') into updates_sql from unnest(string_to_array(columns_sql,',')) c;
  execute format('insert into public.%1$I as t(id,%2$s) select id,%2$s from jsonb_populate_record(null::public.%1$I,$1)
    on conflict(id) do update set %3$s returning to_jsonb(t)',table_name,columns_sql,updates_sql) into result using merged;
  return result;
end;
$$;
revoke all on function public.gymflow_catalogue(text,uuid,jsonb,integer,integer) from public,anon,authenticated;
grant execute on function public.gymflow_catalogue(text,uuid,jsonb,integer,integer) to authenticated;
commit;
