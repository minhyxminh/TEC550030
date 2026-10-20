import { readConfig } from './config.js';
import { makeClientFactory } from './supabase.js';
import { createApp } from './app.js';

try {
  const config = readConfig();
  const app = createApp({
    createSupabase: makeClientFactory(config),
    createServiceSupabase: config.SUPABASE_SERVICE_ROLE_KEY
      ? makeClientFactory({
          SUPABASE_URL: config.SUPABASE_URL,
          SUPABASE_PUBLISHABLE_KEY: config.SUPABASE_SERVICE_ROLE_KEY,
        })
      : null,
    paymentConfig: {
      bankId: config.PAYMENT_BANK_ID,
      accountNo: config.PAYMENT_ACCOUNT_NO,
      accountName: config.PAYMENT_ACCOUNT_NAME,
      sepayApiKey: config.SEPAY_API_KEY,
    },
    corsOrigins: config.CORS_ORIGINS.split(',').map(value => value.trim()).filter(Boolean),
  });
  const server = app.listen(config.PORT, config.HOST, () => {
    console.log(`GymFlow API listening on port ${config.PORT}. Verify database via GET /health.`);
  });
  server.on('error', error => { console.error(`Cannot start API: ${error.code}`); process.exitCode = 1; });
  for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => server.close());
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
