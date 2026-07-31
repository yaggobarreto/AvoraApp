import { corsHeadersFor } from "./cors.ts";

const TMDB_API_KEY = Deno.env.get("TMDB_API_KEY");
export const TMDB_BASE_URL = "https://api.themoviedb.org/3";

/// TMDB ids go straight into the request path, so anything other than digits
/// would let a caller pivot to arbitrary TMDB endpoints using our key
/// (e.g. tmdb_id="550/reviews"). Reject rather than sanitize.
export function parseTmdbId(raw: string | null): number | null {
  if (raw === null || !/^\d{1,12}$/.test(raw)) return null;
  const value = Number(raw);
  return Number.isSafeInteger(value) && value > 0 ? value : null;
}

export function parseMediaType(raw: string | null): "movie" | "tv" {
  return raw === "tv" ? "tv" : "movie";
}

export function jsonResponse(
  req: Request,
  body: unknown,
  status = 200,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeadersFor(req), "Content-Type": "application/json" },
  });
}

export function errorResponse(
  req: Request,
  message: string,
  status: number,
): Response {
  return jsonResponse(req, { error: message }, status);
}

export async function fetchTmdb(path: string): Promise<unknown> {
  const response = await fetch(`${TMDB_BASE_URL}${path}`, {
    headers: {
      Authorization: `Bearer ${TMDB_API_KEY}`,
      accept: "application/json",
    },
  });

  if (!response.ok) {
    // Upstream error bodies can name internal endpoints and key state, so
    // they're logged server-side and never forwarded to the client.
    console.error(`TMDB request failed: ${response.status} ${path}`);
    throw new Error("upstream_error");
  }

  return await response.json();
}

/// Wraps a handler so unexpected failures return a generic message instead of
/// a Deno stack trace, and OPTIONS preflight is handled uniformly.
export function serveTmdb(handler: (req: Request) => Promise<Response>) {
  Deno.serve(async (req) => {
    if (req.method === "OPTIONS") {
      return new Response("ok", { headers: corsHeadersFor(req) });
    }
    if (req.method !== "GET") {
      return errorResponse(req, "Method not allowed", 405);
    }
    if (!TMDB_API_KEY) {
      console.error("TMDB_API_KEY is not configured");
      return errorResponse(req, "Service unavailable", 503);
    }

    try {
      return await handler(req);
    } catch (error) {
      console.error("Unhandled function error:", error);
      return errorResponse(req, "Something went wrong", 502);
    }
  });
}
