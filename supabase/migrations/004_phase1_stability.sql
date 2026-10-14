-- Phase 1: preserve existing ledger rows while enforcing daily check-in awards.
begin;

alter table public.users add column if not exists home_gym_id text;
alter table public.membership_orders add column if not exists gym_id text;
update public.memberships set points_per_checkin = 5
where points_per_checkin <> 5;
alter table public.memberships drop constraint if exists memberships_points_per_checkin_flat;
alter table public.memberships add constraint memberships_points_per_checkin_flat
  check (points_per_checkin = 5);
alter table public.memberships add column if not exists points_on_activation integer
  generated always as (
    case lower(btrim(name))
      when 'basic' then 100
      when 'premium' then 200
      when 'vip' then 300
      else 50
    end
  ) stored;
alter table public.point_transactions add column if not exists membership_order_id uuid
  references public.membership_orders(id);
alter table public.point_transactions add column if not exists checkin_day date;

update public.memberships set description = '5 GP tối đa một lần mỗi ngày check-in; 100 GP khi kích hoạt.'
where id = '10000000-0000-4000-8000-000000000001'
  and description = 'Gói tập cơ bản, 10 điểm cho mỗi QR mới.';
update public.memberships set description = '5 GP tối đa một lần mỗi ngày check-in; 200 GP khi kích hoạt.'
where id = '10000000-0000-4000-8000-000000000002'
  and description = 'Gói Premium, 20 điểm cho mỗi QR mới.';
update public.memberships set description = '5 GP tối đa một lần mỗi ngày check-in; 300 GP khi kích hoạt.'
where id = '10000000-0000-4000-8000-000000000003'
  and description = 'Gói VIP, 30 điểm cho mỗi QR mới.';

with active_gym as (
  select min(gym_id) as gym_id
  from (select distinct gym_id from public.qr_tokens
    where revoked_at is null and expires_at > now()) available_gyms
  having count(*) = 1
)
update public.users u set home_gym_id = g.gym_id
from active_gym g
where u.active_membership_id is not null and u.home_gym_id is null;

update public.membership_orders o set gym_id = u.home_gym_id
from public.users u
where o.user_id = u.id and o.gym_id is null and u.home_gym_id is not null;

alter table public.point_transactions drop constraint if exists point_transactions_check;
alter table public.point_transactions add constraint point_transactions_source_check check (
  (type = 'EARN' and points > 0 and (
    (qr_token_id is not null and gym_session_id is not null
      and redemption_id is null and membership_order_id is null)
    or
    (qr_token_id is null and gym_session_id is null
      and redemption_id is null and membership_order_id is not null)
  ))
  or
  (type = 'REDEEM' and points < 0 and redemption_id is not null
    and qr_token_id is null and gym_session_id is null and membership_order_id is null)
);

create unique index if not exists point_transactions_daily_checkin_once
  on public.point_transactions(user_id, checkin_day)
  where type = 'EARN' and checkin_day is not null;
create unique index if not exists point_transactions_membership_award_once
  on public.point_transactions(membership_order_id)
  where membership_order_id is not null;

create or replace function public.gymflow_limit_daily_checkin_points()
returns trigger language plpgsql set search_path = '' as $$
declare
  local_day date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
begin
  if new.type = 'EARN' and new.qr_token_id is not null then
    new.checkin_day := local_day;
    if exists (
      select 1 from public.point_transactions p
      where p.user_id = new.user_id and p.type = 'EARN' and p.qr_token_id is not null
        and (p.checkin_day = local_day or
          (p.checkin_day is null and (p.created_at at time zone 'Asia/Ho_Chi_Minh')::date = local_day))
    ) then
      return null;
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.gymflow_limit_daily_checkin_points() from public, anon, authenticated;
drop trigger if exists gymflow_daily_checkin_points on public.point_transactions;
create trigger gymflow_daily_checkin_points
  before insert on public.point_transactions
  for each row execute function public.gymflow_limit_daily_checkin_points();

create or replace function public.gymflow_assign_order_gym()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.gym_id is null then
    select home_gym_id into new.gym_id from public.users where id = new.user_id;
  end if;
  return new;
end;
$$;
revoke all on function public.gymflow_assign_order_gym() from public, anon, authenticated;
drop trigger if exists gymflow_membership_order_gym on public.membership_orders;
create trigger gymflow_membership_order_gym
  before insert on public.membership_orders
  for each row execute function public.gymflow_assign_order_gym();

create or replace function public.gymflow_assign_membership_gym_and_award()
returns trigger language plpgsql set search_path = '' as $$
declare
  package public.memberships;
begin
  if old.status = 'PENDING' and new.status = 'APPROVED' then
    select * into package from public.memberships where id = new.membership_id;
    update public.users set home_gym_id = coalesce(new.gym_id, home_gym_id) where id = new.user_id;
    insert into public.point_transactions(user_id, type, points, reason, membership_order_id)
      values(new.user_id, 'EARN', package.points_on_activation,
        'Kích hoạt gói ' || package.name, new.id);
  end if;
  return new;
end;
$$;
revoke all on function public.gymflow_assign_membership_gym_and_award() from public, anon, authenticated;
drop trigger if exists gymflow_membership_activation_award on public.membership_orders;
create trigger gymflow_membership_activation_award
  after update of status on public.membership_orders
  for each row execute function public.gymflow_assign_membership_gym_and_award();

create or replace function public.gymflow_validate_session_gym()
returns trigger language plpgsql set search_path = '' as $$
declare
  selected_gym text;
begin
  select home_gym_id into selected_gym from public.users where id = new.user_id;
  if selected_gym is null then
    raise exception using errcode = 'P0001', message = 'GYM_REQUIRED';
  end if;
  if selected_gym <> new.gym_id then
    raise exception using errcode = 'P0001', message = 'WRONG_GYM';
  end if;
  return new;
end;
$$;
revoke all on function public.gymflow_validate_session_gym() from public, anon, authenticated;
drop trigger if exists gymflow_session_gym_check on public.gym_sessions;
create trigger gymflow_session_gym_check
  before insert on public.gym_sessions
  for each row execute function public.gymflow_validate_session_gym();

create or replace function public.gymflow_my_profile()
returns jsonb language sql stable security invoker set search_path = '' as $$
  select to_jsonb(u) || jsonb_build_object(
    'membership_active', coalesce(
      u.active_membership_id is not null and u.membership_expires_at > now(), false))
  from public.users u where u.id = (select auth.uid());
$$;
revoke all on function public.gymflow_my_profile() from public, anon;
grant execute on function public.gymflow_my_profile() to authenticated;

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
  if action in ('occupancy','hourly') and not exists(
    select 1 from public.users where id=uid and (role='ADMIN' or home_gym_id=payload->>'gym_id')) then
    raise exception using errcode='P0001', message='FORBIDDEN';
  end if;
  if action='occupancy' then
    select jsonb_build_object('count',count(*),'gym_id',payload->>'gym_id','updated_at',now()) into result
      from public.gym_sessions where gym_id=payload->>'gym_id' and check_out_at is null;
  elsif action='hourly' then
    day_start := coalesce((payload->>'date')::date,(now() at time zone 'Asia/Ho_Chi_Minh')::date)::timestamp at time zone 'Asia/Ho_Chi_Minh';
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

commit;