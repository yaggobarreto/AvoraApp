// Proxies TMDB's weekly trending (movies + TV) for the Home tab's
// "Lançamentos" rail. Expects: GET /tmdb-trending
import { corsHeaders } from "../_shared/cors.ts";

const TMDB_API_KEY = Deno.env.get("TMDB_API_KEY");
const TMDB_BASE_URL = "https://api.themoviedb.org/3";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const tmdbUrl = `${TMDB_BASE_URL}/trending/all/week?language=pt-BR`;

  const tmdbResponse = await fetch(tmdbUrl, {
    headers: {
      Authorization: `Bearer ${TMDB_API_KEY}`,
      accept: "application/json",
    },
  });

  const data = await tmdbResponse.json();

  if (Array.isArray(data.results)) {
    data.results = data.results.filter(
      (item: { media_type?: string }) =>
        item.media_type === "movie" || item.media_type === "tv",
    );
  }

  return new Response(JSON.stringify(data), {
    status: tmdbResponse.status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
