import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { PGlite } from '@electric-sql/pglite';

test('persistent hourly QR and media: database enforces rotation, privacy and ownership',async t=> {
  const db=new PGlite();
  t.after(()=>db.close());
  await db.exec(`create role anon;create role authenticated;create role service_role bypassrls;
    create schema auth;create table auth.users(id uuid primary key,raw_user_meta_data jsonb default '{}');
    create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
    create schema storage;
    create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
    create table storage.objects(id uuid default gen_random_uuid(),bucket_id text,name text);
    alter table storage.objects enable row level security;
    grant usage on schema auth,storage to authenticated,anon;
    grant insert,select on storage.objects to authenticated;`);
  for(const file of ['migrations/001_initial_schema.sql','migrations/002_workflows.sql','migrations/003_media_hourly_qr.sql']) {
    await db.exec(await readFile(new URL(`../../supabase/${file}`,import.meta.url),'utf8'));
  }
  await db.exec(await readFile(new URL('../../supabase/migrations/003_media_hourly_qr.sql',import.meta.url),'utf8'));
  const admin='a0000000-0000-4000-8000-000000000001';
  const member='a0000000-0000-4000-8000-000000000002';
  await db.query("insert into auth.users(id) values($1),($2)",[admin,member]);
  await db.query("update public.users set role='ADMIN' where id=$1",[admin]);
  async function as(id) {await db.exec(`reset role;set role authenticated;set request.jwt.claim.sub='${id}'`);}
  const current=async()=> (await db.query('select public.gymflow_current_qr() as data')).rows[0].data;
  await as(member);
  await assert.rejects(current(),/FORBIDDEN/);
  await assert.rejects(db.query('select * from public.gym_qr_displays'),/permission denied/);
  await assert.rejects(db.query("select public.gymflow_rotate_qr('1')"),/permission denied/);
  const path=`avatars/${member}/${crypto.randomUUID()}.png`;
  await db.query("insert into storage.objects(bucket_id,name) values('gymflow-images',$1)",[path]);
  const profile=(await db.query('select public.gymflow_update_profile($1) as data',[JSON.stringify({name:'Updated',avatar_path:path})])).rows[0].data;
  assert.equal(profile.avatar_path,path);
  assert.equal(profile.role,undefined);
  await assert.rejects(db.query('select public.gymflow_update_profile($1)',[JSON.stringify({name:'Member',avatar_path:`avatars/${admin}/${crypto.randomUUID()}.png`})]),/INVALID_IMAGE/);
  await assert.rejects(db.query("insert into storage.objects(bucket_id,name) values('gymflow-images',$1)",[`rewards/${member}/${crypto.randomUUID()}.png`]),/row-level security/);
  await as(admin);
  await db.query("insert into storage.objects(bucket_id,name) values('gymflow-images',$1)",[`trainers/${admin}/${crypto.randomUUID()}.png`]);
  const qr=await current();
  assert.match(qr.token,/^[A-Z0-9]{10}$/);
  assert.equal((await current()).token,qr.token);
  assert.equal(qr.token_hash,undefined);
  await db.exec('reset role');
  const stored=(await db.query('select token_hash,expires_at from public.qr_tokens where id=$1',[qr.id])).rows[0];
  assert.equal(stored.token_hash,createHash('sha256').update(qr.token).digest('hex'));
  assert.equal(new Date(stored.expires_at).getUTCMinutes(),0);
  // Simulate an expired hour without waiting or invalidating historical visits.
  await db.query("update public.qr_tokens set issued_at=now()-interval '2 hours',expires_at=now()-interval '1 hour' where id=$1",[qr.id]);
  await db.query('select public.gymflow_rotate_all_qr()');
  await as(admin);
  const next=await current();
  assert.notEqual(next.id,qr.id);
  assert.notEqual(next.token,qr.token);
  assert.equal((await current()).token,next.token);
  await db.query("select public.gymflow_command('admin_revoke_qr',$1)",[JSON.stringify({id:next.id})]);
  const revoked=await current();
  assert.equal(revoked.id,next.id);
  assert.ok(revoked.revoked_at);
});
