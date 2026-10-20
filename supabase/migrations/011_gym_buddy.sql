-- Migration 011: Gym Buddy feature, candidate feed, swipe/match, and chat extension for DIRECT/GROUP.
begin;

-- 1. Extend existing public.conversations for DIRECT and GROUP chats.
-- Retain legacy user_id for existing SUPPORT conversations while allowing NULL for DIRECT/GROUP.
alter table public.conversations add column if not exists type text not null default 'SUPPORT' check (type in ('SUPPORT', 'DIRECT', 'GROUP'));
alter table public.conversations add column if not exists title text;
alter table public.conversations add column if not exists created_by uuid references public.users(id) on delete set null;

alter table public.conversations alter column user_id drop not null;
alter table public.conversations drop constraint if exists conversations_user_id_key;

create unique index if not exists conversations_support_user_id_idx on public.conversations(user_id) where type = 'SUPPORT';
alter table public.conversations drop constraint if exists conversations_support_user_check;
alter table public.conversations add constraint conversations_support_user_check check (type <> 'SUPPORT' or user_id is not null);

-- 2. Conversation participants table.
create table if not exists public.conversation_participants (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  role text not null default 'MEMBER' check (role in ('MEMBER', 'ADMIN', 'OWNER')),
  joined_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);
create index if not exists conversation_participants_user_idx on public.conversation_participants(user_id, conversation_id);

create or replace function public.gymflow_is_conversation_member(target_conv_id uuid, check_user_id uuid)
returns boolean language sql security definer stable set search_path = '' as $$
  select exists(
    select 1 from public.conversation_participants
    where conversation_id = target_conv_id and user_id = check_user_id
  );
$$;
revoke all on function public.gymflow_is_conversation_member(uuid, uuid) from public, anon;
grant execute on function public.gymflow_is_conversation_member(uuid, uuid) to authenticated;

alter table public.conversation_participants enable row level security;
revoke all on public.conversation_participants from anon, authenticated;
grant select on public.conversation_participants to authenticated;

drop policy if exists conversation_participants_read on public.conversation_participants;
create policy conversation_participants_read on public.conversation_participants for select to authenticated
  using (
    user_id = auth.uid()
    or public.gymflow_is_conversation_member(conversation_id, auth.uid())
    or exists (select 1 from public.users where id = auth.uid() and role = 'ADMIN')
  );

-- Update RLS on conversations and messages to allow DIRECT / GROUP members to access their chat.
drop policy if exists conversations_read on public.conversations;
create policy conversations_read on public.conversations for select to authenticated
  using (
    (type = 'SUPPORT' and (user_id = auth.uid() or exists(select 1 from public.users where id = auth.uid() and role = 'ADMIN')))
    or
    (type in ('DIRECT', 'GROUP') and public.gymflow_is_conversation_member(id, auth.uid()))
  );

drop policy if exists messages_read on public.messages;
create policy messages_read on public.messages for select to authenticated
  using (
    exists (
      select 1 from public.conversations c
      where c.id = conversation_id
      and (
        (c.type = 'SUPPORT' and (c.user_id = auth.uid() or exists(select 1 from public.users where id = auth.uid() and role = 'ADMIN')))
        or
        (c.type in ('DIRECT', 'GROUP') and public.gymflow_is_conversation_member(c.id, auth.uid()))
      )
    )
  );

-- Extend gymflow_chat RPC for DIRECT / GROUP chats while strictly preserving SUPPORT behavior.
create or replace function public.gymflow_chat(action text, payload jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  uid uuid := auth.uid();
  admin_user boolean;
  conv public.conversations;
  msg public.messages;
  result jsonb;
  text_content text;
  request_id uuid;
  page_limit integer := least(100, greatest(1, coalesce((payload->>'limit')::integer,50)));
  page_offset integer := greatest(0,coalesce((payload->>'offset')::integer,0));
begin
  if uid is null then raise exception 'UNAUTHORIZED'; end if;
  select role='ADMIN' into admin_user from public.users where id=uid;
  if not found then raise exception 'PROFILE_NOT_FOUND'; end if;
  if action='open' then
    insert into public.conversations(user_id, type) values(uid, 'SUPPORT')
      on conflict(user_id) where type = 'SUPPORT' do update set user_id=excluded.user_id returning * into conv;
    return to_jsonb(conv);
  elsif action='inbox' then
    if not admin_user then raise exception 'FORBIDDEN'; end if;
    select coalesce(jsonb_agg(to_jsonb(c)),'[]'::jsonb) into result from (
      select c.*, u.name, (select content from public.messages m
        where m.conversation_id=c.id order by sequence desc limit 1) as last_message,
        (select count(*) from public.messages m where m.conversation_id=c.id
          and m.sender_id=c.user_id and m.read_at is null) as unread
      from public.conversations c join public.users u on u.id=c.user_id
      where c.type = 'SUPPORT'
      order by c.updated_at desc,c.id limit page_limit offset page_offset
    ) c;
    return jsonb_build_object('conversations',result);
  end if;
  select * into conv from public.conversations where id=(payload->>'conversation_id')::uuid;
  if not found then raise exception 'NOT_FOUND'; end if;
  if conv.type = 'SUPPORT' then
    if conv.user_id <> uid and not admin_user then raise exception 'NOT_FOUND'; end if;
  else
    if not exists(select 1 from public.conversation_participants where conversation_id=conv.id and user_id=uid) then
      raise exception 'NOT_FOUND';
    end if;
  end if;
  if action='messages' then
    select coalesce(jsonb_agg(to_jsonb(m) order by m.sequence),'[]'::jsonb) into result from (
      select * from public.messages where conversation_id=conv.id
        and (payload->>'before' is null or sequence<(payload->>'before')::bigint)
      order by sequence desc limit page_limit
    ) m;
    return jsonb_build_object('messages',result);
  elsif action='send' then
    text_content := btrim(payload->>'content');
    request_id := (payload->>'client_id')::uuid;
    if text_content is null or length(text_content) not between 1 and 2000 or request_id is null then
      raise exception 'INVALID_INPUT';
    end if;
    -- Serialize sends within a conversation so sequence is a stable polling cursor.
    perform 1 from public.conversations where id=conv.id for update;
    insert into public.messages(conversation_id,sender_id,content,client_id)
      values(conv.id,uid,text_content,request_id)
      on conflict(sender_id,client_id) do nothing returning * into msg;
    if not found then
      select * into msg from public.messages where sender_id=uid and client_id=request_id;
      if msg.conversation_id<>conv.id or msg.content<>text_content then raise exception 'REQUEST_CONFLICT'; end if;
    else
      update public.conversations set updated_at=now() where id=conv.id;
    end if;
    return to_jsonb(msg);
  elsif action='read' then
    update public.messages set read_at=now() where conversation_id=conv.id and read_at is null
      and sequence<=coalesce((payload->>'through')::bigint,0)
      and ((conv.type='SUPPORT' and ((uid=conv.user_id and sender_id<>uid) or (admin_user and sender_id=conv.user_id)))
           or (conv.type in ('DIRECT','GROUP') and sender_id<>uid));
    return jsonb_build_object('ok',true);
  end if;
  raise exception 'INVALID_INPUT';
end;
$$;

-- 3. Buddy Profiles table.
create table if not exists public.buddy_profiles (
  user_id uuid primary key references public.users(id) on delete cascade,
  enabled boolean not null default true,
  age smallint null check (age is null or (age >= 16 and age <= 100)),
  gender text null,
  show_age boolean not null default true,
  show_gender boolean not null default true,
  fitness_goal text null,
  experience_level text null check (experience_level is null or experience_level in ('BEGINNER', 'INTERMEDIATE', 'ADVANCED')),
  favorite_workouts text[] not null default '{}',
  preferred_workout_times text[] not null default '{}',
  workout_style text[] not null default '{}',
  bio text null,
  onboarding_completed boolean not null default false,
  looking_for_partner boolean not null default false,
  partner_date date null,
  partner_start_time time null,
  partner_end_time time null,
  partner_workout text null,
  partner_gym_id text null references public.gyms(id) on delete set null,
  partner_note text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (partner_start_time is null or partner_end_time is null or partner_end_time > partner_start_time)
);

create index if not exists buddy_profiles_feed_idx on public.buddy_profiles(enabled, onboarding_completed, looking_for_partner, updated_at desc);

alter table public.buddy_profiles enable row level security;
revoke all on public.buddy_profiles from anon, authenticated;
grant select on public.buddy_profiles to authenticated;

drop policy if exists buddy_profiles_read on public.buddy_profiles;
create policy buddy_profiles_self_read on public.buddy_profiles for select to authenticated
  using (user_id = auth.uid());

-- 4. Buddy Swipes table.
create table if not exists public.buddy_swipes (
  id uuid primary key default gen_random_uuid(),
  swiper_id uuid not null references public.users(id) on delete cascade,
  target_id uuid not null references public.users(id) on delete cascade,
  action text not null check (action in ('LIKE', 'PASS')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (swiper_id <> target_id),
  unique (swiper_id, target_id)
);

create index if not exists buddy_swipes_swiper_idx on public.buddy_swipes(swiper_id, target_id);
create index if not exists buddy_swipes_target_action_idx on public.buddy_swipes(target_id, action);

alter table public.buddy_swipes enable row level security;
revoke all on public.buddy_swipes from anon, authenticated;
grant select on public.buddy_swipes to authenticated;

create policy buddy_swipes_self_read on public.buddy_swipes for select to authenticated
  using (swiper_id = auth.uid());

-- 5. Buddy Matches table.
create table if not exists public.buddy_matches (
  id uuid primary key default gen_random_uuid(),
  user_1 uuid not null references public.users(id) on delete cascade,
  user_2 uuid not null references public.users(id) on delete cascade,
  conversation_id uuid references public.conversations(id) on delete set null,
  created_at timestamptz not null default now(),
  check (user_1 < user_2),
  unique (user_1, user_2)
);

create index if not exists buddy_matches_user1_idx on public.buddy_matches(user_1);
create index if not exists buddy_matches_user2_idx on public.buddy_matches(user_2);

alter table public.buddy_matches enable row level security;
revoke all on public.buddy_matches from anon, authenticated;
grant select on public.buddy_matches to authenticated;

create policy buddy_matches_read on public.buddy_matches for select to authenticated
  using (user_1 = auth.uid() or user_2 = auth.uid());

-- 6. Core RPC: gymflow_buddy
create or replace function public.gymflow_buddy(action text, payload jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  my_home_gym text;
  result jsonb;
  target_user uuid;
  swipe_action text;
  has_reciprocal boolean;
  u1 uuid;
  u2 uuid;
  new_conv_id uuid;
  match_rec public.buddy_matches;
  feed_limit integer;
  group_title text;
  group_member_ids uuid[];
  group_member_count integer;
  matched_member_count integer;
begin
  if uid is null then
    raise exception 'UNAUTHORIZED';
  end if;

  if not exists (select 1 from public.users where id = uid) then
    raise exception 'PROFILE_NOT_FOUND';
  end if;

  if action = 'PROFILE_GET' then
    select jsonb_build_object(
      'user_id', u.id,
      'name', u.name,
      'avatar_path', u.avatar_path,
      'home_gym_id', u.home_gym_id,
      'gym_name', g.name,
      'district', g.district,
      'enabled', coalesce(bp.enabled, true),
      'age', bp.age,
      'gender', bp.gender,
      'show_age', coalesce(bp.show_age, true),
      'show_gender', coalesce(bp.show_gender, true),
      'fitness_goal', bp.fitness_goal,
      'experience_level', bp.experience_level,
      'favorite_workouts', coalesce(bp.favorite_workouts, '{}'::text[]),
      'preferred_workout_times', coalesce(bp.preferred_workout_times, '{}'::text[]),
      'workout_style', coalesce(bp.workout_style, '{}'::text[]),
      'bio', bp.bio,
      'onboarding_completed', coalesce(bp.onboarding_completed, false),
      'looking_for_partner', coalesce(bp.looking_for_partner, false),
      'partner_date', bp.partner_date,
      'partner_start_time', bp.partner_start_time,
      'partner_end_time', bp.partner_end_time,
      'partner_workout', bp.partner_workout,
      'partner_gym_id', bp.partner_gym_id,
      'partner_gym_name', pg.name,
      'partner_note', bp.partner_note,
      'created_at', bp.created_at,
      'updated_at', bp.updated_at
    ) into result
    from public.users u
    left join public.buddy_profiles bp on bp.user_id = u.id
    left join public.gyms g on g.id = u.home_gym_id
    left join public.gyms pg on pg.id = bp.partner_gym_id
    where u.id = uid;
    return result;

  elsif action = 'PROFILE_UPSERT' then
    if payload ? 'partner_gym_id' and payload->>'partner_gym_id' is not null and btrim(payload->>'partner_gym_id') <> '' then
      if not exists (select 1 from public.gyms where id = payload->>'partner_gym_id' and is_active = true) then
        raise exception 'GYM_NOT_FOUND';
      end if;
    end if;

    insert into public.buddy_profiles (
      user_id,
      enabled,
      age,
      gender,
      show_age,
      show_gender,
      fitness_goal,
      experience_level,
      favorite_workouts,
      preferred_workout_times,
      workout_style,
      bio,
      onboarding_completed,
      looking_for_partner,
      partner_date,
      partner_start_time,
      partner_end_time,
      partner_workout,
      partner_gym_id,
      partner_note,
      updated_at
    ) values (
      uid,
      coalesce((payload->>'enabled')::boolean, true),
      (payload->>'age')::smallint,
      payload->>'gender',
      coalesce((payload->>'show_age')::boolean, true),
      coalesce((payload->>'show_gender')::boolean, true),
      payload->>'fitness_goal',
      payload->>'experience_level',
      coalesce((select array_agg(x::text) from jsonb_array_elements_text(coalesce(payload->'favorite_workouts', '[]'::jsonb)) x), '{}'::text[]),
      coalesce((select array_agg(x::text) from jsonb_array_elements_text(coalesce(payload->'preferred_workout_times', '[]'::jsonb)) x), '{}'::text[]),
      coalesce((select array_agg(x::text) from jsonb_array_elements_text(coalesce(payload->'workout_style', '[]'::jsonb)) x), '{}'::text[]),
      payload->>'bio',
      coalesce((payload->>'onboarding_completed')::boolean, false),
      coalesce((payload->>'looking_for_partner')::boolean, false),
      nullif(payload->>'partner_date', '')::date,
      nullif(payload->>'partner_start_time', '')::time,
      nullif(payload->>'partner_end_time', '')::time,
      payload->>'partner_workout',
      nullif(payload->>'partner_gym_id', ''),
      payload->>'partner_note',
      now()
    )
    on conflict (user_id) do update set
      enabled = coalesce((excluded.enabled), public.buddy_profiles.enabled),
      age = excluded.age,
      gender = excluded.gender,
      show_age = excluded.show_age,
      show_gender = excluded.show_gender,
      fitness_goal = excluded.fitness_goal,
      experience_level = excluded.experience_level,
      favorite_workouts = excluded.favorite_workouts,
      preferred_workout_times = excluded.preferred_workout_times,
      workout_style = excluded.workout_style,
      bio = excluded.bio,
      onboarding_completed = excluded.onboarding_completed,
      looking_for_partner = excluded.looking_for_partner,
      partner_date = excluded.partner_date,
      partner_start_time = excluded.partner_start_time,
      partner_end_time = excluded.partner_end_time,
      partner_workout = excluded.partner_workout,
      partner_gym_id = excluded.partner_gym_id,
      partner_note = excluded.partner_note,
      updated_at = now();

    return public.gymflow_buddy('PROFILE_GET');

  elsif action = 'FEED' then
    select home_gym_id into my_home_gym from public.users where id = uid;
    feed_limit := least(100, greatest(1, coalesce((payload->>'limit')::integer, 20)));

    select coalesce(jsonb_agg(to_jsonb(c)), '[]'::jsonb) into result from (
      select
        bp.user_id,
        u.name,
        u.avatar_path,
        case when bp.show_age then bp.age else null end as age,
        case when bp.show_gender then bp.gender else null end as gender,
        bp.show_age,
        bp.show_gender,
        u.home_gym_id,
        g.name as gym_name,
        g.district,
        bp.fitness_goal,
        bp.experience_level,
        bp.favorite_workouts,
        bp.preferred_workout_times,
        bp.workout_style,
        bp.bio,
        bp.looking_for_partner,
        bp.partner_date,
        bp.partner_start_time,
        bp.partner_end_time,
        bp.partner_workout,
        bp.partner_gym_id,
        pg.name as partner_gym_name,
        bp.partner_note
      from public.buddy_profiles bp
      join public.users u on u.id = bp.user_id
      left join public.gyms g on g.id = u.home_gym_id
      left join public.gyms pg on pg.id = bp.partner_gym_id
      where bp.user_id <> uid
        and bp.enabled = true
        and bp.onboarding_completed = true
        and u.active_membership_id is not null
        and u.membership_expires_at > now()
        and not exists (
          select 1 from public.buddy_swipes s
          where s.swiper_id = uid and s.target_id = bp.user_id
        )
      order by
        case when my_home_gym is not null and u.home_gym_id = my_home_gym then 1 else 0 end desc,
        bp.looking_for_partner desc,
        bp.updated_at desc
      limit feed_limit
    ) c;
    return jsonb_build_object('candidates', result);

  elsif action = 'SWIPE' then
    target_user := (payload->>'target_id')::uuid;
    swipe_action := upper(btrim(payload->>'action'));

    if target_user is null or swipe_action not in ('LIKE', 'PASS') then
      raise exception 'INVALID_INPUT';
    end if;

    if target_user = uid then
      raise exception 'CANNOT_SWIPE_SELF';
    end if;

    if not exists (select 1 from public.users where id = target_user) then
      raise exception 'NOT_FOUND';
    end if;

    insert into public.buddy_swipes (swiper_id, target_id, action, updated_at)
    values (uid, target_user, swipe_action, now())
    on conflict (swiper_id, target_id) do update set
      action = excluded.action,
      updated_at = now();

    if swipe_action = 'PASS' then
      return jsonb_build_object('matched', false, 'action', 'PASS');
    end if;

    select exists (
      select 1 from public.buddy_swipes bs
      where bs.swiper_id = target_user and bs.target_id = uid and bs.action = 'LIKE'
    ) into has_reciprocal;

    if not has_reciprocal then
      return jsonb_build_object('matched', false, 'action', 'LIKE');
    end if;

    u1 := least(uid, target_user);
    u2 := greatest(uid, target_user);

    select * into match_rec from public.buddy_matches where user_1 = u1 and user_2 = u2;
    if found then
      return jsonb_build_object(
        'matched', true,
        'action', 'LIKE',
        'match_id', match_rec.id,
        'conversation_id', match_rec.conversation_id,
        'is_new', false
      );
    end if;

    -- Create DIRECT conversation and link both participants
    insert into public.conversations (type, title, created_by)
    values ('DIRECT', null, uid)
    returning id into new_conv_id;

    insert into public.conversation_participants (conversation_id, user_id, role)
    values
      (new_conv_id, u1, 'MEMBER'),
      (new_conv_id, u2, 'MEMBER')
    on conflict (conversation_id, user_id) do nothing;

    insert into public.buddy_matches (user_1, user_2, conversation_id)
    values (u1, u2, new_conv_id)
    returning * into match_rec;

    return jsonb_build_object(
      'matched', true,
      'action', 'LIKE',
      'match_id', match_rec.id,
      'conversation_id', new_conv_id,
      'is_new', true
    );

  elsif action = 'MATCHES' then
    select coalesce(jsonb_agg(to_jsonb(m)), '[]'::jsonb) into result from (
      select
        bm.id,
        bm.conversation_id,
        bm.created_at,
        other_u.id as other_user_id,
        other_u.name as other_user_name,
        other_u.avatar_path as other_avatar_path
      from public.buddy_matches bm
      join public.users other_u on other_u.id = (case when bm.user_1 = uid then bm.user_2 else bm.user_1 end)
      where bm.user_1 = uid or bm.user_2 = uid
      order by bm.created_at desc
    ) m;
    return jsonb_build_object('matches', result);

  elsif action = 'MATCH_GET' then
    select to_jsonb(m) into result from (
      select
        bm.id,
        bm.conversation_id,
        bm.created_at,
        other_u.id as other_user_id,
        other_u.name as other_user_name,
        other_u.avatar_path as other_avatar_path
      from public.buddy_matches bm
      join public.users other_u on other_u.id = (case when bm.user_1 = uid then bm.user_2 else bm.user_1 end)
      where (bm.user_1 = uid or bm.user_2 = uid)
        and (
          (payload ? 'match_id' and bm.id = (payload->>'match_id')::uuid)
          or
          (payload ? 'other_user_id' and other_u.id = (payload->>'other_user_id')::uuid)
        )
      limit 1
    ) m;
    if result is null then raise exception 'NOT_FOUND'; end if;
    return result;

  elsif action = 'GROUP_CREATE' then
    group_title := btrim(payload->>'title');
    if group_title is null or length(group_title) not between 1 and 80 then
      raise exception 'INVALID_INPUT';
    end if;

    select coalesce(array_agg(value::uuid), '{}'::uuid[])
      into group_member_ids
    from jsonb_array_elements_text(coalesce(payload->'member_ids', '[]'::jsonb));

    group_member_count := cardinality(group_member_ids);
    if group_member_count not between 2 and 20 then
      raise exception 'INVALID_INPUT';
    end if;

    if uid = any(group_member_ids) then
      raise exception 'INVALID_INPUT';
    end if;

    if (
      select count(distinct member_id)
      from unnest(group_member_ids) as members(member_id)
    ) <> group_member_count then
      raise exception 'INVALID_INPUT';
    end if;

    select count(*) into matched_member_count
    from unnest(group_member_ids) as members(member_id)
    where exists (
      select 1
      from public.buddy_matches bm
      where
        (bm.user_1 = uid and bm.user_2 = member_id)
        or
        (bm.user_2 = uid and bm.user_1 = member_id)
    );

    if matched_member_count <> group_member_count then
      raise exception 'NOT_MATCHED';
    end if;

    insert into public.conversations (type, title, created_by)
    values ('GROUP', group_title, uid)
    returning id into new_conv_id;

    insert into public.conversation_participants (conversation_id, user_id, role)
    values (new_conv_id, uid, 'OWNER');

    insert into public.conversation_participants (conversation_id, user_id, role)
    select new_conv_id, member_id, 'MEMBER'
    from unnest(group_member_ids) as members(member_id)
    on conflict (conversation_id, user_id) do nothing;

    return jsonb_build_object(
      'id', new_conv_id,
      'conversation_id', new_conv_id,
      'type', 'GROUP',
      'title', group_title,
      'member_count', group_member_count + 1
    );

  end if;

  raise exception 'INVALID_INPUT';
end;
$$;

revoke all on function public.gymflow_buddy(text, jsonb) from public, anon;
grant execute on function public.gymflow_buddy(text, jsonb) to authenticated;

commit;
