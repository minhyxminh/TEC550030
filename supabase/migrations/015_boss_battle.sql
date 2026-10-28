-- Đại chiến Boss: a monthly community boss.
-- A member's first check-in of the day, at any branch, adds 1 HP to Hổ Flow
-- (the same once-a-day rule as GymPoint, so repeat scans cannot farm HP). When Hổ Flow's HP
-- reaches the boss's fixed HP (or in the last week of the month) members
-- can start the fight; a win pays every member's GymPoint reward at once.
begin;

create table if not exists public.boss_battles (
  month date primary key check (extract(day from month) = 1),
  boss_name text not null default 'Quái Vật Lười Biếng',
  boss_hp integer not null default 30 check (boss_hp > 0),
  reward_points integer not null default 20 check (reward_points > 0),
  defeated_at timestamptz,
  defeated_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now()
);
alter table public.boss_battles enable row level security;
-- Re-running this file also moves an earlier 500 HP default to 30.
alter table public.boss_battles alter column boss_hp set default 30;

alter table public.point_transactions add column if not exists boss_month date
  references public.boss_battles(month);

alter table public.point_transactions drop constraint if exists point_transactions_source_check;
alter table public.point_transactions add constraint point_transactions_source_check check (
  (type = 'EARN' and points > 0 and (
    (qr_token_id is not null and gym_session_id is not null
      and redemption_id is null and membership_order_id is null and boss_month is null)
    or
    (qr_token_id is null and gym_session_id is null
      and redemption_id is null and membership_order_id is not null and boss_month is null)
    or
    (qr_token_id is null and gym_session_id is null
      and redemption_id is null and membership_order_id is null and boss_month is not null)
  ))
  or
  (type = 'REDEEM' and points < 0 and redemption_id is not null
    and qr_token_id is null and gym_session_id is null and membership_order_id is null
    and boss_month is null)
);
create unique index if not exists point_transactions_boss_reward_once
  on public.point_transactions(user_id, boss_month)
  where boss_month is not null;

-- Security definer: tiger HP counts every member's check-ins, which RLS
-- hides from a single member. Only totals per branch leave the function.
create or replace function public.gymflow_boss(action text, payload jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  local_now timestamp := now() at time zone 'Asia/Ho_Chi_Minh';
  this_month date := date_trunc('month', local_now)::date;
  month_start timestamptz := this_month::timestamp at time zone 'Asia/Ho_Chi_Minh';
  month_end timestamptz := (this_month + interval '1 month')::timestamp at time zone 'Asia/Ho_Chi_Minh';
  days_left integer := ((this_month + interval '1 month')::date - local_now::date);
  battle public.boss_battles;
  tiger_hp integer;
  today_hp integer;
  my_hp integer;
  fight_open boolean;
  claimed boolean;
  branches jsonb;
begin
  if uid is null then raise exception using errcode='P0001', message='UNAUTHORIZED'; end if;
  if not exists(select 1 from public.users where id = uid) then
    raise exception using errcode='P0001', message='PROFILE_NOT_FOUND';
  end if;

  insert into public.boss_battles(month) values (this_month) on conflict (month) do nothing;
  select * into battle from public.boss_battles where month = this_month;

  -- One HP per member per day: their first check-in that day, at the branch
  -- where it happened.
  with visits as (
    select distinct on (s.user_id, (s.check_in_at at time zone 'Asia/Ho_Chi_Minh')::date)
      s.user_id, (s.check_in_at at time zone 'Asia/Ho_Chi_Minh')::date as day
    from public.gym_sessions s
    where s.check_in_at >= month_start and s.check_in_at < month_end
    order by s.user_id, (s.check_in_at at time zone 'Asia/Ho_Chi_Minh')::date, s.check_in_at
  )
  select count(*), count(*) filter (where day = local_now::date),
    count(*) filter (where user_id = uid)
    into tiger_hp, today_hp, my_hp from visits;
  select coalesce(jsonb_agg(b order by b.hp desc, b.gym_id), '[]'::jsonb) into branches from (
    select v.gym_id, coalesce(g.district, g.name, v.gym_id) as name, count(*)::integer as hp
    from (
      select distinct on (s.user_id, (s.check_in_at at time zone 'Asia/Ho_Chi_Minh')::date)
        s.gym_id
      from public.gym_sessions s
      where s.check_in_at >= month_start and s.check_in_at < month_end
      order by s.user_id, (s.check_in_at at time zone 'Asia/Ho_Chi_Minh')::date, s.check_in_at
    ) v left join public.gyms g on g.id = v.gym_id
    group by v.gym_id, g.district, g.name
    order by hp desc, v.gym_id limit 3
  ) b;
  -- The fight opens once the tiger is strong enough, or in the final week.
  fight_open := battle.defeated_at is null and (tiger_hp >= battle.boss_hp or days_left <= 7);

  if action = 'fight' then
    if battle.defeated_at is not null then
      raise exception using errcode='P0001', message='BOSS_ALREADY_DEFEATED';
    end if;
    if not fight_open then
      raise exception using errcode='P0001', message='BOSS_FIGHT_CLOSED';
    end if;
    if tiger_hp >= battle.boss_hp then
      update public.boss_battles set defeated_at = now(), defeated_by = uid
        where month = this_month and defeated_at is null
        returning * into battle;
      -- The whole community wins: the reward goes straight into every wallet.
      insert into public.point_transactions(user_id, type, points, reason, boss_month)
        select u.id, 'EARN', battle.reward_points,
          'Hạ Boss ' || battle.boss_name || ' tháng ' || to_char(this_month, 'MM/YYYY'), this_month
        from public.users u
        on conflict do nothing;
    end if;
  elsif action <> 'status' then
    raise exception using errcode='P0001', message='INVALID_INPUT';
  end if;

  -- Members who joined after the win are paid on their first visit.
  if battle.defeated_at is not null then
    insert into public.point_transactions(user_id, type, points, reason, boss_month)
      values (uid, 'EARN', battle.reward_points,
        'Hạ Boss ' || battle.boss_name || ' tháng ' || to_char(this_month, 'MM/YYYY'), this_month)
      on conflict do nothing;
  end if;

  select exists(select 1 from public.point_transactions
    where user_id = uid and boss_month = this_month) into claimed;

  return jsonb_build_object(
    'month', this_month,
    'boss_name', battle.boss_name,
    'boss_hp', battle.boss_hp,
    'tiger_hp', tiger_hp,
    'today_hp', today_hp,
    'my_hp', my_hp,
    'reward_points', battle.reward_points,
    'days_left', days_left,
    'fight_open', fight_open,
    'defeated', battle.defeated_at is not null,
    'claimed', claimed,
    'top_branches', branches,
    'result', case when action = 'fight' then
      case when battle.defeated_at is not null then 'WIN' else 'LOSE' end end
  );
end;
$$;
revoke all on function public.gymflow_boss(text, jsonb) from public, anon;
grant execute on function public.gymflow_boss(text, jsonb) to authenticated;

commit;
