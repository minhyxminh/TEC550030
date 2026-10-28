import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';

test('boss battle: one HP per member per day, branch ranking, fight and reward paid to every wallet', async t => {
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
    '013_catalogue_food_voucher',
    '014_catalogue_copy',
    '015_boss_battle',
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

  const members = [crypto.randomUUID(), crypto.randomUUID(), crypto.randomUUID()];
  for (const id of members) await db.query('insert into auth.users(id) values($1)', [id]);
  const [me, other, third] = members;

  const as = async id => db.exec(
    `reset role; set role authenticated; set request.jwt.claim.sub='${id}'`,
  );
  const boss = async (action) =>
    (await db.query('select public.gymflow_boss($1) as data', [action])).rows[0].data;
  // Check-ins on given days of this month (0 = the 1st), written directly as
  // the database owner. `hour` is Vietnam local time.
  const checkIns = async (user, gym, days, hour = 10) => {
    await db.exec('reset role;');
    // Sessions must match the member's chosen branch.
    await db.query('update public.users set home_gym_id=$2 where id=$1', [user, gym]);
    for (const day of days) {
      const at = `((date_trunc('month', now() at time zone 'Asia/Ho_Chi_Minh')
        + interval '${day} days ${hour} hours') at time zone 'Asia/Ho_Chi_Minh')`;
      const token = (await db.query(
        `insert into public.qr_tokens(gym_id, token_hash, issued_at, expires_at)
         values($1, $2, ${at}, ${at} + interval '10 minutes') returning id`,
        [gym, crypto.randomUUID().replaceAll('-', '').padEnd(64, '0')],
      )).rows[0].id;
      await db.query(
        `insert into public.gym_sessions(user_id, gym_id, qr_token_id, check_in_at, check_out_at)
         values($1, $2, $3, ${at}, ${at} + interval '1 minute')`,
        [user, gym, token],
      );
    }
  };
  await db.exec("reset role; insert into public.boss_battles(month, boss_hp) values (date_trunc('month', now() at time zone 'Asia/Ho_Chi_Minh')::date, 8) on conflict (month) do update set boss_hp = 8");

  // Scanning twice on day 0 still counts once.
  await checkIns(me, 'q1', [0, 0, 1]);
  await checkIns(other, 'bt', [0, 1, 2, 3]);
  // Two branches on one day: one HP, credited to the first branch.
  await checkIns(third, 'q1', [2], 9);
  await checkIns(third, 'bt', [2], 15);
  // Last month's check-ins do not count.
  await db.exec('reset role;');
  await db.query('update public.users set home_gym_id=$2 where id=$1', [third, 'td']);
  const lastMonth = "now() - interval '40 days'";
  const oldToken = (await db.query(
    `insert into public.qr_tokens(gym_id, token_hash, issued_at, expires_at)
     values('td', $1, ${lastMonth}, ${lastMonth} + interval '10 minutes') returning id`,
    [crypto.randomUUID().replaceAll('-', '').padEnd(64, '0')],
  )).rows[0].id;
  await db.query(
    `insert into public.gym_sessions(user_id, gym_id, qr_token_id, check_in_at, check_out_at)
     values($1, 'td', $2, ${lastMonth}, ${lastMonth} + interval '1 minute')`,
    [third, oldToken],
  );

  // Member-days: me {0,1}, other {0,1,2,3}, third {2}.
  const today = new Date(Date.now() + 7 * 3600e3).getUTCDate() - 1;
  const visitDays = [0, 1, 0, 1, 2, 3, 2];
  await as(me);
  let state = await boss('status');
  assert.equal(state.tiger_hp, 7);
  assert.equal(state.my_hp, 2);
  assert.equal(state.today_hp, visitDays.filter(d => d === today).length);
  assert.equal(state.boss_hp, 8);
  assert.equal(state.reward_points, 20);
  assert.deepEqual(state.top_branches.map(b => [b.name, b.hp]), [['Bình Thạnh', 4], ['Quận 1', 3]]);
  assert.equal(state.defeated, false);

  // Too weak: the fight is a loss and the boss stays undefeated.
  if (state.fight_open) {
    await as(me);
    const lost = await boss('fight');
    assert.equal(lost.result, 'LOSE');
    assert.equal(lost.defeated, false);
  } else {
    await as(me);
    await assert.rejects(boss('fight'), /BOSS_FIGHT_CLOSED/);
  }
  await db.exec('reset role;');
  const paid = async id => (await db.query(
    "select coalesce(sum(points),0)::int as p from public.point_transactions where user_id=$1 and boss_month is not null",
    [id],
  )).rows[0].p;
  assert.equal(await paid(me), 0, 'no reward before the boss falls');

  // One more member-day makes Hổ Flow strong enough.
  await checkIns(other, 'bt', [4]);
  await as(other);
  state = await boss('status');
  assert.equal(state.fight_open, true);
  const won = await boss('fight');
  assert.equal(won.result, 'WIN');
  assert.equal(won.defeated, true);
  await assert.rejects(boss('fight'), /BOSS_ALREADY_DEFEATED/);

  // The win pays every member straight away, exactly once.
  await db.exec('reset role;');
  for (const id of members) assert.equal(await paid(id), 20);
  for (const id of members) {
    await as(id);
    assert.equal((await boss('status')).claimed, true);
  }
  await db.exec('reset role;');
  for (const id of members) assert.equal(await paid(id), 20);

  // Someone joining after the win is paid on their first visit.
  const late = crypto.randomUUID();
  await db.query('insert into auth.users(id) values($1)', [late]);
  await as(late);
  assert.equal((await boss('status')).claimed, true);
  await db.exec('reset role;');
  assert.equal(await paid(late), 20);

  // Members cannot read the battle table or call the function anonymously.
  await as(me);
  await assert.rejects(db.query('select * from public.boss_battles'));
  await db.exec('reset role; set role anon;');
  await assert.rejects(boss('status'));
});
