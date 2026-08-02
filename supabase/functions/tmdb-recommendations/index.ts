// Proxies TMDB's own "if you liked X" recommendations, seeded from a movie
// or show the user (or their group) already rated highly — a pragmatic
// stand-in for a custom recommendation algorithm.
// Expects: GET /tmdb-recommendations?tmdb_id=157336&media_type=movie
import {
  errorResponse,
  fetchTmdb,
  jsonResponse,
  parseMediaType,
  parseTmdbId,
  serveTmdb,
} from "../_shared/tmdb.ts";

serveTmdb(async (req) => {
  const url = new URL(req.url);
  const tmdbId = parseTmdbId(url.searchParams.get("tmdb_id"));
  const mediaType = parseMediaType(url.searchParams.get("media_type"));

  if (tmdbId === null) {
    return errorResponse(req, "Invalid 'tmdb_id' parameter", 400);
  }

  const data = await fetchTmdb(
    `/${mediaType}/${tmdbId}/recommendations?language=pt-BR`,
  ) as { results?: unknown[] };

  // The recommendations endpoint doesn't tag results with media_type (it's
  // implicitly the same type as the seed), so inject it for consistent
  // parsing on the client.
  if (Array.isArray(data.results)) {
    data.results = data.results.map((item) => ({
      ...(item as Record<string, unknown>),
      media_type: mediaType,
    }));
  }

  return jsonResponse(req, data);
});
