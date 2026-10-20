import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';

export async function buildEdgeSource() {
  const [app, supabase, lockText] = await Promise.all([
    readFile(new URL('../src/app.js', import.meta.url), 'utf8'),
    readFile(new URL('../src/supabase.js', import.meta.url), 'utf8'),
    readFile(new URL('../package-lock.json', import.meta.url), 'utf8'),
  ]);
  const lock = JSON.parse(lockText);
  const pinImports = source => source.replace(/from '([^']+)'/g, (match, name) => {
    const version = lock.packages[`node_modules/${name}`]?.version;
    if (!version) throw new Error(`Missing locked dependency: ${name}`);
    return `from 'npm:${name}@${version}'`;
  });
  return `// @ts-nocheck
// Generated from backend/src/app.js and supabase.js. Do not edit by hand.
// Rebuild with: cd backend && npm.cmd run build:edge
${pinImports(app)}
${pinImports(supabase)}
// Supabase forwards URLs with the function name included in the path.
export function createEdgeApp(options) {
  const gateway = express();
  gateway.disable('x-powered-by');
  gateway.use('/gymflow-api', createApp(options));
  return gateway;
}

if (typeof Deno !== 'undefined') {
  const url = Deno.env.get('SUPABASE_URL');
  const namedKeys = JSON.parse(Deno.env.get('SUPABASE_PUBLISHABLE_KEYS') || '{}');
  const key = Deno.env.get('SUPABASE_PUBLISHABLE_KEY') || namedKeys.default || Deno.env.get('SUPABASE_ANON_KEY');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !key) throw new Error('Missing Supabase URL or publishable/anon key.');
  const gateway = createEdgeApp({
    // User routes stay on the unprivileged key + JWT/RLS.
    createSupabase: makeClientFactory({ SUPABASE_URL: url, SUPABASE_PUBLISHABLE_KEY: key }),
    // Trusted webhook settlement is isolated to the payment endpoint.
    createServiceSupabase: serviceKey
      ? makeClientFactory({ SUPABASE_URL: url, SUPABASE_PUBLISHABLE_KEY: serviceKey })
      : null,
    paymentConfig: {
      bankId: Deno.env.get('PAYMENT_BANK_ID'),
      accountNo: Deno.env.get('PAYMENT_ACCOUNT_NO'),
      accountName: Deno.env.get('PAYMENT_ACCOUNT_NAME'),
      sepayApiKey: Deno.env.get('SEPAY_API_KEY'),
    },
    corsOrigins: '*',
    trustProxy: 1,
  });
  gateway.listen(8000);
}
`;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const target = new URL('../../supabase/functions/gymflow-api/index.ts', import.meta.url);
  await mkdir(new URL('.', target), { recursive: true });
  await writeFile(target, await buildEdgeSource(), 'utf8');
  console.log('Created supabase/functions/gymflow-api/index.ts. Paste into Supabase Dashboard to deploy.');
}
