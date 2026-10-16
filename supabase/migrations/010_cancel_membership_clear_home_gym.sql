-- Clear the current branch and close open sessions; keep all history.
begin;

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

  update public.users set home_gym_id = null, membership_expires_at = cancelled_at_value,
    membership_cancelled_at = cancelled_at_value,
    membership_cancelled_by = uid,
    membership_cancellation_reason = safe_reason
  where id = target_user_id;

  update public.gym_sessions set check_out_at = greatest(check_in_at, cancelled_at_value)
  where user_id = target_user_id and check_out_at is null;

  return jsonb_build_object(
    'user_id', target_user_id,
    'membership_id', profile.active_membership_id,
    'membership_order_id', active_order.id,
    'cancelled_at', cancelled_at_value,
    'cancelled_by', uid,
    'cancellation_reason', safe_reason,
    'home_gym_id', null,
    'has_open_session', exists(select 1 from public.gym_sessions s
      where s.user_id = target_user_id and s.check_out_at is null)
  );
end;
$$;
revoke all on function public.gymflow_admin_cancel_membership(uuid, text) from public, anon, authenticated;
grant execute on function public.gymflow_admin_cancel_membership(uuid, text) to authenticated;

commit;