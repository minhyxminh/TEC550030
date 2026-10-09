import { createClient } from '@supabase/supabase-js';

export function makeClientFactory(config) {
  // Each request has its own client. Auth calls must never share session state.
  return token => createClient(config.SUPABASE_URL, config.SUPABASE_PUBLISHABLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
    global: token ? { headers: { Authorization: `Bearer ${token}` } } : {},
  });
}
