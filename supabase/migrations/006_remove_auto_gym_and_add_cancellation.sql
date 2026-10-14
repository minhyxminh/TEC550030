-- Remove the temporary Phase 1 gym bridge and add Admin membership cancellation.
begin;

drop trigger if exists gymflow_membership_approval_gym on public.membership_orders;
drop function if exists public.gymflow_assign_approval_gym();

update public.users set home_gym_id = null where home_gym_id = '1';
update public.membership_orders set gym_id = null where gym_id = '1';

alter table public.users
  add column if not exists membership_cancelled_at timestamptz,
  add column if not exists membership_cancelled_by uuid references public.users(id),
  add column if not exists membership_cancellation_reason text;

alter table public.membership_orders
  add column if not exists cancelled_at timestamptz,
  add column if not exists cancelled_by uuid references public.users(id),
  add column if not exists cancellation_reason text;

alter table public.membership_orders drop constraint if exists membership_orders_status_check;
alter table public.membership_orders add constraint membership_orders_status_check
  check (status in ('PENDING', 'APPROVED', 'REJECTED', 'CANCELLED'));
alter table public.membership_orders drop constraint if exists membership_orders_check;
alter table public.membership_orders drop constraint if exists membership_orders_approval_fields_check;
alter table public.membership_orders add constraint membership_orders_approval_fields_check check (
  (status in ('APPROVED', 'CANCELLED') and approved_at is not null
    and starts_at is not null and ends_at is not null and ends_at > starts_at)
  or
  (status in ('PENDING', 'REJECTED') and approved_at is null
    and starts_at is null and ends_at is null)
);
alter table public.membership_orders drop constraint if exists membership_orders_cancellation_fields_check;
alter table public.membership_orders add constraint membership_orders_cancellation_fields_check check (
  (status = 'CANCELLED' and cancelled_at is not null and cancelled_by is not null)
  or
  (status <> 'CANCELLED' and cancelled_at is null and cancelled_by is null
    and cancellation_reason is null)
);

create or replace function public.gymflow_admin_members(page_limit integer default 100,
  page_offset integer default 0)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  result jsonb;
begin
  if uid is null then raise exception using errcode = 'P0001', message = 'UNAUTHORIZED'; end if;
  if not exists(select 1 from public.users where id = uid and role = 'ADMIN') then
    raise exception using errcode = 'P0001', message = 'FORBIDDEN';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'user_id', u.id,
    'name', u.name,
    'membership_id', u.active_membership_id,
    'membership_name', m.name,
    'home_gym_id', u.home_gym_id,
    'membership_expires_at', u.membership_expires_at,
    'has_open_session', exists(select 1 from public.gym_sessions s
      where s.user_id = u.id and s.check_out_at is null)
  ) order by u.name, u.id), '[]'::jsonb)
  into result
  from (
    select * from public.users
    where active_membership_id is not null and membership_expires_at > now()
    order by name, id
    limit least(100, greatest(1, page_limit))
    offset least(100000, greatest(0, page_offset))
  ) u
  left join public.memberships m on m.id = u.active_membership_id;
  return result;
end;
$$;
revoke all on function public.gymflow_admin_members(integer, integer) from public, anon;
grant execute on function public.gymflow_admin_members(integer, integer) to authenticated;

create or replace function public.gymflow_admin_cancel_membership(target_user_id uuid,
  cancellation_reason text default '')
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  profile public.users;
  active_order public.membership_orders;
  cancelled_at_value timestamptz := now();
  safe_reason text := left(trim(coalesce(cancellation_reason, '')), 500);
begin
  if uid is null then raise exception using errcode = 'P0001', message = 'UNAUTHORIZED'; end if;
  if not exists(select 1 from public.users where id = uid and role = 'ADMIN') then
    raise exception using errcode = 'P0001', message = 'FORBIDDEN';
  end if;

  select * into profile from public.users where id = target_user_id for update;
  if not found then raise exception using errcode = 'P0001', message = 'NOT_FOUND'; end if;
  if profile.active_membership_id is null or profile.membership_expires_at is null
      or profile.membership_expires_at <= cancelled_at_value then
    raise exception using errcode = 'P0001', message = 'MEMBERSHIP_NOT_ACTIVE';
  end if;

  select * into active_order from public.membership_orders
  where user_id = target_user_id and status = 'APPROVED'
    and membership_id = profile.active_membership_id
    and ends_at = profile.membership_expires_at
    and starts_at <= cancelled_at_value
  order by approved_at desc, id
  limit 1 for update;

  if found then
    update public.membership_orders set status = 'CANCELLED',
      cancelled_at = cancelled_at_value, cancelled_by = uid,
      cancellation_reason = safe_reason
    where id = active_order.id;
  end if;

  update public.users set membership_expires_at = cancelled_at_value,
    membership_cancelled_at = cancelled_at_value,
    membership_cancelled_by = uid,
    membership_cancellation_reason = safe_reason
  where id = target_user_id;

  return jsonb_build_object(
    'user_id', target_user_id,
    'membership_id', profile.active_membership_id,
    'membership_order_id', active_order.id,
    'cancelled_at', cancelled_at_value,
    'cancelled_by', uid,
    'cancellation_reason', safe_reason,
    'home_gym_id', profile.home_gym_id,
    'has_open_session', exists(select 1 from public.gym_sessions s
      where s.user_id = target_user_id and s.check_out_at is null)
  );
end;
$$;
revoke all on function public.gymflow_admin_cancel_membership(uuid, text) from public, anon, authenticated;
grant execute on function public.gymflow_admin_cancel_membership(uuid, text) to authenticated;

commit;