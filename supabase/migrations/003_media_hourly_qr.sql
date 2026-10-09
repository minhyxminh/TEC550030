-- Run after 002. Preserves existing users, visits, points and catalogue records.
begin;

alter table public.users add column if not exists avatar_path text;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('gymflow-images','gymflow-images',true,3145728,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=true,file_size_limit=excluded.file_size_limit,
  allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists gymflow_image_insert on storage.objects;
create policy gymflow_image_insert on storage.objects for insert to authenticated with check (
  bucket_id='gymflow-images' and split_part(name,'/',2)=auth.uid()::text
  and (
    split_part(name,'/',1)='avatars'
    or (split_part(name,'/',1) in ('rewards','trainers')
      and exists(select 1 from public.users where id=auth.uid() and role='ADMIN'))
  )
);

create or replace function public.gymflow_update_profile(payload jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  uid uuid := auth.uid();
  image_path text := payload->>'avatar_path';
  result jsonb;
begin
  if uid is null then raise exception using errcode='P0001',message='UNAUTHORIZED'; end if;
  if payload->>'name' is null or length(trim(payload->>'name')) not between 1 and 100 then
    raise exception using errcode='P0001',message='INVALID_INPUT';
  end if;
  if payload ? 'avatar_path' and image_path is not null then
    if image_path !~ ('^avatars/'||uid::text||'/[0-9a-f-]{36}\.(jpg|png|webp)$')
      or not exists(select 1 from storage.objects where bucket_id='gymflow-images' and name=image_path) then
      raise exception using errcode='P0001',message='INVALID_IMAGE';
    end if;
  end if;
  update public.users set name=trim(payload->>'name'),
    avatar_path=case when payload ? 'avatar_path' then image_path else avatar_path end
    where id=uid returning to_jsonb(users.*)-'role' into result;
  if result is null then raise exception using errcode='P0001',message='PROFILE_NOT_FOUND'; end if;
  return result;
end;
$$;
revoke all on function public.gymflow_update_profile(jsonb) from public,anon,authenticated;
grant execute on function public.gymflow_update_profile(jsonb) to authenticated;

-- Raw display codes are held separately from the member-readable workflow.
-- Only the admin RPC can return these codes; no direct client table privileges.
create table if not exists public.gym_qr_displays (
  gym_id text primary key check(length(gym_id) between 1 and 100),
  qr_token_id uuid not null references public.qr_tokens(id),
  token text not null check(token ~ '^[A-Z0-9]{10}$')
);
alter table public.gym_qr_displays enable row level security;
revoke all on public.gym_qr_displays from public,anon,authenticated;

create or replace function public.gymflow_rotate_qr(gym_id_input text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  qr public.qr_tokens;
  code text;
  random_bytes bytea;
  b integer;
  i integer;
  alphabet text := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
begin
  if gym_id_input is null or length(gym_id_input) not between 1 and 100 then
    raise exception using errcode='P0001',message='INVALID_INPUT';
  end if;
  -- GETs from multiple admins and the scheduled job share one transaction lock.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('gymflow-qr:'||gym_id_input,0));
  select q.* into qr from public.gym_qr_displays d
    join public.qr_tokens q on q.id=d.qr_token_id where d.gym_id=gym_id_input;
  if qr.id is not null and qr.expires_at>now() then
    select d.token into code from public.gym_qr_displays d where d.gym_id=gym_id_input;
  else
    loop
      code := '';
      while length(code)<10 loop
        random_bytes := decode(replace(gen_random_uuid()::text,'-',''),'hex');
        for i in 0..15 loop
          -- Skip UUID version/variant bytes; remaining bytes have random bits.
          if i in (6,8) then continue; end if;
          b := get_byte(random_bytes,i);
          if b<252 then code := code||substr(alphabet,1+b%36,1); end if;
          exit when length(code)=10;
        end loop;
      end loop;
      exit when code ~ '[A-Z]' and code ~ '[0-9]' and not exists(
        select 1 from public.qr_tokens where token_hash=encode(sha256(convert_to(code,'UTF8')),'hex'));
    end loop;
    update public.qr_tokens set revoked_at=now()
      where gym_id=gym_id_input and revoked_at is null and expires_at>now();
    insert into public.qr_tokens(gym_id,token_hash,issued_at,expires_at)
      values(gym_id_input,encode(sha256(convert_to(code,'UTF8')),'hex'),now(),date_trunc('hour',now())+interval '1 hour')
      returning * into qr;
    insert into public.gym_qr_displays(gym_id,qr_token_id,token) values(gym_id_input,qr.id,code)
      on conflict(gym_id) do update set qr_token_id=excluded.qr_token_id,token=excluded.token;
  end if;
  return jsonb_build_object('id',qr.id,'gym_id',qr.gym_id,'token',code,
    'issued_at',qr.issued_at,'expires_at',qr.expires_at,'revoked_at',qr.revoked_at);
end;
$$;
revoke all on function public.gymflow_rotate_qr(text) from public,anon,authenticated;

create or replace function public.gymflow_current_qr(gym_id text default '1')
returns jsonb language plpgsql security definer set search_path='' as $$
begin
  if not exists(select 1 from public.users where id=auth.uid() and role='ADMIN') then
    raise exception using errcode='P0001',message='FORBIDDEN';
  end if;
  return public.gymflow_rotate_qr(gym_id);
end;
$$;
revoke all on function public.gymflow_current_qr(text) from public,anon,authenticated;
grant execute on function public.gymflow_current_qr(text) to authenticated;

create or replace function public.gymflow_rotate_all_qr()
returns void language plpgsql security definer set search_path='' as $$
declare gym text;
begin
  for gym in select gym_id from public.gym_qr_displays union select '1' order by 1 loop
    perform public.gymflow_rotate_qr(gym);
  end loop;
end;
$$;
revoke all on function public.gymflow_rotate_all_qr() from public,anon,authenticated;
grant execute on function public.gymflow_rotate_all_qr() to service_role;
select public.gymflow_rotate_all_qr();
commit;
