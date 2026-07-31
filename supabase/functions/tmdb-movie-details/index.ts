// Proxies TMDB movie/TV details + credits + videos + watch providers in one
// call. Used both to populate the `movies` cache table when a title is first
// selected, and to render the full detail page (streaming availability goes
// stale, so that page always calls this fresh instead of relying on the cache).
// Expects: GET /tmdb-movie-details?tmdb_id=157336&media_type=movie
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
    `${TMDB_BASE_URL}/${mediaType}/${tmdbId}?language=pt-BR` +
    `&append_to_response=credits,videos,watch/providers`;

  const tmdbResponse = await fetch(tmdbUrl, {
    headers: {
      Authorization: `Bearer ${TMDB_API_KEY}`,
      accept: "application/json",
    },
  });

  const data = await tmdbResponse.json();

  return new Response(JSON.stringify({ ...data, media_type: mediaType }), {
    status: tmdbResponse.status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
