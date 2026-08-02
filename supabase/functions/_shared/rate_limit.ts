import { createClient, SupabaseClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

export function adminClient(): SupabaseClient {
  return createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
}

/// Resolves the caller's user id from their JWT. The platform already rejects
/// requests without a valid token, but the id is needed to attribute usage,
/// and it must come from the verified token rather than the request body.
export async function userIdFrom(
  authHeader: string,
): Promise<string | null> {
  const client = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data, error } = await client.auth.getUser();
  if (error || !data.user) return null;
  return data.user.id;
}

/// Returns true when the call is within budget. Fails **closed** on an
/// unexpected error: a rate limiter that silently stops limiting when the
/// database misbehaves is the same as having none.
export async function withinRateLimit(
  admin: SupabaseClient,
  userId: string,
  action: string,
  maxCalls: number,
  windowSeconds: number,
): Promise<boolean> {
  const { data, error } = await admin.rpc("consume_rate_limit", {
    p_user_id: userId,
    p_action: action,
    p_max_calls: maxCalls,
    p_window_seconds: windowSeconds,
  });

  if (error) {
    console.error("Rate limit check failed:", error);
    return false;
  }

  // Cheap opportunistic cleanup so the events table doesn't grow forever.
  if (Math.random() < 0.01) {
    admin.rpc("prune_rate_limit_events").then(({ error: pruneError }) => {
      if (pruneError) console.error("Prune failed:", pruneError);
    });
  }

  return data === true;
}
