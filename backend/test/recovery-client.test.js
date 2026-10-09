import test from 'node:test';
import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {once} from 'node:events';
import {makeClientFactory} from '../src/supabase.js';

test('installed Supabase SDK holds a recovery session only on its request and updates password with that JWT',async t=> {
  const user={id:'a0000000-0000-4000-8000-000000000001',aud:'authenticated',email:'member@example.com'};
  const jwt=[{alg:'HS256'},{sub:user.id,exp:Math.floor(Date.now()/1000)+3600},'sig'].map(p=>Buffer.from(typeof p==='string'?p:JSON.stringify(p)).toString('base64url')).join('.');
  const calls=[];
  const server=createServer(async(req,res)=> {
    let body='';
    for await(const chunk of req) body+=chunk;
    calls.push({path:req.url,method:req.method,authorization:req.headers.authorization,body:JSON.parse(body || '{}')});
    res.setHeader('Content-Type','application/json');
    if(req.url.startsWith('/auth/v1/logout')) {res.statusCode=204;res.end();return;}
    res.end(JSON.stringify(req.url==='/auth/v1/verify'
      ? {access_token:jwt,refresh_token:'recovery-refresh',token_type:'bearer',expires_in:3600,user}
      : {user}));
  }).listen(0,'127.0.0.1');
  await once(server,'listening');
  t.after(()=> {server.closeAllConnections();return new Promise(resolve=>server.close(resolve));});
  const factory=makeClientFactory({SUPABASE_URL:`http://127.0.0.1:${server.address().port}`,SUPABASE_PUBLISHABLE_KEY:'test-public-key'});
  const client=factory();
  const verified=await client.auth.verifyOtp({email:user.email,token:'123456',type:'recovery'});
  assert.equal(verified.error,null);
  assert.equal((await client.auth.updateUser({password:'new-password123'})).error,null);
  const update=calls.find(c=>c.method==='PUT');
  assert.equal(update.authorization,`Bearer ${jwt}`);
  assert.equal(update.body.password,'new-password123');
  assert.equal((await client.auth.signOut({scope:'global'})).error,null);
  assert.equal((await client.auth.getSession()).data.session,null);
  assert.equal((await factory().auth.getSession()).data.session,null);
});
