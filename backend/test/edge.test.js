import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { readFile } from 'node:fs/promises';
import { buildEdgeSource } from '../scripts/build-edge.mjs';

test('generated deployment exposes the same API under its function prefix with auth and CORS', async t => {
  // Exercise the actual generated code; only translate Deno npm imports for Node.
  const source = (await buildEdgeSource()).replace(/from 'npm:([^']+)'/g, (_, pinned) => {
    const name = pinned.slice(0, pinned.lastIndexOf('@'));
    return `from '${import.meta.resolve(name)}'`;
  });
  const { createEdgeApp } = await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`);
  const user = { id: 'a0000000-0000-4000-8000-000000000001', email: 'member@example.com' };
  const seenTokens = [];
  const gateway = createEdgeApp({ corsOrigins: '*', trustProxy: 1, createSupabase: token => {
    seenTokens.push(token);
    return {
      auth: { getUser: async jwt => jwt === 'valid-token'
        ? { data: { user }, error: null } : { data: { user: null }, error: { message: 'Invalid' } } },
      from: () => ({ select: () => ({
        data: null, error: null,
        eq: () => ({ maybeSingle: async () => ({ data: { id: user.id, name: 'Member' }, error: null }) }),
      }) }),
    };
  } });
  const server = gateway.listen(0, '127.0.0.1');
  await once(server, 'listening');
  t.after(() => { server.closeAllConnections(); return new Promise(resolve => server.close(resolve)); });
  const base = `http://127.0.0.1:${server.address().port}/gymflow-api`;
  assert.deepEqual(await (await fetch(`${base}/health`)).json(), { status: 'ok', database: 'connected' });
  assert.equal((await fetch(`${base}/me`)).status, 401);
  assert.equal((await fetch(`${base}/me`, { headers: { Authorization: 'Bearer forged-token' } })).status, 401);
  const me = await fetch(`${base}/me`, { headers: { Authorization: 'Bearer valid-token' } });
  assert.equal(me.status, 200);
  assert.equal((await me.json()).email, user.email);
  assert.ok(seenTokens.includes('valid-token'));
  const preflight = await fetch(`${base}/auth/login`, {
    method: 'OPTIONS', headers: { Origin: 'https://example.com', 'Access-Control-Request-Method': 'POST' },
  });
  assert.equal(preflight.status, 204);
  assert.equal(preflight.headers.get('access-control-allow-origin'), '*');
});

test('deployment imports are pinned and require no privileged key', async () => {
  const source = await readFile(new URL('../../supabase/functions/gymflow-api/index.ts', import.meta.url), 'utf8');
  assert.equal(source, await buildEdgeSource(), 'Rebuild the deployed source after changing Express routes.');
  assert.match(source, /npm:express@\d+\.\d+\.\d+/);
  assert.match(source, /npm:@supabase\/supabase-js@\d+\.\d+\.\d+/);
  assert.doesNotMatch(source, /SUPABASE_SERVICE_ROLE_KEY|SUPABASE_SECRET_KEY|dotenv|sb_secret_/);
  assert.match(source, /auth\.getUser\(match\[1\]\)/);
});
