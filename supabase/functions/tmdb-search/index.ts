// Proxies TMDB multi-search (movies + TV) so the API key never ships inside
// the Flutter app. Expects: GET /tmdb-search?query=interestelar
import {
  errorResponse,
  fetchTmdb,
  jsonResponse,
  serveTmdb,
} from "../_shared/tmdb.ts";

const MAX_QUERY_LENGTH = 120;

serveTmdb(async (req) => {
  const url = new URL(req.url);
  const query = url.searchParams.get("query")?.trim() ?? "";

  if (query.length === 0) {
    return errorResponse(req, "Missing 'query' parameter", 400);
  }
  if (query.length > MAX_QUERY_LENGTH) {
    return errorResponse(req, "Query too long", 400);
  }

  const data = await fetchTmdb(
    `/search/multi?query=${encodeURIComponent(query)}` +
      `&language=pt-BR&include_adult=false`,
  ) as { results?: { media_type?: string }[] };

  // Multi-search also returns "person" results (actors/directors) — this app
  // only cares about movies and TV shows.
  if (Array.isArray(data.results)) {
    data.results = data.results.filter(
      (item) => item.media_type === "movie" || item.media_type === "tv",
    );
  }

  return jsonResponse(req, data);
});
