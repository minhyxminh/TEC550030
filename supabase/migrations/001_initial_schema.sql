-- GymFlow schema v1. Run once in Supabase SQL Editor before registering users.
-- A transaction prevents a partially installed schema if any statement fails.
begin;

create table public.memberships (
  id uuid primary key default gen_random_uuid(),
  name text not null unique check (length(name) between 1 and 100),
  description text not null default '',
  price_vnd integer not null check (price_vnd >= 0),
  duration_days integer not null check (duration_days > 0),
  points_per_checkin integer not null check (points_per_checkin > 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- Password hashes and login emails are managed by Supabase in auth.users.
-- Never accept a role or active membership supplied by a registration request.
create table public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null check (length(name) between 1 and 100),
  role text not null default 'MEMBER' check (role in ('MEMBER', 'ADMIN')),
  active_membership_id uuid references public.memberships(id),
  membership_expires_at timestamptz,
  created_at timestamptz not null default now(),
  check ((active_membership_id is null) = (membership_expires_at is null))
);

create table public.qr_tokens (
  id uuid primary key default gen_random_uuid(),
  -- Current Flutter Home uses gym ID "1". A gyms table can be added later.
  gym_id text not null default '1' check (length(gym_id) between 1 and 100),
  -- Store SHA-256 of a cryptographically random QR token, not its raw value.
  token_hash text not null unique check (token_hash ~ '^[0-9a-f]{64}$'),
  issued_at timestamptz not null default now(),
  expires_at timestamptz not null,
  revoked_at timestamptz,
  unique (id, gym_id),
  check (expires_at > issued_at),
  check (expires_at <= issued_at + interval '1 hour')
);

create table public.gym_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  gym_id text not null,
  qr_token_id uuid not null,
  check_in_at timestamptz not null default now(),
  check_out_at timestamptz,
  unique (id, user_id),
  foreign key (qr_token_id, gym_id) references public.qr_tokens(id, gym_id),
  check (check_out_at is null or check_out_at >= check_in_at)
);
-- Only one open session per member, across all gyms.
create unique index one_open_session_per_user on public.gym_sessions(user_id)
  where check_out_at is null;
create index gym_sessions_occupancy_idx on public.gym_sessions(gym_id)
  where check_out_at is null;
create index gym_sessions_history_idx on public.gym_sessions(user_id, check_in_at desc);
create index gym_sessions_hourly_idx on public.gym_sessions(gym_id, check_in_at, check_out_at);

create table public.rewards (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(name) between 1 and 100),
  description text not null default '',
  points integer not null check (points > 0),
  stock integer not null default 0 check (stock >= 0),
  image_url text not null default '',
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.redemptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  reward_id uuid not null references public.rewards(id),
  points_spent integer not null check (points_spent > 0),
  status text not null default 'PENDING' check (status in ('PENDING', 'FULFILLED')),
  -- Send a new UUID per intentional redeem, reuse it when retrying that request.
  idempotency_key uuid not null,
  created_at timestamptz not null default now(),
  unique (user_id, idempotency_key),
  unique (id, user_id)
);

create table public.point_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  type text not null check (type in ('EARN', 'REDEEM')),
  points integer not null,
  reason text not null,
  qr_token_id uuid references public.qr_tokens(id),
  gym_session_id uuid,
  redemption_id uuid unique,
  created_at timestamptz not null default now(),
  foreign key (gym_session_id, user_id) references public.gym_sessions(id, user_id),
  foreign key (redemption_id, user_id) references public.redemptions(id, user_id) on delete cascade,
  check (
    (type = 'EARN' and points > 0 and qr_token_id is not null and gym_session_id is not null and redemption_id is null)
    or
    (type = 'REDEEM' and points < 0 and redemption_id is not null and qr_token_id is null and gym_session_id is null)
  )
);
-- Check-in again is allowed; awarding points again for the same token is not.
create unique index earn_once_per_user_token on public.point_transactions(user_id, qr_token_id)
  where type = 'EARN';
create index point_transactions_history_idx on public.point_transactions(user_id, created_at desc);
create index redemptions_history_idx on public.redemptions(user_id, created_at desc);

create table public.membership_orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  membership_id uuid not null references public.memberships(id),
  price_vnd_at_order integer not null check (price_vnd_at_order >= 0),
  duration_days_at_order integer not null check (duration_days_at_order > 0),
  status text not null default 'PENDING' check (status in ('PENDING', 'APPROVED', 'REJECTED')),
  approved_at timestamptz,
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  check (
    (status = 'APPROVED' and approved_at is not null and starts_at is not null and ends_at is not null and ends_at > starts_at)
    or
    (status <> 'APPROVED' and approved_at is null and starts_at is null and ends_at is null)
  )
);
create index membership_orders_history_idx on public.membership_orders(user_id, created_at desc);

create table public.trainers (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(name) between 1 and 100),
  specialty text not null default '',
  experience_years integer not null default 0 check (experience_years >= 0),
  description text not null default '',
  image_url text not null default '',
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.pt_bookings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  trainer_id uuid not null references public.trainers(id),
  -- MVP: fixed 60-minute slots, starting on the hour in Asia/Ho_Chi_Minh.
  slot timestamptz not null,
  status text not null default 'CONFIRMED' check (status in ('CONFIRMED', 'CANCELLED')),
  created_at timestamptz not null default now(),
  check (extract(minute from slot at time zone 'Asia/Ho_Chi_Minh') = 0),
  check (extract(second from slot at time zone 'Asia/Ho_Chi_Minh') = 0)
);
create unique index trainer_slot_once on public.pt_bookings(trainer_id, slot) where status = 'CONFIRMED';
create unique index user_slot_once on public.pt_bookings(user_id, slot) where status = 'CONFIRMED';
create index pt_bookings_history_idx on public.pt_bookings(user_id, slot desc);

create function public.gymflow_handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.users(id, name)
  values (new.id, left(coalesce(nullif(trim(new.raw_user_meta_data ->> 'name'), ''), 'Member'), 100));
  return new;
end;
$$;
revoke all on function public.gymflow_handle_new_user() from public, anon, authenticated;
create trigger gymflow_auth_user_created after insert on auth.users
  for each row execute function public.gymflow_handle_new_user();

-- Backfill accounts that existed before schema installation; do not change them.
insert into public.users(id, name)
select id, left(coalesce(nullif(trim(raw_user_meta_data ->> 'name'), ''), 'Member'), 100)
from auth.users on conflict (id) do nothing;

-- RLS + explicit privileges. No app user may write point/stock/membership fields.
do $$
declare table_name text;
begin
  foreach table_name in array array[
    'users','gym_sessions','qr_tokens','point_transactions','rewards',
    'redemptions','memberships','membership_orders','trainers','pt_bookings'
  ] loop
    execute format('alter table public.%I enable row level security', table_name);
    execute format('revoke all on table public.%I from anon, authenticated', table_name);
    execute format('grant all on table public.%I to service_role', table_name);
  end loop;
end;
$$;

grant select on public.rewards, public.memberships, public.trainers to anon, authenticated;
create policy rewards_active_read on public.rewards for select to anon, authenticated using (is_active);
create policy memberships_active_read on public.memberships for select to anon, authenticated using (is_active);
create policy trainers_active_read on public.trainers for select to anon, authenticated using (is_active);

grant select on public.users, public.gym_sessions, public.point_transactions,
  public.redemptions, public.membership_orders, public.pt_bookings to authenticated;
create policy users_self_read on public.users for select to authenticated using (id = (select auth.uid()));
create policy sessions_self_read on public.gym_sessions for select to authenticated using (user_id = (select auth.uid()));
create policy points_self_read on public.point_transactions for select to authenticated using (user_id = (select auth.uid()));
create policy redemptions_self_read on public.redemptions for select to authenticated using (user_id = (select auth.uid()));
create policy orders_self_read on public.membership_orders for select to authenticated using (user_id = (select auth.uid()));
create policy bookings_self_read on public.pt_bookings for select to authenticated using (user_id = (select auth.uid()));
-- qr_tokens has no client read policy or grants: copying the catalogue must not reveal valid tokens.

-- Sum inside PostgreSQL, avoiding PostgREST row limits on long histories.
create function public.get_my_point_balance()
returns bigint language sql stable security invoker set search_path = '' as $$
  select coalesce(sum(points), 0)::bigint from public.point_transactions
  where user_id = (select auth.uid());
$$;
revoke all on function public.get_my_point_balance() from public, anon;
grant execute on function public.get_my_point_balance() to authenticated;

commit;
