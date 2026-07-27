// Proxies TMDB movie details + credits + videos in one call, used when the
// user selects a movie from search results to populate the `movies` cache table.
// Expects: GET /tmdb-movie-details?tmdb_id=157336
import { corsHeaders } from "../_shared/cors.ts";

const TMDB_API_KEY = Deno.env.get("TMDB_API_KEY");
const TMDB_BASE_URL = "https://api.themoviedb.org/3";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const url = new URL(req.url);
  const tmdbId = url.searchParams.get("tmdb_id");

  if (!tmdbId) {
    return new Response(JSON.stringify({ error: "Missing 'tmdb_id' parameter" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const tmdbUrl = `${TMDB_BASE_URL}/movie/${tmdbId}?language=pt-BR&append_to_response=credits,videos`;

  const tmdbResponse = await fetch(tmdbUrl, {
    headers: {
      Authorization: `Bearer ${TMDB_API_KEY}`,
      accept: "application/json",
    },
  });

  const data = await tmdbResponse.json();

  return new Response(JSON.stringify(data), {
    status: tmdbResponse.status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
