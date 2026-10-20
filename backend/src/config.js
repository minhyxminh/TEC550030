import 'dotenv/config';
import { z } from 'zod';

const schema = z.object({
  PORT: z.coerce.number().int().min(1).max(65535).default(3000),
  HOST: z.string().default('0.0.0.0'),
  SUPABASE_URL: z.url(),
  SUPABASE_PUBLISHABLE_KEY: z.string().min(20),
  SUPABASE_SERVICE_ROLE_KEY: z.string().min(20).optional(),
  PAYMENT_BANK_ID: z.string().trim().min(2).max(50).optional(),
  PAYMENT_ACCOUNT_NO: z.string().trim().min(6).max(30).optional(),
  PAYMENT_ACCOUNT_NAME: z.string().trim().min(2).max(100).optional(),
  SEPAY_API_KEY: z.string().min(16).optional(),
  CORS_ORIGINS: z.string().default('http://localhost:3000'),
});

export function readConfig(env = process.env) {
  const result = schema.safeParse(env);
  if (!result.success) {
    // Print field names only: environment values may contain credentials.
    throw new Error(`Invalid/missing environment fields: ${result.error.issues.map(i => i.path.join('.')).join(', ')}`);
  }
  return result.data;
}
