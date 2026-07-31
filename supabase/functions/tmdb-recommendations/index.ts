// Proxies TMDB's own "if you liked X" recommendations, seeded from a movie
// or show the user (or their group) already rated highly — a pragmatic
// stand-in for a custom recommendation algorithm.
// Expects: GET /tmdb-recommendations?tmdb_id=157336&media_type=movie
import { corsHeaders } from "../_shared/cors.ts";

const TMDB_API_KEY = Deno.env.get("TMDB_API_KEY");
const TMDB_BASE_URL = "https://api.themoviedb.org/3";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const url = new URL(req.url);
  const tmdbId = url.searchParams.get("tmdb_id");
  const mediaType = url.searchParams.get("media_type") === "tv" ? "tv" : "movie";

  if (!tmdbId) {
    return new Response(JSON.stringify({ error: "Missing 'tmdb_id' parameter" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const tmdbUrl =
    `${TMDB_BASE_URL}/${mediaType}/${tmdbId}/recommendations?language=pt-BR`;

  const tmdbResponse = await fetch(tmdbUrl, {
    headers: {
      Authorization: `Bearer ${TMDB_API_KEY}`,
      accept: "application/json",
    },
  });

  const data = await tmdbResponse.json();

  // The recommendations endpoint doesn't tag results with media_type (it's
  // implicitly the same type as the seed), so inject it for consistent
  // parsing on the client.
  if (Array.isArray(data.results)) {
    data.results = data.results.map((item: Record<string, unknown>) => ({
      ...item,
      media_type: mediaType,
    }));
  }

  return new Response(JSON.stringify(data), {
    status: tmdbResponse.status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
