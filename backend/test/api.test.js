import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { createApp, createQrToken } from '../src/app.js';
import { createHash } from 'node:crypto';
import { readConfig } from '../src/config.js';

const memberId = 'a0000000-0000-4000-8000-000000000001';
const user = { id: memberId, email: 'member@example.com', user_metadata: { name: 'Member' } };
const session = { access_token: 'valid-token', refresh_token: 'refresh-token', expires_in: 3600 };

function fakeSupabase({ databaseError = null, sessionData = session, rpcResult, role='MEMBER', recoveryError=null, emailError=null } = {}) {
  const calls = [];
  return {
    calls,
    createSupabase(token) {
      calls.push({ token });
      return {
        auth: {
          async getUser(jwt) { return jwt === 'valid-token' ? { data: { user }, error: null } : { data: { user: null }, error: { message: 'invalid' } }; },
          async signInWithPassword(input) { calls.push({ login: input }); return { data: { user, session: sessionData }, error: null }; },
          async signUp(input) { calls.push({ signup: input }); return { data: { user, session: sessionData }, error: null }; },
          async refreshSession() { return { data: { user, session }, error: null }; },
          async resetPasswordForEmail(email) { calls.push({recoveryEmail:email}); return {error:emailError}; },
          async verifyOtp(input) { calls.push({verify:input}); return {data:{user,session},error:recoveryError}; },
          async updateUser(input) { calls.push({updateUser:input}); return {data:{user},error:null}; },
          async signOut(input) { calls.push({signout:input}); return {error:null}; },
        },
        from(table) {
          const query = { table, token, filters: [] };
          calls.push(query);
          const builder = {
            select(fields) { query.fields = fields; return this; },
            eq(field, value) { query.filters.push([field, value]); return this; },
            is(field, value) { query.filters.push([field, value]); return this; },
            order(field) { (query.orders ??= []).push(field); return this; },
            range(start, end) { query.range = [start, end]; return this; },
            async maybeSingle() { return { data: table === 'users' ? { id: memberId, name: 'Member',role } : null, error: databaseError }; },
            then(resolve, reject) {
              const rows = table === 'rewards'
                ? [{ id: 'reward-id', name: 'Water', points: 20, stock: 50, image_url: '' }]
                : table === 'gyms'
                ? [{ id: '1', name: 'GymFlow Nguyễn Chí Thanh', district: 'Quận 10' }]
                : [];
              return Promise.resolve({ data: rows, error: databaseError }).then(resolve, reject);
            },
          };
          return builder;
        },
        async rpc(name, args) {
          calls.push({ rpc: name, token, args });
          if (rpcResult) return rpcResult(name,args);
          if (name === 'gymflow_my_profile') return { data: { id: memberId, name: 'Member', role, home_gym_id: '1', membership_active: true }, error: databaseError };
          return { data: 30, error: databaseError };
        },
        storage:{ from(bucket) { return {
          async upload(path,bytes,options) {calls.push({upload:{bucket,path,bytes:Array.from(bytes),options},token});return {error:null};},
          getPublicUrl(path) {return {data:{publicUrl:`https://example.supabase.co/storage/v1/object/public/${bucket}/${path}`}};},
        };}},
      };
    },
  };
}

async function start(t, options) {
  const fake = fakeSupabase(options);
  const server = createApp(fake).listen(0, '127.0.0.1');
  await once(server, 'listening');
  t.after(() => { server.closeAllConnections(); return new Promise(resolve => server.close(resolve)); });
  return { ...fake, url: `http://127.0.0.1:${server.address().port}` };
}

test('health actually queries rewards and fails if the database fails', async t => {
  const good = await start(t);
  assert.deepEqual(await (await fetch(`${good.url}/health`)).json(), { status: 'ok', database: 'connected' });
  assert.ok(good.calls.some(call => call.table === 'rewards'));
  const bad = await start(t, { databaseError: { message: 'private credential or SQL details' } });
  const response = await fetch(`${bad.url}/health`);
  assert.equal(response.status, 503);
  assert.equal((await response.json()).code, 'DATABASE_ERROR');
});

test('workflow routes validate inputs and pass JWT-scoped commands with hashed QR only', async t => {
  const api = await start(t);
  const auth = { Authorization: 'Bearer valid-token', 'Content-Type': 'application/json' };
  async function post(path, body, headers = auth) {
    return fetch(`${api.url}${path}`, { method: 'POST', headers, body: JSON.stringify(body) });
  }
  assert.equal((await post('/gym/check-in', { token: 'raw-secret-QR' }, { 'Content-Type': 'application/json' })).status, 401);
  assert.equal((await post('/gym/check-in', { token: 'raw-secret-QR' })).status, 200);
  const qrCall = api.calls.find(c => c.args?.action === 'check_in');
  assert.equal(qrCall.token, 'valid-token');
  assert.match(qrCall.args.payload.token_hash, /^[a-f0-9]{64}$/);
  assert.equal(qrCall.args.payload.token, undefined);
  assert.equal((await post('/redemptions', { reward_id: 'bad', idempotency_key: crypto.randomUUID() })).status, 400);
  assert.equal((await post('/membership-orders', { membership_id: '10000000-0000-4000-8000-000000000001', idempotency_key: crypto.randomUUID(), user_id: memberId })).status, 400);
  assert.equal((await fetch(`${api.url}/gym/session`, { headers: auth })).status, 200);
  const query = api.calls.find(c => c.table === 'gym_sessions');
  assert.deepEqual(query.filters, [['user_id', memberId], ['check_out_at', null]]);
});

test('workflow business conflicts map to safe HTTP errors', async t => {
  for(const [message, status] of [['FORBIDDEN',403],['GYM_REQUIRED',403],['WRONG_GYM',403],['GYM_NOT_FOUND',404],['OPEN_SESSION',409],['MEMBERSHIP_NOT_ACTIVE',409],['INSUFFICIENT_POINTS',409],['INVALID_QR',400],['NOT_FOUND',404]]) {
    const api=await start(t, { databaseError:{code:'P0001',message} });
    const res=await fetch(`${api.url}/gym/check-in`,{method:'POST',headers:{Authorization:'Bearer valid-token','Content-Type':'application/json'},body:JSON.stringify({token:'test'})});
    assert.equal(res.status,status);
    assert.equal((await res.json()).code,message);
  }
});

test('branch catalogue is public and home-gym selection is authenticated and RPC-backed', async t => {
  const api = await start(t, {
    rpcResult(name, args) {
      if (name === 'gymflow_select_home_gym') return { data: { id: memberId, home_gym_id: args.gym_id_input }, error: null };
      return { data: null, error: null };
    },
  });
  const list = await fetch(`${api.url}/gyms?limit=10&offset=0`);
  assert.equal(list.status, 200);
  assert.equal((await list.json())[0].id, '1');
  const catalogueQuery = api.calls.find(call => call.table === 'gyms');
  assert.equal(catalogueQuery.token, undefined);
  assert.deepEqual(catalogueQuery.fields, 'id,name,address,district,latitude,longitude,opening_hours');
  assert.deepEqual(catalogueQuery.filters, [['is_active', true]]);
  assert.deepEqual(catalogueQuery.orders, ['district', 'name']);
  assert.deepEqual(catalogueQuery.range, [0, 9]);

  const body = { gym_id: 'q5' };
  assert.equal((await fetch(`${api.url}/me/home-gym`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body),
  })).status, 401);
  const selected = await fetch(`${api.url}/me/home-gym`, {
    method: 'POST',
    headers: { Authorization: 'Bearer valid-token', 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  assert.equal(selected.status, 200);
  assert.equal((await selected.json()).home_gym_id, 'q5');
  assert.deepEqual(api.calls.find(call => call.rpc === 'gymflow_select_home_gym').args, { gym_id_input: 'q5' });
  assert.equal((await fetch(`${api.url}/me/home-gym`, {
    method: 'POST',
    headers: { Authorization: 'Bearer valid-token', 'Content-Type': 'application/json' },
    body: JSON.stringify({ gym_id: 'q5', role: 'ADMIN' }),
  })).status, 400);
});

test('Admin member listing and membership cancellation use role-checked RPCs', async t => {
  const api = await start(t, {
    rpcResult(name, args) {
      if (name === 'gymflow_admin_members') return { data: [{ user_id: memberId, name: 'Member', membership_name: 'Basic' }], error: null };
      if (name === 'gymflow_admin_cancel_membership') return { data: { user_id: memberId, cancelled_at: '2026-10-12T00:00:00Z' }, error: null };
      return { data: null, error: null };
    },
  });
  const headers = { Authorization: 'Bearer valid-token', 'Content-Type': 'application/json' };
  const members = await fetch(`${api.url}/admin/members?limit=10&offset=0`, { headers });
  assert.equal(members.status, 200);
  assert.equal((await members.json())[0].membership_name, 'Basic');
  const listCall = api.calls.find(call => call.rpc === 'gymflow_admin_members');
  assert.equal(listCall.token, 'valid-token');
  assert.deepEqual(listCall.args, { page_limit: 10, page_offset: 0 });

  const response = await fetch(`${api.url}/admin/members/${memberId}/cancel-membership`, {
    method: 'POST', headers, body: JSON.stringify({ reason: 'Admin cancellation' }),
  });
  assert.equal(response.status, 200);
  const cancelCall = api.calls.find(call => call.rpc === 'gymflow_admin_cancel_membership');
  assert.equal(cancelCall.token, 'valid-token');
  assert.deepEqual(cancelCall.args, { target_user_id: memberId, cancellation_reason: 'Admin cancellation' });

  const denied = await start(t, { rpcResult: () => ({ data: null, error: { code: 'P0001', message: 'FORBIDDEN' } }) });
  const deniedResponse = await fetch(`${denied.url}/admin/members/${memberId}/cancel-membership`, {
    method: 'POST', headers, body: JSON.stringify({ reason: '' }),
  });
  assert.equal(deniedResponse.status, 403);
});

test('catalogue PATCH preserves omitted stock/default fields and rejects arbitrary fields', async t => {
  const api=await start(t);
  const auth={Authorization:'Bearer valid-token','Content-Type':'application/json'};
  const url=`${api.url}/admin/rewards/20000000-0000-4000-8000-000000000001`;
  assert.equal((await fetch(url,{method:'PATCH',headers:auth,body:JSON.stringify({name:'Updated'})})).status,200);
  const rpc=api.calls.find(c=>c.rpc==='gymflow_catalogue');
  assert.deepEqual(rpc.args.changes,{name:'Updated'});
  assert.equal((await fetch(url,{method:'PATCH',headers:auth,body:JSON.stringify({user_id:memberId})})).status,400);
});

test('membership catalogue fixes check-in points at five GP and rejects tier-specific rates', async t => {
  const api=await start(t);
  const headers={Authorization:'Bearer valid-token','Content-Type':'application/json'};
  const base={name:'Starter',price_vnd:100000,duration_days:30};
  const created=await fetch(`${api.url}/admin/memberships`,{method:'POST',headers,body:JSON.stringify(base)});
  assert.equal(created.status,201);
  assert.equal(api.calls.find(c=>c.rpc==='gymflow_catalogue').args.changes.points_per_checkin,5);
  const invalid=await fetch(`${api.url}/admin/memberships`,{method:'POST',headers,body:JSON.stringify({...base,name:'Premium',points_per_checkin:20})});
  assert.equal(invalid.status,400);
});

test('rewards response matches Flutter list contract and uses active filter/pagination', async t => {
  const api = await start(t);
  const response = await fetch(`${api.url}/rewards?limit=20&offset=10`);
  assert.equal(response.status, 200);
  assert.equal((await response.json())[0].points, 20);
  const query = api.calls.find(call => call.table === 'rewards');
  assert.deepEqual(query.filters, [['is_active', true]]);
  assert.deepEqual(query.range, [10, 29]);
  assert.equal((await fetch(`${api.url}/rewards?limit=-1`)).status, 400);
  assert.equal((await fetch(`${api.url}/rewards/not-a-uuid`)).status, 400);
  assert.equal((await fetch(`${api.url}/rewards/20000000-0000-4000-8000-000000000001`)).status, 404);
});

test('private profile rejects absent and forged JWT before querying data', async t => {
  const api = await start(t);
  assert.equal((await fetch(`${api.url}/me`)).status, 401);
  assert.equal((await fetch(`${api.url}/me/`)).status, 401);
  assert.equal((await fetch(`${api.url}/me`, { headers: { Authorization: 'Bearer forged-token' } })).status, 401);
  assert.ok(!api.calls.some(call => call.table === 'users'));
});

test('profile uses verified JWT user and database-derived membership state', async t => {
  const api = await start(t);
  const response = await fetch(`${api.url}/me?user_id=someone-else`, { headers: { Authorization: 'Bearer valid-token' } });
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.id, memberId);
  assert.equal(body.home_gym_id, '1');
  assert.equal(body.membership_active, true);
  const query = api.calls.find(call => call.rpc === 'gymflow_my_profile');
  assert.equal(query.token, 'valid-token');
});

test('balance uses database aggregate, history uses verified user', async t => {
  const api = await start(t);
  const headers = { Authorization: 'Bearer valid-token' };
  assert.deepEqual(await (await fetch(`${api.url}/points/balance`, { headers })).json(), { balance: 30 });
  assert.ok(api.calls.some(call => call.rpc === 'get_my_point_balance' && call.token === 'valid-token'));
  assert.deepEqual(await (await fetch(`${api.url}/points/history`, { headers })).json(), []);
  assert.deepEqual(api.calls.find(call => call.table === 'point_transactions').filters, [['user_id', memberId]]);
});

test('login returns Flutter token/user fields and refresh info', async t => {
  const api = await start(t);
  const response = await fetch(`${api.url}/auth/login`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: 'member@example.com', password: 'long-password' }),
  });
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.access_token, 'valid-token');
  assert.equal(body.user.name, 'Member');
  assert.equal(body.refresh_token, 'refresh-token');
});

test('register tells callers when email confirmation is required', async t => {
  const api = await start(t, { sessionData: null });
  const response = await fetch(`${api.url}/auth/register`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: 'member@example.com', name: 'Member', password: 'long-password' }),
  });
  assert.equal(response.status, 201);
  const body = await response.json();
  assert.equal(body.access_token, null);
  assert.equal(body.requires_email_confirmation, true);
});

test('input validation rejects role escalation and malformed JSON without auth calls', async t => {
  const api = await start(t);
  const headers = { 'Content-Type': 'application/json' };
  const response = await fetch(`${api.url}/auth/register`, {
    method: 'POST', headers,
    body: JSON.stringify({ email: 'member@example.com', name: 'Member', password: 'long-password', role: 'ADMIN' }),
  });
  assert.equal(response.status, 400);
  assert.ok(!api.calls.some(call => call.signup));
  assert.equal((await fetch(`${api.url}/auth/login`, { method: 'POST', headers, body: '{' })).status, 400);
  assert.equal((await fetch(`${api.url}/gym/check`, { method: 'POST', headers, body: '{}' })).status, 404);
});

test('invalid env errors never include the supplied credential value', () => {
  assert.throws(() => readConfig({ SUPABASE_URL: 'not-a-url', SUPABASE_PUBLISHABLE_KEY: 'SECRET' }),
    error => error.message.includes('SUPABASE_URL') && !error.message.includes('SECRET'));
});

test('QR uses 10 uppercase letters/digits, retries collisions, and check-in normalizes only short codes', async t => {
  const tokens = new Set(Array.from({length:1000},createQrToken));
  assert.equal(tokens.size,1000);
  for(const token of tokens) {
    assert.match(token,/^[A-Z0-9]{10}$/);
    assert.match(token,/[A-Z]/);
    assert.match(token,/[0-9]/);
  }
  let attempts=0;
  const api=await start(t,{rpcResult:(_name,args)=> {
    if(args.action==='admin_qr' && ++attempts===1) return {error:{code:'23505'},data:null};
    return {data:{id:'issued'},error:null};
  }});
  const headers={Authorization:'Bearer valid-token','Content-Type':'application/json'};
  const issued=await fetch(`${api.url}/admin/qr-tokens`,{method:'POST',headers,body:JSON.stringify({gym_id:'1',minutes:15})});
  assert.equal(issued.status,201);
  const {token}=await issued.json();
  assert.match(token,/^[A-Z0-9]{10}$/);
  assert.equal(attempts,2);
  const qrCalls=api.calls.filter(c=>c.args?.action==='admin_qr');
  assert.equal(qrCalls[1].args.payload.token_hash,createHash('sha256').update(token).digest('hex'));
  assert.ok(!JSON.stringify(qrCalls).includes(token));
  for(const raw of ['ab12cd34ef','Old-UUID-with-Mixed-Case']) {
    const res=await fetch(`${api.url}/gym/check-in`,{method:'POST',headers,body:JSON.stringify({token:raw})});
    assert.equal(res.status,200);
    const call=api.calls.filter(c=>c.args?.action==='check_in').at(-1);
    const normalized=raw.length===10 ? raw.toUpperCase() : raw;
    assert.equal(call.args.payload.token_hash,createHash('sha256').update(normalized).digest('hex'));
  }
});

test('password recovery requires a recovery OTP and never returns recovery credentials',async t=> {
  const api=await start(t);
  const headers={'Content-Type':'application/json'};
  const post=(path,body)=>fetch(`${api.url}/auth/${path}`,{method:'POST',headers,body:JSON.stringify(body)});
  assert.equal((await post('forgot-password',{email:'member@example.com'})).status,200);
  assert.equal(api.calls.find(c=>c.recoveryEmail).recoveryEmail,'member@example.com');
  const deliveryFailed=await start(t,{emailError:{message:'Email address not authorized'}});
  const failedMail=await fetch(`${deliveryFailed.url}/auth/forgot-password`,{method:'POST',headers,body:JSON.stringify({email:'member@example.com'})});
  assert.equal(failedMail.status,200);
  assert.ok(!JSON.stringify(await failedMail.json()).includes('not authorized'));
  assert.equal((await post('reset-password',{email:'member@example.com',token:'123456',password:'short'})).status,400);
  assert.ok(!api.calls.some(c=>c.verify));
  const response=await post('reset-password',{email:'member@example.com',token:'123456',password:'new-password123'});
  assert.equal(response.status,200);
  assert.equal((await response.json()).access_token,undefined);
  assert.deepEqual(api.calls.find(c=>c.verify).verify,{email:'member@example.com',token:'123456',type:'recovery'});
  assert.deepEqual(api.calls.find(c=>c.updateUser).updateUser,{password:'new-password123'});
  assert.deepEqual(api.calls.find(c=>c.signout).signout,{scope:'global'});
  const rejected=await start(t,{recoveryError:{message:'expired'}});
  const bad=await fetch(`${rejected.url}/auth/reset-password`,{method:'POST',headers,body:JSON.stringify({email:'member@example.com',token:'123456',password:'new-password123'})});
  assert.equal(bad.status,400);
  assert.ok(!rejected.calls.some(c=>c.updateUser));
});

test('image uploads use caller paths, check image signatures, and deny member catalogue writes',async t=> {
  const api=await start(t);
  const bytes=Uint8Array.from([137,80,78,71,13,10,26,10,0]);
  const headers={Authorization:'Bearer valid-token','Content-Type':'image/png'};
  const post=(kind,body)=>fetch(`${api.url}/media/${kind}`,{method:'POST',headers,body});
  assert.equal((await post('avatars',new Uint8Array([1,2,3]))).status,400);
  assert.ok(!api.calls.some(c=>c.upload));
  assert.equal((await post('rewards',bytes)).status,403);
  const response=await post('avatars',bytes);
  assert.equal(response.status,201);
  const data=await response.json();
  assert.match(data.path,new RegExp(`^avatars/${memberId}/[0-9a-f-]{36}\\.png$`));
  const call=api.calls.find(c=>c.upload);
  assert.equal(call.token,'valid-token');
  assert.deepEqual(call.upload.bytes,Array.from(bytes));
  assert.equal(call.upload.options.upsert,false);
  const admin=await start(t,{role:'ADMIN'});
  assert.equal((await fetch(`${admin.url}/media/trainers`,{method:'POST',headers,body:bytes})).status,201);
});

test('profile image path is validated by an authenticated RPC and current QR is admin-only',async t=> {
  const api=await start(t);
  const headers={Authorization:'Bearer valid-token','Content-Type':'application/json'};
  const response=await fetch(`${api.url}/me`,{method:'PATCH',headers,body:JSON.stringify({name:'Member',avatar_path:`avatars/${memberId}/${crypto.randomUUID()}.png`})});
  assert.equal(response.status,200);
  assert.equal(api.calls.find(c=>c.rpc==='gymflow_update_profile').token,'valid-token');
  const forbidden=await start(t,{databaseError:{message:'FORBIDDEN'}});
  assert.equal((await fetch(`${forbidden.url}/admin/qr-current`,{headers})).status,403);
  assert.equal((await fetch(`${api.url}/admin/qr-current`)).status,401);
});
