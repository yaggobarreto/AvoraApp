// Proxies TMDB movie search so the API key never ships inside the Flutter app.
// Expects: GET /tmdb-search?query=interestelar
import { corsHeaders } from "../_shared/cors.ts";

const TMDB_API_KEY = Deno.env.get("TMDB_API_KEY");
const TMDB_BASE_URL = "https://api.themoviedb.org/3";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const url = new URL(req.url);
  const query = url.searchParams.get("query");

  if (!query) {
    return new Response(JSON.stringify({ error: "Missing 'query' parameter" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const tmdbUrl = `${TMDB_BASE_URL}/search/movie?query=${encodeURIComponent(query)}&language=pt-BR&include_adult=false`;

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
