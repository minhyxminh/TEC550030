-- Migration 012: Real bank-transfer payment foundation for membership purchases.
-- Keeps catalogue prices unchanged while using small demo transfer amounts:
-- Basic 5,000 VND, Premium 10,000 VND, VIP 15,000 VND.
begin;

alter table public.membership_orders
  add column if not exists payment_amount_vnd integer,
  add column if not exists payment_code text,
  add column if not exists payment_status text,
  add column if not exists payment_provider text,
  add column if not exists provider_transaction_id text,
  add column if not exists paid_at timestamptz,
  add column if not exists provider_transaction_at timestamptz,
  add column if not exists payment_content text;

alter table public.membership_orders
  drop constraint if exists membership_orders_payment_amount_check;
alter table public.membership_orders
  add constraint membership_orders_payment_amount_check
  check (payment_amount_vnd is null or payment_amount_vnd > 0);

alter table public.membership_orders
  drop constraint if exists membership_orders_payment_status_check;
alter table public.membership_orders
  add constraint membership_orders_payment_status_check
  check (payment_status is null or payment_status in ('UNPAID', 'PAID'));

alter table public.membership_orders
  drop constraint if exists membership_orders_payment_code_check;
alter table public.membership_orders
  add constraint membership_orders_payment_code_check
  check (payment_code is null or payment_code ~ '^GF[A-Z0-9]{12}$');

create unique index if not exists membership_orders_payment_code_unique
  on public.membership_orders(payment_code)
  where payment_code is not null;

create unique index if not exists membership_orders_provider_tx_unique
  on public.membership_orders(payment_provider, provider_transaction_id)
  where provider_transaction_id is not null;

-- A payment-backed order must never be manually approved before money is confirmed.
create or replace function public.gymflow_require_paid_membership_order()
returns trigger language plpgsql set search_path = '' as $$
begin
  if old.status = 'PENDING'
    and new.status = 'APPROVED'
    and new.payment_code is not null
    and coalesce(new.payment_status, 'UNPAID') <> 'PAID' then
    raise exception using errcode = 'P0001', message = 'PAYMENT_REQUIRED';
  end if;
  return new;
end;
$$;
revoke all on function public.gymflow_require_paid_membership_order()
  from public, anon, authenticated;

drop trigger if exists gymflow_membership_payment_required on public.membership_orders;
create trigger gymflow_membership_payment_required
  before update of status, payment_status on public.membership_orders
  for each row execute function public.gymflow_require_paid_membership_order();

-- Member creates a payment order. Catalogue price remains the real displayed price;
-- payment_amount_vnd is the reduced live-demo transfer amount.
create or replace function public.gymflow_create_membership_payment(
  membership_id_input uuid,
  idempotency_key_input uuid
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  package public.memberships;
  existing_order public.membership_orders;
  created_order public.membership_orders;
  demo_amount integer;
  generated_code text;
begin
  if uid is null then
    raise exception using errcode = 'P0001', message = 'UNAUTHORIZED';
  end if;
  if membership_id_input is null or idempotency_key_input is null then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;

  -- Serialize membership purchases for this member.
  perform 1 from public.users where id = uid for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'PROFILE_NOT_FOUND';
  end if;

  select * into existing_order
  from public.membership_orders
  where user_id = uid and idempotency_key = idempotency_key_input;

  if found then
    if existing_order.membership_id <> membership_id_input then
      raise exception using errcode = 'P0001', message = 'REQUEST_CONFLICT';
    end if;
    return (
      select to_jsonb(o) || jsonb_build_object(
        'membership_name', m.name,
        'points_on_activation', m.points_on_activation
      )
      from public.membership_orders o
      join public.memberships m on m.id = o.membership_id
      where o.id = existing_order.id
    );
  end if;

  select * into package
  from public.memberships
  where id = membership_id_input and is_active
  for share;
  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND';
  end if;

  if exists (
    select 1 from public.membership_orders
    where user_id = uid and status = 'PENDING'
  ) then
    raise exception using errcode = 'P0001', message = 'PENDING_ORDER_EXISTS';
  end if;

  demo_amount := case lower(btrim(package.name))
    when 'basic' then 5000
    when 'premium' then 10000
    when 'vip' then 15000
    else null
  end;
  if demo_amount is null then
    raise exception using errcode = 'P0001', message = 'PAYMENT_NOT_CONFIGURED';
  end if;

  generated_code := 'GF' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12));

  insert into public.membership_orders(
    user_id,
    membership_id,
    price_vnd_at_order,
    duration_days_at_order,
    status,
    idempotency_key,
    payment_amount_vnd,
    payment_code,
    payment_status,
    payment_provider
  ) values (
    uid,
    membership_id_input,
    package.price_vnd,
    package.duration_days,
    'PENDING',
    idempotency_key_input,
    demo_amount,
    generated_code,
    'UNPAID',
    'SEPAY'
  )
  returning * into created_order;

  return to_jsonb(created_order) || jsonb_build_object(
    'membership_name', package.name,
    'points_on_activation', package.points_on_activation
  );
end;
$$;
revoke all on function public.gymflow_create_membership_payment(uuid, uuid)
  from public, anon;
grant execute on function public.gymflow_create_membership_payment(uuid, uuid)
  to authenticated;

create or replace function public.gymflow_get_membership_payment(order_id_input uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  result jsonb;
begin
  if uid is null then
    raise exception using errcode = 'P0001', message = 'UNAUTHORIZED';
  end if;

  select to_jsonb(o) || jsonb_build_object(
    'membership_name', m.name,
    'points_on_activation', m.points_on_activation
  )
  into result
  from public.membership_orders o
  join public.memberships m on m.id = o.membership_id
  where o.id = order_id_input and o.user_id = uid;

  if result is null then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND';
  end if;
  return result;
end;
$$;
revoke all on function public.gymflow_get_membership_payment(uuid)
  from public, anon;
grant execute on function public.gymflow_get_membership_payment(uuid)
  to authenticated;

-- Trusted payment callback. Only the service_role used by the Edge Function may call it.
-- The existing activation trigger awards GymPoint exactly once when status becomes APPROVED.
create or replace function public.gymflow_confirm_membership_payment(
  payment_code_input text,
  provider_transaction_id_input text,
  transfer_amount_input bigint,
  transfer_content_input text default null,
  provider_transaction_at_input timestamptz default null
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  ord public.membership_orders;
  profile public.users;
  start_time timestamptz;
  provider_tx text := nullif(btrim(provider_transaction_id_input), '');
begin
  if payment_code_input is null
    or payment_code_input !~ '^GF[A-Z0-9]{12}$'
    or provider_tx is null
    or transfer_amount_input is null
    or transfer_amount_input <= 0 then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;

  -- Webhook retry/idempotency: a provider transaction can only settle one order.
  select * into ord
  from public.membership_orders
  where payment_provider = 'SEPAY'
    and provider_transaction_id = provider_tx
  for update;

  if found then
    return jsonb_build_object(
      'matched', true,
      'paid', ord.payment_status = 'PAID',
      'order_id', ord.id,
      'payment_code', ord.payment_code,
      'idempotent', true
    );
  end if;

  select * into ord
  from public.membership_orders
  where payment_code = payment_code_input
  for update;

  if not found then
    return jsonb_build_object('matched', false, 'paid', false);
  end if;

  if ord.status <> 'PENDING' then
    return jsonb_build_object(
      'matched', true,
      'paid', ord.payment_status = 'PAID',
      'order_id', ord.id,
      'payment_code', ord.payment_code,
      'reason', 'ORDER_NOT_PENDING'
    );
  end if;

  if transfer_amount_input <> ord.payment_amount_vnd then
    return jsonb_build_object(
      'matched', true,
      'paid', false,
      'order_id', ord.id,
      'payment_code', ord.payment_code,
      'expected_amount_vnd', ord.payment_amount_vnd,
      'received_amount_vnd', transfer_amount_input,
      'reason', 'AMOUNT_MISMATCH'
    );
  end if;

  select * into profile
  from public.users
  where id = ord.user_id
  for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'PROFILE_NOT_FOUND';
  end if;

  start_time := greatest(now(), coalesce(profile.membership_expires_at, now()));

  update public.membership_orders
  set payment_status = 'PAID',
      provider_transaction_id = provider_tx,
      payment_content = left(coalesce(transfer_content_input, ''), 500),
      provider_transaction_at = coalesce(provider_transaction_at_input, now()),
      paid_at = now(),
      status = 'APPROVED',
      approved_at = now(),
      starts_at = start_time,
      ends_at = start_time + make_interval(days => ord.duration_days_at_order)
  where id = ord.id
  returning * into ord;

  update public.users
  set active_membership_id = ord.membership_id,
      membership_expires_at = ord.ends_at,
      membership_cancelled_at = null,
      membership_cancelled_by = null,
      membership_cancellation_reason = null
  where id = ord.user_id;

  return jsonb_build_object(
    'matched', true,
    'paid', true,
    'order_id', ord.id,
    'payment_code', ord.payment_code,
    'membership_id', ord.membership_id,
    'starts_at', ord.starts_at,
    'ends_at', ord.ends_at,
    'idempotent', false
  );
end;
$$;
revoke all on function public.gymflow_confirm_membership_payment(text, text, bigint, text, timestamptz)
  from public, anon, authenticated;
grant execute on function public.gymflow_confirm_membership_payment(text, text, bigint, text, timestamptz)
  to service_role;

commit;
