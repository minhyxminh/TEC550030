begin;

create table if not exists public.gyms (
  id text primary key,
  name text not null check (length(trim(name)) between 1 and 120),
  address text not null check (length(trim(address)) between 1 and 300),
  district text not null check (length(trim(district)) between 1 and 100),
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  opening_hours text not null default '06:00-22:00',
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.gyms enable row level security;
revoke all on table public.gyms from anon, authenticated;
grant all on table public.gyms to service_role;
grant select on table public.gyms to anon, authenticated;

drop policy if exists gymflow_gyms_public_read on public.gyms;
create policy gymflow_gyms_public_read on public.gyms
  for select to anon, authenticated using (is_active = true);

-- ID 1 remains the branch displayed by the existing QR flow.
insert into public.gyms(id,name,address,district,latitude,longitude,opening_hours,is_active)
values
('1','GymFlow Nguyễn Chí Thanh','Khu Nguyễn Chí Thanh','Quận 10',10.7724,106.6676,'06:00-22:00',true),
('q1','GymFlow Nguyễn Huệ','Khu Nguyễn Huệ','Quận 1',10.7769,106.7009,'06:00-22:00',true),
('q3','GymFlow Võ Văn Tần','Khu Võ Văn Tần','Quận 3',10.7849,106.6865,'06:00-22:00',true),
('q5','GymFlow An Dương Vương','Khu An Dương Vương','Quận 5',10.7540,106.6634,'06:00-22:00',true),
('q6','GymFlow Hậu Giang','Khu Hậu Giang','Quận 6',10.7481,106.6358,'06:00-22:00',true),
('q7','GymFlow Nguyễn Thị Thập','Khu Nguyễn Thị Thập','Quận 7',10.7353,106.7216,'06:00-22:00',true),
('bt','GymFlow Bình Thạnh','Khu Xô Viết Nghệ Tĩnh','Bình Thạnh',10.8106,106.7091,'06:00-22:00',true),
('pn','GymFlow Phú Nhuận','Khu Phan Xích Long','Phú Nhuận',10.7992,106.6803,'06:00-22:00',true),
('tb','GymFlow Tân Bình','Khu Cộng Hòa','Tân Bình',10.8015,106.6526,'06:00-22:00',true),
('gv','GymFlow Gò Vấp','Khu Quang Trung','Gò Vấp',10.8387,106.6653,'06:00-22:00',true),
('td','GymFlow Thủ Đức','Khu Võ Văn Ngân','TP. Thủ Đức',10.8494,106.7537,'06:00-22:00',true)
on conflict(id) do update set
  name=excluded.name,
  address=excluded.address,
  district=excluded.district,
  latitude=excluded.latitude,
  longitude=excluded.longitude,
  opening_hours=excluded.opening_hours,
  is_active=excluded.is_active;

create or replace function public.gymflow_select_home_gym(gym_id_input text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  profile public.users;
  chosen public.gyms;
  result jsonb;
begin
  if uid is null then
    raise exception using errcode='P0001', message='UNAUTHORIZED';
  end if;

  select * into profile from public.users where id=uid for update;
  if not found then
    raise exception using errcode='P0001', message='PROFILE_NOT_FOUND';
  end if;

  select * into chosen
  from public.gyms
  where id=gym_id_input and is_active=true;
  if not found then
    raise exception using errcode='P0001', message='GYM_NOT_FOUND';
  end if;

  if exists (
    select 1 from public.gym_sessions
    where user_id=uid and check_out_at is null
  ) then
    raise exception using errcode='P0001', message='OPEN_SESSION';
  end if;

  update public.users set home_gym_id=chosen.id
  where id=uid
  returning to_jsonb(users.*) into result;
  return result;
end;
$$;
revoke all on function public.gymflow_select_home_gym(text) from public, anon, authenticated;
grant execute on function public.gymflow_select_home_gym(text) to authenticated;

commit;