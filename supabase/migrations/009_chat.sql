-- Phase 2D: text support conversations, with all writes checked by the RPC.
begin;
create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.messages (
  id uuid primary key default gen_random_uuid(),
  sequence bigint generated always as identity unique,
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.users(id),
  content text not null check (length(btrim(content)) between 1 and 2000),
  client_id uuid not null,
  created_at timestamptz not null default now(),
  read_at timestamptz,
  unique(sender_id, client_id)
);
create index messages_conversation_sequence on public.messages(conversation_id, sequence desc);
create index conversations_updated on public.conversations(updated_at desc, id);
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
revoke all on public.conversations, public.messages from anon, authenticated;
grant select on public.conversations, public.messages to authenticated;
create policy conversations_read on public.conversations for select to authenticated
  using (user_id=auth.uid() or exists(select 1 from public.users where id=auth.uid() and role='ADMIN'));
create policy messages_read on public.messages for select to authenticated
  using (exists(select 1 from public.conversations c where c.id=conversation_id
    and (c.user_id=auth.uid() or exists(select 1 from public.users where id=auth.uid() and role='ADMIN'))));

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
    insert into public.conversations(user_id) values(uid)
      on conflict(user_id) do update set user_id=excluded.user_id returning * into conv;
    return to_jsonb(conv);
  elsif action='inbox' then
    if not admin_user then raise exception 'FORBIDDEN'; end if;
    select coalesce(jsonb_agg(to_jsonb(c)),'[]'::jsonb) into result from (
      select c.*, u.name, (select content from public.messages m
        where m.conversation_id=c.id order by sequence desc limit 1) as last_message,
        (select count(*) from public.messages m where m.conversation_id=c.id
          and m.sender_id=c.user_id and m.read_at is null) as unread
      from public.conversations c join public.users u on u.id=c.user_id
      order by c.updated_at desc,c.id limit page_limit offset page_offset
    ) c;
    return jsonb_build_object('conversations',result);
  end if;
  select * into conv from public.conversations where id=(payload->>'conversation_id')::uuid;
  if not found or (conv.user_id<>uid and not admin_user) then raise exception 'NOT_FOUND'; end if;
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
      and ((uid=conv.user_id and sender_id<>uid) or (admin_user and sender_id=conv.user_id));
    return jsonb_build_object('ok',true);
  end if;
  raise exception 'INVALID_INPUT';
end;
$$;
revoke all on function public.gymflow_chat(text,jsonb) from public,anon;
grant execute on function public.gymflow_chat(text,jsonb) to authenticated;
commit;
