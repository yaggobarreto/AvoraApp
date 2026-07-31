// Origins allowed to call the Edge Functions from a browser. Set
// ALLOWED_ORIGINS (comma-separated) in the function secrets for production;
// the fallback covers local development only.
const ALLOWED_ORIGINS = (Deno.env.get("ALLOWED_ORIGINS") ??
  "http://localhost:5695,http://127.0.0.1:5695")
  .split(",")
  .map((origin) => origin.trim())
  .filter(Boolean);

/// Reflecting only known origins (instead of "*") keeps a random site from
/// spending our TMDB quota through a logged-in visitor's browser.
export function corsHeadersFor(req: Request): Record<string, string> {
  const origin = req.headers.get("Origin");
  const headers: Record<string, string> = {
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "GET, OPTIONS",
    "Vary": "Origin",
    "X-Content-Type-Options": "nosniff",
  };

  if (origin && ALLOWED_ORIGINS.includes(origin)) {
    headers["Access-Control-Allow-Origin"] = origin;
  }

  return headers;
}
