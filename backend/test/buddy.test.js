import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';

test('Gym Buddy: migration 011 schema, feed rules, swipe/match transaction, chat extension and RLS', async t => {
  const db = new PGlite();
  t.after(() => db.close());

  await db.exec(`
    create role anon; create role authenticated; create role service_role bypassrls;
    create schema auth;
    create table auth.users(id uuid primary key, raw_user_meta_data jsonb default '{}');
    create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid$$;
    create schema storage;
    create table storage.buckets(id text primary key, name text, public boolean, file_size_limit bigint, allowed_mime_types text[]);
    create table storage.objects(id uuid default gen_random_uuid(), bucket_id text, name text);
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
  ]) {
    await db.exec(await readFile(new URL(`../../supabase/migrations/${file}.sql`, import.meta.url), 'utf8'));
    if (file === '001_initial_schema') {
      await db.exec(await readFile(new URL('../../supabase/seed.sql', import.meta.url), 'utf8'));
    }
  }

  // Create users: User A, User B, User C (unrelated), Inactive User, Admin
  const userA = crypto.randomUUID();
  const userB = crypto.randomUUID();
  const userC = crypto.randomUUID();
  const inactiveUser = crypto.randomUUID();
  const admin = crypto.randomUUID();

  for (const id of [userA, userB, userC, inactiveUser, admin]) {
    await db.query('insert into auth.users(id) values($1)', [id]);
  }

  await db.query("update public.users set role='ADMIN' where id=$1", [admin]);
  await db.query("update public.users set name='User A', home_gym_id='1', active_membership_id='10000000-0000-4000-8000-000000000001', membership_expires_at=now() + interval '30 days' where id=$1", [userA]);
  await db.query("update public.users set name='User B', home_gym_id='1', active_membership_id='10000000-0000-4000-8000-000000000001', membership_expires_at=now() + interval '30 days' where id=$1", [userB]);
  await db.query("update public.users set name='User C', home_gym_id='q5', active_membership_id='10000000-0000-4000-8000-000000000001', membership_expires_at=now() + interval '30 days' where id=$1", [userC]);
  // inactiveUser has expired membership
  await db.query("update public.users set name='Inactive User', home_gym_id='1', active_membership_id='10000000-0000-4000-8000-000000000001', membership_expires_at=now() - interval '1 day' where id=$1", [inactiveUser]);

  const as = async id => db.exec(`reset role; set role authenticated; set request.jwt.claim.sub='${id}'`);
  const buddy = async (action, payload = {}) =>
    (await db.query('select public.gymflow_buddy($1, $2) as data', [action, JSON.stringify(payload)])).rows[0].data;
  const chat = async (action, payload = {}) =>
    (await db.query('select public.gymflow_chat($1, $2) as data', [action, JSON.stringify(payload)])).rows[0].data;

  // Setup initial onboarding profiles
  await as(userA);
  await buddy('PROFILE_UPSERT', {
    age: 24,
    gender: 'Nam',
    show_age: true,
    show_gender: true,
    fitness_goal: 'Tăng cơ',
    experience_level: 'INTERMEDIATE',
    favorite_workouts: ['Ngực', 'Chân'],
    preferred_workout_times: ['Chiều tối'],
    workout_style: ['Tập nặng'],
    bio: 'Looking for spotter',
    onboarding_completed: true,
    enabled: true,
  });

  await as(userB);
  await buddy('PROFILE_UPSERT', {
    age: 26,
    gender: 'Nữ',
    fitness_goal: 'Giảm mỡ',
    experience_level: 'BEGINNER',
    favorite_workouts: ['Cardio'],
    onboarding_completed: true,
    enabled: true,
  });

  await as(userC);
  await buddy('PROFILE_UPSERT', {
    age: 30,
    gender: 'Nam',
    fitness_goal: 'Sức bền',
    onboarding_completed: true,
    enabled: true,
  });

  await as(inactiveUser);
  await buddy('PROFILE_UPSERT', {
    age: 22,
    gender: 'Nam',
    onboarding_completed: true,
    enabled: true,
  });

  // 1. User cannot swipe self
  await t.test('1. User cannot swipe self', async () => {
    await as(userA);
    await assert.rejects(buddy('SWIPE', { target_id: userA, action: 'LIKE' }), /CANNOT_SWIPE_SELF/);
  });

  // 2. Inactive member is excluded from feed
  await t.test('2. Inactive member is excluded from feed', async () => {
    await as(userA);
    const feed = await buddy('FEED', { limit: 20 });
    const userIds = feed.candidates.map(c => c.user_id);
    assert.ok(!userIds.includes(inactiveUser), 'Inactive member should be excluded');
  });

  // 3. enabled=false profile is excluded
  await t.test('3. enabled=false profile is excluded', async () => {
    await as(userC);
    await buddy('PROFILE_UPSERT', { enabled: false, onboarding_completed: true });

    await as(userA);
    const feed = await buddy('FEED', { limit: 20 });
    const userIds = feed.candidates.map(c => c.user_id);
    assert.ok(!userIds.includes(userC), 'Disabled buddy profile should be excluded from feed');

    // Re-enable for subsequent tests
    await as(userC);
    await buddy('PROFILE_UPSERT', { enabled: true, onboarding_completed: true });
  });

  // 4. onboarding_completed=false profile is excluded
  await t.test('4. onboarding_completed=false profile is excluded', async () => {
    await as(userC);
    await buddy('PROFILE_UPSERT', { onboarding_completed: false });

    await as(userA);
    const feed = await buddy('FEED', { limit: 20 });
    const userIds = feed.candidates.map(c => c.user_id);
    assert.ok(!userIds.includes(userC), 'Incomplete onboarding profile should be excluded');

    // Re-complete for subsequent tests
    await as(userC);
    await buddy('PROFILE_UPSERT', { onboarding_completed: true });
  });

  // 5. PASS: -> no match
  await t.test('5. PASS: records pass and returns no match', async () => {
    await as(userA);
    const passResult = await buddy('SWIPE', { target_id: userC, action: 'PASS' });
    assert.equal(passResult.matched, false);
    assert.equal(passResult.action, 'PASS');
  });

  // 6. Already-swiped user is excluded from feed
  await t.test('6. Already-swiped user is excluded from feed', async () => {
    await as(userA);
    const feed = await buddy('FEED', { limit: 20 });
    const userIds = feed.candidates.map(c => c.user_id);
    assert.ok(!userIds.includes(userC), 'Swiped user C should now be excluded from user A feed');
    assert.ok(userIds.includes(userB), 'Unswiped user B should still be in user A feed');
  });

  // 7. A LIKE B only: -> no match
  await t.test('7. A LIKE B only: no match yet', async () => {
    await as(userA);
    const swipeA = await buddy('SWIPE', { target_id: userB, action: 'LIKE' });
    assert.equal(swipeA.matched, false);
    assert.equal(swipeA.action, 'LIKE');

    const matchesA = await buddy('MATCHES');
    assert.equal(matchesA.matches.length, 0);
  });

  // 8. A LIKE B + B LIKE A: -> exactly one match
  let conversationId;
  let matchId;
  await t.test('8. A LIKE B + B LIKE A: creates reciprocal match and DIRECT chat', async () => {
    await as(userB);
    const swipeB = await buddy('SWIPE', { target_id: userA, action: 'LIKE' });
    assert.equal(swipeB.matched, true);
    assert.equal(swipeB.is_new, true);
    assert.ok(swipeB.match_id);
    assert.ok(swipeB.conversation_id);
    matchId = swipeB.match_id;
    conversationId = swipeB.conversation_id;

    // Both should see the match in MATCHES
    const matchesB = await buddy('MATCHES');
    assert.equal(matchesB.matches.length, 1);
    assert.equal(matchesB.matches[0].other_user_id, userA);

    await as(userA);
    const matchesA = await buddy('MATCHES');
    assert.equal(matchesA.matches.length, 1);
    assert.equal(matchesA.matches[0].other_user_id, userB);
  });

  // 9. Repeating reciprocal LIKE: -> still exactly one match
  await t.test('9. Repeating reciprocal LIKE: idempotent match and conversation', async () => {
    await as(userB);
    const retryB = await buddy('SWIPE', { target_id: userA, action: 'LIKE' });
    assert.equal(retryB.matched, true);
    assert.equal(retryB.is_new, false);
    assert.equal(retryB.match_id, matchId);
    assert.equal(retryB.conversation_id, conversationId);

    const matchCount = (await db.query('select count(*)::int as n from public.buddy_matches')).rows[0].n;
    assert.equal(matchCount, 1, 'Must have exactly 1 row in buddy_matches');
  });

  // 10. Buddy profile can only be modified by owner (RPC operates on auth.uid())
  await t.test('10. Buddy profile can only be modified by owner and direct RLS select is self-only', async () => {
    await as(userA);
    const updated = await buddy('PROFILE_UPSERT', { bio: 'Updated bio by A' });
    assert.equal(updated.user_id, userA);
    assert.equal(updated.bio, 'Updated bio by A');

    // Direct RLS select on public.buddy_profiles returns only userA's own profile
    const directProfilesA = await db.query('select * from public.buddy_profiles');
    assert.equal(directProfilesA.rows.length, 1);
    assert.equal(directProfilesA.rows[0].user_id, userA);

    // Profile of B is unchanged
    await as(userB);
    const profileB = await buddy('PROFILE_GET');
    assert.equal(profileB.user_id, userB);
    assert.notEqual(profileB.bio, 'Updated bio by A');
  });

  // 11. User A cannot read User C's private swipe state (RLS check on buddy_swipes)
  await t.test('11. User A cannot read User C private swipe state via RLS', async () => {
    // User C swipes user B
    await as(userC);
    await buddy('SWIPE', { target_id: userB, action: 'LIKE' });

    // User A directly queries public.buddy_swipes under RLS
    await as(userA);
    const visibleSwipes = await db.query('select * from public.buddy_swipes');
    // User A should only see their own swipes (swiper_id = userA)
    assert.ok(visibleSwipes.rows.length > 0);
    assert.ok(visibleSwipes.rows.every(row => row.swiper_id === userA));
  });

  // 12. Match participants can access their match (RLS check on buddy_matches)
  await t.test('12. Match participants can read their match via RLS', async () => {
    await as(userA);
    const matchesA = await db.query('select * from public.buddy_matches');
    assert.equal(matchesA.rows.length, 1);
    assert.equal(matchesA.rows[0].id, matchId);

    await as(userB);
    const matchesB = await db.query('select * from public.buddy_matches');
    assert.equal(matchesB.rows.length, 1);
    assert.equal(matchesB.rows[0].id, matchId);
  });

  // 13. Unrelated member cannot access the match
  await t.test('13. Unrelated member C cannot read the match via RLS', async () => {
    await as(userC);
    const matchesC = await db.query('select * from public.buddy_matches');
    assert.equal(matchesC.rows.length, 0);

    // Also MATCH_GET RPC rejects user C
    await assert.rejects(buddy('MATCH_GET', { match_id: matchId }), /NOT_FOUND/);
  });

  // 14. Direct match creates/reuses one DIRECT conversation
  await t.test('14. Direct match creates DIRECT conversation', async () => {
    await db.exec('reset role');
    const conv = (await db.query('select * from public.conversations where id=$1', [conversationId])).rows[0];
    assert.equal(conv.type, 'DIRECT');
  });

  // 15. Both matched users become conversation participants
  await t.test('15. Both matched users become conversation participants', async () => {
    await db.exec('reset role');
    const participants = (await db.query('select user_id from public.conversation_participants where conversation_id=$1 order by user_id', [conversationId])).rows.map(r => r.user_id);
    const expected = [userA, userB].sort();
    assert.deepEqual(participants, expected);
  });

  // 16. Unrelated user cannot read/send DIRECT conversation messages
  await t.test('16. Unrelated user cannot read or send to DIRECT conversation', async () => {
    await as(userA);
    const msgA = await chat('send', {
      conversation_id: conversationId,
      content: 'Chào bạn tập!',
      client_id: crypto.randomUUID(),
    });
    assert.equal(msgA.content, 'Chào bạn tập!');

    // User B (participant) can read
    await as(userB);
    const msgsB = await chat('messages', { conversation_id: conversationId });
    assert.equal(msgsB.messages.length, 1);
    assert.equal(msgsB.messages[0].content, 'Chào bạn tập!');

    // User C (unrelated) is blocked from reading and sending
    await as(userC);
    await assert.rejects(chat('messages', { conversation_id: conversationId }), /NOT_FOUND/);
    await assert.rejects(chat('send', {
      conversation_id: conversationId,
      content: 'I should not be able to send',
      client_id: crypto.randomUUID(),
    }), /NOT_FOUND/);

    // Direct RLS table select also blocks User C
    const rlsMessages = await db.query('select * from public.messages where conversation_id=$1', [conversationId]);
    assert.equal(rlsMessages.rows.length, 0);
  });

  // 17. GROUP creation only accepts Gym Buddies already matched with the creator
  let groupConversationId;
  await t.test('17. GROUP creation requires matched buddies and creates owner/member participants', async () => {
    // Complete a second match: A <-> C. A previously PASSed C, so LIKE updates that swipe.
    await as(userC);
    await buddy('SWIPE', { target_id: userA, action: 'LIKE' });
    await as(userA);
    const secondMatch = await buddy('SWIPE', { target_id: userC, action: 'LIKE' });
    assert.equal(secondMatch.matched, true);

    const group = await buddy('GROUP_CREATE', {
      title: 'Leg Day Team',
      member_ids: [userB, userC],
    });
    assert.equal(group.type, 'GROUP');
    assert.equal(group.title, 'Leg Day Team');
    assert.equal(group.member_count, 3);
    assert.ok(group.conversation_id);
    groupConversationId = group.conversation_id;

    await db.exec('reset role');
    const conv = (await db.query('select * from public.conversations where id=$1', [groupConversationId])).rows[0];
    assert.equal(conv.type, 'GROUP');
    assert.equal(conv.title, 'Leg Day Team');
    assert.equal(conv.created_by, userA);

    const participants = (await db.query(
      'select user_id, role from public.conversation_participants where conversation_id=$1 order by user_id',
      [groupConversationId],
    )).rows;
    assert.equal(participants.length, 3);
    assert.equal(participants.find(p => p.user_id === userA).role, 'OWNER');
    assert.equal(participants.find(p => p.user_id === userB).role, 'MEMBER');
    assert.equal(participants.find(p => p.user_id === userC).role, 'MEMBER');
  });

  await t.test('18. GROUP creation rejects users who are not matched with the creator', async () => {
    await as(userA);
    await assert.rejects(
      buddy('GROUP_CREATE', {
        title: 'Invalid Group',
        member_ids: [userB, inactiveUser],
      }),
      /NOT_MATCHED/,
    );
  });

  await t.test('19. GROUP participants can send/read while outsiders are blocked', async () => {
    await as(userA);
    await chat('send', {
      conversation_id: groupConversationId,
      content: 'Team leg day lúc 18h nhé!',
      client_id: crypto.randomUUID(),
    });

    await as(userC);
    const groupMessages = await chat('messages', {
      conversation_id: groupConversationId,
    });
    assert.equal(groupMessages.messages.length, 1);
    assert.equal(groupMessages.messages[0].content, 'Team leg day lúc 18h nhé!');

    await as(inactiveUser);
    await assert.rejects(
      chat('messages', { conversation_id: groupConversationId }),
      /NOT_FOUND/,
    );
    await assert.rejects(
      chat('send', {
        conversation_id: groupConversationId,
        content: 'Not in this group',
        client_id: crypto.randomUUID(),
      }),
      /NOT_FOUND/,
    );
  });

  // 20. Existing SUPPORT chat tests still pass
  await t.test('20. Existing SUPPORT chat flow still functions perfectly', async () => {
    await as(userA);
    const supportConv = await chat('open');
    assert.ok(supportConv.id);
    assert.notEqual(supportConv.id, conversationId);

    const supportMsg = await chat('send', {
      conversation_id: supportConv.id,
      content: 'Support inquiry from Member A',
      client_id: crypto.randomUUID(),
    });
    assert.equal(supportMsg.content, 'Support inquiry from Member A');

    // Admin can see inbox with Member A support conversation
    await as(admin);
    const inbox = await chat('inbox');
    assert.ok(inbox.conversations.some(c => c.id === supportConv.id));

    // Admin can read support messages
    const adminMsgs = await chat('messages', { conversation_id: supportConv.id });
    assert.equal(adminMsgs.messages.length, 1);
    assert.equal(adminMsgs.messages[0].content, 'Support inquiry from Member A');
  });
});

