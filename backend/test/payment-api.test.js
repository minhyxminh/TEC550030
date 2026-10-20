import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { createApp } from '../src/app.js';

const memberId = 'a0000000-0000-4000-8000-000000000001';
const membershipId = '10000000-0000-4000-8000-000000000001';
const orderId = 'b0000000-0000-4000-8000-000000000001';
const paymentCode = 'GFABCDEF123456';
const user = {
  id: memberId,
  email: 'member@example.com',
  user_metadata: { name: 'Member' },
};

function makeApi() {
  const calls = [];
  const userClient = {
    auth: {
      async getUser(token) {
        return token === 'valid-token'
          ? { data: { user }, error: null }
          : { data: { user: null }, error: { message: 'invalid' } };
      },
    },
    async rpc(name, args) {
      calls.push({ client: 'user', name, args });
      if (name === 'gymflow_create_membership_payment') {
        return {
          data: {
            id: orderId,
            membership_id: membershipId,
            membership_name: 'Basic',
            price_vnd_at_order: 300000,
            payment_amount_vnd: 5000,
            payment_code: paymentCode,
            payment_status: 'UNPAID',
            status: 'PENDING',
            points_on_activation: 100,
          },
          error: null,
        };
      }
      if (name === 'gymflow_get_membership_payment') {
        return {
          data: {
            id: orderId,
            membership_id: membershipId,
            membership_name: 'Basic',
            payment_amount_vnd: 5000,
            payment_code: paymentCode,
            payment_status: 'PAID',
            status: 'APPROVED',
            points_on_activation: 100,
          },
          error: null,
        };
      }
      return { data: null, error: null };
    },
  };
  const serviceClient = {
    async rpc(name, args) {
      calls.push({ client: 'service', name, args });
      return {
        data: {
          matched: true,
          paid: true,
          order_id: orderId,
          payment_code: paymentCode,
        },
        error: null,
      };
    },
  };

  const app = createApp({
    createSupabase: () => userClient,
    createServiceSupabase: () => serviceClient,
    paymentConfig: {
      bankId: '970415',
      accountNo: '1234567890',
      accountName: 'GYMFLOW DEMO',
      sepayApiKey: 'test-sepay-api-key-123456',
    },
    corsOrigins: '*',
  });
  return { app, calls };
}

async function start(t) {
  const api = makeApi();
  const server = api.app.listen(0, '127.0.0.1');
  await once(server, 'listening');
  t.after(() => {
    server.closeAllConnections();
    return new Promise(resolve => server.close(resolve));
  });
  return { ...api, url: `http://127.0.0.1:${server.address().port}` };
}

test('membership payment endpoints require auth and return configured real QR data', async t => {
  const api = await start(t);
  const body = {
    membership_id: membershipId,
    idempotency_key: crypto.randomUUID(),
  };

  const unauth = await fetch(`${api.url}/payments/membership-orders`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  assert.equal(unauth.status, 401);

  const response = await fetch(`${api.url}/payments/membership-orders`, {
    method: 'POST',
    headers: {
      Authorization: 'Bearer valid-token',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });
  assert.equal(response.status, 201);
  const order = await response.json();
  assert.equal(order.payment_amount_vnd, 5000);
  assert.equal(order.payment_ready, true);
  assert.equal(order.bank.account_no, '1234567890');
  assert.match(order.qr_url, /^https:\/\/img\.vietqr\.io\/image\/970415-1234567890-compact\.svg\?/);
  assert.match(order.qr_url, /amount=5000/);
  assert.match(order.qr_url, /SEVQR/);
  assert.match(order.qr_url, new RegExp(paymentCode));

  const rpc = api.calls.find(c => c.name === 'gymflow_create_membership_payment');
  assert.equal(rpc.client, 'user');
  assert.equal(rpc.args.membership_id_input, membershipId);
});

test('SePay webhook rejects spoofing and settles incoming transaction with service client', async t => {
  const api = await start(t);
  const payload = {
    id: 92704,
    gateway: 'Vietcombank',
    transactionDate: '2026-10-20 16:30:00',
    accountNumber: '1234567890',
    code: paymentCode,
    content: `${paymentCode} thanh toan GymFlow`,
    transferType: 'in',
    transferAmount: 5000,
    referenceCode: 'FT2600001',
  };

  const bad = await fetch(`${api.url}/webhooks/sepay`, {
    method: 'POST',
    headers: {
      Authorization: 'Apikey wrong',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
  });
  assert.equal(bad.status, 401);

  const good = await fetch(`${api.url}/webhooks/sepay`, {
    method: 'POST',
    headers: {
      Authorization: 'Apikey test-sepay-api-key-123456',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
  });
  assert.equal(good.status, 200);
  const data = await good.json();
  assert.deepEqual(data, { success: true });

  const rpc = api.calls.find(c => c.client === 'service');
  assert.equal(rpc.name, 'gymflow_confirm_membership_payment');
  assert.equal(rpc.args.payment_code_input, paymentCode);
  assert.equal(rpc.args.provider_transaction_id_input, '92704');
  assert.equal(rpc.args.transfer_amount_input, 5000);
  assert.match(rpc.args.provider_transaction_at_input, /\+07:00$/);
});

test('SePay webhook safely ignores outgoing or unrelated bank transactions', async t => {
  const api = await start(t);
  const headers = {
    Authorization: 'Apikey test-sepay-api-key-123456',
    'Content-Type': 'application/json',
  };

  const outgoing = await fetch(`${api.url}/webhooks/sepay`, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      id: 1,
      content: paymentCode,
      transferType: 'out',
      transferAmount: 5000,
    }),
  });
  assert.deepEqual(await outgoing.json(), {
    success: true,
    ignored: true,
    reason: 'NOT_INCOMING',
  });

  const unrelated = await fetch(`${api.url}/webhooks/sepay`, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      id: 2,
      content: 'chuyen tien binh thuong',
      transferType: 'in',
      transferAmount: 5000,
    }),
  });
  assert.deepEqual(await unrelated.json(), {
    success: true,
    ignored: true,
    reason: 'NO_PAYMENT_CODE',
  });

  assert.equal(api.calls.filter(c => c.client === 'service').length, 0);
});
