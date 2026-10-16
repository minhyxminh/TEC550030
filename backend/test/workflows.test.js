import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';

test('workflows: authorization, atomic balances, idempotency, membership and PT lifecycle', async t => {
  const db = new PGlite();
  t.after(() => db.close());
  await db.exec(`create role anon; create role authenticated; create role service_role bypassrls;
    create schema auth; create table auth.users(id uuid primary key, raw_user_meta_data jsonb);
    create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
    grant usage on schema auth to authenticated; grant execute on function auth.uid() to authenticated;`);
  for (const file of ['migrations/001_initial_schema.sql', 'seed.sql', 'migrations/002_workflows.sql']) {
    await db.exec(await readFile(new URL(`../../supabase/${file}`, import.meta.url), 'utf8'));
  }
  const member = 'a0000000-0000-4000-8000-000000000001';
  const admin = 'a0000000-0000-4000-8000-000000000002';
  const other = 'a0000000-0000-4000-8000-000000000003';
  const membership = '10000000-0000-4000-8000-000000000001';
  const reward = '20000000-0000-4000-8000-000000000001';
  const trainer = '30000000-0000-4000-8000-000000000001';
  const gymId = 'gym-seeded-west';
  const bridgeMember = 'a0000000-0000-4000-8000-000000000004';
  const ambiguousMember = 'a0000000-0000-4000-8000-000000000005';
  const cancelMember = 'a0000000-0000-4000-8000-000000000006';
  const legacyMember = 'a0000000-0000-4000-8000-000000000007';
  for (const id of [member, admin, other, bridgeMember, ambiguousMember, cancelMember, legacyMember]) await db.query('insert into auth.users values($1,\'{}\')', [id]);
  await db.query("update public.users set role='ADMIN' where id=$1", [admin]);
  await db.query("update public.users set active_membership_id=$2,membership_expires_at=now()+interval '30 days' where id=$1", [member, membership]);
  await db.query('insert into public.qr_tokens(gym_id,token_hash,expires_at) values($1,$2,now()+interval \'1 hour\')', [gymId, 'a'.repeat(64)]);
  // Updating an installed workflow migration must preserve all existing tables/data.
  await db.exec(await readFile(new URL('../../supabase/migrations/002_workflows.sql',import.meta.url),'utf8'));
  // Reapply 002 before its forward replacements, so later authorization is preserved.
  await db.exec(await readFile(new URL('../../supabase/migrations/004_phase1_stability.sql', import.meta.url), 'utf8'));
  await db.exec(await readFile(new URL('../../supabase/migrations/005_phase1_home_gym_bridge.sql', import.meta.url), 'utf8'));
  await db.query("update public.users set home_gym_id='1' where id=$1", [member]);
  await db.query("update public.users set active_membership_id=$2,membership_expires_at=now()+interval '30 days',home_gym_id='1' where id=$1", [legacyMember, membership]);
  await db.query(`insert into public.membership_orders(user_id,membership_id,price_vnd_at_order,duration_days_at_order,status,approved_at,starts_at,ends_at,gym_id,idempotency_key)
    values($1,$2,300000,30,'APPROVED',now()-interval '1 day',now()-interval '1 day',now()+interval '29 days','1',$3)`, [legacyMember, membership, crypto.randomUUID()]);
  const qrCountBeforeCleanup = Number((await db.query('select count(*) as n from public.qr_tokens')).rows[0].n);
  await db.exec(await readFile(new URL('../../supabase/migrations/006_remove_auto_gym_and_add_cancellation.sql', import.meta.url), 'utf8'));
  assert.equal((await db.query('select home_gym_id from public.users where id=$1', [member])).rows[0].home_gym_id, null);
  assert.equal((await db.query('select home_gym_id from public.users where id=$1', [legacyMember])).rows[0].home_gym_id, null);
  assert.equal((await db.query('select gym_id from public.membership_orders where user_id=$1', [legacyMember])).rows[0].gym_id, null);
  assert.equal((await db.query("select to_regprocedure('public.gymflow_assign_approval_gym()') as fn")).rows[0].fn, null);
  assert.equal(Number((await db.query('select count(*) as n from public.qr_tokens')).rows[0].n), qrCountBeforeCleanup);
  await db.exec(await readFile(new URL('../../supabase/migrations/007_phase2a_gym_branches.sql', import.meta.url), 'utf8'));
  await db.exec(await readFile(new URL('../../supabase/migrations/008_global_qr_checkin.sql', import.meta.url), 'utf8'));
  await db.query('update public.users set home_gym_id=$2 where id in ($1,$3)', [member, gymId, cancelMember]);
  assert.equal((await db.query("select id from public.gyms where id='1'")).rows[0].id, '1');
  assert.match((await db.query('select description from public.memberships where id=$1', [membership])).rows[0].description, /5 GP.*100 GP khi kích hoạt/);
  assert.equal((await db.query('select home_gym_id from public.users where id=$1', [member])).rows[0].home_gym_id, gymId);
  assert.deepEqual((await db.query('select name,points_per_checkin,points_on_activation from public.memberships order by name')).rows, [
    { name: 'Basic', points_per_checkin: 5, points_on_activation: 100 },
    { name: 'Premium', points_per_checkin: 5, points_on_activation: 200 },
    { name: 'VIP', points_per_checkin: 5, points_on_activation: 300 },
  ]);
  async function as(id) { await db.exec(`reset role; set role authenticated; set request.jwt.claim.sub='${id}';`); }
  async function call(action, payload = {}, read = false) {
    return (await db.query(`select public.${read ? 'gymflow_read' : 'gymflow_command'}($1,$2::jsonb) as data`, [action, JSON.stringify(payload)])).rows[0].data;
  }
  const key = () => crypto.randomUUID();
  await as(bridgeMember);
  assert.equal((await db.query("select public.gymflow_select_home_gym('1') as data")).rows[0].data.home_gym_id, '1');
  await assert.rejects(db.query("select public.gymflow_select_home_gym('not-a-gym')"), /GYM_NOT_FOUND/);
  const bridgeOrder = await call('membership_order', { membership_id: membership, idempotency_key: key() });
  await as(admin);
  const bridgeApproved = await call('admin_order', { id: bridgeOrder.id, status: 'APPROVED' });
  assert.equal(bridgeApproved.gym_id, '1');
  await as(bridgeMember);
  assert.equal((await db.query('select home_gym_id from public.users where id=$1', [bridgeMember])).rows[0].home_gym_id, '1');

  await as(cancelMember);
  const cancellableOrder = await call('membership_order', { membership_id: membership, idempotency_key: key() });
  await as(admin);
  const cancellableApproved = await call('admin_order', { id: cancellableOrder.id, status: 'APPROVED' });
  assert.equal(cancellableApproved.gym_id, gymId);
  const cancellationTokenHash = 'f'.repeat(64);
  await call('admin_qr', { gym_id: gymId, minutes: 15, token_hash: cancellationTokenHash });
  await as(cancelMember);
  const openVisit = await call('check_in', { token_hash: cancellationTokenHash });
  assert.equal(openVisit.points_earned, 5);
  await assert.rejects(db.query("select public.gymflow_select_home_gym('1')"), /OPEN_SESSION/);
  const pointsBeforeCancellation = Number((await db.query('select public.get_my_point_balance() as n')).rows[0].n);
  await assert.rejects(db.query(
    'select public.gymflow_admin_cancel_membership($1,$2)',
    [cancelMember, 'not an admin'],
  ), /FORBIDDEN/);
  await as(admin);
  const cancellation = (await db.query(
    'select public.gymflow_admin_cancel_membership($1,$2) as data',
    [cancelMember, 'Admin cancellation test'],
  )).rows[0].data;
  assert.equal(cancellation.has_open_session, true);
  assert.equal(cancellation.home_gym_id, gymId);
  await db.exec('reset role');
  const cancelledOrder = (await db.query('select status,cancelled_at,cancelled_by,cancellation_reason from public.membership_orders where id=$1', [cancellableOrder.id])).rows[0];
  assert.equal(cancelledOrder.status, 'CANCELLED');
  assert.ok(cancelledOrder.cancelled_at);
  assert.equal(cancelledOrder.cancelled_by, admin);
  assert.equal(cancelledOrder.cancellation_reason, 'Admin cancellation test');
  assert.equal((await db.query('select count(*)::int as n from public.gym_sessions where user_id=$1', [cancelMember])).rows[0].n, 1);
  assert.equal((await db.query('select count(*)::int as n from public.point_transactions where user_id=$1', [cancelMember])).rows[0].n, 2);
  await as(cancelMember);
  const cancelledProfile = (await db.query('select public.gymflow_my_profile() as data')).rows[0].data;
  assert.equal(cancelledProfile.membership_active, false);
  assert.equal(cancelledProfile.membership_cancelled_by, admin);
  assert.equal(Number((await db.query('select public.get_my_point_balance() as n')).rows[0].n), pointsBeforeCancellation);
  await call('check_out', { session_id: openVisit.session.id });
  assert.equal((await call('occupancy', { gym_id: gymId }, true)).count, 0);
  await assert.rejects(call('check_in', { token_hash: cancellationTokenHash }), /MEMBERSHIP_REQUIRED/);

  await as(admin);
  await call('admin_qr', { gym_id: 'gym-second-active', minutes: 15, token_hash: 'e'.repeat(64) });
  await as(ambiguousMember);
  const ambiguousOrder = await call('membership_order', { membership_id: membership, idempotency_key: key() });
  await as(admin);
  const ambiguousApproved = await call('admin_order', { id: ambiguousOrder.id, status: 'APPROVED' });
  assert.equal(ambiguousApproved.gym_id, null);
  await as(ambiguousMember);
  assert.equal((await db.query('select home_gym_id from public.users where id=$1', [ambiguousMember])).rows[0].home_gym_id, null);

  await as(member);
  await assert.rejects(call('admin_qr', {}), /FORBIDDEN/);
  await assert.rejects(call('admin_dashboard', {}, true), /FORBIDDEN/);
  await assert.rejects(db.query("select public.gymflow_catalogue('rewards')"), /FORBIDDEN/);
  const orderPayload = { membership_id: membership, idempotency_key: key() };
  const order = await call('membership_order', orderPayload);
  assert.equal((await call('membership_order', orderPayload)).id, order.id);
  await assert.rejects(call('membership_order', { ...orderPayload, idempotency_key: key() }), /PENDING_ORDER_EXISTS/);
  await as(admin);
  const added = (await db.query("select public.gymflow_catalogue('rewards',null,$1) as data", [JSON.stringify({ name: 'Test reward', points: 5, stock: 2 })])).rows[0].data;
  assert.equal(added.stock, 2);
  assert.equal(added.is_active, true);
  const edited = (await db.query("select public.gymflow_catalogue('rewards',$1,$2) as data", [added.id, JSON.stringify({ is_active: false })])).rows[0].data;
  assert.equal(edited.stock, 2);
  assert.equal(edited.is_active, false);
  await assert.rejects(db.query("select public.gymflow_catalogue('users',null,'{}')"), /INVALID_INPUT/);
  await assert.rejects(db.query("select public.gymflow_catalogue('rewards',$1,'{\"created_at\":\"2000-01-01\"}')", [added.id]), /INVALID_INPUT/);
  const approved = await call('admin_order', { id: order.id, status: 'APPROVED' });
  assert.equal((await call('admin_order', { id: order.id, status: 'APPROVED' })).ends_at, approved.ends_at);
  await as(member);
  assert.equal((await db.query('select home_gym_id from public.users where id=$1', [member])).rows[0].home_gym_id, gymId);
  await as(admin);
  assert.equal(Number((await db.query('select points_on_activation from public.memberships where id=$1', [membership])).rows[0].points_on_activation), 100);
  await assert.rejects(call('admin_order', { id: order.id, status: 'REJECTED' }), /ORDER_PROCESSED/);
  const tokenHash = 'b'.repeat(64);
  const qr = await call('admin_qr', { gym_id: gymId, minutes: 15, token_hash: tokenHash });
  assert.equal(qr.token_hash, undefined);
  await as(member);
  assert.equal(Number((await db.query('select public.get_my_point_balance() as n')).rows[0].n), 100);
  const profile = (await db.query('select public.gymflow_my_profile() as data')).rows[0].data;
  assert.equal(profile.home_gym_id, gymId);
  assert.equal(profile.membership_active, true);
  await as(other);
  await assert.rejects(call('check_in', { token_hash: tokenHash }), /MEMBERSHIP_REQUIRED/);
  await as(member);
  await assert.rejects(call('check_in', { token_hash: 'c'.repeat(64) }), /INVALID_QR/);
  const visit = await call('check_in', { token_hash: tokenHash });
  assert.ok(visit.points_earned > 0);
  assert.equal(visit.points_earned, 5);
  assert.equal((await call('check_in', { token_hash: tokenHash })).points_earned, 0);
  await call('check_out', { session_id: visit.session.id });
  await call('check_out', { session_id: visit.session.id });
  assert.equal(Number((await db.query('select public.get_my_point_balance() as n')).rows[0].n), 105);
  assert.equal((await call('occupancy', { gym_id: gymId }, true)).count, 0);
  await as(admin);
  await call('admin_qr', { gym_id: gymId, minutes: 15, token_hash: 'c'.repeat(64) });
  await call('admin_qr', { gym_id: '2', minutes: 15, token_hash: 'd'.repeat(64) });
  await as(member);
  const reentry = await call('check_in', { token_hash: 'c'.repeat(64) });
  assert.equal(reentry.points_earned, 0);
  assert.equal((await call('occupancy', { gym_id: gymId }, true)).count, 1);
  await assert.rejects(call('occupancy', { gym_id: '2' }, true), /FORBIDDEN/);
  await call('check_out', { session_id: reentry.session.id });
  assert.equal((await call('occupancy', { gym_id: gymId }, true)).count, 0);
  const globalVisit = await call('check_in', { token_hash: 'd'.repeat(64) });
  assert.equal(globalVisit.session.gym_id, gymId);
  assert.equal(globalVisit.points_earned, 0);
  await call('check_out', { session_id: globalVisit.session.id });
  const hourly = await call('hourly',{gym_id:gymId},true);
  // The cancelled member's earlier visit plus this member's repeated visits:
  // two distinct members, regardless of how often the second member re-enters.
  assert.equal(hourly.at(-1).count,2);
  await db.exec('reset role');
  await db.query('update public.rewards set points=1000,stock=1 where id=$1', [reward]);
  await as(member);
  const redemptionPayload = { reward_id: reward, idempotency_key: key() };
  await assert.rejects(call('redeem', redemptionPayload), /INSUFFICIENT_POINTS/);
  assert.equal(Number((await db.query('select stock from public.rewards where id=$1', [reward])).rows[0].stock), 1);
  assert.equal(Number((await db.query('select public.get_my_point_balance() as n')).rows[0].n), 105);
  await db.exec('reset role');
  await db.query('update public.rewards set points=1,stock=1 where id=$1', [reward]);
  await as(member);
  const redemption = await call('redeem', redemptionPayload);
  assert.equal((await call('redeem', redemptionPayload)).id, redemption.id);
  assert.equal(Number((await db.query('select stock from public.rewards where id=$1', [reward])).rows[0].stock), 0);
  const debit = (await db.query('select type,points,redemption_id from public.point_transactions where redemption_id=$1', [redemption.id])).rows[0];
  assert.deepEqual(debit, { type: 'REDEEM', points: -1, redemption_id: redemption.id });
  assert.equal((await call('history', {}, true)).redemptions[0].id, redemption.id);
  await assert.rejects(call('redeem', { ...redemptionPayload, idempotency_key: key() }), /OUT_OF_STOCK/);
  assert.equal(Number((await db.query('select public.get_my_point_balance() as n')).rows[0].n), 104);
  await as(admin);
  await call('admin_fulfill', { id: redemption.id });
  await call('admin_revoke_qr', { id: qr.id });
  await as(member);
  await assert.rejects(call('check_in', { token_hash: tokenHash }), /INVALID_QR/);
  const date = new Date(Date.now() + 86400000).toISOString().slice(0, 10);
  const slots = await call('pt_slots', { trainer_id: trainer, date }, true);
  assert.ok(slots.length > 0);
  const bookingPayload = { trainer_id: trainer, slot: slots[0].slot, idempotency_key: key() };
  const booking = await call('book_pt', bookingPayload);
  assert.equal((await call('book_pt', bookingPayload)).id, booking.id);
  await as(other);
  await assert.rejects(call('book_pt', { ...bookingPayload, idempotency_key: key() }), { code: '23505' });
  await assert.rejects(call('cancel_pt', { id: booking.id }), /NOT_FOUND/);
  await as(member);
  await call('cancel_pt', { id: booking.id });
  await as(other);
  await call('book_pt', { ...bookingPayload, idempotency_key: key() });
  const history = await call('history', {}, true);
  assert.equal(history.orders.length, 0);
  assert.equal(history.bookings.length, 1);
  await db.exec('reset role; set role anon;');
  assert.equal((await db.query("select id from public.gyms where id='1'")).rows[0].id, '1');
  await assert.rejects(call('occupancy', {}, true), { code: '42501' });
});
