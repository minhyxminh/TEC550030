import 'dotenv/config';
import { z } from 'zod';

const schema = z.object({
  PORT: z.coerce.number().int().min(1).max(65535).default(3000),
  HOST: z.string().default('0.0.0.0'),
  SUPABASE_URL: z.url(),
  SUPABASE_PUBLISHABLE_KEY: z.string().min(20),
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
