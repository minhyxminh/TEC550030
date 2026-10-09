import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';

test('schema v1: PostgreSQL constraints, Auth trigger, seed and RLS', async t => {
  const db = new PGlite();
  t.after(() => db.close());
  // Local stand-in for Supabase-managed roles and auth schema; never sent online.
  await db.exec(`
    create role anon;
    create role authenticated;
    create role service_role bypassrls;
    create schema auth;
    create table auth.users(id uuid primary key, email text, raw_user_meta_data jsonb);
    create function auth.uid() returns uuid language sql stable as $$
      select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
    $$;
    grant usage on schema auth to anon, authenticated;
    grant execute on function auth.uid() to anon, authenticated;
    insert into auth.users values ('a0000000-0000-4000-8000-000000000003','old@example.com', '{}');
  `);
  const migration = await readFile(new URL('../../supabase/migrations/001_initial_schema.sql', import.meta.url), 'utf8');
  const seed = await readFile(new URL('../../supabase/seed.sql', import.meta.url), 'utf8');
  await db.exec(migration);
  await db.exec(seed);
  const uid = 'a0000000-0000-4000-8000-000000000001';
  const other = 'a0000000-0000-4000-8000-000000000002';
  const qr = '40000000-0000-4000-8000-000000000001';
  const visit = '50000000-0000-4000-8000-000000000001';
  const reward = '20000000-0000-4000-8000-000000000001';
  const trainer = '30000000-0000-4000-8000-000000000001';
  const packageId = '10000000-0000-4000-8000-000000000001';
  await db.query('insert into auth.users values ($1,$2,$3), ($4,$5,$6)', [
    uid, 'a@example.com', JSON.stringify({ name: 'A', role: 'ADMIN' }), other, 'b@example.com', JSON.stringify({ name: 'B' }),
  ]);

  await t.test('creates all 10 RLS tables and safe profiles for new/existing Auth users', async () => {
    const tables = await db.query("select tablename, rowsecurity from pg_tables where schemaname = 'public'");
    assert.equal(tables.rows.length, 10);
    assert.ok(tables.rows.every(row => row.rowsecurity));
    const profiles = await db.query('select * from public.users order by id');
    assert.equal(profiles.rows.length, 3);
    assert.equal(profiles.rows[0].role, 'MEMBER');
    assert.equal(profiles.rows[2].name, 'Member');
  });

  await t.test('seed is repeatable without resetting rewards', async () => {
    await db.query('update public.rewards set stock = 42 where id = $1', [reward]);
    await db.exec(seed);
    assert.equal((await db.query('select stock from public.rewards where id = $1', [reward])).rows[0].stock, 42);
    assert.equal((await db.query('select count(*)::int as n from public.rewards')).rows[0].n, 4);
  });

  await db.query(`insert into public.qr_tokens(id,gym_id,token_hash,issued_at,expires_at)
    values ($1,'1',$2,'2026-10-08T10:00:00Z','2026-10-08T11:00:00Z')`, [qr, 'a'.repeat(64)]);
  await db.query('insert into public.gym_sessions(id,user_id,gym_id,qr_token_id) values ($1,$2,$3,$4)', [visit, uid, '1', qr]);

  await t.test('prevents two open visits, but allows re-entry after checkout', async () => {
    await assert.rejects(db.query('insert into public.gym_sessions(user_id,gym_id,qr_token_id) values ($1,$2,$3)', [uid, '1', qr]), { code: '23505' });
    await db.query('update public.gym_sessions set check_out_at = now() where id = $1', [visit]);
    await db.query('insert into public.gym_sessions(user_id,gym_id,qr_token_id) values ($1,$2,$3)', [uid, '1', qr]);
  });

  await t.test('awards only once per member/QR and checks ledger sign', async () => {
    const earn = `insert into public.point_transactions(user_id,type,points,reason,qr_token_id,gym_session_id)
      values ($1,'EARN',10,'Check-in',$2,$3)`;
    await db.query(earn, [uid, qr, visit]);
    await assert.rejects(db.query(earn, [uid, qr, visit]), { code: '23505' });
    await assert.rejects(db.query("insert into public.point_transactions(user_id,type,points,reason,qr_token_id,gym_session_id) values ($1,'EARN',-10,'Invalid',$2,$3)", [other, qr, visit]), { code: '23514' });
  });

  await t.test('rejects invalid stock, token lifetime, gym mismatch and incomplete approvals', async () => {
    await assert.rejects(db.query('update public.rewards set stock = -1 where id = $1', [reward]), { code: '23514' });
    await assert.rejects(db.query("insert into public.qr_tokens(token_hash,issued_at,expires_at) values ($1,'2026-10-08T10:00:00Z','2026-10-08T12:00:00Z')", ['b'.repeat(64)]), { code: '23514' });
    await assert.rejects(db.query('insert into public.gym_sessions(user_id,gym_id,qr_token_id) values ($1,$2,$3)', [other, 'other-gym', qr]), { code: '23503' });
    await assert.rejects(db.query("insert into public.membership_orders(user_id,membership_id,price_vnd_at_order,duration_days_at_order,status,approved_at,starts_at) values ($1,$2,300000,30,'APPROVED',now(),now())", [uid, packageId]), { code: '23514' });
  });

  await t.test('prevents duplicate PT slot; cancellation frees it', async () => {
    const booking = "insert into public.pt_bookings(user_id,trainer_id,slot) values ($1,$2,'2026-10-10T03:00:00Z')";
    await db.query(booking, [uid, trainer]);
    await assert.rejects(db.query(booking, [other, trainer]), { code: '23505' });
    await db.query("update public.pt_bookings set status = 'CANCELLED' where user_id = $1", [uid]);
    await db.query(booking, [other, trainer]);
    await assert.rejects(db.query("insert into public.pt_bookings(user_id,trainer_id,slot) values ($1,$2,'2026-10-10T03:30:00Z')", [uid, trainer]), { code: '23514' });
  });

  await t.test('RLS isolates profiles/ledger and blocks writes to protected tables', async () => {
    await db.exec(`set role authenticated; set request.jwt.claim.sub = '${uid}';`);
    try {
      assert.deepEqual((await db.query('select id from public.users')).rows, [{ id: uid }]);
      assert.equal((await db.query('select * from public.point_transactions')).rows.length, 1);
      assert.equal(Number((await db.query('select public.get_my_point_balance() as balance')).rows[0].balance), 10);
      await assert.rejects(db.exec("update public.users set role = 'ADMIN'"), { code: '42501' });
      await assert.rejects(db.exec('update public.rewards set stock = 999'), { code: '42501' });
      await assert.rejects(db.exec('select * from public.qr_tokens'), { code: '42501' });
      await db.exec(`set request.jwt.claim.sub = '${other}';`);
      assert.equal((await db.query('select * from public.point_transactions')).rows.length, 0);
      assert.equal(Number((await db.query('select public.get_my_point_balance() as balance')).rows[0].balance), 0);
    } finally { await db.exec('reset role;'); }
  });

  await t.test('anonymous callers see active catalogues only, never member data', async () => {
    await db.query('update public.rewards set is_active = false where id = $1', [reward]);
    await db.exec('set role anon;');
    try {
      assert.equal((await db.query('select * from public.rewards')).rows.length, 3);
      await assert.rejects(db.exec('select * from public.users'), { code: '42501' });
      await assert.rejects(db.exec('select public.get_my_point_balance()'), { code: '42501' });
    } finally { await db.exec('reset role;'); }
  });
});
