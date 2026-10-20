import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';

test('membership payments: demo amounts, settlement idempotency, GymPoint and repurchase after cancellation', async t => {
  const db = new PGlite();
  t.after(() => db.close());

  await db.exec(`
    create role anon;
    create role authenticated;
    create role service_role bypassrls;
    create schema auth;
    create table auth.users(id uuid primary key, raw_user_meta_data jsonb default '{}');
    create function auth.uid() returns uuid language sql stable
      as $$select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid$$;
    create schema storage;
    create table storage.buckets(
      id text primary key, name text, public boolean,
      file_size_limit bigint, allowed_mime_types text[]
    );
    create table storage.objects(
      id uuid default gen_random_uuid(), bucket_id text, name text
    );
    alter table storage.objects enable row level security;
    grant usage on schema auth, storage to authenticated, anon;
    grant insert, select on storage.objects to authenticated;
  `);

  for (const file of [
    '001_initial_schema',
    '002_workflows',
    '003_media_hourly_qr',
    '004_phase1_stability',
    '005_phase1_home_gym_bridge',
    '006_remove_auto_gym_and_add_cancellation',
    '007_phase2a_gym_branches',
    '008_global_qr_checkin',
    '009_chat',
    '010_cancel_membership_clear_home_gym',
    '011_gym_buddy',
    '012_membership_payments',
  ]) {
    await db.exec(await readFile(
      new URL(`../../supabase/migrations/${file}.sql`, import.meta.url),
      'utf8',
    ));
    if (file === '001_initial_schema') {
      await db.exec(await readFile(
        new URL('../../supabase/seed.sql', import.meta.url),
        'utf8',
      ));
    }
  }

  const member = crypto.randomUUID();
  const secondMember = crypto.randomUUID();
  const admin = crypto.randomUUID();
  for (const id of [member, secondMember, admin]) {
    await db.query('insert into auth.users(id) values($1)', [id]);
  }
  await db.query("update public.users set name='Member' where id=$1", [member]);
  await db.query("update public.users set name='Second' where id=$1", [secondMember]);
  await db.query("update public.users set role='ADMIN', name='Admin' where id=$1", [admin]);

  const basic = '10000000-0000-4000-8000-000000000001';
  const premium = '10000000-0000-4000-8000-000000000002';
  const vip = '10000000-0000-4000-8000-000000000003';

  const as = async id => db.exec(
    `reset role; set role authenticated; set request.jwt.claim.sub='${id}'`,
  );
  const createPayment = async (membershipId, key = crypto.randomUUID()) =>
    (await db.query(
      'select public.gymflow_create_membership_payment($1,$2) as data',
      [membershipId, key],
    )).rows[0].data;
  const settle = async (code, transactionId, amount) => {
    await db.exec('reset role; set role service_role;');
    return (await db.query(
      `select public.gymflow_confirm_membership_payment(
        $1,$2,$3,$4,$5
      ) as data`,
      [code, transactionId, amount, `${code} payment`, new Date().toISOString()],
    )).rows[0].data;
  };

  await as(member);
  const key = crypto.randomUUID();
  const order = await createPayment(basic, key);
  assert.equal(order.payment_amount_vnd, 5000);
  assert.equal(order.price_vnd_at_order, 300000);
  assert.equal(order.payment_status, 'UNPAID');
  assert.equal(order.status, 'PENDING');
  assert.match(order.payment_code, /^GF[A-Z0-9]{12}$/);
  assert.equal(order.points_on_activation, 100);

  const retryCreate = await createPayment(basic, key);
  assert.equal(retryCreate.id, order.id);
  assert.equal(retryCreate.payment_code, order.payment_code);

  await assert.rejects(
    createPayment(premium),
    /PENDING_ORDER_EXISTS/,
  );

  const wrongAmount = await settle(order.payment_code, 'sepay-wrong-1', 4999);
  assert.equal(wrongAmount.matched, true);
  assert.equal(wrongAmount.paid, false);
  assert.equal(wrongAmount.reason, 'AMOUNT_MISMATCH');

  await as(member);
  assert.equal(
    Number((await db.query('select public.get_my_point_balance() as n')).rows[0].n),
    0,
  );

  const paid = await settle(order.payment_code, 'sepay-basic-1', 5000);
  assert.equal(paid.paid, true);
  assert.equal(paid.idempotent, false);

  const paidRetry = await settle(order.payment_code, 'sepay-basic-1', 5000);
  assert.equal(paidRetry.paid, true);
  assert.equal(paidRetry.idempotent, true);

  await as(member);
  const stored = (await db.query(
    `select status,payment_status,provider_transaction_id,paid_at
     from public.membership_orders where id=$1`,
    [order.id],
  )).rows[0];
  assert.equal(stored.status, 'APPROVED');
  assert.equal(stored.payment_status, 'PAID');
  assert.equal(stored.provider_transaction_id, 'sepay-basic-1');
  assert.ok(stored.paid_at);
  assert.equal(
    Number((await db.query('select public.get_my_point_balance() as n')).rows[0].n),
    100,
    'activation GymPoint must be awarded exactly once',
  );
  const profile = (await db.query(
    'select active_membership_id,membership_expires_at from public.users where id=$1',
    [member],
  )).rows[0];
  assert.equal(profile.active_membership_id, basic);
  assert.ok(profile.membership_expires_at);

  // Admin cancellation ends the active membership. A later registration is a
  // brand-new payment order and therefore requires another transfer.
  await as(admin);
  await db.query(
    'select public.gymflow_admin_cancel_membership($1,$2)',
    [member, 'Payment repurchase test'],
  );
  await as(member);
  const repurchase = await createPayment(premium);
  assert.equal(repurchase.payment_amount_vnd, 10000);
  assert.equal(repurchase.payment_status, 'UNPAID');
  assert.notEqual(repurchase.id, order.id);

  // Payment-backed orders cannot be manually approved before payment.
  await as(admin);
  await assert.rejects(
    db.query(
      "select public.gymflow_command('admin_order',$1::jsonb)",
      [JSON.stringify({ id: repurchase.id, status: 'APPROVED' })],
    ),
    /PAYMENT_REQUIRED/,
  );

  // Verify the top demo tier mapping on an independent member.
  await as(secondMember);
  const vipOrder = await createPayment(vip);
  assert.equal(vipOrder.payment_amount_vnd, 15000);

  // A user can only read their own payment order through the payment RPC.
  await assert.rejects(
    db.query('select public.gymflow_get_membership_payment($1)', [order.id]),
    /NOT_FOUND/,
  );
});
